#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import "../src/SCDevicePresets.h"

#define PREFS_PATH @"/var/mobile/Library/Preferences/com.iosspoof.tweak.plist"
#define PREFS_PATH_RL @"/var/jb/var/mobile/Library/Preferences/com.iosspoof.tweak.plist"
#define NOTIFY @"com.iosspoof.tweak.prefs-changed"

@interface SCRootListController : PSListController
@end

@implementation SCRootListController

- (NSString *)prefsPath {
    return access("/var/jb", F_OK) == 0 ? PREFS_PATH_RL : PREFS_PATH;
}

- (NSMutableDictionary *)loadPrefs {
    return [NSMutableDictionary dictionaryWithContentsOfFile:[self prefsPath]] ?: [NSMutableDictionary dictionary];
}

- (void)savePrefs:(NSDictionary *)d {
    NSMutableDictionary *m = [self loadPrefs];
    [m addEntriesFromDictionary:d];
    [m writeToFile:[self prefsPath] atomically:YES];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.iosspoof.tweak.prefs-changed"), NULL, NULL, TRUE);
}

- (void)specifiersLoaded {
    [super specifiersLoaded];
}

// ---- Actions ----

- (void)setEnabled:(id)value forSpecifier:(PSSpecifier *)spec {
    [self savePrefs:@{ @"enabled": value }];
    [(PSSpecifier *)spec setProperty:value forKey:@"enabled"];
    [self reloadSpecifier:spec];
}

- (id)readEnabled:(PSSpecifier *)spec {
    return [self loadPrefs][@"enabled"] ?: @NO;
}

- (void)setProductType:(id)value forSpecifier:(PSSpecifier *)spec {
    [self savePrefs:@{ @"productType": value ?: [NSNull null] }];
    [self reloadSpecifier:spec];
}

- (id)readProductType:(PSSpecifier *)spec {
    return [self loadPrefs][@"productType"] ?: @"random";
}

- (id)readValuesForSpecifier:(PSSpecifier *)spec {
    return @[@"random"];
}
- (id)readTitlesForSpecifier:(PSSpecifier *)spec {
    NSMutableArray *t = [@[@"Random"] mutableCopy];
    for (SCDevicePreset *p in [SCDevicePresets allPresets]) {
        [t addObject:[NSString stringWithFormat:@"%@ (%@)", p.marketingName, p.productType]];
    }
    return t;
}
- (id)readValues:(PSSpecifier *)spec {
    NSMutableArray *v = [@[@"random"] mutableCopy];
    for (SCDevicePreset *p in [SCDevicePresets allPresets]) {
        [v addObject:p.productType];
    }
    return v;
}

// Carrier
- (void)setCarrierName:(id)v forSpecifier:(PSSpecifier *)s { [self savePrefs:@{@"carrierName":v}]; }
- (id)readCarrierName:(PSSpecifier *)s { return [self loadPrefs][@"carrierName"] ?: @"Viettel"; }
- (void)setCarrierMCC:(id)v forSpecifier:(PSSpecifier *)s { [self savePrefs:@{@"carrierMCC":v}]; }
- (id)readCarrierMCC:(PSSpecifier *)s { return [self loadPrefs][@"carrierMCC"] ?: @"452"; }
- (void)setCarrierMNC:(id)v forSpecifier:(PSSpecifier *)s { [self savePrefs:@{@"carrierMNC":v}]; }
- (id)readCarrierMNC:(PSSpecifier *)s { return [self loadPrefs][@"carrierMNC"] ?: @"04"; }
- (void)setCarrierISO:(id)v forSpecifier:(PSSpecifier *)s { [self savePrefs:@{@"carrierISO":v}]; }
- (id)readCarrierISO:(PSSpecifier *)s { return [self loadPrefs][@"carrierISO"] ?: @"vn"; }

- (void)setRadioTech:(id)v forSpecifier:(PSSpecifier *)s { [self savePrefs:@{@"radioTech":v}]; }
- (id)readRadioTech:(PSSpecifier *)s { return [self loadPrefs][@"radioTech"] ?: @"CTRadioAccessTechnologyNRNSA"; }

