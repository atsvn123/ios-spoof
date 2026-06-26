#import "SCSpoofConfig.h"

NSNotificationName const SCSpoofConfigDidChangeNotification = @"SCSpoofConfigDidChange";

#define SC_READ_BOOL(k)        [d objectForKey:k] ? [[d objectForKey:k] boolValue] : NO
#define SC_READ_STR(k)         [d objectForKey:k] ? [[d objectForKey:k] stringValue] : nil
#define SC_READ_DBL(k)         [d objectForKey:k] ? [[d objectForKey:k] doubleValue] : 0.0

@interface SCSpoofConfig ()
{
    NSDictionary *_raw;
    SCDevicePreset *_resolved;
    NSString *_bundleID;
    NSString *_udid, *_serial, *_ecid, *_imei, *_mac, *_idfa;
}
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
    // Rootless: /var/jb/var/mobile/Library/Preferences/com.iosspoof.tweak.plist
    // Rootful:  /var/mobile/Library/Preferences/...
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *lib = paths.firstObject ?: @"/var/mobile/Library";
    return [lib stringByAppendingPathComponent:@"Preferences/com.iosspoof.tweak.plist"];
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
    _hideProxy = SC_READ_BOOL(@"hideProxy");
    _hideVPN = SC_READ_BOOL(@"hideVPN");
    _hideJailbreak = SC_READ_BOOL(@"hideJailbreak");
    _spoofIDFA = SC_READ_BOOL(@"spoofIDFA");
    _spoofIDFV = SC_READ_BOOL(@"spoofIDFV");
    _spoofBattery = SC_READ_BOOL(@"spoofBattery");

    [self resolvePreset];
    [self ensureSpoofedIds];

    [[NSNotificationCenter defaultCenter] postNotificationName:SCSpoofConfigDidChangeNotification object:nil];
}

- (void)resolvePreset {
    SCDevicePreset *p;
    NSString *pt = _productType;
    // per-bundle override productType
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
    // apply global carrier override
    if (_carrierName) p.carrierName = _carrierName;
    if (_carrierMCC)  p.carrierMCC  = _carrierMCC;
    if (_carrierMNC)  p.carrierMNC  = _carrierMNC;
    if (_carrierISO)  p.carrierISO  = _carrierISO;
    if (_radioTech)   p.radioTech   = _radioTech;
    // apply per-bundle override
    if (ov) {
        for (NSString *k in ov) {
            if ([k hasPrefix:@"carrier"] || [k isEqualToString:@"radioTech"]) {
                if ([p respondsToSelector:NSSelectorFromString(k)]) {
                    [p setValue:ov[k] forKey:k];
                }
            }
        }
    }
    _resolved = p;
}

- (void)ensureSpoofedIds {
    // UDID 40 hex, có thể persist theo bundle trong prefs để stable
    NSString *idsPath = [[self prefsPath] stringByDeletingLastPathComponent];
    idsPath = [idsPath stringByAppendingPathComponent:@"com.iosspoof.tweak.ids.plist"];
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
    // persist
    ids[key] = @{ @"udid":_udid, @"serial":_serial, @"ecid":_ecid,
                  @"imei":_imei, @"mac":_mac, @"idfa":_idfa };
    [ids writeToFile:idsPath atomically:YES];
}

- (NSString *)currentBundleID { return _bundleID; }
- (SCDevicePreset *)resolvedPreset { return _resolved; }
- (NSString *)spoofedUDID { return _udid; }
- (NSString *)spoofedSerial { return _serial; }
- (NSString *)spoofedECID { return _ecid; }
- (NSString *)spoofedIMEI { return _imei; }
- (NSString *)spoofedMAC { return _mac; }
- (NSString *)spoofedIDFA { return _idfa; }

@end
