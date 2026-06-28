#import "SCSpoofConfig.h"
#import "SCDevicePresets.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <sys/sysctl.h>
#import <sys/stat.h>
#import <sys/utsname.h>
#import <sys/mount.h>
#import <sys/statvfs.h>
#import <sys/time.h>
#import <net/if.h>
#import <mach/mach.h>
#import <mach/host_info.h>
#import <dlfcn.h>
#import <fcntl.h>
#import <unistd.h>
#import <errno.h>
#import <string.h>
#import <time.h>
#import <mach-o/dyld.h>
#import <sandbox.h>
#import <sys/sysctl.h>
#import <spawn.h>
#import <mach/mach_traps.h>
#import <mach/task_info.h>
#import <mach/mach_init.h>
#import <mach/mach_port.h>
#import <substrate.h>
#import <IOKit/IOKitLib.h>

@class WKWebViewConfiguration;
@class WKUserContentController;

@interface WKWebView : UIView
@property (nonatomic, copy) NSString *customUserAgent;
- (instancetype)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration;
@end

@interface WKWebViewConfiguration : NSObject
@property (nonatomic, strong) WKUserContentController *userContentController;
@property (nonatomic, copy) NSString *applicationNameForUserAgent;
@end

@interface WKUserContentController : NSObject
- (void)addUserScript:(id)userScript;
@end

#ifndef HW_MEMSIZE
#define HW_MEMSIZE 24
#endif
#ifndef HW_MACHINE
#define HW_MACHINE 1
#endif
#ifndef HW_MODEL
#define HW_MODEL 2
#endif

// ============================================================================
//  iOSSpoof - Tweak.x
//  Device hooks: UIDevice, sysctl, IOKit, UIScreen, battery, jailbreak.
//  Per-process config từ SCSpoofConfig.
//
//  QUAN TRỌNG: Tất cả hook chỉ được cài đặt khi shouldInjectForCurrentBundle
//  trả YES. Process không nằm trong targetBundles sẽ không bị hook gì cả.
// ============================================================================

static SCSpoofConfig *CFG() { return [SCSpoofConfig shared]; }
static SCDevicePreset *P()  { return CFG().resolvedPreset; }
static BOOL SC_ON()         { return CFG().enabled; }

static unsigned long long SCFakeTotalBytes(void) {
    NSUInteger gb = CFG().totalStorage;
    if (gb == 0 && P().capacityGB.length) gb = (NSUInteger)[P().capacityGB integerValue];
    return gb > 0 ? (unsigned long long)gb * 1024ULL * 1024ULL * 1024ULL : 0;
}

static unsigned long long SCFakeFreeBytes(void) {
    NSUInteger freeGB = CFG().freeStorage;
    if (freeGB == 0) {
        NSUInteger totalGB = CFG().totalStorage ?: (NSUInteger)[P().capacityGB integerValue];
        freeGB = totalGB > 0 ? totalGB / 3 : 0;
    }
    return freeGB > 0 ? (unsigned long long)freeGB * 1024ULL * 1024ULL * 1024ULL : 0;
}

static uint64_t SCRamBytesForPreset(void) {
    NSString *pt = P().productType ?: @"";
    if ([pt hasPrefix:@"iPhone10,"]) return 3ULL * 1024ULL * 1024ULL * 1024ULL;
    if ([pt hasPrefix:@"iPhone12,"]) return 4ULL * 1024ULL * 1024ULL * 1024ULL;
    if ([pt hasPrefix:@"iPhone13,"]) return 4ULL * 1024ULL * 1024ULL * 1024ULL;
    if ([pt hasPrefix:@"iPhone14,2"] || [pt hasPrefix:@"iPhone14,3"]) return 6ULL * 1024ULL * 1024ULL * 1024ULL;
    if ([pt hasPrefix:@"iPhone14,"]) return 4ULL * 1024ULL * 1024ULL * 1024ULL;
    if ([pt hasPrefix:@"iPhone15,"]) return 6ULL * 1024ULL * 1024ULL * 1024ULL;
    if ([pt hasPrefix:@"iPhone16,"]) return 8ULL * 1024ULL * 1024ULL * 1024ULL;
    return 6ULL * 1024ULL * 1024ULL * 1024ULL;
}

static NSOperatingSystemVersion SCFakeOSVersion(void) {
    NSString *version = CFG().systemVersion.length ? CFG().systemVersion : @"17.5";
    NSArray<NSString *> *parts = [version componentsSeparatedByString:@"."];
    NSOperatingSystemVersion v = {17, 5, 0};
    if (parts.count > 0) v.majorVersion = [parts[0] integerValue];
    if (parts.count > 1) v.minorVersion = [parts[1] integerValue];
    if (parts.count > 2) v.patchVersion = [parts[2] integerValue];
    return v;
}

static NSDictionary *SCFakeSystemVersionDictionary(void) {
    NSString *version = CFG().systemVersion.length ? CFG().systemVersion : @"17.5";
    NSString *build = CFG().buildID.length ? CFG().buildID : @"21F90";
    return @{
        @"ProductName": @"iPhone OS",
        @"ProductVersion": version,
        @"ProductBuildVersion": build,
        @"BuildVersion": build
    };
}

static BOOL SCIsSystemVersionPlistPath(NSString *path) {
    return [path isKindOfClass:NSString.class] && [path hasSuffix:@"/System/Library/CoreServices/SystemVersion.plist"];
}

static NSData *SCFakeSystemVersionPlistData(void) {
    NSDictionary *dict = SCFakeSystemVersionDictionary();
    return [NSPropertyListSerialization dataWithPropertyList:dict format:NSPropertyListXMLFormat_v1_0 options:0 error:nil];
}

static NSUUID *SCFakePasteboardUUID(void) {
    if (!SC_ON() || !CFG().pasteboardUUID.length) return nil;
    return [[NSUUID alloc] initWithUUIDString:CFG().pasteboardUUID];
}

