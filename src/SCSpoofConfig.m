#import "SCSpoofConfig.h"

NSNotificationName const SCSpoofConfigDidChangeNotification = @"SCSpoofConfigDidChange";

#define SC_READ_BOOL(k)        [d objectForKey:k] ? [[d objectForKey:k] boolValue] : NO
#define SC_READ_BOOL_DEF(k, v) [d objectForKey:k] ? [[d objectForKey:k] boolValue] : (v)
#define SC_READ_STR(k)         [d objectForKey:k] ? ([[d objectForKey:k] isKindOfClass:[NSString class]] ? [d objectForKey:k] : [[d objectForKey:k] stringValue]) : nil
#define SC_READ_DBL(k)         [d objectForKey:k] ? [[d objectForKey:k] doubleValue] : 0.0

@interface SCSpoofConfig () { NSDictionary *_raw; SCDevicePreset *_resolved; NSString *_bundleID; NSString *_udid, *_serial, *_ecid, *_imei, *_mac, *_idfa; NSArray<NSDictionary *> *_simSlots; NSInteger _activeSIMIndex; NSInteger _networkMode; NSString *_wifiSSID; NSString *_wifiBSSID; NSString *_cellularServiceID; NSString *_cellularIPv4; NSString *_cellularRouter; NSString *_systemVersion; NSUInteger _totalStorage; NSUInteger _freeStorage; BOOL _lowPowerMode; NSString *_buildID; NSString *_uniqueID; NSString *_pasteboardUUID; NSString *_deviceName; NSString *_bluetoothMAC; NSString *_bluetoothDeviceName; BOOL _bluetoothConnected; NSInteger _signalStrength; NSString *_localeIdentifier; NSString *_timezoneIdentifier; NSTimeInterval _timestampOffset; BOOL _kernelMode; BOOL _spoofWebKit; }
@end

@implementation SCSpoofConfig

+ (instancetype)shared {
    static SCSpoofConfig *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [self new]; });
    return s;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _bundleID = [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown";
        [self reload];
    }
    return self;
}

- (NSString *)prefsPath {
    // Try multiple paths for rootless/rootful jailbreaks
    // Rootless: /var/jb/var/mobile/Library/Preferences/
    // Rootful: /var/mobile/Library/Preferences/
    // Some rootless may use different prefix
    static NSString *cachedPath = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSArray *candidates = @[
            @"/var/jb/var/mobile/Library/Preferences/com.iosspoof.tweak.plist",
            @"/var/mobile/Library/Preferences/com.iosspoof.tweak.plist",
            @"/var/jb/var/root/Library/Preferences/com.iosspoof.tweak.plist",
            @"/var/root/Library/Preferences/com.iosspoof.tweak.plist",
        ];
        NSFileManager *fm = [NSFileManager defaultManager];
        for (NSString *p in candidates) {
            if ([fm fileExistsAtPath:p]) {
                cachedPath = p;
                return;
            }
        }
        // Default to rootless path (will be created by config app)
        cachedPath = @"/var/jb/var/mobile/Library/Preferences/com.iosspoof.tweak.plist";
    });
    return cachedPath;
}

