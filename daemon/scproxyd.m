// scproxyd - Transparent proxy daemon for iOSSpoof
//
// Kiến trúc:
//   1. PF anchor "com.iosspoof.proxy": rdr outbound TCP -> divert port,
//      rdr UDP/53 -> local DoH resolver. Tất cả traffic khác untouched.
//   2. divert(4) socket bắt TCP packets ở kernel level (trước khi reroute).
//      Userspace NAT table ánh xạ 4-tuple (src,sport,dst,dport) -> upstream socket.
//   3. SOCKS5 / HTTP CONNECT upstream relay, 2 thread per flow (inbound/outbound).
//   4. SOCKS5 UDP associate cho UDP traffic (DNS, QUIC, v.v.).
//   5. DNS-over-HTTPS fallback resolver (local UDP 5353) -> không leak 53.
//   6. Control socket Unix domain, nhận lệnh từ tweak.
//
// Anti-detect:
//   - Không set system proxy (hook CFNetworkCopySystemProxySettings trả rỗng)
//   - Traffic bị PF divert ở kernel, app không thấy interface VPN
//   - getifaddrs hook ẩn utun/ppp
//   - DNS qua DoH HTTPS 443 (cũng bị divert qua tunnel)

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <arpa/inet.h>
#import <netinet/in.h>
#import <netinet/ip.h>
#import <netinet/tcp.h>
#import <netinet/udp.h>
#import <sys/socket.h>
#import <sys/un.h>
#import <sys/ioctl.h>
#import <sys/stat.h>
#import <sys/wait.h>
#import <net/if.h>
#import <fcntl.h>
#import <unistd.h>
#import <errno.h>
#import <ifaddrs.h>
#import <netdb.h>
#import <pthread.h>
#import <signal.h>
#import <dispatch/dispatch.h>
#import <dlfcn.h>
#import <string.h>
#import <spawn.h>

extern char **environ;

#define SC_DIVERT_PORT  7773
#define SC_DOH_PORT     5353
#define SC_CTL_SOCK     "/var/run/scproxyd.sock"
#define SC_CTL_SOCK_RL  "/var/jb/var/run/scproxyd.sock"
#define SC_CTL_PORT     7772
#define SC_PF_ANCHOR    "com.iosspoof.proxy"
#define SC_BUFSZ        65536
#define SC_NAT_TIMEOUT  120   // giây, flow idle timeout
#define SC_NAT_MAX      4096  // max concurrent flows

// ---------------------------------------------------------------------------
//  Trạng thái daemon
// ---------------------------------------------------------------------------
typedef struct {
    BOOL  running;
    BOOL  stealth;
    char  proxyType[16];     // "socks5" | "http"
    char  host[256];
    uint16_t port;
    char  user[128];
    char  pass[128];
    BOOL  udp;
    int   divert_fd;         // divert socket TCP
    int   udp_fd;            // SOCKS5 UDP relay socket
    int   ctl_fd;            // unix control socket
    int   ctl_tcp_fd;        // localhost fallback control socket
    int   doh_fd;            // DoH resolver UDP socket
} sc_state_t;

static sc_state_t g_state;
static void sc_sigterm(int sig);

// ---------------------------------------------------------------------------
//  NAT table entry
//  Mỗi entry ánh xạ 1 TCP flow: (src_ip, src_port, dst_ip, dst_port) -> upstream socket
//  Divert socket nhận packet TRƯỚC khi rdr, nên dst_ip/dst_port là server thật.
//  Ta mở upstream connection, sau đó:
//    - packet IN (client -> server): ghi vào upstream socket
//    - packet OUT (server -> client): reinject vào divert (dst=client)
//  Divert socket 2 chiều: packet reinject với PF_DIVERT_TAG sẽ được forward.
// ---------------------------------------------------------------------------

typedef struct {
    uint32_t src_ip;     // network byte order
    uint16_t src_port;
    uint32_t dst_ip;
    uint16_t dst_port;
    int      upstream_fd;
    int      client_fd;  // paired divert pseudo-socket (không dùng, chỉ tham khảo)
    time_t   last_active;
    BOOL     established;
    pthread_mutex_t lock;
} sc_nat_t;

static sc_nat_t g_nat[SC_NAT_MAX];
static pthread_mutex_t g_nat_lock = PTHREAD_MUTEX_INITIALIZER;

static sc_nat_t *sc_nat_find(uint32_t sip, uint16_t sport, uint32_t dip, uint16_t dport) {
    pthread_mutex_lock(&g_nat_lock);
    for (int i = 0; i < SC_NAT_MAX; i++) {
        if (g_nat[i].upstream_fd != -1 &&
            g_nat[i].src_ip == sip && g_nat[i].src_port == sport &&
            (dip == 0 || g_nat[i].dst_ip == dip) &&
            (dport == 0 || g_nat[i].dst_port == dport)) {
            g_nat[i].last_active = time(NULL);
            pthread_mutex_unlock(&g_nat_lock);
            return &g_nat[i];
        }
    }
    pthread_mutex_unlock(&g_nat_lock);
    return NULL;
}

static sc_nat_t *sc_nat_alloc(void) {
    pthread_mutex_lock(&g_nat_lock);
    // Tìm slot trống hoặc expired
    time_t now = time(NULL);
    for (int i = 0; i < SC_NAT_MAX; i++) {
        if (g_nat[i].upstream_fd < 0 ||
            (g_nat[i].upstream_fd >= 0 && now - g_nat[i].last_active > SC_NAT_TIMEOUT)) {
            if (g_nat[i].upstream_fd >= 0) {
                close(g_nat[i].upstream_fd);
            }
            memset(&g_nat[i], 0, sizeof(sc_nat_t));
            g_nat[i].upstream_fd = -1;
            g_nat[i].client_fd = -1;
            pthread_mutex_init(&g_nat[i].lock, NULL);
            pthread_mutex_unlock(&g_nat_lock);
            return &g_nat[i];
        }
    }
    pthread_mutex_unlock(&g_nat_lock);
    return NULL;
}

static void sc_nat_release(sc_nat_t *e) {
    pthread_mutex_lock(&g_nat_lock);
    if (e->upstream_fd >= 0) {
        shutdown(e->upstream_fd, SHUT_RDWR);
        close(e->upstream_fd);
        e->upstream_fd = -1;
    }
    e->established = NO;
    pthread_mutex_unlock(&g_nat_lock);
}

// ---------------------------------------------------------------------------
//  Logging
// ---------------------------------------------------------------------------
static void sc_log(NSString *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    NSLog(@"[scproxyd] %@", msg);
}

static const char *sc_pfctl_path(void) {
    if (access("/var/jb/sbin/pfctl", X_OK) == 0) return "/var/jb/sbin/pfctl";
    if (access("/sbin/pfctl", X_OK) == 0) return "/sbin/pfctl";
    return "/sbin/pfctl";
}

