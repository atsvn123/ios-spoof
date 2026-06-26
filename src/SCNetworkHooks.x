#import "SCSpoofConfig.h"
#import "SCDevicePresets.h"
#import <objc/runtime.h>
#import <CoreTelephony/CoreTelephony.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <CFNetwork/CFNetwork.h>
#import <netinet/in.h>
#import <ifaddrs.h>
#import <net/if.h>
#import <netdb.h>
#import <sys/ioctl.h>

// ============================================================================
//  SCNetworkHooks.x
//  - Spoof carrier (CTCarrier, CTTelephonyNetworkInfo)
//  - Spoof radio access technology (LTE / NR / 3G...)
//  - ẩn proxy: CFNetworkCopySystemProxySettings trả về rỗng
//  - ẩn VPN interface: getifaddrs filter utun/ppp/ipsec/tap/tun/gif
//  - ẩn jailbreak network markers
// ============================================================================

static SCSpoofConfig *CFG() { return [SCSpoofConfig shared]; }
static SCDevicePreset *P()  { return CFG().resolvedPreset; }
static BOOL SC_ON()         { return CFG().enabled; }

// ============================================================================
//  1. CTCarrier / CTTelephonyNetworkInfo
// ============================================================================

%hook CTCarrier
- (NSString *)carrierName {
    if (SC_ON() && P()) return P().carrierName ?: @"carrier";
    return %orig;
}
- (NSString *)mobileCountryCode {
    if (SC_ON() && P()) return P().carrierMCC ?: @"";
    return %orig;
}
- (NSString *)mobileNetworkCode {
    if (SC_ON() && P()) return P().carrierMNC ?: @"";
    return %orig;
}
- (NSString *)isoCountryCode {
    if (SC_ON() && P()) return (P().carrierISO ?: @"vn").uppercaseString;
    return %orig;
}
- (BOOL)allowsVOIP {
    return YES;
}
%end

%hook CTTelephonyNetworkInfo
- (NSDictionary<NSString *, CTCarrier *> *)serviceSubscriberCellularProviders {
    NSDictionary *orig = %orig;
    if (!SC_ON() || !P()) return orig;
    // Trả về dict đã modify carrier
    NSMutableDictionary *m = [NSMutableDictionary dictionaryWithDictionary:orig];
    for (NSString *key in m.allKeys) {
        // CTCarrier immutable -> hook method trả spoof, không cần thay object
        // nhưng đảm bảo key tồn tại
        (void)key;
    }
    if (m.count == 0) {
        // Tạo carrier giả nếu rỗng
        CTCarrier *c = [CTCarrier new];
        m[@"kCTCarrierSlot1"] = c;
    }
    return m.copy;
}
- (NSString *)serviceSubscriberCellularProvidersDidUpdateNotifier { return %orig; }
- (NSString *)currentRadioAccessTechnology {
    if (SC_ON() && P()) return P().radioTech ?: @"CTRadioAccessTechnologyLTE";
    return %orig;
}
- (NSDictionary<NSString *, NSString *> *)serviceCurrentRadioAccessTechnology {
    NSDictionary *orig = %orig;
    if (!SC_ON() || !P()) return orig;
    if (orig.count == 0) return @{ @"kCTRadioAccessTechnologySlot1": P().radioTech };
    // Modify value
    NSMutableDictionary *m = [NSMutableDictionary dictionary];
    for (NSString *k in orig) m[k] = P().radioTech ?: @"CTRadioAccessTechnologyLTE";
    return m.copy;
}
%end

// ============================================================================
//  2. CFNetwork - ẩn proxy system
// ============================================================================

CFDictionaryRef (*orig_CFNetworkCopySystemProxySettings)(void);
CFDictionaryRef sc_CFNetworkCopySystemProxySettings(void) {
    CFDictionaryRef r = orig_CFNetworkCopySystemProxySettings();
    if (SC_ON() && CFG().hideProxy) {
        // Trả về dict rỗng (no proxy) để app không thấy HTTP proxy
        return CFDictionaryCreate(NULL, NULL, NULL, 0, NULL, NULL);
    }
    return r;
}