// ----------------------------------------------------------------------------
//  Lắng nghe thay đổi preferences
// ----------------------------------------------------------------------------
static void SCPostCenter(CFNotificationCenterRef center, void *observer,
                         CFStringRef name, const void *object,
                         CFDictionaryRef userInfo) {
    [CFG() reload];
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
        if (CFG().deviceName.length) return CFG().deviceName;
        return [NSString stringWithFormat:@"%@'s iPhone", P().marketingName ?: @"iPhone"];
    }
    return %orig;
}
- (NSUUID *)identifierForVendor {
    if (SC_ON() && CFG().spoofIDFV) {
        return [[NSUUID alloc] initWithUUIDString:CFG().spoofedIDFA] ?: [NSUUID UUID];
    }
    return %orig;
}
- (NSString *)systemName {
    return %orig;
}
- (NSString *)systemVersion {
    if (SC_ON() && CFG().systemVersion) return CFG().systemVersion;
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
//  3. sysctlbyname / sysctl
// ============================================================================

static int (*orig_sysctlbyname)(const char *, void *, size_t *, void *, size_t);
static int sc_sysctlbyname(const char *name, void *oldp, size_t *oldlenp,
                           void *newp, size_t newlen) {
    if (!name) return orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
    if (SC_ON() && P()) {
        NSString *n = [NSString stringWithUTF8String:name];
        const char *val = NULL;
        if ([n isEqualToString:@"hw.machine"]) val = [P().productType UTF8String];
        else if ([n isEqualToString:@"hw.model"]) val = [P().hardwareModel UTF8String];
        else if ([n isEqualToString:@"hw.serialnumber"] || [n isEqualToString:@"hw.serialno"]) val = [CFG().spoofedSerial UTF8String];
        else if ([n isEqualToString:@"hw.UUID"] || [n isEqualToString:@"hw.uuid"]) val = [CFG().spoofedUDID UTF8String];
        else if ([n isEqualToString:@"hw.product"] || [n isEqualToString:@"hw.productname"]) val = [P().productType UTF8String];
        if ([n isEqualToString:@"hw.target"]) val = [P().internalName UTF8String];
        else if ([n isEqualToString:@"hw.bluetooth"]) val = [CFG().bluetoothMAC ?: CFG().spoofedMAC UTF8String];
        else if ([n isEqualToString:@"hw.model"]) val = [P().hardwareModel UTF8String];
        else if ([n isEqualToString:@"hw.machine_arch"]) val = "arm64e";
        else if ([n isEqualToString:@"kern.bootargs"]) val = "";
        else if ([n isEqualToString:@"kern.osversion"]) val = [CFG().buildID ?: @"21F90" UTF8String];
        else if ([n isEqualToString:@"hw.cpu_subtype"]) val = "2";
        else if ([n isEqualToString:@"hw.cpusubtype"]) val = "2";
        else if ([n isEqualToString:@"hw.cputype"]) val = "16777928"; // CPU_TYPE_ARM64
        else if ([n isEqualToString:@"hw.cpu64bit_capable"]) {
            uint32_t v = 1;
            if (oldlenp) { if (oldp && *oldlenp >= sizeof(v)) memcpy(oldp, &v, sizeof(v)); *oldlenp = sizeof(v); }
            return 0;
        }
        else if ([n isEqualToString:@"hw.physicalcpu"] || [n isEqualToString:@"hw.logicalcpu"]) {
            uint32_t v = 6;
            if (oldlenp) { if (oldp && *oldlenp >= sizeof(v)) memcpy(oldp, &v, sizeof(v)); *oldlenp = sizeof(v); }
            return 0;
        }
        else if ([n isEqualToString:@"hw.l2cachesize"]) {
            uint32_t v = 4194304;
            if (oldlenp) { if (oldp && *oldlenp >= sizeof(v)) memcpy(oldp, &v, sizeof(v)); *oldlenp = sizeof(v); }
            return 0;
        }
        else if ([n isEqualToString:@"hw.l3cachesize"]) {
            uint32_t v = 16777216;
            if (oldlenp) { if (oldp && *oldlenp >= sizeof(v)) memcpy(oldp, &v, sizeof(v)); *oldlenp = sizeof(v); }
            return 0;
        }
        else if ([n isEqualToString:@"hw.cachelinesize"]) {
            uint32_t v = 128;
            if (oldlenp) { if (oldp && *oldlenp >= sizeof(v)) memcpy(oldp, &v, sizeof(v)); *oldlenp = sizeof(v); }
            return 0;
        }
        else if ([n isEqualToString:@"hw.memsize"]) {
            uint64_t mem = SCRamBytesForPreset();
            size_t need = sizeof(mem);
            if (oldlenp) {
                if (oldp && *oldlenp >= need) memcpy(oldp, &mem, need);
                *oldlenp = need;
            }
            return 0;
        }
        if (val) {
            size_t need = strlen(val) + 1;
            if (oldlenp) {
                if (oldp && *oldlenp >= need) {
                    memcpy(oldp, val, need);
                }
                *oldlenp = need;
            }
            return 0;
        }
    }
    return orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
}

static int (*orig_sysctl)(int *, u_int, void *, size_t *, void *, size_t);
static int sc_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (SC_ON() && P() && name && namelen >= 2 && name[0] == CTL_HW) {
        if (name[1] == HW_MEMSIZE) {
            uint64_t mem = SCRamBytesForPreset();
            size_t need = sizeof(mem);
            if (oldlenp) {
                if (oldp && *oldlenp >= need) memcpy(oldp, &mem, need);
                *oldlenp = need;
            }
            return 0;
        }
        if (name[1] == HW_MACHINE || name[1] == HW_MODEL) {
            const char *val = name[1] == HW_MACHINE ? [P().productType UTF8String] : [P().hardwareModel UTF8String];
            size_t need = strlen(val) + 1;
            if (oldlenp) {
                if (oldp && *oldlenp >= need) memcpy(oldp, val, need);
                *oldlenp = need;
            }
            return 0;
        }
    }
    return orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
}

// ============================================================================
//  4. IOKit
// ============================================================================

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
        if ([k isEqualToString:@"board-id"] || [k isEqualToString:@"BoardId"]) {
            return SCCFDataFromString(P().boardId ?: @"");
        }
        if ([k isEqualToString:@"product-name"] || [k isEqualToString:@"ProductType"] || [k isEqualToString:@"hw.machine"]) {
            return SCCFDataFromString(P().productType ?: @"");
        }
        if ([k isEqualToString:@"model"] || [k isEqualToString:@"device-model"] || [k isEqualToString:@"hw.model"] || [k isEqualToString:@"HWModel"]) {
            return SCCFDataFromString(P().hardwareModel ?: @"");
        }
        if ([k isEqualToString:@"DeviceName"] || [k isEqualToString:@"MarketingName"]) {
            return (__bridge_retained CFTypeRef)(P().marketingName ?: @"iPhone");
        }
        if ([k isEqualToString:@"HardwareModel"] || [k isEqualToString:@"HWModelStr"]) {
            return (__bridge_retained CFTypeRef)(P().hardwareModel ?: @"D63AP");
        }
        // Bluetooth MAC address
        if ([k isEqualToString:@"BluetoothAddress"] || [k isEqualToString:@"local-address"]) {
            return (__bridge_retained CFTypeRef)(CFG().bluetoothMAC ?: CFG().spoofedMAC);
        }
        // Baseband version
        if ([k isEqualToString:@"baseband-versions"] || [k isEqualToString:@"sbg"] || [k isEqualToString:@"BasebandKeyHashInformation"]) {
            NSString *bb = [NSString stringWithFormat:@"%@- %@",
                CFG().systemVersion ?: P().marketingName ?: @"iPhone",
                CFG().buildID ?: @"21F90"];
            return SCCFDataFromString(bb);
        }
        // Device tree product chip
        if ([k isEqualToString:@"chip-id"]) {
            return SCCFDataFromString(P().chipId ?: @"");
        }
        if ([k isEqualToString:@"target-type"]) {
            return SCCFDataFromString(P().deviceClass ?: @"");
        }
    }
    return orig_IORegistryEntryCreateCFProperty(entry, key, allocator, options);
}

// ============================================================================
//  4b. Storage / Disk space spoofing
// ============================================================================

static int (*orig_statfs)(const char *, struct statfs *);
static int sc_statfs(const char *path, struct statfs *buf) {
    int r = orig_statfs(path, buf);
    if (r == 0 && SC_ON() && buf) {
        unsigned long long total = SCFakeTotalBytes();
        unsigned long long free = SCFakeFreeBytes();
        if (total == 0 || free == 0 || buf->f_bsize == 0) return r;
        buf->f_blocks = total / buf->f_bsize;
        buf->f_bfree = free / buf->f_bsize;
        buf->f_bavail = free / buf->f_bsize;
    }
    return r;
}

static int (*orig_statvfs)(const char *, struct statvfs *);
static int sc_statvfs(const char *path, struct statvfs *buf) {
    int r = orig_statvfs(path, buf);
    if (r == 0 && SC_ON() && buf) {
        unsigned long long total = SCFakeTotalBytes();
        unsigned long long free = SCFakeFreeBytes();
        if (total == 0 || free == 0 || buf->f_frsize == 0) return r;
        buf->f_blocks = total / buf->f_frsize;
        buf->f_bfree = free / buf->f_frsize;
        buf->f_bavail = free / buf->f_frsize;
    }
    return r;
}

// getattrlist hook removed: buffer layout is complex and caused target app crashes.
// statfs + statvfs + NSFileManager + NSURL already cover most storage detection APIs.

// host_statistics64 hook removed: vm_page_size may be 0 at hook time, causing division by zero.
// NSProcessInfo.physicalMemory + sysctl(hw.memsize) already cover RAM detection.

%hook NSFileManager
- (NSDictionary *)attributesOfFileSystemForPath:(NSString *)path error:(NSError **)error {
    NSDictionary *orig = %orig;
    if (!SC_ON()) return orig;
    unsigned long long total = SCFakeTotalBytes();
    unsigned long long free = SCFakeFreeBytes();
    if (total == 0 || free == 0) return orig;
    NSMutableDictionary *m = [NSMutableDictionary dictionaryWithDictionary:orig ?: @{}];
    m[NSFileSystemSize] = @(total);
    m[NSFileSystemFreeSize] = @(free);
    return m.copy;
}
%end