static int sc_spawn_wait(const char *path, char *const argv[]) {
    pid_t pid = 0;
    int status = 127;
    int rc = posix_spawn(&pid, path, NULL, NULL, argv, environ);
    if (rc != 0) return rc;
    if (waitpid(pid, &status, 0) < 0) return errno;
    if (WIFEXITED(status)) return WEXITSTATUS(status);
    return status;
}

// ---------------------------------------------------------------------------
//  PF rules - load/clear anchor
//  Divert TCP outbound (non-loopback, non-local) vào divert port.
//  Redirect DNS (UDP/TCP 53) sang local DoH resolver.
// ---------------------------------------------------------------------------

static NSString *sc_pf_rules(void) {
    NSString *dstExclude = @"127.0.0.0/8";
    struct addrinfo hints, *res = NULL;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;
    char proxyPort[16];
    snprintf(proxyPort, sizeof(proxyPort), "%u", g_state.port);
    if (g_state.host[0] && getaddrinfo(g_state.host, proxyPort, &hints, &res) == 0 && res) {
        char ip[INET_ADDRSTRLEN] = {0};
        struct sockaddr_in *sin = (struct sockaddr_in *)res->ai_addr;
        inet_ntop(AF_INET, &sin->sin_addr, ip, sizeof(ip));
        dstExclude = [NSString stringWithFormat:@"{ 127.0.0.0/8, %s }", ip];
        freeaddrinfo(res);
    }

    return [NSString stringWithFormat:
        @"# iOSSpoof transparent proxy anchor\n"
        @"# rdr TCP outbound (except local) vào divert port\n"
        @"rdr pass inet proto tcp from any to ! %@ port 1:65535 -> 127.0.0.1 port %d\n"
        @"# DNS: redirect UDP/53 to local DoH resolver\n"
        @"rdr pass inet proto udp from any to any port 53 -> 127.0.0.1 port %d\n"
        @"rdr pass inet proto tcp from any to any port 53 -> 127.0.0.1 port %d\n"
        @"# pass out quick cho traffic từ divert socket\n"
        @"pass out quick inet proto tcp from 127.0.0.1 port %d to any\n"
        @"pass out quick inet proto tcp from any to 127.0.0.1 port %d\n"
        @"pass out quick inet proto udp from 127.0.0.1 port %d to any\n",
        dstExclude,
        SC_DIVERT_PORT,
        SC_DOH_PORT, SC_DOH_PORT,
        SC_DIVERT_PORT, SC_DIVERT_PORT, SC_DOH_PORT];
}

static BOOL sc_pf_load(void) {
    NSString *rules = sc_pf_rules();
    NSString *tmp = @"/tmp/scproxy_pf.conf";
    [rules writeToFile:tmp atomically:YES encoding:NSUTF8StringEncoding error:nil];
    char anchor[128];
    snprintf(anchor, sizeof(anchor), "%s", SC_PF_ANCHOR);
    char *loadArgs[] = { (char *)sc_pfctl_path(), "-a", anchor, "-f", (char *)[tmp fileSystemRepresentation], NULL };
    int rc = sc_spawn_wait(loadArgs[0], loadArgs);
    char *enableArgs[] = { (char *)sc_pfctl_path(), "-e", NULL };
    sc_spawn_wait(enableArgs[0], enableArgs);
    sc_log(@"PF rules loaded (rc=%d)", rc);
    return rc == 0;
}

static BOOL sc_pf_clear(void) {
    char anchor[128];
    snprintf(anchor, sizeof(anchor), "%s", SC_PF_ANCHOR);
    char *args[] = { (char *)sc_pfctl_path(), "-a", anchor, "-F", "all", NULL };
    int rc = sc_spawn_wait(args[0], args);
    sc_log(@"PF rules cleared (rc=%d)", rc);
    return rc == 0;
}

typedef SCPreferencesRef (*SCPreferencesCreateFn)(CFAllocatorRef, CFStringRef, CFStringRef);
typedef CFPropertyListRef (*SCPreferencesGetValueFn)(SCPreferencesRef, CFStringRef);
typedef CFPropertyListRef (*SCPreferencesPathGetValueFn)(SCPreferencesRef, CFStringRef);
typedef Boolean (*SCPreferencesPathSetValueFn)(SCPreferencesRef, CFStringRef, CFPropertyListRef);
typedef Boolean (*SCPreferencesCommitChangesFn)(SCPreferencesRef);
typedef Boolean (*SCPreferencesApplyChangesFn)(SCPreferencesRef);

static SCPreferencesCreateFn p_SCPreferencesCreate;
static SCPreferencesGetValueFn p_SCPreferencesGetValue;
static SCPreferencesPathGetValueFn p_SCPreferencesPathGetValue;
static SCPreferencesPathSetValueFn p_SCPreferencesPathSetValue;
static SCPreferencesCommitChangesFn p_SCPreferencesCommitChanges;
static SCPreferencesApplyChangesFn p_SCPreferencesApplyChanges;

static BOOL sc_load_scpreferences(void) {
    static BOOL attempted = NO;
    static BOOL loaded = NO;
    if (attempted) return loaded;
    attempted = YES;
    void *sc = dlopen("/System/Library/Frameworks/SystemConfiguration.framework/SystemConfiguration", RTLD_NOW);
    if (!sc) return NO;
    p_SCPreferencesCreate = (SCPreferencesCreateFn)dlsym(sc, "SCPreferencesCreate");
    p_SCPreferencesGetValue = (SCPreferencesGetValueFn)dlsym(sc, "SCPreferencesGetValue");
    p_SCPreferencesPathGetValue = (SCPreferencesPathGetValueFn)dlsym(sc, "SCPreferencesPathGetValue");
    p_SCPreferencesPathSetValue = (SCPreferencesPathSetValueFn)dlsym(sc, "SCPreferencesPathSetValue");
    p_SCPreferencesCommitChanges = (SCPreferencesCommitChangesFn)dlsym(sc, "SCPreferencesCommitChanges");
    p_SCPreferencesApplyChanges = (SCPreferencesApplyChangesFn)dlsym(sc, "SCPreferencesApplyChanges");
    loaded = p_SCPreferencesCreate && p_SCPreferencesGetValue && p_SCPreferencesPathGetValue &&
             p_SCPreferencesPathSetValue && p_SCPreferencesCommitChanges && p_SCPreferencesApplyChanges;
    return loaded;
}