// Geo
- (void)setGeoEnabled:(id)v forSpecifier:(PSSpecifier *)s { [self savePrefs:@{@"geoEnabled":v}]; [self reloadSpecifier:s]; }
- (id)readGeoEnabled:(PSSpecifier *)s { return [self loadPrefs][@"geoEnabled"] ?: @NO; }
- (void)setLatitude:(id)v forSpecifier:(PSSpecifier *)s { [self savePrefs:@{@"latitude":v}]; }
- (id)readLatitude:(PSSpecifier *)s { return [self loadPrefs][@"latitude"] ?: @(21.0285); }
- (void)setLongitude:(id)v forSpecifier:(PSSpecifier *)s { [self savePrefs:@{@"longitude":v}]; }
- (id)readLongitude:(PSSpecifier *)s { return [self loadPrefs][@"longitude"] ?: @(105.8542); }
- (void)setAltitude:(id)v forSpecifier:(PSSpecifier *)s { [self savePrefs:@{@"altitude":v}]; }
- (id)readAltitude:(PSSpecifier *)s { return [self loadPrefs][@"altitude"] ?: @(20.0); }
- (void)setAccuracy:(id)v forSpecifier:(PSSpecifier *)s { [self savePrefs:@{@"horizontalAccuracy":v}]; }
- (id)readAccuracy:(PSSpecifier *)s { return [self loadPrefs][@"horizontalAccuracy"] ?: @(5.0); }
- (void)setHeading:(id)v forSpecifier:(PSSpecifier *)s { [self savePrefs:@{@"heading":v}]; }
- (id)readHeading:(PSSpecifier *)s { return [self loadPrefs][@"heading"] ?: @(0.0); }

// Proxy
- (void)setProxyEnabled:(id)v forSpecifier:(PSSpecifier *)s { [self savePrefs:@{@"proxyEnabled":v}]; [self reloadSpecifier:s]; }
- (id)readProxyEnabled:(PSSpecifier *)s { return [self loadPrefs][@"proxyEnabled"] ?: @NO; }
- (void)setProxyType:(id)v forSpecifier:(PSSpecifier *)s { [self savePrefs:@{@"proxyType":v}]; }
- (id)readProxyType:(PSSpecifier *)s { return [self loadPrefs][@"proxyType"] ?: @"socks5"; }
- (void)setProxyHost:(id)v forSpecifier:(PSSpecifier *)s { [self savePrefs:@{@"proxyHost":v}]; }
- (id)readProxyHost:(PSSpecifier *)s { return [self loadPrefs][@"proxyHost"] ?: @""; }
- (void)setProxyPort:(id)v forSpecifier:(PSSpecifier *)s { [self savePrefs:@{@"proxyPort":v}]; }
- (id)readProxyPort:(PSSpecifier *)s { return [self loadPrefs][@"proxyPort"] ?: @(1080); }
- (void)setProxyUser:(id)v forSpecifier:(PSSpecifier *)s { [self savePrefs:@{@"proxyUser":v}]; }
- (id)readProxyUser:(PSSpecifier *)s { return [self loadPrefs][@"proxyUser"] ?: @""; }
- (void)setProxyPass:(id)v forSpecifier:(PSSpecifier *)s { [self savePrefs:@{@"proxyPass":v}]; }
- (id)readProxyPass:(PSSpecifier *)s { return [self loadPrefs][@"proxyPass"] ?: @""; }
- (void)setProxyUDP:(id)v forSpecifier:(PSSpecifier *)s { [self savePrefs:@{@"proxyUDP":v}]; }
- (id)readProxyUDP:(PSSpecifier *)s { return [self loadPrefs][@"proxyUDP"] ?: @NO; }

- (void)setHideProxy:(id)v forSpecifier:(PSSpecifier *)s { [self savePrefs:@{@"hideProxy":v}]; }
- (id)readHideProxy:(PSSpecifier *)s { return [self loadPrefs][@"hideProxy"] ?: @YES; }
- (void)setHideVPN:(id)v forSpecifier:(PSSpecifier *)s { [self savePrefs:@{@"hideVPN":v}]; }
- (id)readHideVPN:(PSSpecifier *)s { return [self loadPrefs][@"hideVPN"] ?: @YES; }
- (void)setHideJailbreak:(id)v forSpecifier:(PSSpecifier *)s { [self savePrefs:@{@"hideJailbreak":v}]; }
- (id)readHideJailbreak:(PSSpecifier *)s { return [self loadPrefs][@"hideJailbreak"] ?: @YES; }

- (void)setSpoofIDFA:(id)v forSpecifier:(PSSpecifier *)s { [self savePrefs:@{@"spoofIDFA":v}]; }
- (id)readSpoofIDFA:(PSSpecifier *)s { return [self loadPrefs][@"spoofIDFA"] ?: @YES; }
- (void)setSpoofIDFV:(id)v forSpecifier:(PSSpecifier *)s { [self savePrefs:@{@"spoofIDFV":v}]; }
- (id)readSpoofIDFV:(PSSpecifier *)s { return [self loadPrefs][@"spoofIDFV"] ?: @YES; }
- (void)setSpoofBattery:(id)v forSpecifier:(PSSpecifier *)s { [self savePrefs:@{@"spoofBattery":v}]; }
- (id)readSpoofBattery:(PSSpecifier *)s { return [self loadPrefs][@"spoofBattery"] ?: @YES; }

// Apply / respring
- (void)applyAndRespring {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.iosspoof.tweak.prefs-changed"), NULL, NULL, TRUE);
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"iOSSpoof"
        message:@"Đã áp dụng. Respring để生效?" preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Respring" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        system("killall -9 SpringBoard");
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

@end