%hook NSURL
- (BOOL)getResourceValue:(id *)value forKey:(NSURLResourceKey)key error:(NSError **)error {
    BOOL ok = %orig;
    if (ok && SC_ON() && value) {
        unsigned long long total = SCFakeTotalBytes();
        unsigned long long free = SCFakeFreeBytes();
        if ([key isEqualToString:NSURLVolumeTotalCapacityKey] && total > 0) *value = @(total);
        else if ([key isEqualToString:NSURLVolumeAvailableCapacityKey] && free > 0) *value = @(free);
        else if (@available(iOS 11.0, *)) {
            if ([key isEqualToString:NSURLVolumeAvailableCapacityForImportantUsageKey] && free > 0) *value = @(free);
            else if ([key isEqualToString:NSURLVolumeAvailableCapacityForOpportunisticUsageKey] && free > 0) *value = @(free);
        }
    }
    return ok;
}
- (NSDictionary<NSURLResourceKey, id> *)resourceValuesForKeys:(NSArray<NSURLResourceKey> *)keys error:(NSError **)error {
    NSDictionary *orig = %orig;
    if (!SC_ON()) return orig;
    unsigned long long total = SCFakeTotalBytes();
    unsigned long long free = SCFakeFreeBytes();
    if (total == 0 || free == 0) return orig;
    NSMutableDictionary *m = [NSMutableDictionary dictionaryWithDictionary:orig ?: @{}];
    if ([keys containsObject:NSURLVolumeTotalCapacityKey]) m[NSURLVolumeTotalCapacityKey] = @(total);
    if ([keys containsObject:NSURLVolumeAvailableCapacityKey]) m[NSURLVolumeAvailableCapacityKey] = @(free);
    if (@available(iOS 11.0, *)) {
        if ([keys containsObject:NSURLVolumeAvailableCapacityForImportantUsageKey]) m[NSURLVolumeAvailableCapacityForImportantUsageKey] = @(free);
        if ([keys containsObject:NSURLVolumeAvailableCapacityForOpportunisticUsageKey]) m[NSURLVolumeAvailableCapacityForOpportunisticUsageKey] = @(free);
    }
    return m.copy;
}
%end

// ============================================================================
//  4c. NSProcessInfo - processorCount, physicalMemory, thermalState
// ============================================================================

%hook NSProcessInfo
- (NSUInteger)processorCount {
    if (SC_ON() && P()) {
        // A-series: 6 cores for modern devices
        return 6;
    }
    return %orig;
}
- (uint64_t)physicalMemory {
    if (SC_ON() && P()) {
        return SCRamBytesForPreset();
    }
    return %orig;
}
- (NSString *)operatingSystemVersionString {
    if (SC_ON() && CFG().systemVersion) {
        return [NSString stringWithFormat:@"Version %@ (Build %@)", CFG().systemVersion, CFG().buildID ?: @"21F90"];
    }
    return %orig;
}
- (NSOperatingSystemVersion)operatingSystemVersion {
    if (SC_ON() && CFG().systemVersion.length) return SCFakeOSVersion();
    return %orig;
}
- (BOOL)isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion)version {
    if (SC_ON() && CFG().systemVersion.length) {
        NSOperatingSystemVersion current = SCFakeOSVersion();
        if (current.majorVersion != version.majorVersion) return current.majorVersion > version.majorVersion;
        if (current.minorVersion != version.minorVersion) return current.minorVersion > version.minorVersion;
        return current.patchVersion >= version.patchVersion;
    }
    return %orig;
}
- (NSProcessInfoThermalState)thermalState {
    if (SC_ON()) return NSProcessInfoThermalStateNominal;
    return %orig;
}
- (BOOL)isLowPowerModeEnabled {
    if (SC_ON()) return CFG().lowPowerMode;
    return %orig;
}
%end

// ============================================================================
//  4d. UIDevice power state (already hooked in section 1)
// ============================================================================

// ============================================================================
//  4e. User-Agent spoofing (NSMutableURLRequest / NSURLSession)
// ============================================================================

static UILabel *SCStatusOverlayLabel;

static NSString *SCNativeUserAgent(void) {
    NSString *version = CFG().systemVersion.length ? CFG().systemVersion : @"17.5";
    NSString *v = [version stringByReplacingOccurrencesOfString:@"." withString:@"_"];
    return [NSString stringWithFormat:@"Mozilla/5.0 (iPhone; CPU iPhone OS %@ like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/%@ Mobile/15E148 Safari/604.1", v, version];
}

static void SCUpdateStatusOverlayText(UIWindow *window) {
    if (!SCStatusOverlayLabel || !window) return;
    CGFloat top = 0;
    if (@available(iOS 11.0, *)) top = window.safeAreaInsets.top;
    if (top < 20) top = 20;
    SCStatusOverlayLabel.frame = CGRectMake(0, 0, window.bounds.size.width, top);
    NSString *ssid = CFG().wifiSSID.length ? CFG().wifiSSID : @"MyWiFi";
    NSString *network = CFG().networkMode == 1 ? [NSString stringWithFormat:@"WiFi %@", ssid] : (CFG().networkMode == 2 ? @"Cellular" : @"Net");
    NSString *storage = SCFakeTotalBytes() > 0 ? [NSString stringWithFormat:@"%llu/%lluGB", SCFakeFreeBytes() / 1024ULL / 1024ULL / 1024ULL, SCFakeTotalBytes() / 1024ULL / 1024ULL / 1024ULL] : @"";
    NSString *ram = [NSString stringWithFormat:@"%lluGB", SCRamBytesForPreset() / 1024ULL / 1024ULL / 1024ULL];
    SCStatusOverlayLabel.text = [NSString stringWithFormat:@" %@ | %@ | %@ | %@ ", P().marketingName ?: P().productType ?: @"iPhone", network, storage, ram];
    [window bringSubviewToFront:SCStatusOverlayLabel];
}

static void SCInstallStatusOverlay(UIWindow *window) {
    if (!SC_ON() || !window || !P()) return;
    if (window.windowLevel > UIWindowLevelNormal) return;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SCStatusOverlayLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        SCStatusOverlayLabel.tag = 55123;
        SCStatusOverlayLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.78];
        SCStatusOverlayLabel.textColor = [UIColor whiteColor];
        SCStatusOverlayLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
        SCStatusOverlayLabel.textAlignment = NSTextAlignmentCenter;
        SCStatusOverlayLabel.numberOfLines = 1;
        SCStatusOverlayLabel.userInteractionEnabled = NO;
        SCStatusOverlayLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    });
    if (!SCStatusOverlayLabel.superview) {
        [window addSubview:SCStatusOverlayLabel];
    }
    SCUpdateStatusOverlayText(window);
}

%hook UIWindow
- (void)makeKeyAndVisible {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        SCInstallStatusOverlay(self);
    });
}
- (void)didMoveToWindow {
    %orig;
    if (self.isKeyWindow) {
        dispatch_async(dispatch_get_main_queue(), ^{
            SCInstallStatusOverlay(self);
        });
    }
}
- (void)layoutSubviews {
    %orig;
    if (SCStatusOverlayLabel && SCStatusOverlayLabel.superview == self) {
        SCUpdateStatusOverlayText(self);
    }
}
%end

%hook NSMutableURLRequest
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if (SC_ON() && [field caseInsensitiveCompare:@"User-Agent"] == NSOrderedSame) {
        %orig(SCNativeUserAgent(), field);
        return;
    }
    %orig;
}
- (void)setAllHTTPHeaderFields:(NSDictionary<NSString *,NSString *> *)headerFields {
    if (SC_ON()) {
        NSMutableDictionary *m = [NSMutableDictionary dictionaryWithDictionary:headerFields ?: @{}];
        m[@"User-Agent"] = SCNativeUserAgent();
        %orig(m);
        return;
    }
    %orig;
}
%end