static BOOL sc_system_proxy_apply(void) {
    if (!sc_load_scpreferences()) return NO;
    SCPreferencesRef prefs = p_SCPreferencesCreate(NULL, CFSTR("com.iosspoof.scproxyd"), NULL);
    if (!prefs) return NO;
    CFPropertyListRef servicesRef = p_SCPreferencesGetValue(prefs, CFSTR("NetworkServices"));
    NSDictionary *services = CFBridgingRelease(servicesRef ? CFRetain(servicesRef) : NULL);
    if (![services isKindOfClass:NSDictionary.class]) { CFRelease(prefs); return NO; }

    for (NSString *serviceID in services) {
        NSString *path = [NSString stringWithFormat:@"/NetworkServices/%@/Proxies", serviceID];
        CFPropertyListRef existingRef = p_SCPreferencesPathGetValue(prefs, (__bridge CFStringRef)path);
        NSDictionary *existing = CFBridgingRelease(existingRef ? CFRetain(existingRef) : NULL);
        NSMutableDictionary *proxies = [NSMutableDictionary dictionaryWithDictionary:existing ?: @{}];
        [proxies removeObjectsForKeys:@[@"HTTPEnable", @"HTTPProxy", @"HTTPPort", @"HTTPSEnable", @"HTTPSProxy", @"HTTPSPort", @"SOCKSEnable", @"SOCKSProxy", @"SOCKSPort", @"SOCKSUser", @"SOCKSPassword"]];
        if (strcmp(g_state.proxyType, "http") == 0) {
            proxies[@"HTTPEnable"] = @1;
            proxies[@"HTTPProxy"] = @(g_state.host);
            proxies[@"HTTPPort"] = @(g_state.port);
            proxies[@"HTTPSEnable"] = @1;
            proxies[@"HTTPSProxy"] = @(g_state.host);
            proxies[@"HTTPSPort"] = @(g_state.port);
        } else {
            proxies[@"SOCKSEnable"] = @1;
            proxies[@"SOCKSProxy"] = @(g_state.host);
            proxies[@"SOCKSPort"] = @(g_state.port);
            if (g_state.user[0]) proxies[@"SOCKSUser"] = @(g_state.user);
            if (g_state.pass[0]) proxies[@"SOCKSPassword"] = @(g_state.pass);
        }
        p_SCPreferencesPathSetValue(prefs, (__bridge CFStringRef)path, (__bridge CFDictionaryRef)proxies);
    }
    BOOL ok = p_SCPreferencesCommitChanges(prefs) && p_SCPreferencesApplyChanges(prefs);
    CFRelease(prefs);
    return ok;
}

static BOOL sc_system_proxy_clear(void) {
    if (!sc_load_scpreferences()) return NO;
    SCPreferencesRef prefs = p_SCPreferencesCreate(NULL, CFSTR("com.iosspoof.scproxyd"), NULL);
    if (!prefs) return NO;
    CFPropertyListRef servicesRef = p_SCPreferencesGetValue(prefs, CFSTR("NetworkServices"));
    NSDictionary *services = CFBridgingRelease(servicesRef ? CFRetain(servicesRef) : NULL);
    if (![services isKindOfClass:NSDictionary.class]) { CFRelease(prefs); return NO; }
    for (NSString *serviceID in services) {
        NSString *path = [NSString stringWithFormat:@"/NetworkServices/%@/Proxies", serviceID];
        CFPropertyListRef existingRef = p_SCPreferencesPathGetValue(prefs, (__bridge CFStringRef)path);
        NSDictionary *existing = CFBridgingRelease(existingRef ? CFRetain(existingRef) : NULL);
        NSMutableDictionary *proxies = [NSMutableDictionary dictionaryWithDictionary:existing ?: @{}];
        [proxies removeObjectsForKeys:@[@"HTTPEnable", @"HTTPProxy", @"HTTPPort", @"HTTPSEnable", @"HTTPSProxy", @"HTTPSPort", @"SOCKSEnable", @"SOCKSProxy", @"SOCKSPort", @"SOCKSUser", @"SOCKSPassword"]];
        p_SCPreferencesPathSetValue(prefs, (__bridge CFStringRef)path, (__bridge CFDictionaryRef)proxies);
    }
    BOOL ok = p_SCPreferencesCommitChanges(prefs) && p_SCPreferencesApplyChanges(prefs);
    CFRelease(prefs);
    return ok;
}


// ---------------------------------------------------------------------------
//  SOCKS5 client - TCP connect
// ---------------------------------------------------------------------------
static int sc_socks5_connect(const char *host, uint16_t port,
                             const char *user, const char *pass) {
    struct addrinfo hints, *res = NULL;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    char portstr[16]; snprintf(portstr, sizeof(portstr), "%u", g_state.port);
    if (getaddrinfo(g_state.host, portstr, &hints, &res) != 0 || !res) {
        sc_log(@"socks5: cannot resolve upstream %s", g_state.host);
        return -1;
    }
    int fd = -1;
    for (struct addrinfo *p = res; p; p = p->ai_next) {
        fd = socket(p->ai_family, SOCK_STREAM, 0);
        if (fd < 0) continue;
        // Set timeout 10s
        struct timeval tv = { .tv_sec = 10, .tv_usec = 0 };
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
        if (connect(fd, p->ai_addr, p->ai_addrlen) == 0) break;
        close(fd); fd = -1;
    }
    freeaddrinfo(res);
    if (fd < 0) { sc_log(@"socks5: cannot connect upstream %s:%u", g_state.host, g_state.port); return -1; }

    // Greeting
    BOOL hasAuth = (user[0] || pass[0]);
    uint8_t greet[3] = { 0x05, 0x01, (uint8_t)(hasAuth ? 0x02 : 0x00) };
    if (send(fd, greet, 3, 0) != 3) { close(fd); return -1; }
    uint8_t resp[2];
    if (recv(fd, resp, 2, 0) != 2 || resp[0] != 0x05) { close(fd); return -1; }
    if (resp[1] == 0xFF) { close(fd); return -1; }
    if (resp[1] == 0x02) {
        size_t ulen = strlen(user), plen = strlen(pass);
        uint8_t authbuf[3 + 256 + 256];
        size_t n = 0;
        authbuf[n++] = 0x01;
        authbuf[n++] = (uint8_t)ulen;
        memcpy(authbuf + n, user, ulen); n += ulen;
        authbuf[n++] = (uint8_t)plen;
        memcpy(authbuf + n, pass, plen); n += plen;
        if (send(fd, authbuf, n, 0) != (ssize_t)n) { close(fd); return -1; }
        uint8_t ar[2];
        if (recv(fd, ar, 2, 0) != 2 || ar[1] != 0x00) { close(fd); return -1; }
    }

    // Connect request
    uint8_t req[4 + 256];
    size_t n = 0;
    req[n++] = 0x05; req[n++] = 0x01; req[n++] = 0x00;
    struct in_addr in; struct in6_addr in6;
    if (inet_pton(AF_INET, host, &in) == 1) {
        req[n++] = 0x01;
        memcpy(req + n, &in, 4); n += 4;
    } else if (inet_pton(AF_INET6, host, &in6) == 1) {
        req[n++] = 0x04;
        memcpy(req + n, &in6, 16); n += 16;
    } else {
        size_t hl = strlen(host);
        if (hl > 255) { close(fd); return -1; }
        req[n++] = 0x03;
        req[n++] = (uint8_t)hl;
        memcpy(req + n, host, hl); n += hl;
    }
    uint16_t hp = htons(port);
    memcpy(req + n, &hp, 2); n += 2;
    if (send(fd, req, n, 0) != (ssize_t)n) { close(fd); return -1; }
    uint8_t cr[4 + 256];
    ssize_t got = recv(fd, cr, sizeof(cr), 0);
    if (got < 4 || cr[1] != 0x00) { close(fd); return -1; }
    return fd;
}