- (void)reload {
    NSString *path = [self prefsPath];
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:path] ?: @{};
    _raw = d;

    _enabled = SC_READ_BOOL(@"enabled");
    _productType = SC_READ_STR(@"productType");
    _randomizeOnLaunch = SC_READ_BOOL(@"randomizeOnLaunch");
    _bundleOverrides = d[@"bundleOverrides"] ?: @{};
    _carrierName = SC_READ_STR(@"carrierName");
    _carrierMCC = SC_READ_STR(@"carrierMCC");
    _carrierMNC = SC_READ_STR(@"carrierMNC");
    _carrierISO = SC_READ_STR(@"carrierISO");
    _radioTech = SC_READ_STR(@"radioTech");
    _simSlots = [d[@"simSlots"] isKindOfClass:NSArray.class] ? d[@"simSlots"] : @[];
    _activeSIMIndex = d[@"activeSIMIndex"] ? [d[@"activeSIMIndex"] integerValue] : 0;
    _geoEnabled = SC_READ_BOOL(@"geoEnabled");
    _latitude = SC_READ_DBL(@"latitude");
    _longitude = SC_READ_DBL(@"longitude");
    _altitude = SC_READ_DBL(@"altitude");
    _horizontalAccuracy = SC_READ_DBL(@"horizontalAccuracy");
    _heading = SC_READ_DBL(@"heading");
    _proxyEnabled = SC_READ_BOOL(@"proxyEnabled");
    _proxyType = SC_READ_STR(@"proxyType") ?: @"socks5";
    _proxyHost = SC_READ_STR(@"proxyHost");
    _proxyPort = (uint16_t)[d[@"proxyPort"] unsignedIntValue];
    _proxyUser = SC_READ_STR(@"proxyUser");
    _proxyPass = SC_READ_STR(@"proxyPass");
    _proxyUDP = SC_READ_BOOL(@"proxyUDP");
    _hideProxy = SC_READ_BOOL_DEF(@"hideProxy", YES);
    _hideVPN = SC_READ_BOOL_DEF(@"hideVPN", YES);
    _hideJailbreak = SC_READ_BOOL_DEF(@"hideJailbreak", YES);
    _spoofIDFA = SC_READ_BOOL_DEF(@"spoofIDFA", YES);
    _spoofIDFV = SC_READ_BOOL_DEF(@"spoofIDFV", YES);
    _spoofBattery = SC_READ_BOOL_DEF(@"spoofBattery", YES);
    _spoofWebKit = SC_READ_BOOL_DEF(@"spoofWebKit", NO);

    _networkMode = d[@"networkMode"] ? [d[@"networkMode"] integerValue] : 0;
    _wifiSSID = SC_READ_STR(@"wifiSSID") ?: @"MyWiFi";
    _wifiBSSID = SC_READ_STR(@"wifiBSSID") ?: @"02:00:00:00:00:00";
    _cellularServiceID = SC_READ_STR(@"cellularServiceID") ?: @"00000000-0000-0000-0000-000000000000";
    _cellularIPv4 = SC_READ_STR(@"cellularIPv4") ?: @"10.23.42.10";
    _cellularRouter = SC_READ_STR(@"cellularRouter") ?: @"10.23.42.1";
    _systemVersion = SC_READ_STR(@"systemVersion") ?: @"17.5";
    _totalStorage = d[@"totalStorage"] ? [d[@"totalStorage"] unsignedIntegerValue] : 0;
    _freeStorage = d[@"freeStorage"] ? [d[@"freeStorage"] unsignedIntegerValue] : 0;
    _lowPowerMode = SC_READ_BOOL(@"lowPowerMode");
    _buildID = SC_READ_STR(@"buildID");
    _uniqueID = SC_READ_STR(@"uniqueID");
    _pasteboardUUID = SC_READ_STR(@"pasteboardUUID");
    _deviceName = SC_READ_STR(@"deviceName");
    _bluetoothMAC = SC_READ_STR(@"bluetoothMAC") ?: _mac;
    _bluetoothDeviceName = SC_READ_STR(@"bluetoothDeviceName");
    _bluetoothConnected = SC_READ_BOOL_DEF(@"bluetoothConnected", YES);
    _signalStrength = d[@"signalStrength"] ? [d[@"signalStrength"] integerValue] : 4;
    _localeIdentifier = SC_READ_STR(@"localeIdentifier");
    _timezoneIdentifier = SC_READ_STR(@"timezoneIdentifier");
    _timestampOffset = [d[@"timestampOffset"] doubleValue];
    _kernelMode = [d[@"kernelMode"] boolValue];

    id tb = d[@"targetBundles"];
    if ([tb isKindOfClass:[NSArray class]]) {
        _targetBundles = tb;
    } else if ([tb isKindOfClass:[NSString class]]) {
        _targetBundles = [tb componentsSeparatedByString:@","];
    } else {
        _targetBundles = @[];
    }

    [self resolvePreset];
    [self ensureSpoofedIds];

    [[NSNotificationCenter defaultCenter] postNotificationName:SCSpoofConfigDidChangeNotification object:nil];
}