%hook NSURLRequest
- (NSDictionary<NSString *,NSString *> *)allHTTPHeaderFields {
    NSDictionary *d = %orig;
    if (SC_ON()) {
        NSMutableDictionary *m = [NSMutableDictionary dictionaryWithDictionary:d ?: @{}];
        m[@"User-Agent"] = SCNativeUserAgent();
        return m;
    }
    return d;
}
%end

%hook NSURLSessionConfiguration
- (NSDictionary *)HTTPAdditionalHeaders {
    NSDictionary *d = %orig;
    if (SC_ON() && CFG().systemVersion) {
        NSString *ua = SCNativeUserAgent();
        NSMutableDictionary *m = [NSMutableDictionary dictionaryWithDictionary:d ?: @{}];
        m[@"User-Agent"] = ua;
        return [m copy];
    }
    return d;
}
%end

// ============================================================================
//  4g. Pasteboard UUID fingerprint surface
// ============================================================================

%hook UIPasteboard
- (NSUUID *)uniquePasteboardUUID {
    NSUUID *uuid = SCFakePasteboardUUID();
    if (uuid) return uuid;
    return %orig;
}
- (id)valueForPasteboardType:(NSString *)pasteboardType {
    if ([pasteboardType isEqualToString:@"com.apple.uikit.pboard-uuid"]) {
        NSUUID *uuid = SCFakePasteboardUUID();
        if (uuid) return [NSKeyedArchiver archivedDataWithRootObject:uuid];
    }
    return %orig;
}
%end

// ============================================================================
//  4f. SystemVersion.plist / CoreFoundation version dictionary
// ============================================================================

%hook NSDictionary
+ (id)dictionaryWithContentsOfFile:(NSString *)path {
    if (SC_ON() && SCIsSystemVersionPlistPath(path)) return SCFakeSystemVersionDictionary();
    return %orig;
}
- (id)initWithContentsOfFile:(NSString *)path {
    if (SC_ON() && SCIsSystemVersionPlistPath(path)) return [SCFakeSystemVersionDictionary() copy];
    return %orig;
}
%end

%hook NSData
+ (id)dataWithContentsOfFile:(NSString *)path {
    if (SC_ON() && SCIsSystemVersionPlistPath(path)) return SCFakeSystemVersionPlistData();
    return %orig;
}
- (id)initWithContentsOfFile:(NSString *)path {
    if (SC_ON() && SCIsSystemVersionPlistPath(path)) return [SCFakeSystemVersionPlistData() copy];
    return %orig;
}
%end

%hook NSString
+ (id)stringWithContentsOfFile:(NSString *)path encoding:(NSStringEncoding)enc error:(NSError **)error {
    if (SC_ON() && SCIsSystemVersionPlistPath(path)) {
        NSData *data = SCFakeSystemVersionPlistData();
        return [[NSString alloc] initWithData:data encoding:enc ?: NSUTF8StringEncoding];
    }
    return %orig;
}
- (id)initWithContentsOfFile:(NSString *)path encoding:(NSStringEncoding)enc error:(NSError **)error {
    if (SC_ON() && SCIsSystemVersionPlistPath(path)) {
        NSData *data = SCFakeSystemVersionPlistData();
        return [[NSString alloc] initWithData:data encoding:enc ?: NSUTF8StringEncoding];
    }
    return %orig;
}
%end

static CFDictionaryRef (*orig_CFCopySystemVersionDictionary)(void);
static CFDictionaryRef sc_CFCopySystemVersionDictionary(void) {
    if (SC_ON() && CFG().systemVersion.length) return CFBridgingRetain(SCFakeSystemVersionDictionary());
    return orig_CFCopySystemVersionDictionary ? orig_CFCopySystemVersionDictionary() : NULL;
}

static void SCInstallSystemVersionHooks(void) {
    void *cf = dlopen("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation", RTLD_NOW);
    if (!cf) return;
    void *copyDict = dlsym(cf, "CFCopySystemVersionDictionary");
    if (copyDict) MSHookFunction(copyDict, (void *)sc_CFCopySystemVersionDictionary, (void **)&orig_CFCopySystemVersionDictionary);
}

// ============================================================================
//  5. AdSupport - IDFA
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

// ============================================================================
//  6. Jailbreak detection - statfs-based + hardcoded paths
//     Học từ roothide: dùng statfs để check mount point thay vì chỉ check path string
// ============================================================================

static NSArray *sc_jb_paths;
static NSArray *sc_jb_path_prefixes;
static NSArray *sc_jb_dylib_patterns;

// statfs-based check: nếu file nằm trên mount point != "/" → có thể là jbroot
static BOOL sc_is_jb_mountpoint(const char *path) {
    if (!path) return NO;
    struct statfs fs;
    if (statfs(path, &fs) != 0) return NO; // path not found = might be jb
    // Rootfs mount = "/"
    if (strcmp(fs.f_mntonname, "/") == 0) return NO;
    // If mounted on anything other than rootfs, likely jbroot
    // Common jbroot mount points: /var/jb, /private/preboot, etc
    if (strstr(fs.f_mntonname, "/var/jb") != NULL) return YES;
    if (strstr(fs.f_mntonname, "/private/preboot") != NULL) return YES;
    if (strstr(fs.f_mntonname, "/var/containers") != NULL) return NO; // app container, not jb
    // Unknown mount point → treat as jb
    if (strlen(fs.f_mntonname) > 1) return YES;
    return NO;
}

static BOOL sc_is_jb_path(NSString *p) {
    if (!sc_jb_paths) {
        sc_jb_paths = @[
            // Classic JB
            @"/Applications/Cydia.app", @"/Applications/Sileo.app",
            @"/Applications/Zebra.app", @"/Applications/Installer.app",
            @"/Applications/Rook.app", @"/Applications/Filza.app",
            @"/Applications/NewTerm.app", @"/Applications/MTerminal.app",
            @"/Applications/SSH.term",
            // Substrate/Substitute/Ellekit
            @"/Library/MobileSubstrate/MobileSubstrate.dylib",
            @"/usr/lib/substitute-loader.dylib", @"/usr/lib/substitute.dylib",
            @"/Library/Substitute", @"/usr/lib/substrate",
            @"/usr/lib/ellekit", @"/usr/lib/libellekit.dylib",
            @"/usr/lib/TweakInject", @"/Library/TweakInject",
            // SSH/FTP
            @"/bin/bash", @"/usr/sbin/sshd", @"/usr/bin/ssh",
            @"/etc/ssh/sshd_config", @"/usr/libexec/sftp-server",
            @"/usr/libexec/ssh-keysign",
            // APT
            @"/etc/apt", @"/etc/apt/sources.list",
            @"/var/lib/apt", @"/var/cache/apt", @"/var/log/apt",
            @"/private/var/lib/apt", @"/private/var/cache/apt",
            @"/private/var/lib/cydia",
            // Checkra1n
            @"/var/checkra1n.dmg", @"/.checkra1n", @"/var/checkra1n",
            // Other
            @"/.bootstrapped", @"/.file",
            @"/usr/lib/pspawn-helper", @"/usr/lib/prebootHelper",
        ];
        sc_jb_path_prefixes = @[
            @"/var/jb/", @"/var/checkra1n", @"/.file", @"/usr/lib/ellekit",
            @"/var/jb/usr/lib/", @"/var/jb/Library/",
            @"/private/preboot/", @"/var/jb/.basebin/",
            @"/var/containers/Bundle/Application/.jbroot",
        ];
        sc_jb_dylib_patterns = @[
            @"MobileSubstrate", @"SubstrateLoader", @"ellekit", @"Substitute",
            @"TweakInject", @"cycript", @"libhooker", @"pspawn", @"prebootHelper",
            @"libsubstrate", @"substitute-loader", @"tweakinject",
        ];
    }
    if (!p) return NO;
    // Hardcoded exact match
    if ([sc_jb_paths containsObject:p]) return YES;
    // Prefix match
    for (NSString *pre in sc_jb_path_prefixes) {
        if ([p hasPrefix:pre]) return YES;
    }
    // statfs-based check (like roothide)
    const char *cpath = [p UTF8String];
    if (sc_is_jb_mountpoint(cpath)) return YES;
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
            [s isEqualToString:@"activator"] || [s isEqualToString:@"apple-magnifier"] ||
            [s isEqualToString:@"cocktaildiagnostics"] || [s isEqualToString:@"santander"] ||
            [s isEqualToString:@"afctools"] || [s isEqualToString:@"appcake"] ||
            [s isEqualToString:@"crackerxi"] || [s isEqualToString:@"electric"] ||
            [s isEqualToString:@"flex"] || [s isEqualToString:@"flex3"] ||
            [s isEqualToString:@"filza"] || [s isEqualToString:@"cyclect"] ||
            [s isEqualToString:@"iodine"] || [s isEqualToString:@"njailbreak"] ||
            [s isEqualToString:@"pokemon"] || [s isEqualToString:@"pangu"] ||
            [s isEqualToString:@"p0laris"] || [s isEqualToString:@"tvplus"]) {
            return NO;
        }
    }
    return %orig;
}
%end