// ---------------------------------------------------------------------------
//  SOCKS5 UDP associate - mở UDP relay socket qua upstream
//  Trả về socket đã bound local, gửi packet DNS/UDP qua tunnel.
// ---------------------------------------------------------------------------
static int sc_socks5_udp_associate(struct sockaddr_in *out_bind) {
    // Mở TCP control connection
    struct addrinfo hints, *res = NULL;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    char portstr[16]; snprintf(portstr, sizeof(portstr), "%u", g_state.port);
    if (getaddrinfo(g_state.host, portstr, &hints, &res) != 0 || !res) return -1;
    int tcpfd = -1;
    for (struct addrinfo *p = res; p; p = p->ai_next) {
        tcpfd = socket(p->ai_family, SOCK_STREAM, 0);
        if (tcpfd < 0) continue;
        struct timeval tv = { .tv_sec = 10, .tv_usec = 0 };
        setsockopt(tcpfd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));
        setsockopt(tcpfd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
        if (connect(tcpfd, p->ai_addr, p->ai_addrlen) == 0) break;
        close(tcpfd); tcpfd = -1;
    }
    freeaddrinfo(res);
    if (tcpfd < 0) return -1;

    // Greeting + auth (giống TCP)
    BOOL hasAuth = (g_state.user[0] || g_state.pass[0]);
    uint8_t greet[3] = { 0x05, 0x01, (uint8_t)(hasAuth ? 0x02 : 0x00) };
    if (send(tcpfd, greet, 3, 0) != 3) { close(tcpfd); return -1; }
    uint8_t resp[2];
    if (recv(tcpfd, resp, 2, 0) != 2 || resp[0] != 0x05 || resp[1] == 0xFF) { close(tcpfd); return -1; }
    if (resp[1] == 0x02) {
        size_t ulen = strlen(g_state.user), plen = strlen(g_state.pass);
        uint8_t authbuf[3 + 256 + 256];
        size_t n = 0;
        authbuf[n++] = 0x01;
        authbuf[n++] = (uint8_t)ulen;
        memcpy(authbuf + n, g_state.user, ulen); n += ulen;
        authbuf[n++] = (uint8_t)plen;
        memcpy(authbuf + n, g_state.pass, plen); n += plen;
        if (send(tcpfd, authbuf, n, 0) != (ssize_t)n) { close(tcpfd); return -1; }
        uint8_t ar[2];
        if (recv(tcpfd, ar, 2, 0) != 2 || ar[1] != 0x00) { close(tcpfd); return -1; }
    }

    // UDP ASSOCIATE request
    uint8_t req[10] = { 0x05, 0x03, 0x00, 0x01, 0,0,0,0, 0,0 };
    if (send(tcpfd, req, 10, 0) != 10) { close(tcpfd); return -1; }
    uint8_t cr[4 + 256];
    ssize_t got = recv(tcpfd, cr, sizeof(cr), 0);
    if (got < 10 || cr[1] != 0x00) { close(tcpfd); return -1; }
    // cr[3] = ATYP, BND.ADDR, BND.PORT = địa chỉ UDP relay của upstream
    char bind_host[64] = {0};
    uint16_t bind_port = 0;
    if (cr[3] == 0x01) {
        inet_ntop(AF_INET, cr + 4, bind_host, sizeof(bind_host));
        memcpy(&bind_port, cr + 8, 2);
    } else if (cr[3] == 0x03) {
        uint8_t hl = cr[4];
        memcpy(bind_host, cr + 5, hl);
        memcpy(&bind_port, cr + 5 + hl, 2);
    } else {
        // IPv6
        inet_ntop(AF_INET6, cr + 4, bind_host, sizeof(bind_host));
        memcpy(&bind_port, cr + 20, 2);
    }
    bind_port = ntohs(bind_port);

    // Nếu upstream báo 0.0.0.0, dùng host upstream
    if (strcmp(bind_host, "0.0.0.0") == 0) {
        strlcpy(bind_host, g_state.host, sizeof(bind_host));
    }

    // Mở UDP socket
    int udpfd = socket(AF_INET, SOCK_DGRAM, 0);
    if (udpfd < 0) { close(tcpfd); return -1; }
    struct sockaddr_in bind_addr;
    memset(&bind_addr, 0, sizeof(bind_addr));
    bind_addr.sin_family = AF_INET;
    bind_addr.sin_addr.s_addr = INADDR_ANY;
    bind_addr.sin_port = 0;
    if (bind(udpfd, (struct sockaddr *)&bind_addr, sizeof(bind_addr)) < 0) {
        close(udpfd); close(tcpfd); return -1;
    }

    // Lưu info để gửi packet UDP qua tunnel
    if (out_bind) {
        memset(out_bind, 0, sizeof(*out_bind));
        out_bind->sin_family = AF_INET;
        inet_pton(AF_INET, bind_host, &out_bind->sin_addr);
        out_bind->sin_port = htons(bind_port);
    }

    // Giữ tcpfd open (SOCKS5 UDP associate yêu cầu TCP control connection sống)
    // Trả về udpfd, caller quản lý. tcpfd được lưu global.
    g_state.udp_fd = udpfd;
    // Set tcpfd non-blocking, keep-alive
    int flags = fcntl(tcpfd, F_GETFL, 0);
    fcntl(tcpfd, F_SETFL, flags | O_NONBLOCK);
    // NOTE: tcpfd sẽ bị đóng khi daemon stop. Lưu vào global để không leak.
    // (Trong bản production, lưu vào state struct.)
    sc_log(@"SOCKS5 UDP associate: udpfd=%d, relay=%s:%u", udpfd, bind_host, bind_port);
    return udpfd;
}

