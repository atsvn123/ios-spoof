#import "SCSpoofConfig.h"
#import "SCDevicePresets.h"
#import <objc/runtime.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <CFNetwork/CFNetwork.h>
#import <netinet/in.h>
#import <ifaddrs.h>
#import <net/if.h>
#import <netdb.h>
#import <sys/ioctl.h>
#import <dlfcn.h>
#import <substrate.h>
#import <string.h>

// iOS 17 SDKs used by CI may not expose CoreTelephony headers. We only need
// Objective-C selectors for Logos hooks, so forward declarations are enough.
@class CTCarrier;

@interface CTCarrier : NSObject
- (NSString *)carrierName;
- (NSString *)mobileCountryCode;
- (NSString *)mobileNetworkCode;
- (NSString *)isoCountryCode;
- (BOOL)allowsVOIP;
@end

@interface CTTelephonyNetworkInfo : NSObject
- (CTCarrier *)subscriberCellularProvider;
- (NSDictionary<NSString *, CTCarrier *> *)serviceSubscriberCellularProviders;
- (NSString *)serviceSubscriberCellularProvidersDidUpdateNotifier;
- (NSString *)currentRadioAccessTechnology;
- (NSDictionary<NSString *, NSString *> *)serviceCurrentRadioAccessTechnology;
- (NSString *)dataServiceIdentifier;
@end

typedef NS_ENUM(NSInteger, CTCellularDataRestrictedState) {
    kCTCellularDataRestrictedStateUnknown = 0,
    kCTCellularDataRestricted = 1,
    kCTCellularDataNotRestricted = 2,
};

@interface CTCellularData : NSObject
- (CTCellularDataRestrictedState)restrictedState;
@end

@interface NEHotspotNetwork : NSObject
- (NSString *)SSID;
- (NSString *)BSSID;
@end

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

static NSString *SCFakeSSID(void) {
    return CFG().wifiSSID.length ? CFG().wifiSSID : @"MyWiFi";
}

static NSString *SCFakeBSSID(void) {
    return CFG().wifiBSSID.length ? CFG().wifiBSSID : @"02:00:00:00:00:00";
}

static void SCNetworkPrefsChanged(CFNotificationCenterRef center, void *observer,
                                  CFStringRef name, const void *object,
                                  CFDictionaryRef userInfo) {
    [CFG() reload];
}

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
- (CTCarrier *)subscriberCellularProvider {
    CTCarrier *orig = %orig;
    if (SC_ON() && P()) return orig ?: [CTCarrier new];
    return orig;
}
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
- (NSString *)dataServiceIdentifier {
    if (SC_ON() && P()) return @"0000000100000001";
    return %orig;
}
%end