// Hook getenv - hide jailbreak env vars
static char *(*orig_getenv)(const char *);
static char *sc_getenv(const char *name) {
    if (!name) return orig_getenv(name);
    if (SC_ON() && CFG().hideJailbreak) {
        NSString *n = [NSString stringWithUTF8String:name];
        if ([n isEqualToString:@"DYLD_INSERT_LIBRARIES"] ||
            [n isEqualToString:@"_MSSafeMode"] ||
            [n isEqualToString:@"SUBSTRATE_HOME"] ||
            [n isEqualToString:@"ELLEKIT_HOME"] ||
            [n isEqualToString:@"CFFIXED_USER_HOME"] ||
            [n isEqualToString:@"DPREFIX"] ||
            [n isEqualToString:@"JailbreakOverlayPath"] ||
            [n isEqualToString:@"jailbreak"] ||
            [n isEqualToString:@"TWEAKS_ROOT"] ||
            [n isEqualToString:@"DOPAMINE_JB"] ||
            [n isEqualToString:@"ROOTHIDE_JB"] ||
            [n isEqualToString:@"CHECKRA1N_JB"]) {
            return NULL;
        }
    }
    return orig_getenv(name);
}

// fopen hook - hide jailbreak files
static FILE *(*orig_fopen)(const char *, const char *);
static FILE *sc_fopen(const char *path, const char *mode) {
    if (!path) return orig_fopen(path, mode);
    if (SC_ON() && CFG().hideJailbreak) {
        if (sc_is_jb_path([NSString stringWithUTF8String:path])) {
            return NULL;
        }
    }
    return orig_fopen(path, mode);
}

// dlopen hook - block jailbreak detection dylibs
static void *(*orig_dlopen)(const char *, int);
static void *sc_dlopen(const char *path, int mode) {
    if (!path) return orig_dlopen(path, mode);
    if (SC_ON() && CFG().hideJailbreak) {
        NSString *p = [NSString stringWithUTF8String:path];
        for (NSString *pattern in sc_jb_dylib_patterns) {
            if ([p containsString:pattern]) return NULL;
        }
    }
    return orig_dlopen(path, mode);
}

// fork() - banking apps check if fork() works
static int (*orig_fork)(void);
static pid_t sc_fork(void) {
    if (SC_ON() && CFG().hideJailbreak) {
        errno = ENOSYS;
        return -1;
    }
    return orig_fork();
}

// task_for_pid - banking apps detect debugger/jailbreak
static int (*orig_task_for_pid)(pid_t, mach_port_t *);
static int sc_task_for_pid(pid_t pid, mach_port_t *t) {
    if (SC_ON() && CFG().hideJailbreak) {
        if (t) *t = MACH_PORT_NULL;
        return 5; // KERN_FAILURE
    }
    return orig_task_for_pid(pid, t);
}

// _dyld_image_count / _dyld_get_image_name - hide dylibs injected by jailbreak
static uint32_t (*orig_dyld_image_count)(void);
static uint32_t sc_dyld_image_count(void) {
    uint32_t count = orig_dyld_image_count();
    if (SC_ON() && CFG().hideJailbreak) {
        // Subtract injected dylibs from count
        // We can't know exact count, but return a lower number
        // to hide our own dylib and substrate/ellekit
        if (count > 2) count -= 2;
    }
    return count;
}

static const char *(*orig_dyld_get_image_name)(uint32_t);
static const char *sc_dyld_get_image_name(uint32_t image_index) {
    const char *name = orig_dyld_get_image_name(image_index);
    if (SC_ON() && CFG().hideJailbreak && name) {
        NSString *n = [NSString stringWithUTF8String:name];
        for (NSString *pattern in sc_jb_dylib_patterns) {
            if ([n containsString:pattern]) {
                // Return a system framework path instead
                return "/System/Library/Frameworks/Foundation.framework/Foundation";
            }
        }
        if ([n containsString:@"iOSSpoof"]) return "/System/Library/Frameworks/Foundation.framework/Foundation";
    }
    return name;
}

// sandbox_check - banking apps use sandbox_check for jailbreak detection
static int (*orig_sandbox_init)(const char *, uint64_t, char **);
static int sc_sandbox_init(const char *profile, uint64_t flags, char **errorbuf) {
    return orig_sandbox_init(profile, flags, errorbuf);
}

// csops - banking apps check CS_OPS_STATUS for code signing flags
extern int csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);
static int (*orig_csops)(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);
static int sc_csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize) {
    int r = orig_csops(pid, ops, useraddr, usersize);
    if (r == 0 && SC_ON() && CFG().hideJailbreak && ops == 0 && useraddr && usersize >= sizeof(uint32_t)) {
        uint32_t *flags = (uint32_t *)useraddr;
        *flags &= ~0x04000000; // CS_PLATFORM_BINARY
        *flags &= ~0x10000000; // CS_DEBUGGED
    }
    return r;
}

// ============================================================================
//  6b. Process enumeration / mach_msg / /proc/self/environ
//      Roothide KHÔNG cover những thứ này — iOSSpoof bổ sung
// ============================================================================

// proc_listpids — DISABLED: causes crash, proc_pidpath/proc_name are sufficient
// static int (*orig_proc_listpids)(uint32_t, uint32_t, void *, uint32_t);

// sysctl(KERN_PROC) — banking apps enumerate processes via sysctl
// Already hooked in sc_sysctl, but that only handles CTL_HW
// We need a separate hook for KERN_PROC to filter process names
static int (*orig_proc_pidpath)(pid_t pid, void *buffer, uint32_t buffersize);
extern int proc_pidpath(pid_t pid, void *buffer, uint32_t buffersize);
static int sc_proc_pidpath(pid_t pid, void *buffer, uint32_t buffersize) {
    int r = orig_proc_pidpath(pid, buffer, buffersize);
    if (r > 0 && SC_ON() && CFG().hideJailbreak && buffer) {
        char *path = (char *)buffer;
        NSString *p = [NSString stringWithUTF8String:path];
        // Hide jailbreak process paths
        if ([p containsString:@"jailbreakd"] || [p containsString:@"sshd"] ||
            [p containsString:@"bash"] || [p containsString:@"substrate"] ||
            [p containsString:@"ellekit"] || [p containsString:@"dpkg"] ||
            [p containsString:@"apt"] || [p containsString:@"cydia"] ||
            [p containsString:@"sileo"] || [p containsString:@"zebra"] ||
            [p containsString:@"tweakloader"] || [p containsString:@"roothide"] ||
            [p containsString:@"dopamine"] || [p containsString:@"jbctl"]) {
            strlcpy(path, "/usr/libexec/logd", buffersize);
        }
    }
    return r;
}