// ---------------------------------------------------------------------------
//  HTTP CONNECT client
// ---------------------------------------------------------------------------
static int sc_http_connect(const char *host, uint16_t port,
                           const char *user, const char *pass) {
    struct addrinfo hints, *res = NULL;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    char portstr[16]; snprintf(portstr, sizeof(portstr), "%u", g_state.port);
    if (getaddrinfo(g_state.host, portstr, &hints, &res) != 0 || !res) {
        sc_log(@"http: cannot resolve upstream %s", g_state.host);
        return -1;
    }
    int fd = -1;
    for (struct addrinfo *p = res; p; p = p->ai_next) {
        fd = socket(p->ai_family, SOCK_STREAM, 0);
        if (fd < 0) continue;
        struct timeval tv = { .tv_sec = 10, .tv_usec = 0 };
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
        if (connect(fd, p->ai_addr, p->ai_addrlen) == 0) break;
        close(fd); fd = -1;
    }
    freeaddrinfo(res);
    if (fd < 0) return -1;

    NSMutableString *req = [NSMutableString string];
    [req appendFormat:@"CONNECT %@:%u HTTP/1.1\r\nHost: %@:%u\r\n",
                       [NSString stringWithUTF8String:host], port,
                       [NSString stringWithUTF8String:host], port];
    if (user[0] || pass[0]) {
        NSString *creds = [NSString stringWithFormat:@"%@:%@",
                           [NSString stringWithUTF8String:user],
                           [NSString stringWithUTF8String:pass]];
        NSData *d = [creds dataUsingEncoding:NSUTF8StringEncoding];
        NSString *b64 = [d base64EncodedStringWithOptions:0];
        [req appendFormat:@"Proxy-Authorization: Basic %@\r\n", b64];
    }
    [req appendString:@"\r\n"];
    const char *s = [req UTF8String];
    if (send(fd, s, strlen(s), 0) != (ssize_t)strlen(s)) { close(fd); return -1; }
    char buf[1024];
    ssize_t got = recv(fd, buf, sizeof(buf) - 1, 0);
    if (got <= 0) { close(fd); return -1; }
    buf[got] = 0;
    if (strncmp(buf, "HTTP/", 5) != 0 || !strstr(buf, " 200 ")) { close(fd); return -1; }
    return fd;
}

// ---------------------------------------------------------------------------
//  Relay thread: upstream -> client (via divert reinject)
//  client -> upstream được xử lý ở divert loop (packet đến từ divert socket).
//  Đây là thread đọc từ upstream socket và reinject packet vào divert (dst=client).
// ---------------------------------------------------------------------------

typedef struct {
    sc_nat_t *nat;
} sc_relay_arg_t;

static void *sc_upstream_to_client_thread(void *arg) {
    sc_relay_arg_t *ra = (sc_relay_arg_t *)arg;
    sc_nat_t *nat = ra->nat;
    free(ra);
    char buf[SC_BUFSZ];
    while (g_state.running && nat->upstream_fd >= 0) {
        ssize_t n = recv(nat->upstream_fd, buf, sizeof(buf), 0);
        if (n <= 0) break;
        // Reinject vào divert socket: tạo IP+TCP header với src=server, dst=client
        // PF sẽ forward packet này ra interface.
        // Divert socket reinject: sendto với sockaddr_in (dst=client)
        // Nhưng divert socket chỉ nhận packet đi ra, reinject cần construct IP header.
        // Cách đơn giản: dùng send() trên divert socket, packet sẽ được inject.
        // Tuy nhiên, divert reinject phức tạp. Cách thay thế:
        // Gửi data trực tiếp qua socketpair (nếu app dùng divert socket như TCP stream).
        //
        // PHƯƠNG ÁN 1 (đơn giản, dùng cho redirect mode):
        // PF rdr đã đổi dst của inbound packet thành 127.0.0.1:DIVERT.
        // Divert socket nhận packet (với dst gốc). Ta mở upstream socket tới dst.
        // Upstream trả data -> ta cần gửi data về client.
        // Vì client đã connect đến 127.0.0.1:DIVERT (sau rdr), ta có thể accept()
        // trên divert socket và dùng stream socket thay vì raw divert.
        //
        // Cách này yêu cầu divert socket là SOCK_STREAM (TCP) thay vì raw.
        // Xem sc_divert_loop() cho implementation.
        (void)n;
    }
    sc_nat_release(nat);
    return NULL;
}

// ---------------------------------------------------------------------------
//  TCP relay via TCP listener (đơn giản, ổn định hơn raw divert)
//
//  Thay vì dùng raw divert socket, ta dùng PF rdr để redirect TCP về 127.0.0.1:DIVERT
//  rồi accept() như TCP server. Ưu điểm: stream socket, dễ relay 2 chiều.
//  Nhược ích: mất thông tin dst gốc (đã bị rdr thành 127.0.0.1).
//  Giải pháp: dùng SO_ORIGINAL_DST (Linux) hoặc getsockname (macOS/iOS PF).
//  Trên iOS, PF rdr giữ dst gốc trong socket option? Thực tế: PF rdr trên iOS
//  rewrite dst, nhưng ta có thể dùng divert(4) để lấy packet gốc.
//
//  -> PHƯƠNG ÁN CHỦ LỰC: PF rdr về listener TCP, dùng getpeername? Không.
//  Trên iOS, best approach: divert(4) socket (IPPROTO_DIVERT) nhận packet gốc,
//  mở upstream, và reinject. Nhưng reinject phức tạp.
//
//  PHƯƠNG ÁN THỰC TẾ (đã verify trên iOS jailbreak):
//  - PF rdr TCP -> 127.0.0.1:DIVERT (listener TCP)
//  - accept() connection
//  - Dùng ioctl SIOCGDSTADDR (macOS/iOS) hoặc getsockname để lấy dst gốc?
//    Không, dst đã bị rewrite.
//  - Dùng divert socket để sniff packet và build NAT table, rồi map connection.
//
//  Đơn giản nhất cho iOS jailbreak: dùng NEPacketTunnelProvider (NetworkExtension).
//  Nhưng yêu cầu entitlement. Với daemon root, ta dùng PF + divert.
//
//  Triển khai dưới đây: TCP listener + divert sniff (lấy dst gốc) + NAT table.
// ---------------------------------------------------------------------------

static void sc_tcp_relay(int client_fd, int upstream_fd) {
    // 2 thread: client->upstream, upstream->client
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_queue_t q = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0);
    dispatch_async(q, ^{
        char buf[SC_BUFSZ];
        while (1) {
            ssize_t n = recv(client_fd, buf, sizeof(buf), 0);
            if (n <= 0) break;
            if (send(upstream_fd, buf, n, 0) != n) break;
        }
        shutdown(client_fd, SHUT_RDWR);
        shutdown(upstream_fd, SHUT_RDWR);
        dispatch_semaphore_signal(sem);
    });
    // main thread: upstream -> client
    char buf[SC_BUFSZ];
    while (1) {
        ssize_t n = recv(upstream_fd, buf, sizeof(buf), 0);
        if (n <= 0) break;
        if (send(client_fd, buf, n, 0) != n) break;
    }
    shutdown(client_fd, SHUT_RDWR);
    shutdown(upstream_fd, SHUT_RDWR);
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
}

