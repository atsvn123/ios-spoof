#import "SCSpoofConfig.h"
#import "SCDevicePresets.h"
#import "SCProxyManager.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <sys/sysctl.h>
#import <sys/stat.h>
#import <sys/utsname.h>
#import <net/if.h>
#import <mach/mach.h>
#import <dlfcn.h>
#import <fcntl.h>
#import <unistd.h>
#import <errno.h>
#import <string.h>
#import <substrate.h>
#import <IOKit/IOKitLib.h>

// ============================================================================
//  iOSSpoof - Tweak.x
//  Device hooks: UIDevice, sysctl, IOKit, NSBundle, UIScreen, battery, jailbreak.
//  Per-process config từ SCSpoofConfig.
// ============================================================================

static SCSpoofConfig *CFG() { return [SCSpoofConfig shared]; }
static SCDevicePreset *P()  { return CFG().resolvedPreset; }
static BOOL SC_ON()         { return CFG().enabled; }

static void SCApplyProxyIfNeeded(void) {
    NSString *bundle = CFG().currentBundleID ?: @"";
    if (![bundle isEqualToString:@"com.apple.springboard"]) return;
    if (CFG().enabled && CFG().proxyEnabled) {
        [[SCProxyManager shared] startProxy];
    } else {
        [[SCProxyManager shared] stopProxy];
    }
}

// ----------------------------------------------------------------------------
//  Lắng nghe thay đổi preferences
// ----------------------------------------------------------------------------
static void SCPostCenter(CFNotificationCenterRef center, void *observer,
                         CFStringRef name, const void *object,
                         CFDictionaryRef userInfo) {
    [CFG() reload];
    SCApplyProxyIfNeeded();
}

static void SCBootstrap(void) {
    @autoreleasepool {
        // trigger load config
        [SCSpoofConfig shared];
        SCApplyProxyIfNeeded();
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
            NULL, SCPostCenter, CFSTR("com.iosspoof.tweak.prefs-changed"), NULL,
            CFNotificationSuspensionBehaviorCoalesce);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"iOSSpoofDebugLog"]) {
            NSLog(@"[iOSSpoof] loaded into %@ (preset=%@)", CFG().currentBundleID, P().productType);
        }
    }
}

// ============================================================================
//  1. UIDevice
// ============================================================================
%hook UIDevice

- (NSString *)model {
    if (SC_ON() && P()) return @"iPhone";
    return %orig;
}
- (NSString *)localizedModel {
    if (SC_ON() && P()) return P().marketingName ?: @"iPhone";
    return %orig;
}
- (NSString *)name {
    if (SC_ON() && P()) {
        return [NSString stringWithFormat:@"%@'s iPhone", P().marketingName ?: @"iPhone"];
    }
    return %orig;
}
- (NSString *)systemName {
    return %orig; // giữ iOS
}
- (NSString *)systemVersion {
    return %orig; // không spoof iOS version để tránh bất nhất với API khác
}
- (NSUUID *)identifierForVendor {
    if (SC_ON() && CFG().spoofIDFV) {
        return [[NSUUID alloc] initWithUUIDString:CFG().spoofedIDFA] ?: [NSUUID UUID];
    }
    return %orig;
}
+ (UIDevice *)currentDevice {
    return %orig;
}

- (float)batteryLevel {
    if (SC_ON() && CFG().spoofBattery && P()) {
        return [P().batteryLevel floatValue];
    }
    return %orig;
}

- (UIDeviceBatteryState)batteryState {
    if (SC_ON() && CFG().spoofBattery && P()) {
        NSString *s = P().batteryState;
        if ([s isEqualToString:@"charging"]) return UIDeviceBatteryStateCharging;
        if ([s isEqualToString:@"full"]) return UIDeviceBatteryStateFull;
        return UIDeviceBatteryStateUnplugged;
    }
    return %orig;
}

- (BOOL)isBatteryMonitoringEnabled {
    if (SC_ON() && CFG().spoofBattery) return YES;
    return %orig;
}

%end

// ============================================================================
//  2. UIScreen - resolution / scale
// ============================================================================
%hook UIScreen

- (CGRect)bounds {
    if (SC_ON() && P()) {
        CGFloat scale = MAX((CGFloat)P().screenScale, 1.0);
        return CGRectMake(0, 0, P().screenWidth / scale, P().screenHeight / scale);
    }
    return %orig;
}
- (CGFloat)scale {
    if (SC_ON() && P()) return (CGFloat)P().screenScale;
    return %orig;
}
- (CGFloat)nativeScale {
    if (SC_ON() && P()) return (CGFloat)P().screenScale;
    return %orig;
}
- (CGSize)nativeBounds {
    if (SC_ON() && P()) {
        return CGSizeMake(P().screenWidth, P().screenHeight);
    }
    return %orig;
}

