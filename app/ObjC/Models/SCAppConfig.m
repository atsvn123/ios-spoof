#import "SCAppConfig.h"
#import "SCDevicePresetStore.h"
#import "SCLocaleStore.h"
#import <CoreFoundation/CoreFoundation.h>

NSString * const SCPreferencesChangedNotification = @"com.iosspoof.tweak.prefs.changed";

static NSString *SCRandomIPv4Octet(NSInteger base) {
    return [NSString stringWithFormat:@"10.%u.%u.%ld", arc4random_uniform(200) + 20, arc4random_uniform(250) + 1, (long)base];
}

static NSArray<NSDictionary *> *SCDefaultSIMSlots(NSString *name, NSString *mcc, NSString *mnc, NSString *iso, NSString *radio, NSString *phone) {
    return @[
        @{@"enabled":@YES, @"label":@"Sim 1", @"carrierName":name ?: @"Viettel", @"carrierMCC":mcc ?: @"452", @"carrierMNC":mnc ?: @"04", @"carrierISO":iso ?: @"vn", @"radioTech":radio ?: @"CTRadioAccessTechnologyLTE", @"phoneNumber":phone ?: @"", @"eSIM":@NO}
    ];
}

@implementation SCAppConfig

+ (instancetype)shared {
    static SCAppConfig *cfg;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cfg = [SCAppConfig new]; [cfg load]; });
    return cfg;
}