static int (*orig_proc_name)(pid_t pid, void *buffer, uint32_t buffersize);
extern int proc_name(pid_t pid, void *buffer, uint32_t buffersize);
static int sc_proc_name(pid_t pid, void *buffer, uint32_t buffersize) {
    int r = orig_proc_name(pid, buffer, buffersize);
    if (r > 0 && SC_ON() && CFG().hideJailbreak && buffer) {
        char *name = (char *)buffer;
        if (strstr(name, "jailbreakd") || strstr(name, "sshd") ||
            strstr(name, "bash") || strstr(name, "substrate") ||
            strstr(name, "ellekit") || strstr(name, "dpkg") ||
            strstr(name, "apt") || strstr(name, "cydia") ||
            strstr(name, "sileo") || strstr(name, "zebra") ||
            strstr(name, "tweakloader") || strstr(name, "roothide") ||
            strstr(name, "dopamine") || strstr(name, "jbctl")) {
            strlcpy(name, "launchd", buffersize);
        }
    }
    return r;
}

// task_info — DISABLED: causes crash in some apps
// static kern_return_t (*orig_task_info)(task_name_t, task_flavor_t, task_info_t, mach_msg_type_number_t *);

// proc_listpids — DISABLED: causes crash, proc_pidpath/proc_name are sufficient
// static int (*orig_proc_listpids)(uint32_t, uint32_t, void *, uint32_t);

// /proc/self/environ — banking apps read this file to get DYLD_INSERT_LIBRARIES
// Hook open/read for /proc paths
static ssize_t (*orig_readlink)(const char *, char *, size_t);
static ssize_t sc_readlink(const char *path, char *buf, size_t bufsize) {
    ssize_t r = orig_readlink(path, buf, bufsize);
    if (r > 0 && SC_ON() && CFG().hideJailbreak && path) {
        NSString *p = [NSString stringWithUTF8String:path];
        // Hide jailbreak symlinks
        if ([p hasPrefix:@"/var/jb"] || [p hasPrefix:@"/private/preboot"]) {
            NSString *result = [NSString stringWithUTF8String:buf];
            if ([result containsString:@"/var/jb"] || [result containsString:@"jbroot"] ||
                [result containsString:@"substrate"] || [result containsString:@"ellekit"]) {
                strlcpy(buf, "/usr/lib", bufsize);
                r = strlen(buf);
            }
        }
    }
    return r;
}

// realpath — resolve symlinks, banking apps use to detect jbroot
static char *(*orig_realpath)(const char *, char *);
static char *sc_realpath(const char *path, char *resolved) {
    char *r = orig_realpath(path, resolved);
    if (r && SC_ON() && CFG().hideJailbreak && path) {
        NSString *p = [NSString stringWithUTF8String:path];
        if ([p hasPrefix:@"/var/jb"] || [p hasPrefix:@"/private/preboot"]) {
            NSString *result = [NSString stringWithUTF8String:r];
            if ([result containsString:@"/var/jb"] || [result containsString:@"jbroot"] ||
                [result containsString:@"/private/preboot"]) {
                // Return original path instead of resolved
                strlcpy(r, path, PATH_MAX);
            }
        }
    }
    return r;
}

// posix_spawn — strip DYLD_INSERT_LIBRARIES from child process env
static int (*orig_posix_spawn)(pid_t *, const char *, const posix_spawn_file_actions_t *, const posix_spawnattr_t *, char *const[], char *const[]);
static int sc_posix_spawn(pid_t *pid, const char *path, const posix_spawn_file_actions_t *file_actions, const posix_spawnattr_t *attrp, char *const argv[], char *const envp[]) {
    if (SC_ON() && CFG().hideJailbreak && envp) {
        @try {
            NSMutableArray *newEnv = [NSMutableArray array];
            for (char *const *e = envp; *e; e++) {
                NSString *env = [NSString stringWithUTF8String:*e];
                if (![env hasPrefix:@"DYLD_INSERT_LIBRARIES="] &&
                    ![env hasPrefix:@"_MSSafeMode="] &&
                    ![env hasPrefix:@"ELLEKIT_HOME="] &&
                    ![env hasPrefix:@"SUBSTRATE_HOME="] &&
                    ![env hasPrefix:@"TWEAKS_ROOT="] &&
                    ![env hasPrefix:@"CFFIXED_USER_HOME="]) {
                    [newEnv addObject:env];
                }
            }
            NSUInteger count = newEnv.count;
            if (count > 0) {
                char **newEnvp = (char **)calloc(count + 1, sizeof(char *));
                for (NSUInteger i = 0; i < count; i++) {
                    newEnvp[i] = (char *)[newEnv[i] UTF8String];
                }
                newEnvp[count] = NULL;
                int r = orig_posix_spawn(pid, path, file_actions, attrp, argv, newEnvp);
                free(newEnvp);
                return r;
            }
        } @catch (__unused id e) {}
    }
    return orig_posix_spawn(pid, path, file_actions, attrp, argv, envp);
}

// ============================================================================
//  6c. Mach-level anti-detection (roothide does NOT cover these)
// ============================================================================

// task_threads — DISABLED: causes crash in some apps
// static kern_return_t (*orig_task_threads)(task_t, thread_act_array_t *, mach_msg_type_number_t *);

// thread_info — DISABLED: causes crash in some apps
// static kern_return_t (*orig_thread_info)(thread_act_t, thread_flavor_t, thread_info_t, mach_msg_type_number_t *);

// mach_port_names — DISABLED: causes crash in some apps
// static kern_return_t (*orig_mach_port_names)(task_t, mach_port_name_array_t *, mach_msg_type_number_t *, mach_port_type_array_t *, mach_msg_type_number_t *);

// task_info — DISABLED: causes crash in some apps
// static kern_return_t (*orig_task_info)(task_name_t, task_flavor_t, task_info_t, mach_msg_type_number_t *);

// ============================================================================
//  7. NSBundle
// ============================================================================

%hook NSBundle
- (NSDictionary *)infoDictionary {
    NSDictionary *d = %orig;
    return d;
}
%end

// ============================================================================
//  8. uname
// ============================================================================

static int (*orig_uname)(struct utsname *);
static int sc_uname(struct utsname *buf) {
    int r = orig_uname(buf);
    if (SC_ON() && P() && r == 0) {
        strlcpy(buf->machine, [P().productType UTF8String], sizeof(buf->machine));
        strlcpy(buf->nodename, "iPhone", sizeof(buf->nodename));
    }
    return r;
}

// ============================================================================
//  10. Locale / Timezone / Timestamp spoof
// ============================================================================

%hook NSLocale
- (NSString *)localeIdentifier {
    if (SC_ON() && CFG().localeIdentifier.length) return CFG().localeIdentifier;
    return %orig;
}
- (NSString *)countryCode {
    if (SC_ON() && CFG().localeIdentifier.length) {
        NSArray *parts = [CFG().localeIdentifier componentsSeparatedByString:@"_"];
        if (parts.count >= 2) return parts[1];
    }
    return %orig;
}
- (NSString *)languageCode {
    if (SC_ON() && CFG().localeIdentifier.length) {
        NSArray *parts = [CFG().localeIdentifier componentsSeparatedByString:@"_"];
        if (parts.count >= 1) return parts[0];
    }
    return %orig;
}
+ (instancetype)currentLocale {
    if (SC_ON() && CFG().localeIdentifier.length) {
        return [NSLocale localeWithLocaleIdentifier:CFG().localeIdentifier];
    }
    return %orig;
}
+ (instancetype)systemLocale {
    if (SC_ON() && CFG().localeIdentifier.length) {
        return [NSLocale localeWithLocaleIdentifier:CFG().localeIdentifier];
    }
    return %orig;
}
+ (NSArray *)preferredLanguages {
    NSArray *orig = %orig;
    if (SC_ON() && CFG().localeIdentifier.length) {
        NSMutableArray *m = [NSMutableArray arrayWithObject:CFG().localeIdentifier];
        [m addObjectsFromArray:orig];
        return m.copy;
    }
    return orig;
}
%end