%end

// ============================================================================
//  3. sysctlbyname / sysctl - hw.machine, hw.model, hw.serialnumber, hw.UUID
//     Đây là vector chính mà app dùng để fingerprint.
// ============================================================================

// MSHookFunction cho C function
static int (*orig_sysctlbyname)(const char *, void *, size_t *, void *, size_t);
static int sc_sysctlbyname(const char *name, void *oldp, size_t *oldlenp,
                           void *newp, size_t newlen) {
    if (!name) return orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
    if (SC_ON() && P()) {
        NSString *n = [NSString stringWithUTF8String:name];
        // hw.machine -> ProductType (iPhone15,2)
        if ([n isEqualToString:@"hw.machine"]) {
            const char *val = [P().productType UTF8String];
            size_t need = strlen(val) + 1;
            if (oldp && oldlenp) {
                if (*oldlenp >= need) { memcpy(oldp, val, need); }
                *oldlenp = need;
            } else if (oldlenp) {
                *oldlenp = need;
            }
            return 0;
        }
        // hw.model -> HardwareModel (D63AP)
        if ([n isEqualToString:@"hw.model"]) {
            const char *val = [P().hardwareModel UTF8String];
            size_t need = strlen(val) + 1;
            if (oldp && oldlenp) {
                if (*oldlenp >= need) memcpy(oldp, val, need);
                *oldlenp = need;
            } else if (oldlenp) {
                *oldlenp = need;
            }
            return 0;
        }
        // hw.serialnumber
        if ([n isEqualToString:@"hw.serialnumber"] || [n isEqualToString:@"hw.serialno"]) {
            const char *val = [CFG().spoofedSerial UTF8String];
            size_t need = strlen(val) + 1;
            if (oldp && oldlenp) {
                if (*oldlenp >= need) memcpy(oldp, val, need);
                *oldlenp = need;
            } else if (oldlenp) {
                *oldlenp = need;
            }
            return 0;
        }
        // hw.UUID / hw.uuid (platform UUID)
        if ([n isEqualToString:@"hw.UUID"] || [n isEqualToString:@"hw.uuid"]) {
            const char *val = [CFG().spoofedUDID UTF8String];
            size_t need = strlen(val) + 1;
            if (oldp && oldlenp) {
                if (*oldlenp >= need) memcpy(oldp, val, need);
                *oldlenp = need;
            } else if (oldlenp) {
                *oldlenp = need;
            }
            return 0;
        }
        // hw.product / hw.productname
        if ([n isEqualToString:@"hw.product"] || [n isEqualToString:@"hw.productname"]) {
            const char *val = [P().productType UTF8String];
            size_t need = strlen(val) + 1;
            if (oldp && oldlenp) {
                if (*oldlenp >= need) memcpy(oldp, val, need);
                *oldlenp = need;
            } else if (oldlenp) {
                *oldlenp = need;
            }
            return 0;
        }
        // hw.target / hw.boardid
        if ([n isEqualToString:@"hw.target"]) {
            const char *val = [P().internalName UTF8String];
            size_t need = strlen(val) + 1;
            if (oldp && oldlenp) {
                if (*oldlenp >= need) memcpy(oldp, val, need);
                *oldlenp = need;
            } else if (oldlenp) {
                *oldlenp = need;
            }
            return 0;
        }
    }
    return orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
}

%ctor {
    MSHookFunction((void *)&sysctlbyname, (void *)sc_sysctlbyname, (void **)&orig_sysctlbyname);
}

// ============================================================================
//  5. IOKit - IOPlatformExpertDevice (UDID, serial, ECID, board-id)
//     App dùng IOKit matching để lấy UniqueDeviceID / serial-number / ECID.
// ============================================================================
// Hook IORegistryEntryCreateCFProperty để filter key trên IOPlatformExpertDevice

extern CFTypeRef IORegistryEntryCreateCFProperty(io_registry_entry_t entry,
    CFStringRef key, CFAllocatorRef allocator, IOOptionBits options);

static CFTypeRef (*orig_IORegistryEntryCreateCFProperty)(io_registry_entry_t,
    CFStringRef, CFAllocatorRef, IOOptionBits);

static CFDataRef SCCFDataFromString(NSString *s) {
    NSData *data = [s dataUsingEncoding:NSUTF8StringEncoding] ?: [NSData data];
    return (__bridge_retained CFDataRef)data;
}