- (void)resolvePreset {
    SCDevicePreset *p;
    NSString *pt = _productType;
    NSDictionary *ov = _bundleOverrides[_bundleID];
    if ([ov objectForKey:@"productType"]) {
        pt = [ov objectForKey:@"productType"];
    }
    if ([pt isEqualToString:@"random"] || (!pt && _randomizeOnLaunch)) {
        p = [SCDevicePresets randomPreset];
    } else if (pt) {
        p = [SCDevicePresets presetForProductType:pt];
        if (!p) p = [SCDevicePresets randomPreset];
    } else {
        p = [SCDevicePresets randomPreset];
    }
    p = [p copy];
    // apply global carrier override (nil-safe)
    if (_carrierName.length) p.carrierName = _carrierName;
    if (_carrierMCC.length)  p.carrierMCC  = _carrierMCC;
    if (_carrierMNC.length)  p.carrierMNC  = _carrierMNC;
    if (_carrierISO.length)  p.carrierISO  = _carrierISO;
    if (_radioTech.length)   p.radioTech   = _radioTech;
    // apply per-bundle override (nil-safe)
    if (ov) {
        for (NSString *k in ov) {
            if ([k hasPrefix:@"carrier"] || [k isEqualToString:@"radioTech"]) {
                id v = ov[k];
                if (![v isKindOfClass:[NSString class]] || ![(NSString *)v length]) continue;
                if ([p respondsToSelector:NSSelectorFromString(k)]) {
                    @try { [p setValue:v forKey:k]; } @catch(__unused id e) {}
                }
            }
        }
    }
    _resolved = p;
}