%hook NSTimeZone
+ (instancetype)systemTimeZone {
    if (SC_ON() && CFG().timezoneIdentifier.length) return [NSTimeZone timeZoneWithName:CFG().timezoneIdentifier];
    return %orig;
}
+ (instancetype)localTimeZone {
    if (SC_ON() && CFG().timezoneIdentifier.length) return [NSTimeZone timeZoneWithName:CFG().timezoneIdentifier];
    return %orig;
}
+ (instancetype)defaultTimeZone {
    if (SC_ON() && CFG().timezoneIdentifier.length) return [NSTimeZone timeZoneWithName:CFG().timezoneIdentifier];
    return %orig;
}
+ (instancetype)timeZoneForSecondsFromGMT:(NSInteger)seconds {
    if (SC_ON() && CFG().timezoneIdentifier.length) return [NSTimeZone timeZoneWithName:CFG().timezoneIdentifier];
    return %orig;
}
%end

%hook NSDate
+ (instancetype)date {
    NSDate *d = %orig;
    if (SC_ON() && CFG().timestampOffset != 0) {
        return [d dateByAddingTimeInterval:CFG().timestampOffset];
    }
    return d;
}
+ (instancetype)distantPast { return %orig; }
+ (instancetype)distantFuture { return %orig; }
- (instancetype)init {
    self = %orig;
    if (SC_ON() && CFG().timestampOffset != 0) {
        return [self dateByAddingTimeInterval:CFG().timestampOffset];
    }
    return self;
}
%end

%hook NSCalendar
+ (instancetype)currentCalendar {
    NSCalendar *c = %orig;
    if (SC_ON() && CFG().timezoneIdentifier.length) {
        c.timeZone = [NSTimeZone timeZoneWithName:CFG().timezoneIdentifier];
    }
    if (SC_ON() && CFG().localeIdentifier.length) {
        c.locale = [NSLocale localeWithLocaleIdentifier:CFG().localeIdentifier];
    }
    return c;
}
+ (instancetype)autoupdatingCurrentCalendar {
    NSCalendar *c = %orig;
    if (SC_ON() && CFG().timezoneIdentifier.length) {
        c.timeZone = [NSTimeZone timeZoneWithName:CFG().timezoneIdentifier];
    }
    if (SC_ON() && CFG().localeIdentifier.length) {
        c.locale = [NSLocale localeWithLocaleIdentifier:CFG().localeIdentifier];
    }
    return c;
}
%end

// time() / gettimeofday() / clock_gettime — fake timestamp
static time_t (*orig_time)(time_t *);
static time_t sc_time(time_t *t) {
    time_t r = orig_time(t);
    if (SC_ON() && CFG().timestampOffset != 0) {
        r += (time_t)CFG().timestampOffset;
        if (t) *t = r;
    }
    return r;
}

static int (*orig_gettimeofday)(struct timeval *, struct timezone *);
static int sc_gettimeofday(struct timeval *tv, struct timezone *tz) {
    int r = orig_gettimeofday(tv, tz);
    if (r == 0 && SC_ON() && CFG().timestampOffset != 0 && tv) {
        tv->tv_sec += (time_t)CFG().timestampOffset;
    }
    return r;
}


//    Chỉ cài hook khi process hiện tại nằm trong targetBundles.
//    Process không target: return ngay, không hook gì, zero overhead.
// ============================================================================

// Protected bundles: tweak sẽ KHÔNG bao giờ inject vào các app này,
// kể cả khi user vô tình thêm vào targetBundles.
static NSSet *sc_protected_bundles(void) {
    static NSSet *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        s = [NSSet setWithArray:@[
            @"com.iosspoof.app",
            @"org.coolstar.SileoStore",
            @"org.coolstar.Sileo",
            @"com.saurik.Cydia",
            @"xyz.willy.Zebra",
            @"me.apptapp.Installer",
            @"com.opa334.Dopamine",
            @"com.opa334.TrollStore",
            @"com.opa334.TrollStorePersistenceHelper",
            @"com.apple.springboard",
            @"com.apple.Preferences",
            @"com.apple.mobilesafari",
            @"com.apple.MobileSMS",
            @"com.apple.mobilephone",
            @"com.apple.mobilemail"
        ]];
    });
    return s;
}

// ============================================================================
// WebKit / WKWebView fingerprint surface
// ============================================================================

static NSString *SCWebKitUserAgent(void) {
    NSString *version = CFG().systemVersion.length ? CFG().systemVersion : @"17_5";
    version = [version stringByReplacingOccurrencesOfString:@"." withString:@"_"];
    return [NSString stringWithFormat:@"Mozilla/5.0 (iPhone; CPU iPhone OS %@ like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", version];
}

static NSString *SCWebKitSpoofScript(void) {
    CGFloat scale = MAX((CGFloat)P().screenScale, 1.0);
    NSInteger width = P().screenWidth / scale;
    NSInteger height = P().screenHeight / scale;
    NSString *locale = CFG().localeIdentifier.length ? [CFG().localeIdentifier stringByReplacingOccurrencesOfString:@"_" withString:@"-"] : @"en-US";
    NSString *tz = CFG().timezoneIdentifier.length ? CFG().timezoneIdentifier : @"UTC";
    NSString *platform = @"iPhone";
    NSString *ua = SCWebKitUserAgent();
    return [NSString stringWithFormat:
        @"(()=>{const def=(o,k,v)=>{try{Object.defineProperty(o,k,{get:()=>v,configurable:true});}catch(e){}};"
         "def(navigator,'userAgent','%@');def(navigator,'platform','%@');def(navigator,'language','%@');def(navigator,'languages',['%@','en-US','en']);"
         "def(navigator,'hardwareConcurrency',6);def(navigator,'maxTouchPoints',5);"
         "def(screen,'width',%ld);def(screen,'height',%ld);def(screen,'availWidth',%ld);def(screen,'availHeight',%ld);def(window,'devicePixelRatio',%.1f);"
         "const ro=Intl.DateTimeFormat.prototype.resolvedOptions;Intl.DateTimeFormat.prototype.resolvedOptions=function(){const r=ro.call(this);r.timeZone='%@';r.locale='%@';return r;};"
         "if(navigator.mediaDevices){navigator.mediaDevices.enumerateDevices=()=>Promise.resolve([]);}"
         "})();", ua, platform, locale, locale, (long)width, (long)height, (long)width, (long)height, scale, tz, locale];
}

static void SCInjectWebKitScript(WKWebViewConfiguration *configuration) {
    if (!SC_ON() || !P() || !configuration) return;
    Class scriptClass = NSClassFromString(@"WKUserScript");
    Class controllerClass = NSClassFromString(@"WKUserContentController");
    if (!scriptClass || !controllerClass) return;
    if (!configuration.userContentController) configuration.userContentController = [controllerClass new];
    SEL initSel = NSSelectorFromString(@"initWithSource:injectionTime:forMainFrameOnly:");
    if (![scriptClass instancesRespondToSelector:initSel]) return;
    id script = ((id (*)(id, SEL, NSString *, NSInteger, BOOL))objc_msgSend)([scriptClass alloc], initSel, SCWebKitSpoofScript(), 0, NO);
    [configuration.userContentController addUserScript:script];
    configuration.applicationNameForUserAgent = @"Mobile/15E148";
}

// ============================================================================
// MobileGestalt — private Apple source for Settings/About and many capabilities
// ============================================================================

static CFTypeRef (*orig_MGCopyAnswer)(CFStringRef key);
static CFDictionaryRef (*orig_MGCopyMultipleAnswers)(CFArrayRef keys, CFDictionaryRef options);