- (NSString *)prefsPath {
    if ([[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb/var/mobile/Library/Preferences"]) {
        return @"/var/jb/var/mobile/Library/Preferences/com.iosspoof.tweak.plist";
    }
    return @"/var/mobile/Library/Preferences/com.iosspoof.tweak.plist";
}

- (NSString *)idsPath {
    if ([[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb/var/mobile/Library/Preferences"]) {
        return @"/var/jb/var/mobile/Library/Preferences/com.iosspoof.tweak.ids.plist";
    }
    return @"/var/mobile/Library/Preferences/com.iosspoof.tweak.ids.plist";
}

- (void)load {
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:[self prefsPath]] ?: @{};
    BOOL needsIdentitySave = !d[@"cellularServiceID"] || !d[@"cellularIPv4"] || !d[@"cellularRouter"] || !d[@"pasteboardUUID"];
    self.enabled = [d[@"enabled"] boolValue];
    self.productType = [d[@"productType"] isKindOfClass:NSString.class] ? d[@"productType"] : @"iPhone14,5";
    self.randomizeOnLaunch = [d[@"randomizeOnLaunch"] boolValue];
    self.targetBundles = [d[@"targetBundles"] isKindOfClass:NSArray.class] ? d[@"targetBundles"] : @[];
    self.carrierName = d[@"carrierName"] ?: @"Viettel";
    self.carrierMCC = d[@"carrierMCC"] ?: @"452";
    self.carrierMNC = d[@"carrierMNC"] ?: @"04";
    self.carrierISO = d[@"carrierISO"] ?: @"vn";
    self.radioTech = d[@"radioTech"] ?: @"CTRadioAccessTechnologyLTE";
    self.simSlots = [d[@"simSlots"] isKindOfClass:NSArray.class] ? d[@"simSlots"] : SCDefaultSIMSlots(self.carrierName, self.carrierMCC, self.carrierMNC, self.carrierISO, self.radioTech, d[@"phoneNumber"] ?: @"");
    self.activeSIMIndex = d[@"activeSIMIndex"] ? [d[@"activeSIMIndex"] integerValue] : 0;
    self.geoEnabled = [d[@"geoEnabled"] boolValue];
    self.latitude = d[@"latitude"] ? [d[@"latitude"] doubleValue] : 21.0285;
    self.longitude = d[@"longitude"] ? [d[@"longitude"] doubleValue] : 105.8542;
    self.altitude = d[@"altitude"] ? [d[@"altitude"] doubleValue] : 20.0;
    self.horizontalAccuracy = d[@"horizontalAccuracy"] ? [d[@"horizontalAccuracy"] doubleValue] : 5.0;
    self.heading = d[@"heading"] ? [d[@"heading"] doubleValue] : 0.0;
    self.proxyEnabled = [d[@"proxyEnabled"] boolValue];
    self.proxyType = d[@"proxyType"] ?: @"socks5";
    self.proxyHost = d[@"proxyHost"] ?: @"";
    self.proxyPort = d[@"proxyPort"] ? [d[@"proxyPort"] integerValue] : 1080;
    self.proxyUser = d[@"proxyUser"] ?: @"";
    self.proxyPass = d[@"proxyPass"] ?: @"";
    self.proxyUDP = [d[@"proxyUDP"] boolValue];
    self.proxyStealthMode = [d[@"proxyStealthMode"] boolValue];
    self.hideProxy = d[@"hideProxy"] ? [d[@"hideProxy"] boolValue] : YES;
    self.hideVPN = d[@"hideVPN"] ? [d[@"hideVPN"] boolValue] : YES;
    self.hideJailbreak = d[@"hideJailbreak"] ? [d[@"hideJailbreak"] boolValue] : YES;
    self.spoofIDFA = d[@"spoofIDFA"] ? [d[@"spoofIDFA"] boolValue] : YES;
    self.spoofIDFV = d[@"spoofIDFV"] ? [d[@"spoofIDFV"] boolValue] : YES;
    self.spoofBattery = d[@"spoofBattery"] ? [d[@"spoofBattery"] boolValue] : YES;
    self.spoofWebKit = d[@"spoofWebKit"] ? [d[@"spoofWebKit"] boolValue] : NO;
    self.networkMode = d[@"networkMode"] ? [d[@"networkMode"] integerValue] : 0;
    self.wifiSSID = d[@"wifiSSID"] ?: @"MyWiFi";
    self.wifiBSSID = d[@"wifiBSSID"] ?: @"02:00:00:00:00:00";
    self.cellularServiceID = d[@"cellularServiceID"] ?: [[NSUUID UUID] UUIDString];
    self.cellularIPv4 = d[@"cellularIPv4"] ?: SCRandomIPv4Octet(10);
    NSArray *parts = [self.cellularIPv4 componentsSeparatedByString:@"."];
    self.cellularRouter = d[@"cellularRouter"] ?: (parts.count == 4 ? [NSString stringWithFormat:@"%@.%@.%@.1", parts[0], parts[1], parts[2]] : SCRandomIPv4Octet(1));
    self.phoneNumber = d[@"phoneNumber"] ?: @"";
    self.geoFromIP = d[@"geoFromIP"] ? [d[@"geoFromIP"] boolValue] : NO;
    self.geoIPCity = d[@"geoIPCity"] ?: @"";
    self.geoIPCountry = d[@"geoIPCountry"] ?: @"";
    self.geoIPIsp = d[@"geoIPIsp"] ?: @"";
    self.systemVersion = d[@"systemVersion"] ?: @"17.5";
    self.buildID = d[@"buildID"] ?: @"21F90";
    self.uniqueID = d[@"uniqueID"] ?: @"";
    self.pasteboardUUID = d[@"pasteboardUUID"] ?: [[NSUUID UUID] UUIDString];
    self.totalStorage = d[@"totalStorage"] ? [d[@"totalStorage"] unsignedIntegerValue] : 0;
    self.freeStorage = d[@"freeStorage"] ? [d[@"freeStorage"] unsignedIntegerValue] : 0;
    self.lowPowerMode = d[@"lowPowerMode"] ? [d[@"lowPowerMode"] boolValue] : NO;
    self.deviceName = d[@"deviceName"] ?: @"";
    self.bluetoothMAC = d[@"bluetoothMAC"] ?: @"";
    self.bluetoothDeviceName = d[@"bluetoothDeviceName"] ?: @"";
    self.bluetoothConnected = d[@"bluetoothConnected"] ? [d[@"bluetoothConnected"] boolValue] : YES;
    self.signalStrength = d[@"signalStrength"] ? [d[@"signalStrength"] integerValue] : 4;
    self.localeIdentifier = d[@"localeIdentifier"] ?: @"";
    self.timezoneIdentifier = d[@"timezoneIdentifier"] ?: @"";
    self.timestampOffset = d[@"timestampOffset"] ? [d[@"timestampOffset"] doubleValue] : 0;
    if (needsIdentitySave) [self save];
}

- (void)save {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"enabled"] = @(self.enabled);
    d[@"productType"] = self.productType ?: @"iPhone14,5";
    d[@"randomizeOnLaunch"] = @(self.randomizeOnLaunch);
    d[@"targetBundles"] = self.targetBundles ?: @[];
    d[@"carrierName"] = self.carrierName ?: @"";
    d[@"carrierMCC"] = self.carrierMCC ?: @"";
    d[@"carrierMNC"] = self.carrierMNC ?: @"";
    d[@"carrierISO"] = self.carrierISO ?: @"";
    d[@"radioTech"] = self.radioTech ?: @"";
    d[@"simSlots"] = self.simSlots ?: SCDefaultSIMSlots(self.carrierName, self.carrierMCC, self.carrierMNC, self.carrierISO, self.radioTech, self.phoneNumber);
    d[@"activeSIMIndex"] = @(MAX(0, MIN(self.activeSIMIndex, (NSInteger)(self.simSlots.count ? self.simSlots.count - 1 : 0))));
    d[@"geoEnabled"] = @(self.geoEnabled);
    d[@"latitude"] = @(self.latitude);
    d[@"longitude"] = @(self.longitude);
    d[@"altitude"] = @(self.altitude);
    d[@"horizontalAccuracy"] = @(self.horizontalAccuracy);
    d[@"heading"] = @(self.heading);
    d[@"proxyEnabled"] = @(self.proxyEnabled);
    d[@"proxyType"] = self.proxyType ?: @"socks5";
    d[@"proxyHost"] = self.proxyHost ?: @"";
    d[@"proxyPort"] = @(self.proxyPort);
    d[@"proxyUser"] = self.proxyUser ?: @"";
    d[@"proxyPass"] = self.proxyPass ?: @"";
    d[@"proxyUDP"] = @(self.proxyUDP);
    d[@"proxyStealthMode"] = @(self.proxyStealthMode);
    d[@"hideProxy"] = @(self.hideProxy);
    d[@"hideVPN"] = @(self.hideVPN);
    d[@"hideJailbreak"] = @(self.hideJailbreak);
    d[@"spoofIDFA"] = @(self.spoofIDFA);
    d[@"spoofIDFV"] = @(self.spoofIDFV);
    d[@"spoofBattery"] = @(self.spoofBattery);
    d[@"spoofWebKit"] = @(self.spoofWebKit);
    d[@"networkMode"] = @(self.networkMode);
    d[@"wifiSSID"] = self.wifiSSID ?: @"MyWiFi";
    d[@"wifiBSSID"] = self.wifiBSSID ?: @"02:00:00:00:00:00";
    d[@"cellularServiceID"] = self.cellularServiceID.length ? self.cellularServiceID : [[NSUUID UUID] UUIDString];
    d[@"cellularIPv4"] = self.cellularIPv4.length ? self.cellularIPv4 : SCRandomIPv4Octet(10);
    d[@"cellularRouter"] = self.cellularRouter.length ? self.cellularRouter : SCRandomIPv4Octet(1);
    d[@"phoneNumber"] = self.phoneNumber ?: @"";
    d[@"geoFromIP"] = @(self.geoFromIP);
    d[@"geoIPCity"] = self.geoIPCity ?: @"";
    d[@"geoIPCountry"] = self.geoIPCountry ?: @"";
    d[@"geoIPIsp"] = self.geoIPIsp ?: @"";
    d[@"systemVersion"] = self.systemVersion ?: @"17.5";
    d[@"buildID"] = self.buildID ?: @"21F90";
    d[@"uniqueID"] = self.uniqueID ?: @"";
    d[@"pasteboardUUID"] = self.pasteboardUUID.length ? self.pasteboardUUID : [[NSUUID UUID] UUIDString];
    d[@"totalStorage"] = @(self.totalStorage);
    d[@"freeStorage"] = @(self.freeStorage);
    d[@"lowPowerMode"] = @(self.lowPowerMode);
    d[@"deviceName"] = self.deviceName ?: @"";
    d[@"bluetoothMAC"] = self.bluetoothMAC ?: @"";
    d[@"bluetoothDeviceName"] = self.bluetoothDeviceName ?: @"";
    d[@"bluetoothConnected"] = @(self.bluetoothConnected);
    d[@"signalStrength"] = @(self.signalStrength);
    d[@"localeIdentifier"] = self.localeIdentifier ?: @"";
    d[@"timezoneIdentifier"] = self.timezoneIdentifier ?: @"";
    d[@"timestampOffset"] = @(self.timestampOffset);
    [d writeToFile:[self prefsPath] atomically:YES];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge CFStringRef)SCPreferencesChangedNotification, NULL, NULL, true);
}

