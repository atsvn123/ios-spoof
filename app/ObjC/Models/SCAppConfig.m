#import "SCAppConfig.h"
#import "SCDevicePresetStore.h"
#import <CoreFoundation/CoreFoundation.h>

NSString * const SCPreferencesChangedNotification = @"com.iosspoof.tweak.prefs.changed";

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
    self.enabled = [d[@"enabled"] boolValue];
    self.productType = [d[@"productType"] isKindOfClass:NSString.class] ? d[@"productType"] : @"iPhone14,5";
    self.randomizeOnLaunch = [d[@"randomizeOnLaunch"] boolValue];
    self.targetBundles = [d[@"targetBundles"] isKindOfClass:NSArray.class] ? d[@"targetBundles"] : @[];
    self.carrierName = d[@"carrierName"] ?: @"Viettel";
    self.carrierMCC = d[@"carrierMCC"] ?: @"452";
    self.carrierMNC = d[@"carrierMNC"] ?: @"04";
    self.carrierISO = d[@"carrierISO"] ?: @"vn";
    self.radioTech = d[@"radioTech"] ?: @"CTRadioAccessTechnologyLTE";
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
    self.hideProxy = d[@"hideProxy"] ? [d[@"hideProxy"] boolValue] : YES;
    self.hideVPN = d[@"hideVPN"] ? [d[@"hideVPN"] boolValue] : YES;
    self.hideJailbreak = d[@"hideJailbreak"] ? [d[@"hideJailbreak"] boolValue] : YES;
    self.spoofIDFA = d[@"spoofIDFA"] ? [d[@"spoofIDFA"] boolValue] : YES;
    self.spoofIDFV = d[@"spoofIDFV"] ? [d[@"spoofIDFV"] boolValue] : YES;
    self.spoofBattery = d[@"spoofBattery"] ? [d[@"spoofBattery"] boolValue] : YES;
    self.networkMode = d[@"networkMode"] ? [d[@"networkMode"] integerValue] : 0;
    self.wifiSSID = d[@"wifiSSID"] ?: @"MyWiFi";
    self.wifiBSSID = d[@"wifiBSSID"] ?: @"02:00:00:00:00:00";
    self.phoneNumber = d[@"phoneNumber"] ?: @"";
    self.geoFromIP = d[@"geoFromIP"] ? [d[@"geoFromIP"] boolValue] : NO;
    self.geoIPCity = d[@"geoIPCity"] ?: @"";
    self.geoIPCountry = d[@"geoIPCountry"] ?: @"";
    self.geoIPIsp = d[@"geoIPIsp"] ?: @"";
    self.systemVersion = d[@"systemVersion"] ?: @"17.5";
    self.buildID = d[@"buildID"] ?: @"21F90";
    self.uniqueID = d[@"uniqueID"] ?: @"";
    self.totalStorage = d[@"totalStorage"] ? [d[@"totalStorage"] unsignedIntegerValue] : 0;
    self.freeStorage = d[@"freeStorage"] ? [d[@"freeStorage"] unsignedIntegerValue] : 0;
    self.lowPowerMode = d[@"lowPowerMode"] ? [d[@"lowPowerMode"] boolValue] : NO;
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
    d[@"hideProxy"] = @(self.hideProxy);
    d[@"hideVPN"] = @(self.hideVPN);
    d[@"hideJailbreak"] = @(self.hideJailbreak);
    d[@"spoofIDFA"] = @(self.spoofIDFA);
    d[@"spoofIDFV"] = @(self.spoofIDFV);
    d[@"spoofBattery"] = @(self.spoofBattery);
    d[@"networkMode"] = @(self.networkMode);
    d[@"wifiSSID"] = self.wifiSSID ?: @"MyWiFi";
    d[@"wifiBSSID"] = self.wifiBSSID ?: @"02:00:00:00:00:00";
    d[@"phoneNumber"] = self.phoneNumber ?: @"";
    d[@"geoFromIP"] = @(self.geoFromIP);
    d[@"geoIPCity"] = self.geoIPCity ?: @"";
    d[@"geoIPCountry"] = self.geoIPCountry ?: @"";
    d[@"geoIPIsp"] = self.geoIPIsp ?: @"";
    d[@"systemVersion"] = self.systemVersion ?: @"17.5";
    d[@"buildID"] = self.buildID ?: @"21F90";
    d[@"uniqueID"] = self.uniqueID ?: @"";
    d[@"totalStorage"] = @(self.totalStorage);
    d[@"freeStorage"] = @(self.freeStorage);
    d[@"lowPowerMode"] = @(self.lowPowerMode);
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
    // Auto storage from preset
    NSArray *storageOpts = [SCDevicePresetStore storageOptionsForProductType:preset[@"productType"]];
    self.totalStorage = [storageOpts[arc4random_uniform((uint32_t)storageOpts.count)] unsignedIntegerValue];
    self.freeStorage = self.totalStorage / (2 + arc4random_uniform(3)); // 33-50% free
    // Auto iOS version + build ID
    NSDictionary *iosVersions = [SCDevicePresetStore iosVersionOptions];
    NSArray *iosKeys = iosVersions.allKeys;
    NSString *iosKey = iosKeys[arc4random_uniform((uint32_t)iosKeys.count)];
    NSDictionary *iosInfo = iosVersions[iosKey];
    self.systemVersion = iosInfo[@"version"];
    self.buildID = iosInfo[@"build"];
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
            [self save];
        });
    }];
    [task resume];
}

@end