static CFTypeRef sc_IORegistryEntryCreateCFProperty(io_registry_entry_t entry,
    CFStringRef key, CFAllocatorRef allocator, IOOptionBits options) {
    if (SC_ON() && P()) {
        NSString *k = (__bridge NSString *)key;
        // Trả về các property đã spoof
        if ([k isEqualToString:@"IOPlatformUUID"]) {
            return (__bridge_retained CFTypeRef)CFG().spoofedUDID;
        }
        if ([k isEqualToString:@"IOPlatformSerialNumber"]) {
            return (__bridge_retained CFTypeRef)CFG().spoofedSerial;
        }
        if ([k isEqualToString:@"IOPlatformECID"]) {
            unsigned long long ecid = 0;
            [[NSScanner scannerWithString:CFG().spoofedECID ?: @"0"] scanHexLongLong:&ecid];
            return CFNumberCreate(kCFAllocatorDefault, kCFNumberLongLongType, &ecid);
        }
        if ([k isEqualToString:@"board-id"]) {
            return SCCFDataFromString(P().boardId ?: @"");
        }
        if ([k isEqualToString:@"product-name"]) {
            return SCCFDataFromString(P().productType ?: @"");
        }
        if ([k isEqualToString:@"model"]) {
            return SCCFDataFromString(P().hardwareModel ?: @"");
        }
        if ([k isEqualToString:@"device-tree"]) {
            // không can thiệp sâu vào device-tree
        }
    }
    return orig_IORegistryEntryCreateCFProperty(entry, key, allocator, options);
}

%ctor {
    void *iokit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW);
    if (iokit) {
        MSHookFunction((void *)&IORegistryEntryCreateCFProperty,
                       (void *)sc_IORegistryEntryCreateCFProperty,
                       (void **)&orig_IORegistryEntryCreateCFProperty);
    }
}

// ============================================================================
//  6. AdSupport - IDFA
// ============================================================================
%group IDFA
@interface ASIdentifierManager : NSObject
+ (instancetype)sharedManager;
- (NSUUID *)advertisingIdentifier;
- (BOOL)isAdvertisingTrackingEnabled;
@end

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    if (SC_ON() && CFG().spoofIDFA) {
        return [[NSUUID alloc] initWithUUIDString:CFG().spoofedIDFA];
    }
    return %orig;
}
- (BOOL)isAdvertisingTrackingEnabled {
    if (SC_ON() && CFG().spoofIDFA) return YES;
    return %orig;
}
%end
%end

%ctor {
    Class c = objc_getClass("ASIdentifierManager");
    if (c) %init(IDFA);
}

// ============================================================================
//  7. Jailbreak detection - ẩn file hệ thống, environment
// ============================================================================

// Hook access/stat/lstat/open để ẩn file jailbreak
static NSArray *sc_jb_paths;
static NSArray *sc_jb_path_prefixes;

static BOOL sc_is_jb_path(NSString *p) {
    if (!sc_jb_paths) {
        sc_jb_paths = @[
            @"/Applications/Cydia.app", @"/Library/MobileSubstrate/MobileSubstrate.dylib",
            @"/bin/bash", @"/usr/sbin/sshd", @"/etc/apt", @"/usr/bin/ssh",
            @"/private/var/lib/apt", @"/Applications/Sileo.app",
            @"/Applications/Zebra.app", @"/var/jb", @"/var/checkra1n.dmg",
            @"/.bootstrapped", @"/var/lib/apt", @"/usr/lib/TweakInject",
            @"/var/jb/usr/lib/TweakInject", @"/Library/TweakInject",
            @"/usr/lib/substitute-loader.dylib", @"/usr/lib/ellekit",
            @"/var/jb/usr/lib/ellekit"
        ];
        sc_jb_path_prefixes = @[
            @"/var/jb/", @"/var/checkra1n", @"/.file", @"/usr/lib/ellekit"
        ];
    }
    if (!p) return NO;
    if ([sc_jb_paths containsObject:p]) return YES;
    for (NSString *pre in sc_jb_path_prefixes) {
        if ([p hasPrefix:pre]) return YES;
    }
    return NO;
}

static int (*orig_access)(const char *, int);
static int sc_access(const char *path, int mode) {
    if (!path) return orig_access(path, mode);
    if (SC_ON() && CFG().hideJailbreak) {
        if (sc_is_jb_path([NSString stringWithUTF8String:path])) return -1;
    }
    return orig_access(path, mode);
}