- (NSDictionary *)resolvedPreset {
    NSDictionary *p = [SCDevicePresetStore presetForProductType:self.productType];
    return p ?: [SCDevicePresetStore allPresets].firstObject;
}

- (NSDictionary *)cachedIDsForBundle:(NSString *)bundleID {
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:[self idsPath]];
    return [d[bundleID] isKindOfClass:NSDictionary.class] ? d[bundleID] : nil;
}

- (void)clearIDCache { [[NSFileManager defaultManager] removeItemAtPath:[self idsPath] error:nil]; }

- (void)resetAll {
    self.enabled = NO;
    self.productType = @"iPhone14,5";
    self.randomizeOnLaunch = NO;
    self.targetBundles = @[];
    self.geoEnabled = NO;
    self.proxyEnabled = NO;
    self.hideProxy = self.hideVPN = self.hideJailbreak = YES;
    self.spoofIDFA = self.spoofIDFV = self.spoofBattery = YES;
    self.spoofWebKit = NO;
    [self save];
}

- (void)randomizeAll {
    NSDictionary *preset = [SCDevicePresetStore randomPreset];
    self.productType = preset[@"productType"];
    self.randomizeOnLaunch = YES;
    self.enabled = YES;
    self.geoEnabled = YES;
    self.carrierName = preset[@"carrierName"];
    self.carrierMCC = preset[@"carrierMCC"];
    self.carrierMNC = preset[@"carrierMNC"];
    self.carrierISO = preset[@"carrierISO"];
    self.radioTech = preset[@"radioTech"];
    self.simSlots = SCDefaultSIMSlots(self.carrierName, self.carrierMCC, self.carrierMNC, self.carrierISO, self.radioTech, self.phoneNumber);
    NSArray *cities = @[
        @[@21.0285, @105.8542], @[@10.8231, @106.6297], @[@16.0471, @108.2068],
        @[@40.7128, @-74.0060], @[@51.5074, @-0.1278], @[@35.6762, @139.6503]
    ];
    NSArray *city = cities[arc4random_uniform((uint32_t)cities.count)];
    self.latitude = [city[0] doubleValue];
    self.longitude = [city[1] doubleValue];
    self.altitude = 5 + arc4random_uniform(45);
    self.horizontalAccuracy = 3 + arc4random_uniform(12);
    self.heading = arc4random_uniform(360);
    self.hideProxy = self.hideVPN = self.hideJailbreak = YES;
    self.spoofIDFA = self.spoofIDFV = self.spoofBattery = YES;
    self.spoofWebKit = NO;
    // Auto storage from preset
    NSArray *storageOpts = [SCDevicePresetStore storageOptionsForProductType:preset[@"productType"]];
    self.totalStorage = [storageOpts[arc4random_uniform((uint32_t)storageOpts.count)] unsignedIntegerValue];
    self.freeStorage = self.totalStorage / (2 + arc4random_uniform(3)); // 33-50% free
    // Auto iOS version + build ID (preset-aware)
    NSDictionary *iosVersions = [SCDevicePresetStore iosVersionOptionsForProductType:preset[@"productType"]];
    NSArray *iosKeys = iosVersions.allKeys;
    NSString *iosKey = iosKeys[arc4random_uniform((uint32_t)iosKeys.count)];
    NSDictionary *iosInfo = iosVersions[iosKey];
    self.systemVersion = iosInfo[@"version"];
    self.buildID = iosInfo[@"build"];
    // Auto Bluetooth
    uint8_t b[6];
    for (int j = 0; j < 6; j++) b[j] = (uint8_t)arc4random_uniform(256);
    b[0] = (b[0] & 0xFE) | 0x02;
    self.bluetoothMAC = [NSString stringWithFormat:@"%02X:%02X:%02X:%02X:%02X:%02X", b[0], b[1], b[2], b[3], b[4], b[5]];
    NSArray *btNames = @[@"AirPods Pro", @"AirPods Pro 2", @"AirPods Max", @"AirPods (3rd gen)", @"Powerbeats Pro", @"Beats Studio Buds"];
    self.bluetoothDeviceName = btNames[arc4random_uniform((uint32_t)btNames.count)];
    self.bluetoothConnected = YES;
    self.signalStrength = 3 + arc4random_uniform(2);
    self.cellularServiceID = [[NSUUID UUID] UUIDString];
    self.cellularIPv4 = SCRandomIPv4Octet(10 + arc4random_uniform(200));
    NSArray *ipParts = [self.cellularIPv4 componentsSeparatedByString:@"."];
    self.cellularRouter = ipParts.count == 4 ? [NSString stringWithFormat:@"%@.%@.%@.1", ipParts[0], ipParts[1], ipParts[2]] : SCRandomIPv4Octet(1);
    self.pasteboardUUID = [[NSUUID UUID] UUIDString];
    // Auto locale from geo
    NSDictionary *localeInfo = [SCLocaleStore localeForGeo:self.latitude lon:self.longitude];
    if (localeInfo) {
        self.localeIdentifier = localeInfo[@"locale"];
        self.timezoneIdentifier = localeInfo[@"tz"];
    }
    [self clearIDCache];
    [self save];
}

