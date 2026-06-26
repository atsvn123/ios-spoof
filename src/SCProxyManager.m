#import "SCProxyManager.h"
#import "SCSpoofConfig.h"

static SCSpoofConfig *CFG() { return [SCSpoofConfig shared]; }
#import "SCSpoofConfig.h"
#import <sys/un.h>
#import <sys/socket.h>
#import <unistd.h>

// Socket path giao tiếp với daemon (rootless: /var/jb/var/run/scproxyd.sock)
#define SC_DAEMON_SOCK  "/var/run/scproxyd.sock"
#define SC_DAEMON_SOCK_ROOTLESS "/var/jb/var/run/scproxyd.sock"

@interface SCProxyManager () {
    int _sock;
    dispatch_queue_t _q;
}
@end

@implementation SCProxyManager

+ (instancetype)shared {
    static SCProxyManager *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [self new]; });
    return s;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _q = dispatch_queue_create("com.iosspoof.proxy", DISPATCH_QUEUE_SERIAL);
        _sock = -1;
    }
    return self;
}

- (NSString *)socketPath {
    // rootless first
    if (access("/var/jb/var/run", F_OK) == 0) return @SC_DAEMON_SOCK_ROOTLESS;
    return @SC_DAEMON_SOCK;
}

- (int)connectDaemon {
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return -1;
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    const char *p = [[self socketPath] UTF8String];
    strlcpy(addr.sun_path, p, sizeof(addr.sun_path));
    if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        close(fd);
        return -1;
    }
    struct timeval tv = { .tv_sec = 3, .tv_usec = 0 };
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));
    return fd;
}

- (NSDictionary *)sendCommand:(NSDictionary *)cmd {
    int fd = [self connectDaemon];
    if (fd < 0) return nil;
    @try {
        NSData *d = [NSJSONSerialization dataWithJSONObject:cmd options:0 error:nil];
        if (!d) { close(fd); return nil; }
        uint32_t len = (uint32_t)d.length;
        len = htonl(len);
        if (send(fd, &len, 4, 0) != 4) { close(fd); return nil; }
        if (send(fd, d.bytes, d.length, 0) != (ssize_t)d.length) { close(fd); return nil; }
        // read response
        uint32_t rlen = 0;
        if (recv(fd, &rlen, 4, 0) != 4) { close(fd); return nil; }
        rlen = ntohl(rlen);
        if (rlen == 0 || rlen > 65536) { close(fd); return nil; }
        NSMutableData *buf = [NSMutableData dataWithLength:rlen];
        ssize_t got = 0;
        while (got < (ssize_t)rlen) {
            ssize_t n = recv(fd, (char *)buf.mutableBytes + got, rlen - got, 0);
            if (n <= 0) break;
            got += n;
        }
        close(fd);
        if (got < (ssize_t)rlen) return nil;
        return [NSJSONSerialization JSONObjectWithData:buf options:0 error:nil];
    } @catch (id e) {
        close(fd);
        return nil;
    }
}

- (NSString *)daemonVersion {
    NSDictionary *r = [self sendCommand:@{ @"cmd":@"version" }];
    return r[@"version"] ?: @"unknown";
}

- (BOOL)isRunning {
    NSDictionary *r = [self sendCommand:@{ @"cmd":@"status" }];
    return [r[@"running"] boolValue];
}

- (BOOL)startProxy {
    SCSpoofConfig *c = CFG();
    if (!c.proxyEnabled) return NO;
    NSDictionary *cmd = @{
        @"cmd": @"start",
        @"type": c.proxyType ?: @"socks5",
        @"host": c.proxyHost ?: @"",
        @"port": @(c.proxyPort),
        @"user": c.proxyUser ?: @"",
        @"pass": c.proxyPass ?: @"",
        @"udp": @(c.proxyUDP)
    };
    NSDictionary *r = [self sendCommand:cmd];
    return [r[@"ok"] boolValue];
}

- (BOOL)stopProxy {
    NSDictionary *r = [self sendCommand:@{ @"cmd":@"stop" }];
    return [r[@"ok"] boolValue];
}

- (BOOL)updateUpstream {
    return [self startProxy]; // start = reconfigure
}

@end