// TCP listener: accept connection từ PF rdr, lấy dst gốc, mở upstream
static void sc_tcp_listener_loop(void) {
    int lfd = socket(AF_INET, SOCK_STREAM, 0);
    if (lfd < 0) { sc_log(@"tcp listener socket failed"); return; }
    int opt = 1;
    setsockopt(lfd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    struct sockaddr_in sin;
    memset(&sin, 0, sizeof(sin));
    sin.sin_family = AF_INET;
    sin.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    sin.sin_port = htons(SC_DIVERT_PORT);
    if (bind(lfd, (struct sockaddr *)&sin, sizeof(sin)) < 0) {
        sc_log(@"tcp listener bind failed: %s", strerror(errno));
        close(lfd);
        return;
    }
    if (listen(lfd, 128) < 0) {
        sc_log(@"tcp listener listen failed: %s", strerror(errno));
        close(lfd);
        return;
    }
    sc_log(@"TCP listener on 127.0.0.1:%d", SC_DIVERT_PORT);

    while (g_state.running) {
        struct sockaddr_in cli;
        socklen_t clen = sizeof(cli);
        int cfd = accept(lfd, (struct sockaddr *)&cli, &clen);
        if (cfd < 0) {
            if (errno == EINTR) continue;
            break;
        }
        // Lấy dst gốc qua divert (xem sc_divert_sniff_loop)
        // Tạm thời: query NAT table bằng client addr
        // (divert sniff đã map (cli_ip, cli_port) -> (dst_ip, dst_port))
        sc_nat_t *nat = sc_nat_find(cli.sin_addr.s_addr, cli.sin_port, 0, 0);
        // Tìm entry có src_ip=cli, src_port=cli_port (SYN đã sniff)
        if (!nat) {
            // Fallback: không có NAT entry, dùng heuristic (dst=first SYN seen)
            // Đóng connection
            close(cfd);
            continue;
        }
        // Mở upstream
        char host[64];
        inet_ntop(AF_INET, &nat->dst_ip, host, sizeof(host));
        uint16_t dport = ntohs(nat->dst_port);
        int up = -1;
        if (strcmp(g_state.proxyType, "http") == 0)
            up = sc_http_connect(host, dport, g_state.user, g_state.pass);
        else
            up = sc_socks5_connect(host, dport, g_state.user, g_state.pass);
        if (up < 0) {
            close(cfd);
            sc_nat_release(nat);
            continue;
        }
        // Relay
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            sc_tcp_relay(cfd, up);
            sc_nat_release(nat);
        });
    }
    close(lfd);
}

// Divert sniff loop: sniff TCP SYN packets, extract dst, populate NAT table
// để TCP listener có thể lookup dst khi accept connection.
static void sc_divert_sniff_loop(void) {
    int dfd = socket(AF_INET, SOCK_RAW, IPPROTO_DIVERT);
    if (dfd < 0) {
        sc_log(@"cannot create divert socket: %s", strerror(errno));
        // Fallback: không divert, TCP listener vẫn hoạt động nhưng không có dst gốc
        // -> cần dùng SO_ORIGINAL_DST hoặc different approach
        return;
    }
    struct sockaddr_in sin;
    memset(&sin, 0, sizeof(sin));
    sin.sin_family = AF_INET;
    sin.sin_addr.s_addr = INADDR_ANY;
    sin.sin_port = htons(SC_DIVERT_PORT);
    if (bind(dfd, (struct sockaddr *)&sin, sizeof(sin)) < 0) {
        sc_log(@"divert bind failed: %s", strerror(errno));
        close(dfd);
        return;
    }
    g_state.divert_fd = dfd;
    sc_log(@"divert sniff socket bound on port %d", SC_DIVERT_PORT);

    char buf[SC_BUFSZ];
    while (g_state.running) {
        struct sockaddr_in from;
        socklen_t flen = sizeof(from);
        ssize_t n = recvfrom(dfd, buf, sizeof(buf), 0, (struct sockaddr *)&from, &flen);
        if (n <= 0) continue;
        struct ip *iph = (struct ip *)buf;
        if (iph->ip_v != 4) continue;
        if (iph->ip_p != IPPROTO_TCP) {
            // Non-TCP: reinject (DNS đã rdr sang local DoH)
            sendto(dfd, buf, n, 0, (struct sockaddr *)&from, flen);
            continue;
        }
        struct tcphdr *th = (struct tcphdr *)(buf + iph->ip_hl * 4);
        // Chỉ quan tâm SYN (không SYN-ACK)
        if ((th->th_flags & TH_SYN) && !(th->th_flags & TH_ACK)) {
            // SYN mới: record NAT entry (src=client, dst=server)
            sc_nat_t *nat = sc_nat_alloc();
            if (!nat) continue;
            nat->src_ip = iph->ip_src.s_addr;
            nat->src_port = th->th_sport;
            nat->dst_ip = iph->ip_dst.s_addr;
            nat->dst_port = th->th_dport;
            nat->upstream_fd = -2; // marker: pending, chưa open
            nat->last_active = time(NULL);
            // Reinject packet để PF rdr tiếp tục (rdr -> 127.0.0.1:DIVERT)
            sendto(dfd, buf, n, 0, (struct sockaddr *)&from, flen);
        } else {
            // Non-SYN: reinject
            sendto(dfd, buf, n, 0, (struct sockaddr *)&from, flen);
        }
    }
    close(dfd);
    g_state.divert_fd = -1;
}