- (void)fetchGeoFromIP {
    NSURLSession *session = [NSURLSession sharedSession];
    NSURL *url = [NSURL URLWithString:@"https://ipwho.is/"];
    NSURLSessionDataTask *task = [session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!data) return;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![json[@"success"] boolValue]) return;
        double lat = [json[@"latitude"] doubleValue];
        double lon = [json[@"longitude"] doubleValue];
        NSString *city = json[@"city"] ?: @"";
        NSString *country = json[@"country"] ?: @"";
        NSString *isp = json[@"connection"][@"isp"] ?: @"";
        NSString *callingCode = json[@"calling_code"] ?: @"";
        dispatch_async(dispatch_get_main_queue(), ^{
            self.latitude = lat;
            self.longitude = lon;
            self.geoIPCity = city;
            self.geoIPCountry = country;
            self.geoIPIsp = isp;
            if (callingCode.length > 0) {
                self.carrierISO = [json[@"country_code"] lowercaseString] ?: self.carrierISO;
            }
            // Sync locale from geo
            NSDictionary *localeInfo = [SCLocaleStore localeForGeo:lat lon:lon];
            if (localeInfo) {
                self.localeIdentifier = localeInfo[@"locale"];
                self.timezoneIdentifier = localeInfo[@"tz"];
            }
            [self save];
        });
    }];
    [task resume];
}

@end