static int (*orig_stat)(const char *, struct stat *);
static int sc_stat(const char *path, struct stat *buf) {
    if (!path) return orig_stat(path, buf);
    if (SC_ON() && CFG().hideJailbreak) {
        if (sc_is_jb_path([NSString stringWithUTF8String:path])) {
            errno = ENOENT;
            return -1;
        }
    }
    return orig_stat(path, buf);
}

static int (*orig_lstat)(const char *, struct stat *);
static int sc_lstat(const char *path, struct stat *buf) {
    if (!path) return orig_lstat(path, buf);
    if (SC_ON() && CFG().hideJailbreak) {
        if (sc_is_jb_path([NSString stringWithUTF8String:path])) {
            errno = ENOENT;
            return -1;
        }
    }
    return orig_lstat(path, buf);
}

static int (*orig_open)(const char *, int, ...);
static int sc_open(const char *path, int flags, ...) {
    mode_t mode = 0;
    if (flags & O_CREAT) {
        va_list ap; va_start(ap, flags);
        mode = va_arg(ap, int); va_end(ap);
    }
    if (!path) return orig_open(path, flags, mode);
    if (SC_ON() && CFG().hideJailbreak) {
        if (sc_is_jb_path([NSString stringWithUTF8String:path])) {
            errno = ENOENT;
            return -1;
        }
    }
    return orig_open(path, flags, mode);
}

// Hook canOpenURL cho scheme cydia://, sileo://
%hook UIApplication
- (BOOL)canOpenURL:(NSURL *)url {
    if (SC_ON() && CFG().hideJailbreak) {
        NSString *s = [url scheme];
        if ([s isEqualToString:@"cydia"] || [s isEqualToString:@"sileo"] ||
            [s isEqualToString:@"undecimus"] || [s isEqualToString:@"filza"] ||
            [s isEqualToString:@"activator"]) {
            return NO;
        }
    }
    return %orig;
}
%end

// Hook getenv cho DYLD_INSERT_LIBRARIES, _MSSafeMode
static char *(*orig_getenv)(const char *);
static char *sc_getenv(const char *name) {
    if (!name) return orig_getenv(name);
    if (SC_ON() && CFG().hideJailbreak) {
        NSString *n = [NSString stringWithUTF8String:name];
        if ([n isEqualToString:@"DYLD_INSERT_LIBRARIES"] ||
            [n isEqualToString:@"_MSSafeMode"] ||
            [n isEqualToString:@"SUBSTRATE_HOME"] ||
            [n isEqualToString:@"ELLEKIT_HOME"]) {
            return NULL;
        }
    }
    return orig_getenv(name);
}

// Hook fork/ptrace để chống anti-debug / detection
static pid_t (*orig_fork)(void);
static pid_t sc_fork(void) {
    if (SC_ON() && CFG().hideJailbreak) {
        errno = ENOTSUP;
        return -1;
    }
    return orig_fork();
}

%ctor {
    MSHookFunction((void *)&access, (void *)sc_access, (void **)&orig_access);
    MSHookFunction((void *)&stat,  (void *)sc_stat,  (void **)&orig_stat);
    MSHookFunction((void *)&lstat, (void *)sc_lstat, (void **)&orig_lstat);
    MSHookFunction((void *)&open,  (void *)sc_open,  (void **)&orig_open);
    MSHookFunction((void *)&getenv,(void *)sc_getenv,(void **)&orig_getenv);
    MSHookFunction((void *)&fork,  (void *)sc_fork,  (void **)&orig_fork);
}

// ============================================================================
//  8. UIScreen native (re-hook vì đã có group trên)
//    Đã cover ở section 2.
// ============================================================================

// ============================================================================
//  9. CFBundleGetValueForInfoDictionaryKey - marketing name, device info
// ============================================================================

// Hook [NSBundle infoDictionary] để sửa một số key nếu cần
%hook NSBundle
- (NSDictionary *)infoDictionary {
    NSDictionary *d = %orig;
    // Không can thiệp quá sâu vào infoDictionary để tránh crash app.
    return d;
}
%end

// ============================================================================
//  10. sysctl CTL_HW / CTL_KERN chung (uname)
// ============================================================================
// uname() trả về machine, nodeName, release...
static int (*orig_uname)(struct utsname *);
static int sc_uname(struct utsname *buf) {
    int r = orig_uname(buf);
    if (SC_ON() && P() && r == 0) {
        strlcpy(buf->machine, [P().productType UTF8String], sizeof(buf->machine));
        strlcpy(buf->nodename, "iPhone", sizeof(buf->nodename));
    }
    return r;
}

%ctor {
    MSHookFunction((void *)&uname, (void *)sc_uname, (void **)&orig_uname);
}

%ctor {
    %init(_ungrouped);
    SCBootstrap();
}