%hook CTCellularData
- (CTCellularDataRestrictedState)restrictedState {
    if (SC_ON() && CFG().networkMode == 2) return kCTCellularDataNotRestricted;
    return %orig;
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
        if (r) CFRelease(r);
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
    if (SC_ON() && key) {
        NSString *k = (__bridge NSString *)key;
        if (CFG().networkMode == 2) {
            if ([k containsString:@"AirPort"] || [k containsString:@"Wi-Fi"] || [k containsString:@"en0"]) {
                return NULL;
            }
            if ([k isEqualToString:@"State:/Network/Global/IPv4"] || [k isEqualToString:@"State:/Network/Global/IPv6"]) {
                return (__bridge_retained CFDictionaryRef)@{
                    @"PrimaryInterface": @"pdp_ip0",
                    @"PrimaryService": @"com.apple.mobile-data"
                };
            }
        } else if (CFG().networkMode == 1) {
            if ([k isEqualToString:@"State:/Network/Global/IPv4"] || [k isEqualToString:@"State:/Network/Global/IPv6"]) {
                return (__bridge_retained CFDictionaryRef)@{
                    @"PrimaryInterface": @"en0",
                    @"PrimaryService": @"com.apple.wifi"
                };
            }
            if ([k containsString:@"AirPort"] || [k containsString:@"Wi-Fi"] || [k containsString:@"en0"]) {
                return (__bridge_retained CFDictionaryRef)@{
                    @"SSID_STR": SCFakeSSID(),
                    @"SSID": SCFakeSSID(),
                    @"BSSID": SCFakeBSSID(),
                    @"Power Status": @"On"
                };
            }
        }

        if (!CFG().hideProxy) return orig_SCDynamicStoreCopyValue(store, key);
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
    if (SC_ON() && CFG().hideProxy && r && pattern) {
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
    if (!SC_ON()) return r;

    if (CFG().networkMode == 2 || CFG().networkMode == 1) {
        struct ifaddrs *net = *ifap;
        while (net) {
            if (net->ifa_name) {
                NSString *name = [NSString stringWithUTF8String:net->ifa_name];
                if (CFG().networkMode == 2 && [name isEqualToString:@"en0"]) {
                    strlcpy(net->ifa_name, "pdp_ip0", IFNAMSIZ);
                } else if (CFG().networkMode == 1 && [name hasPrefix:@"pdp_ip"]) {
                    strlcpy(net->ifa_name, "en0", IFNAMSIZ);
                }
            }
            net = net->ifa_next;
        }
    }

    if (!CFG().hideVPN) return r;

    // Danh sách prefix interface cần ẩn
    NSArray *hidePrefixes = @[@"utun", @"ppp", @"ipsec", @"tap", @"tun", @"gif",
                              @"stf", @"bridge"];
    struct ifaddrs *cur = *ifap;
    while (cur) {
        char *name = cur->ifa_name;
        NSString *n = [NSString stringWithUTF8String:name];
        BOOL hide = NO;
        for (NSString *pre in hidePrefixes) {
            if ([n hasPrefix:pre]) { hide = YES; break; }
        }
        if (hide) {
            // Avoid unlinking nodes because callers will free the original list.
            // Renaming is enough for common VPN/proxy interface checks.
            strlcpy(cur->ifa_name, "lo0", IFNAMSIZ);
        }
        cur = cur->ifa_next;
    }
    return r;
}

// ============================================================================
//  5. if_nametoindex / if_indextoname - ẩn VPN interface name
// ============================================================================

unsigned int (*orig_if_nametoindex)(const char *);
unsigned int sc_if_nametoindex(const char *ifname) {
    if (SC_ON() && ifname) {
        NSString *n = [NSString stringWithUTF8String:ifname];
        if (CFG().networkMode == 2 && [n isEqualToString:@"en0"]) return 0;
        if (CFG().networkMode == 1 && [n hasPrefix:@"pdp_ip"]) return 0;
    }
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
    if (r && SC_ON()) {
        NSString *n = [NSString stringWithUTF8String:r];
        if (CFG().networkMode == 2 && [n isEqualToString:@"en0"]) {
            strlcpy(ifname, "pdp_ip0", IFNAMSIZ);
            return ifname;
        }
        if (CFG().networkMode == 1 && [n hasPrefix:@"pdp_ip"]) {
            strlcpy(ifname, "en0", IFNAMSIZ);
            return ifname;
        }
    }
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
    if (r && SC_ON() && flags) {
        // networkMode 2 = fake cellular: set WWAN flag, clear WiFi
        if (CFG().networkMode == 2) {
            *flags |= kSCNetworkReachabilityFlagsIsWWAN;
            *flags &= ~kSCNetworkReachabilityFlagsIsDirect;
        }
        // networkMode 1 = fake WiFi: clear WWAN flag
        else if (CFG().networkMode == 1) {
            *flags &= ~kSCNetworkReachabilityFlagsIsWWAN;
        }
    }
    return r;
}

// ============================================================================
//  6b. CaptiveNetwork / NEHotspotNetwork - fake WiFi SSID/BSSID or hide WiFi
// ============================================================================

CFArrayRef (*orig_CNCopySupportedInterfaces)(void);
CFArrayRef sc_CNCopySupportedInterfaces(void) {
    if (SC_ON()) {
        if (CFG().networkMode == 2) {
            return CFArrayCreate(NULL, NULL, 0, &kCFTypeArrayCallBacks);
        }
        if (CFG().networkMode == 1) {
            const void *values[] = { CFSTR("en0") };
            return CFArrayCreate(NULL, values, 1, &kCFTypeArrayCallBacks);
        }
    }
    return orig_CNCopySupportedInterfaces ? orig_CNCopySupportedInterfaces() : NULL;
}

CFDictionaryRef (*orig_CNCopyCurrentNetworkInfo)(CFStringRef);
CFDictionaryRef sc_CNCopyCurrentNetworkInfo(CFStringRef interfaceName) {
    CFDictionaryRef r = orig_CNCopyCurrentNetworkInfo ? orig_CNCopyCurrentNetworkInfo(interfaceName) : NULL;
    if (!SC_ON()) return r;
    // networkMode 2 = fake cellular: return NULL (no WiFi)
    if (CFG().networkMode == 2) {
        if (r) CFRelease(r);
        return NULL;
    }
    // networkMode 1 = fake WiFi: replace SSID/BSSID
    if (CFG().networkMode == 1) {
        if (r) CFRelease(r);
        NSString *ssid = SCFakeSSID();
        NSString *bssid = SCFakeBSSID();
        NSData *ssidData = [ssid dataUsingEncoding:NSUTF8StringEncoding] ?: [NSData data];
        return CFDictionaryCreate(NULL,
            (const void *[]){ CFSTR("SSID"), CFSTR("BSSID"), CFSTR("SSIDDATA") },
            (const void *[]){ (__bridge CFStringRef)ssid, (__bridge CFStringRef)bssid, (__bridge CFDataRef)ssidData },
            3, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    }
    return r;
}

static NSString *(*orig_NEHotspotNetwork_SSID)(id, SEL);
static NSString *sc_NEHotspotNetwork_SSID(id self, SEL _cmd) {
    if (SC_ON()) {
        if (CFG().networkMode == 1) return SCFakeSSID();
        if (CFG().networkMode == 2) return nil;
    }
    return orig_NEHotspotNetwork_SSID ? orig_NEHotspotNetwork_SSID(self, _cmd) : nil;
}

static NSString *(*orig_NEHotspotNetwork_BSSID)(id, SEL);
static NSString *sc_NEHotspotNetwork_BSSID(id self, SEL _cmd) {
    if (SC_ON()) {
        if (CFG().networkMode == 1) return SCFakeBSSID();
        if (CFG().networkMode == 2) return nil;
    }
    return orig_NEHotspotNetwork_BSSID ? orig_NEHotspotNetwork_BSSID(self, _cmd) : nil;
}

static void (*orig_NEHotspotNetwork_fetchCurrent)(Class, SEL, void (^)(id));
static void sc_NEHotspotNetwork_fetchCurrent(Class cls, SEL _cmd, void (^completion)(id)) {
    if (SC_ON() && CFG().networkMode == 2) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(nil); });
        return;
    }
    if (orig_NEHotspotNetwork_fetchCurrent) {
        orig_NEHotspotNetwork_fetchCurrent(cls, _cmd, completion);
    } else if (completion) {
        completion(nil);
    }
}