CFArrayRef (*orig_CFNetworkCopyProxiesForURL)(CFURLRef, CFDictionaryRef);
CFArrayRef sc_CFNetworkCopyProxiesForURL(CFURLRef url, CFDictionaryRef settings) {
    if (SC_ON() && CFG().hideProxy) {
        // Trả về empty array -> không proxy
        return CFArrayCreate(NULL, NULL, 0, NULL);
    }
    return orig_CFNetworkCopyProxiesForURL(url, settings);
}

// ============================================================================
//  3. SCDynamicStore - ẩn proxy state, VPN state
// ============================================================================

CFPropertyListRef (*orig_SCDynamicStoreCopyValue)(SCDynamicStoreRef, CFStringRef);
CFPropertyListRef sc_SCDynamicStoreCopyValue(SCDynamicStoreRef store, CFStringRef key) {
    if (SC_ON() && CFG().hideProxy) {
        NSString *k = (__bridge NSString *)key;
        // ẩn HTTP proxy, HTTPS proxy, SOCKS, auto proxy
        if ([k containsString:@"Proxy"] || [k containsString:@"proxy"] ||
            [k containsString:@"HTTPProxy"] || [k containsString:@"HTTPSProxy"] ||
            [k containsString:@"SOCKSProxy"] || [k containsString:@"ProxyAutoConfig"]) {
            return NULL;
        }
        // ẩn state VPN / PPP / IPsec
        if (CFG().hideVPN && ([k containsString:@"VPN"] || [k containsString:@"PPP"] ||
            [k containsString:@"IPSec"] || [k containsString:@"com.apple.networkextension"])) {
            return NULL;
        }
    }
    return orig_SCDynamicStoreCopyValue(store, key);
}

CFArrayRef (*orig_SCDynamicStoreCopyKeyList)(SCDynamicStoreRef, CFStringRef);
CFArrayRef sc_SCDynamicStoreCopyKeyList(SCDynamicStoreRef store, CFStringRef pattern) {
    CFArrayRef r = orig_SCDynamicStoreCopyKeyList(store, pattern);
    if (SC_ON() && CFG().hideProxy && r) {
        NSString *p = (__bridge NSString *)pattern;
        if ([p containsString:@"Proxy"] || [p containsString:@"proxy"]) {
            CFRelease(r);
            return CFArrayCreate(NULL, NULL, 0, NULL);
        }
        if (CFG().hideVPN && ([p containsString:@"VPN"] || [p containsString:@"PPP"] ||
            [p containsString:@"IPSec"])) {
            CFRelease(r);
            return CFArrayCreate(NULL, NULL, 0, NULL);
        }
    }
    return r;
}

// ============================================================================
//  4. getifaddrs - ẩn interface VPN/proxy (utun, ppp, ipsec, tap, tun, gif)
// ============================================================================

int (*orig_getifaddrs)(struct ifaddrs **);
int sc_getifaddrs(struct ifaddrs **ifap) {
    int r = orig_getifaddrs(ifap);
    if (r != 0 || !ifap || !*ifap) return r;
    if (!SC_ON() || !CFG().hideVPN) return r;

    // Danh sách prefix interface cần ẩn
    NSArray *hidePrefixes = @[@"utun", @"ppp", @"ipsec", @"tap", @"tun", @"gif",
                              @"stf", @"bridge"];
    // Link chain filter
    struct ifaddrs **pp = ifap;
    struct ifaddrs *cur = *ifap;
    while (cur) {
        char *name = cur->ifa_name;
        NSString *n = [NSString stringWithUTF8String:name];
        BOOL hide = NO;
        for (NSString *pre in hidePrefixes) {
            if ([n hasPrefix:pre]) { hide = YES; break; }
        }
        if (hide) {
            *pp = cur->ifa_next;
            cur->ifa_next = NULL;
            // không free (an toàn hơn)
            cur = *pp;
        } else {
            pp = &cur->ifa_next;
            cur = cur->ifa_next;
        }
    }
    return r;
}

// ============================================================================
//  5. if_nametoindex / if_indextoname - ẩn VPN interface name
// ============================================================================