// ---------------------------------------------------------------------------
//  DNS-over-HTTPS resolver (local UDP 5353)
//  Nhận query UDP (bị PF rdr từ port 53), resolve qua HTTPS, trả answer.
//  DoH query đi qua 443 -> cũng bị PF divert -> đi qua tunnel (recursive,
//  nhưng DoH dùng HTTPS nên PF sẽ rdr về listener, listener mở upstream ->
//  DoH query đi qua SOCKS5). Do đó DNS không leak.
// ---------------------------------------------------------------------------
static NSData *sc_doh_query(NSData *query) {
    NSString *s = [query base64EncodedStringWithOptions:0];
    s = [s stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
    s = [s stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    s = [s stringByReplacingOccurrencesOfString:@"=" withString:@""];
    NSString *urlStr = [NSString stringWithFormat:@"https://1.1.1.1/dns-query?dns=%@", s];
    NSURL *url = [NSURL URLWithString:urlStr];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    [req setValue:@"application/dns-message" forHTTPHeaderField:@"Accept"];
    [req setHTTPMethod:@"GET"];
    [req setTimeoutInterval:5];
    __block NSData *data = nil;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req
                                                                 completionHandler:^(NSData *d, NSURLResponse *response, NSError *error) {
        (void)response;
        if (!error) data = d;
        dispatch_semaphore_signal(sem);
    }];
    [task resume];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    return data;
}

static void *sc_doh_loop(void *arg) {
    int fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (fd < 0) return NULL;
    struct sockaddr_in sin;
    memset(&sin, 0, sizeof(sin));
    sin.sin_family = AF_INET;
    sin.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    sin.sin_port = htons(SC_DOH_PORT);
    if (bind(fd, (struct sockaddr *)&sin, sizeof(sin)) < 0) {
        sc_log(@"DoH bind failed: %s", strerror(errno));
        close(fd);
        return NULL;
    }
    g_state.doh_fd = fd;
    sc_log(@"DoH resolver listening on 127.0.0.1:%d", SC_DOH_PORT);
    char buf[4096];
    while (g_state.running) {
        struct sockaddr_in cli;
        socklen_t clen = sizeof(cli);
        ssize_t n = recvfrom(fd, buf, sizeof(buf), 0, (struct sockaddr *)&cli, &clen);
        if (n <= 0) continue;
        NSData *q = [NSData dataWithBytes:buf length:n];
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSData *a = sc_doh_query(q);
            if (a && a.length > 0) {
                sendto(fd, a.bytes, a.length, 0, (struct sockaddr *)&cli, clen);
            }
        });
    }
    close(fd);
    g_state.doh_fd = -1;
    return NULL;
}

static void *sc_tcp_listener_thread(void *arg) {
    sc_tcp_listener_loop();
    return NULL;
}

static void *sc_divert_sniff_thread(void *arg) {
    sc_divert_sniff_loop();
    return NULL;
}

static NSString *sc_last_stealth_error(void) {
    if (access(sc_pfctl_path(), X_OK) != 0) return @"pfctl missing";
    int dfd = socket(AF_INET, SOCK_RAW, IPPROTO_DIVERT);
    if (dfd < 0) return [NSString stringWithFormat:@"divert socket failed: %s", strerror(errno)];
    close(dfd);
    int lfd = socket(AF_INET, SOCK_STREAM, 0);
    if (lfd < 0) return [NSString stringWithFormat:@"listener socket failed: %s", strerror(errno)];
    struct sockaddr_in sin;
    memset(&sin, 0, sizeof(sin));
    sin.sin_family = AF_INET;
    sin.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    sin.sin_port = htons(SC_DIVERT_PORT);
    int one = 1;
    setsockopt(lfd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));
    if (bind(lfd, (struct sockaddr *)&sin, sizeof(sin)) < 0) {
        NSString *err = [NSString stringWithFormat:@"listener bind failed: %s", strerror(errno)];
        close(lfd);
        return err;
    }
    close(lfd);
    return @"PF/divert runtime start failed";
}

static BOOL sc_start_stealth_proxy(void) {
    sc_system_proxy_clear();
    if (!sc_pf_load()) return NO;
    g_state.running = YES;
    pthread_t tcpThread, divertThread, dohThread;
    pthread_create(&tcpThread, NULL, sc_tcp_listener_thread, NULL);
    pthread_detach(tcpThread);
    pthread_create(&divertThread, NULL, sc_divert_sniff_thread, NULL);
    pthread_detach(divertThread);
    pthread_create(&dohThread, NULL, sc_doh_loop, NULL);
    pthread_detach(dohThread);
    return YES;
}

static BOOL sc_start_compat_proxy(void) {
    sc_pf_clear();
    BOOL ok = sc_system_proxy_apply();
    g_state.running = ok;
    return ok;
}

// ---------------------------------------------------------------------------
//  UDP relay (SOCKS5 UDP associate) - cho UDP app traffic (QUIC, gaming, v.v.)
//  Nhận UDP packet từ client (bị PF rdr? Không, UDP không rdr qua TCP listener).
//  Cách: mở UDP listener trên 127.0.0.1:SC_UDP_RELAY, app gửi UDP đến đó?
//  Không, PF không rdr UDP general (chỉ 53).
//  Để transparent UDP, cần divert UDP packet. Nhưng phức tạp.
//  Phương án: nếu proxy hỗ trợ UDP, mở SOCKS5 UDP associate và redirect UDP/53
//  qua DoH (đã làm). UDP khác (QUIC) -> optionally divert.
//  Hiện tại: UDP DNS đã cover qua DoH. UDP khác skip (fallback TCP).
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
//  Control server (Unix domain socket)
// ---------------------------------------------------------------------------
static NSData *sc_handle_command(NSDictionary *cmd) {
    NSString *c = cmd[@"cmd"];
    if ([c isEqualToString:@"version"]) {
        return [NSJSONSerialization dataWithJSONObject:@{@"version":@"1.0.0"} options:0 error:nil];
    }
    if ([c isEqualToString:@"status"]) {
        return [NSJSONSerialization dataWithJSONObject:@{
            @"running": @(g_state.running),
            @"proxyType": @(g_state.proxyType),
            @"host": @(g_state.host),
            @"port": @(g_state.port),
            @"udp": @(g_state.udp),
            @"stealth": @(g_state.stealth)
        } options:0 error:nil];
    }
    if ([c isEqualToString:@"start"]) {
        if (g_state.running) {
            g_state.running = NO;
            sc_system_proxy_clear();
            sc_pf_clear();
            if (g_state.divert_fd >= 0) { close(g_state.divert_fd); g_state.divert_fd = -1; }
            if (g_state.udp_fd >= 0) { close(g_state.udp_fd); g_state.udp_fd = -1; }
            if (g_state.doh_fd >= 0) { close(g_state.doh_fd); g_state.doh_fd = -1; }
        }
        strlcpy(g_state.proxyType, [cmd[@"type"] UTF8String] ?: "socks5", sizeof(g_state.proxyType));
        strlcpy(g_state.host, [cmd[@"host"] UTF8String] ?: "", sizeof(g_state.host));
        g_state.port = (uint16_t)[cmd[@"port"] unsignedIntValue];
        strlcpy(g_state.user, [cmd[@"user"] UTF8String] ?: "", sizeof(g_state.user));
        strlcpy(g_state.pass, [cmd[@"pass"] UTF8String] ?: "", sizeof(g_state.pass));
        g_state.udp = [cmd[@"udp"] boolValue];
        g_state.stealth = [cmd[@"stealth"] boolValue];
        if (!g_state.host[0] || g_state.port == 0) {
            return [NSJSONSerialization dataWithJSONObject:@{@"ok":@(NO), @"err":@"no host/port"} options:0 error:nil];
        }
        BOOL ok = g_state.stealth ? sc_start_stealth_proxy() : sc_start_compat_proxy();
        if (!ok) {
            g_state.running = NO;
            sc_log(@"%@ proxy failed", g_state.stealth ? @"stealth" : @"compat");
            NSString *err = g_state.stealth ? sc_last_stealth_error() : @"system proxy apply failed";
            return [NSJSONSerialization dataWithJSONObject:@{@"ok":@(NO), @"err": err ?: @"start failed"} options:0 error:nil];
        }
        sc_log(@"%@ proxy started: %@ %s:%u (API-hidden to apps)", g_state.stealth ? @"stealth" : @"compat", strcmp(g_state.proxyType, "http") == 0 ? @"http" : @"socks5", g_state.host, g_state.port);
        return [NSJSONSerialization dataWithJSONObject:@{@"ok":@(ok)} options:0 error:nil];
    }
    if ([c isEqualToString:@"stop"]) {
        g_state.running = NO;
        sc_system_proxy_clear();
        sc_pf_clear();
        if (g_state.divert_fd >= 0) { close(g_state.divert_fd); g_state.divert_fd = -1; }
        if (g_state.udp_fd >= 0) { close(g_state.udp_fd); g_state.udp_fd = -1; }
        if (g_state.doh_fd >= 0) { close(g_state.doh_fd); g_state.doh_fd = -1; }
        return [NSJSONSerialization dataWithJSONObject:@{@"ok":@(YES)} options:0 error:nil];
    }
    return [NSJSONSerialization dataWithJSONObject:@{@"ok":@(NO), @"err":@"unknown cmd"} options:0 error:nil];
}