static void SCHookNEHotspotNetwork(void) {
    Class cls = objc_getClass("NEHotspotNetwork");
    if (!cls) return;
    if (class_getInstanceMethod(cls, @selector(SSID))) {
        MSHookMessageEx(cls, @selector(SSID), (IMP)sc_NEHotspotNetwork_SSID, (IMP *)&orig_NEHotspotNetwork_SSID);
    }
    if (class_getInstanceMethod(cls, @selector(BSSID))) {
        MSHookMessageEx(cls, @selector(BSSID), (IMP)sc_NEHotspotNetwork_BSSID, (IMP *)&orig_NEHotspotNetwork_BSSID);
    }
    Class meta = object_getClass(cls);
    SEL fetchSel = @selector(fetchCurrentWithCompletionHandler:);
    if (meta && class_getClassMethod(cls, fetchSel)) {
        MSHookMessageEx(meta, fetchSel, (IMP)sc_NEHotspotNetwork_fetchCurrent, (IMP *)&orig_NEHotspotNetwork_fetchCurrent);
    }
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
        NSString *bid = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
        static NSSet *protected;
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            protected = [NSSet setWithArray:@[
                @"com.iosspoof.app", @"org.coolstar.SileoStore", @"org.coolstar.Sileo",
                @"com.saurik.Cydia", @"xyz.willy.Zebra", @"com.opa334.Dopamine",
                @"me.apptapp.Installer", @"com.opa334.TrollStore",
                @"com.opa334.TrollStorePersistenceHelper", @"com.apple.springboard",
                @"com.apple.Preferences"
            ]];
        });
        if ([protected containsObject:bid]) return;
        
        if (![CFG() shouldInjectForCurrentBundle]) return;

        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
            NULL, SCNetworkPrefsChanged, CFSTR("com.iosspoof.tweak.prefs.changed"), NULL,
            CFNotificationSuspensionBehaviorCoalesce);

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
            void *copyValue = dlsym(sc, "SCDynamicStoreCopyValue");
            if (copyValue) {
                MSHookFunction(copyValue,
                               (void *)sc_SCDynamicStoreCopyValue,
                               (void **)&orig_SCDynamicStoreCopyValue);
            }
            void *copyKeyList = dlsym(sc, "SCDynamicStoreCopyKeyList");
            if (copyKeyList) {
                MSHookFunction(copyKeyList,
                               (void *)sc_SCDynamicStoreCopyKeyList,
                               (void **)&orig_SCDynamicStoreCopyKeyList);
            }
            MSHookFunction((void *)&SCNetworkReachabilityGetFlags,
                           (void *)sc_SCNetworkReachabilityGetFlags,
                           (void **)&orig_SCNetworkReachabilityGetFlags);
        }
        MSHookFunction((void *)&getifaddrs, (void *)sc_getifaddrs, (void **)&orig_getifaddrs);
        MSHookFunction((void *)&if_nametoindex, (void *)sc_if_nametoindex, (void **)&orig_if_nametoindex);
        MSHookFunction((void *)&if_indextoname, (void *)sc_if_indextoname, (void **)&orig_if_indextoname);

        if (sc) {
            void *supported = dlsym(sc, "CNCopySupportedInterfaces");
            if (supported) MSHookFunction(supported, (void *)sc_CNCopySupportedInterfaces, (void **)&orig_CNCopySupportedInterfaces);
            void *current = dlsym(sc, "CNCopyCurrentNetworkInfo");
            if (current) MSHookFunction(current, (void *)sc_CNCopyCurrentNetworkInfo, (void **)&orig_CNCopyCurrentNetworkInfo);
        }

        dlopen("/System/Library/Frameworks/NetworkExtension.framework/NetworkExtension", RTLD_NOW);
        SCHookNEHotspotNetwork();
    }
}