- (void)ensureSpoofedIds {
    _udid = nil;
    _serial = nil;
    _ecid = nil;
    _imei = nil;
    _mac = nil;
    _idfa = nil;
    // UDID 40 hex, có thể persist theo bundle trong prefs để stable
    NSString *idsPath = [[self prefsPath] stringByDeletingLastPathComponent];
    idsPath = [idsPath stringByAppendingPathComponent:@"com.iosspoof.tweak.ids.plist"];
    [[NSFileManager defaultManager] createDirectoryAtPath:[idsPath stringByDeletingLastPathComponent]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    NSMutableDictionary *ids = [NSMutableDictionary dictionaryWithContentsOfFile:idsPath] ?: [NSMutableDictionary dictionary];
    NSString *key = _bundleID;
    NSDictionary *per = ids[key];
    if (per && !_randomizeOnLaunch) {
        _udid   = per[@"udid"];
        _serial = per[@"serial"];
        _ecid   = per[@"ecid"];
        _imei   = per[@"imei"];
        _mac    = per[@"mac"];
        _idfa   = per[@"idfa"];
    }
    if (!_udid)   _udid   = [SCDevicePresets generateUDID];
    if (!_serial) _serial = [SCDevicePresets generateSerialNumber];
    if (!_ecid)   _ecid   = [SCDevicePresets generateECID];
    if (!_imei)   _imei   = [SCDevicePresets generateIMEI];
    if (!_mac)    _mac    = [SCDevicePresets generateMAC];
    if (!_idfa)   _idfa   = [SCDevicePresets generateIDFA];
    // persist (sandbox-safe: có thể fail silently nếu app không có quyền ghi)
    ids[key] = @{ @"udid":_udid, @"serial":_serial, @"ecid":_ecid,
                  @"imei":_imei, @"mac":_mac, @"idfa":_idfa };
    @try { [ids writeToFile:idsPath atomically:YES]; } @catch(__unused id e) {}
}

- (NSString *)currentBundleID { return _bundleID; }
- (BOOL)shouldInjectForCurrentBundle {
    static NSSet *protectedBundles;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        protectedBundles = [NSSet setWithArray:@[
            @"com.iosspoof.app",
            @"org.coolstar.SileoStore",
            @"org.coolstar.Sileo",
            @"com.saurik.Cydia",
            @"xyz.willy.Zebra",
            @"me.apptapp.Installer",
            @"com.opa334.Dopamine",
            @"com.opa334.TrollStore",
            @"com.opa334.TrollStorePersistenceHelper",
            @"com.apple.springboard"
        ]];
    });
    if ([protectedBundles containsObject:_bundleID]) return NO;

    NSString *proc = [[NSProcessInfo processInfo] processName] ?: @"";
    BOOL isWebKitHelper = [_bundleID hasPrefix:@"com.apple.WebKit"] || [proc hasPrefix:@"com.apple.WebKit"] || [proc containsString:@"WebContent"] || [proc containsString:@"Networking"];
    if (isWebKitHelper) {
        if (!_enabled || !_spoofWebKit) return NO;
        if (_targetBundles.count == 0) return YES;
        for (NSString *target in _targetBundles) {
            if ([target isKindOfClass:[NSString class]] && ([target isEqualToString:@"com.apple.mobilesafari"] || [target isEqualToString:@"com.apple.SafariViewService"])) {
                return YES;
            }
        }
        return NO;
    }
    
    // If targetBundles is populated, only inject into listed apps
    if (_targetBundles.count > 0) {
        for (NSString *target in _targetBundles) {
            if ([target isKindOfClass:[NSString class]] && [_bundleID isEqualToString:target]) {
                return YES;
            }
        }
        return NO;
    }
    
    // If targetBundles is empty but enabled=YES, inject into ALL non-protected apps
    // This is the "global mode" — useful when user wants to spoof everything
    if (_enabled) {
        return YES;
    }
    
    return NO;
}
- (SCDevicePreset *)resolvedPreset { return _resolved; }
- (NSString *)spoofedUDID { return _udid; }
- (NSString *)spoofedSerial { return _serial; }
- (NSString *)spoofedECID { return _ecid; }
- (NSString *)spoofedIMEI { return _imei; }
- (NSString *)spoofedMAC { return _mac; }
- (NSString *)spoofedIDFA { return _idfa; }
- (NSArray<NSDictionary *> *)simSlots { return _simSlots; }
- (NSInteger)activeSIMIndex { return _activeSIMIndex; }
- (NSInteger)networkMode { return _networkMode; }
- (NSString *)wifiSSID { return _wifiSSID; }
- (NSString *)wifiBSSID { return _wifiBSSID; }
- (NSString *)cellularServiceID { return _cellularServiceID; }
- (NSString *)cellularIPv4 { return _cellularIPv4; }
- (NSString *)cellularRouter { return _cellularRouter; }
- (NSString *)systemVersion { return _systemVersion; }
- (NSUInteger)totalStorage { return _totalStorage; }
- (NSUInteger)freeStorage { return _freeStorage; }
- (BOOL)lowPowerMode { return _lowPowerMode; }
- (NSString *)buildID { return _buildID; }
- (NSString *)uniqueID { return _uniqueID; }
- (NSString *)deviceName { return _deviceName; }
- (NSString *)bluetoothMAC { return _bluetoothMAC; }
- (NSString *)bluetoothDeviceName { return _bluetoothDeviceName; }
- (BOOL)bluetoothConnected { return _bluetoothConnected; }
- (NSInteger)signalStrength { return _signalStrength; }
- (NSString *)localeIdentifier { return _localeIdentifier; }
- (NSString *)timezoneIdentifier { return _timezoneIdentifier; }
- (NSTimeInterval)timestampOffset { return _timestampOffset; }
- (BOOL)kernelMode { return _kernelMode; }
- (BOOL)spoofWebKit { return _spoofWebKit; }

@end