unsigned int (*orig_if_nametoindex)(const char *);
unsigned int sc_if_nametoindex(const char *ifname) {
    if (SC_ON() && CFG().hideVPN && ifname) {
        NSString *n = [NSString stringWithUTF8String:ifname];
        NSArray *hidePrefixes = @[@"utun", @"ppp", @"ipsec", @"tap", @"tun", @"gif"];
        for (NSString *pre in hidePrefixes) {
            if ([n hasPrefix:pre]) return 0;
        }
    }
    return orig_if_nametoindex(ifname);
}

char *(*orig_if_indextoname)(unsigned int, char *);
char *sc_if_indextoname(unsigned int ifindex, char *ifname) {
    char *r = orig_if_indextoname(ifindex, ifname);
    if (r && SC_ON() && CFG().hideVPN) {
        NSString *n = [NSString stringWithUTF8String:r];
        NSArray *hidePrefixes = @[@"utun", @"ppp", @"ipsec", @"tap", @"tun", @"gif"];
        for (NSString *pre in hidePrefixes) {
            if ([n hasPrefix:pre]) {
                // rename thành lo0 để app không thấy VPN
                strlcpy(ifname, "lo0", IFNAMSIZ);
                return ifname;
            }
        }
    }
    return r;
}

// ============================================================================
//  6. SCNetworkReachability - ẩn VPN routing
// ============================================================================

Boolean (*orig_SCNetworkReachabilityGetFlags)(SCNetworkReachabilityRef, SCNetworkReachabilityFlags *);
Boolean sc_SCNetworkReachabilityGetFlags(SCNetworkReachabilityRef ref, SCNetworkReachabilityFlags *flags) {
    Boolean r = orig_SCNetworkReachabilityGetFlags(ref, flags);
    if (r && SC_ON() && CFG().hideVPN && flags) {
        // Xóa flag connection required / is WWAN nếu cần; chủ yếu giữ flag reachability
        // để app thấy WiFi/WWAN bình thường.
    }
    return r;
}

// ============================================================================
//  7. res_query / DNS - tránh leak (DNS resolve vẫn hoạt động nhưng không lộ proxy)
//    DNS leak chủ yếu qua getaddrinfo -> hook để không trả về interface VPN.
//    Không can thiệp sâu ở đây, scproxyd lo phần DNS tunnel.
// ============================================================================

// ============================================================================
//  8. Init - MSHookFunction cho tất cả C function
// ============================================================================

%ctor {
    @autoreleasepool {
        void *cfnet = dlopen("/System/Library/Frameworks/CFNetwork.framework/CFNetwork", RTLD_NOW);
        if (cfnet) {
            MSHookFunction((void *)&CFNetworkCopySystemProxySettings,
                           (void *)sc_CFNetworkCopySystemProxySettings,
                           (void **)&orig_CFNetworkCopySystemProxySettings);
            MSHookFunction((void *)&CFNetworkCopyProxiesForURL,
                           (void *)sc_CFNetworkCopyProxiesForURL,
                           (void **)&orig_CFNetworkCopyProxiesForURL);
        }
        void *sc = dlopen("/System/Library/Frameworks/SystemConfiguration.framework/SystemConfiguration", RTLD_NOW);
        if (sc) {
            MSHookFunction((void *)&SCDynamicStoreCopyValue,
                           (void *)sc_SCDynamicStoreCopyValue,
                           (void **)&orig_SCDynamicStoreCopyValue);
            MSHookFunction((void *)&SCDynamicStoreCopyKeyList,
                           (void *)sc_SCDynamicStoreCopyKeyList,
                           (void **)&orig_SCDynamicStoreCopyKeyList);
            MSHookFunction((void *)&SCNetworkReachabilityGetFlags,
                           (void *)sc_SCNetworkReachabilityGetFlags,
                           (void **)&orig_SCNetworkReachabilityGetFlags);
        }
        MSHookFunction((void *)&getifaddrs, (void *)sc_getifaddrs, (void **)&orig_getifaddrs);
        MSHookFunction((void *)&if_nametoindex, (void *)sc_if_nametoindex, (void **)&orig_if_nametoindex);
        MSHookFunction((void *)&if_indextoname, (void *)sc_if_indextoname, (void **)&orig_if_indextoname);
    }
}