static CFTypeRef SCCopyMobileGestaltAnswer(CFStringRef key) {
    if (!SC_ON() || !P() || !key) return NULL;
    NSString *k = (__bridge NSString *)key;
    NSDictionary *p = @{
        @"ProductType": P().productType ?: @"iPhone14,5",
        @"ProductName": P().marketingName ?: @"iPhone",
        @"MarketingName": P().marketingName ?: @"iPhone",
        @"HWModelStr": P().hardwareModel ?: @"D63AP",
        @"HardwareModel": P().hardwareModel ?: @"D63AP",
        @"DeviceClass": @"iPhone",
        @"DeviceVariant": @"A",
        @"ModelNumber": P().modelNumber ?: @"MLNG3LL/A",
        @"BoardId": P().boardId ?: @"0x08",
        @"ChipID": P().chipId ?: @"t8110",
        @"HardwarePlatform": P().hardwareModel ?: @"D63AP",
        @"ArtworkDeviceSubType": @(P().screenHeight >= 2688 ? 2436 : 1792),
        @"DeviceSubType": @(P().screenHeight >= 2688 ? 2436 : 1792),
        @"BuildVersion": CFG().buildID ?: @"21F90",
        @"ProductVersion": CFG().systemVersion ?: @"17.5",
        @"ReleaseType": @"User",
        @"UniqueDeviceID": CFG().spoofedUDID ?: @"",
        @"SerialNumber": CFG().spoofedSerial ?: @"",
        @"MLBSerialNumber": CFG().spoofedSerial ?: @"",
        @"UniqueChipID": CFG().spoofedECID ?: @"",
        @"DieID": CFG().spoofedECID ?: @"",
        @"InternationalMobileEquipmentIdentity": CFG().spoofedIMEI ?: @"",
        @"InternationalMobileEquipmentIdentity2": CFG().simSlots.count > 1 ? CFG().spoofedIMEI ?: @"" : @"",
        @"BasebandVersion": @"5.00.00",
        @"BasebandChipID": @"0x00000001",
        @"BasebandCertId": @"0x00000001",
        @"FirmwareVersion": CFG().buildID ?: @"21F90",
        @"WifiAddress": CFG().spoofedMAC ?: @"",
        @"BluetoothAddress": CFG().bluetoothMAC.length ? CFG().bluetoothMAC : (CFG().spoofedMAC ?: @""),
        @"RegionCode": CFG().carrierISO.length ? CFG().carrierISO.uppercaseString : @"US",
        @"RegionInfo": CFG().carrierISO.length ? CFG().carrierISO.uppercaseString : @"US",
        @"HasBaseband": @YES,
        @"HasCellularCapability": @YES,
        @"HasTelephonyCapability": @YES,
        @"SupportsDualSIM": @(CFG().simSlots.count > 1),
        @"SupportsESIM": @YES,
        @"n78aHack": @YES,
    };
    id v = p[k];
    if (!v) return NULL;
    return CFRetain((__bridge CFTypeRef)v);
}

static CFTypeRef sc_MGCopyAnswer(CFStringRef key) {
    CFTypeRef fake = SCCopyMobileGestaltAnswer(key);
    if (fake) return fake;
    return orig_MGCopyAnswer ? orig_MGCopyAnswer(key) : NULL;
}

static CFDictionaryRef sc_MGCopyMultipleAnswers(CFArrayRef keys, CFDictionaryRef options) {
    CFDictionaryRef orig = orig_MGCopyMultipleAnswers ? orig_MGCopyMultipleAnswers(keys, options) : NULL;
    NSMutableDictionary *m = orig ? [(__bridge NSDictionary *)orig mutableCopy] : [NSMutableDictionary dictionary];
    if (orig) CFRelease(orig);
    if (SC_ON() && keys) {
        for (id keyObj in (__bridge NSArray *)keys) {
            if (![keyObj isKindOfClass:NSString.class]) continue;
            CFTypeRef fake = SCCopyMobileGestaltAnswer((__bridge CFStringRef)keyObj);
            if (fake) {
                m[keyObj] = CFBridgingRelease(fake);
            }
        }
    }
    return CFBridgingRetain(m);
}

static void SCInstallMobileGestaltHooks(void) {
    void *mg = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_NOW);
    if (!mg) mg = dlopen("/System/Library/PrivateFrameworks/MobileGestalt.framework/MobileGestalt", RTLD_NOW);
    if (!mg) return;

    void *copyAnswer = dlsym(mg, "MGCopyAnswer");
    if (copyAnswer) MSHookFunction(copyAnswer, (void *)sc_MGCopyAnswer, (void **)&orig_MGCopyAnswer);
    void *copyMultiple = dlsym(mg, "MGCopyMultipleAnswers");
    if (copyMultiple) MSHookFunction(copyMultiple, (void *)sc_MGCopyMultipleAnswers, (void **)&orig_MGCopyMultipleAnswers);
}

%ctor {
    @autoreleasepool {
        // Đọc bundle ID sớm, không khởi tạo toàn bộ SCSpoofConfig
        NSString *bid = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
        
        // Không bao giờ inject vào protected bundles
        if ([sc_protected_bundles() containsObject:bid]) return;
        
        // Khởi tạo config
        [SCSpoofConfig shared];
        
        // Kiểm tra: process này có nằm trong danh sách target không?
        if (![CFG() shouldInjectForCurrentBundle]) {
            return;
        }

        BOOL kernelMode = CFG().kernelMode;

        // Đăng ký lắng nghe thay đổi preferences
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
            NULL, SCPostCenter, CFSTR("com.iosspoof.tweak.prefs.changed"), NULL,
            CFNotificationSuspensionBehaviorCoalesce);

        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"iOSSpoofDebugLog"]) {
            NSLog(@"[iOSSpoof] injecting into %@ (preset=%@)", CFG().currentBundleID, P().productType);
        }

        // ObjC hooks
        // In kernel mode, systemhook already hooks ObjC via method_setImplementation
        // In user mode, we hook via Logos %hook (method_exchangeImplementations)
        if (!kernelMode) {
            %init(_ungrouped);

            // IDFA hooks (chỉ nếu class tồn tại)
            Class idfaClass = objc_getClass("ASIdentifierManager");
            if (idfaClass) %init(IDFA);
        }
        // In kernel mode: systemhook handles UIDevice, NSProcessInfo, NWPath, NWInterface,
        // SCNetworkReachability, CNCopyCurrentNetworkInfo via method_setImplementation
        // iOSSpoof only needs to handle ObjC hooks that systemhook doesn't cover:
        // UIScreen, NSLocale, NSTimeZone, NSCalendar, NSDate, NSURL, NSFileManager,
        // NSMutableURLRequest, NSURLSessionConfiguration, UIApplication, UIWindow, NSBundle

        // C function hooks — split by mode
        // In kernel mode: systemhook handles ALL C function hooks via litehook
        // We only keep ObjC hooks (UIDevice, UIScreen, NSProcessInfo, etc.)
        // because ObjC method swizzling cannot be detected by banking apps
        // (they look for MSHookFunction instruction patterns, not ObjC method exchange)
        if (!kernelMode) {
            // User mode: hook everything ourselves
            MSHookFunction((void *)&sysctlbyname, (void *)sc_sysctlbyname, (void **)&orig_sysctlbyname);
            MSHookFunction((void *)&sysctl, (void *)sc_sysctl, (void **)&orig_sysctl);

            void *iokit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW);
            if (iokit) {
                MSHookFunction((void *)&IORegistryEntryCreateCFProperty,
                               (void *)sc_IORegistryEntryCreateCFProperty,
                               (void **)&orig_IORegistryEntryCreateCFProperty);
            }

            MSHookFunction((void *)&uname, (void *)sc_uname, (void **)&orig_uname);
            MSHookFunction((void *)&statfs, (void *)sc_statfs, (void **)&orig_statfs);
            MSHookFunction((void *)&statvfs, (void *)sc_statvfs, (void **)&orig_statvfs);
            MSHookFunction((void *)&time, (void *)sc_time, (void **)&orig_time);
            MSHookFunction((void *)&gettimeofday, (void *)sc_gettimeofday, (void **)&orig_gettimeofday);
            MSHookFunction((void *)&readlink, (void *)sc_readlink, (void **)&orig_readlink);
            MSHookFunction((void *)&realpath, (void *)sc_realpath, (void **)&orig_realpath);
            SCInstallSystemVersionHooks();
            SCInstallMobileGestaltHooks();

            // User-space hide-jailbreak is kept minimal to avoid banking app crashes.
            // Path/process anti-detect belongs in roothide systemhook kernel mode.
        }
        // In kernel mode, all C hooks are handled by roothide systemhook/litehook.
    }
}