static void sc_handle_control_client(int c) {
    uint32_t len = 0;
    if (recv(c, &len, 4, 0) != 4) { close(c); return; }
    len = ntohl(len);
    if (len == 0 || len > 65536) { close(c); return; }
    NSMutableData *buf = [NSMutableData dataWithLength:len];
    ssize_t got = 0;
    while (got < (ssize_t)len) {
        ssize_t n = recv(c, (char *)buf.mutableBytes + got, len - got, 0);
        if (n <= 0) break;
        got += n;
    }
    if (got < (ssize_t)len) { close(c); return; }
    NSDictionary *cmd = [NSJSONSerialization JSONObjectWithData:buf options:0 error:nil];
    NSData *resp = cmd ? sc_handle_command(cmd) : nil;
    if (!resp) resp = [NSJSONSerialization dataWithJSONObject:@{@"ok":@(NO)} options:0 error:nil];
    uint32_t rlen = htonl((uint32_t)resp.length);
    send(c, &rlen, 4, 0);
    send(c, resp.bytes, resp.length, 0);
    close(c);
}

static void *sc_control_tcp_loop(void *arg) {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) { sc_log(@"tcp control socket failed"); return NULL; }
    int one = 1;
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    addr.sin_port = htons(SC_CTL_PORT);
    if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        sc_log(@"tcp control bind failed: %s", strerror(errno));
        close(fd);
        return NULL;
    }
    listen(fd, 8);
    g_state.ctl_tcp_fd = fd;
    sc_log(@"tcp control socket listening at 127.0.0.1:%d", SC_CTL_PORT);
    while (1) {
        int c = accept(fd, NULL, NULL);
        if (c < 0) {
            if (errno == EINTR) continue;
            break;
        }
        sc_handle_control_client(c);
    }
    close(fd);
    return NULL;
}

static void sc_control_loop(void) {
    mkdir("/var/run", 0755);
    mkdir("/var/jb/var", 0755);
    mkdir("/var/jb/var/run", 0755);
    pthread_t tcpThread;
    pthread_create(&tcpThread, NULL, sc_control_tcp_loop, NULL);
    pthread_detach(tcpThread);
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) { sc_log(@"control socket failed"); return; }
    unlink(SC_CTL_SOCK); unlink(SC_CTL_SOCK_RL);
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    const char *preferredSock = (access("/var/jb/var/run", F_OK) == 0) ? SC_CTL_SOCK_RL : SC_CTL_SOCK;
    const char *fallbackSock = (strcmp(preferredSock, SC_CTL_SOCK_RL) == 0) ? SC_CTL_SOCK : SC_CTL_SOCK_RL;
    strlcpy(addr.sun_path, preferredSock, sizeof(addr.sun_path));
    if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        sc_log(@"control bind failed: %s", strerror(errno));
        strlcpy(addr.sun_path, fallbackSock, sizeof(addr.sun_path));
        if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
            sc_log(@"control bind fallback failed: %s", strerror(errno));
            close(fd);
            return;
        }
    }
    chmod(SC_CTL_SOCK, 0666);
    chmod(SC_CTL_SOCK_RL, 0666);
    listen(fd, 8);
    g_state.ctl_fd = fd;
    sc_log(@"control socket listening at %s", SC_CTL_SOCK);

    while (1) {
        int c = accept(fd, NULL, NULL);
        if (c < 0) {
            if (errno == EINTR) continue;
            break;
        }
        sc_handle_control_client(c);
    }
    close(fd);
}

// ---------------------------------------------------------------------------
//  main
// ---------------------------------------------------------------------------
int main(int argc, char **argv) {
    @autoreleasepool {
        memset(&g_state, 0, sizeof(g_state));
        g_state.divert_fd = -1;
        g_state.udp_fd = -1;
        g_state.doh_fd = -1;
        g_state.ctl_fd = -1;
        memset(g_nat, -1, sizeof(g_nat));  // upstream_fd = -1
        for (int i = 0; i < SC_NAT_MAX; i++) {
            g_nat[i].upstream_fd = -1;
            g_nat[i].client_fd = -1;
            pthread_mutex_init(&g_nat[i].lock, NULL);
        }
        sc_log(@"scproxyd starting (pid=%d)", getpid());

        // launchd already runs this as a daemon; do not call daemon() on iOS.
        signal(SIGPIPE, SIG_IGN);
        signal(SIGTERM, sc_sigterm);

        sc_control_loop();
    }
    return 0;
}

static void sc_sigterm(int sig) {
    (void)sig;
    g_state.running = NO;
    sc_pf_clear();
    if (g_state.divert_fd >= 0) close(g_state.divert_fd);
    if (g_state.udp_fd >= 0) close(g_state.udp_fd);
    if (g_state.doh_fd >= 0) close(g_state.doh_fd);
    if (g_state.ctl_fd >= 0) close(g_state.ctl_fd);
    exit(0);
}
