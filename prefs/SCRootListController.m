#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import <unistd.h>
#import <sys/socket.h>
#import <sys/un.h>
#import <arpa/inet.h>
#import <string.h>
#import "../src/SCDevicePresets.h"

#define PREFS_PATH @"/var/mobile/Library/Preferences/com.iosspoof.tweak.plist"
#define PREFS_PATH_RL @"/var/jb/var/mobile/Library/Preferences/com.iosspoof.tweak.plist"
#define NOTIFY @"com.iosspoof.tweak.prefs-changed"

@interface SCRootListController : PSListController
@end

@implementation SCRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (NSString *)prefsPath {
    return access("/var/jb", F_OK) == 0 ? PREFS_PATH_RL : PREFS_PATH;
}

- (NSMutableDictionary *)loadPrefs {
    return [NSMutableDictionary dictionaryWithContentsOfFile:[self prefsPath]] ?: [NSMutableDictionary dictionary];
}

- (void)savePrefs:(NSDictionary *)d {
    NSMutableDictionary *m = [self loadPrefs];
    for (NSString *key in d) {
        id value = d[key];
        if (!value || value == (id)[NSNull null]) {
            [m removeObjectForKey:key];
        } else {
            m[key] = value;
        }
    }
    [[NSFileManager defaultManager] createDirectoryAtPath:[[self prefsPath] stringByDeletingLastPathComponent]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
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

- (void)setRandomizeOnLaunch:(id)value forSpecifier:(PSSpecifier *)spec {
    [self savePrefs:@{ @"randomizeOnLaunch": value ?: @NO }];
}

- (id)readRandomizeOnLaunch:(PSSpecifier *)spec {
    return [self loadPrefs][@"randomizeOnLaunch"] ?: @NO;
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
- (NSArray *)radioValues:(PSSpecifier *)s { return @[@"CTRadioAccessTechnologyLTE", @"CTRadioAccessTechnologyNRNSA", @"CTRadioAccessTechnologyNR", @"CTRadioAccessTechnologyHSDPA", @"CTRadioAccessTechnologyEdge"]; }
- (NSArray *)radioTitles:(PSSpecifier *)s { return @[@"4G LTE", @"5G NR (NSA)", @"5G NR", @"3G HSDPA", @"2G EDGE"]; }

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
- (NSArray *)proxyTypeValues:(PSSpecifier *)s { return @[@"socks5", @"http"]; }
- (NSArray *)proxyTypeTitles:(PSSpecifier *)s { return @[@"SOCKS5", @"HTTP CONNECT"]; }
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

- (NSString *)daemonSocketPath {
    return access("/var/jb/var/run", F_OK) == 0 ? @"/var/jb/var/run/scproxyd.sock" : @"/var/run/scproxyd.sock";
}

- (NSDictionary *)sendDaemonCommand:(NSDictionary *)cmd {
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return nil;
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strlcpy(addr.sun_path, [[self daemonSocketPath] UTF8String], sizeof(addr.sun_path));
    if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        close(fd);
        return nil;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:cmd options:0 error:nil];
    if (!data) { close(fd); return nil; }
    uint32_t len = htonl((uint32_t)data.length);
    send(fd, &len, 4, 0);
    send(fd, data.bytes, data.length, 0);
    uint32_t rlen = 0;
    if (recv(fd, &rlen, 4, 0) != 4) { close(fd); return nil; }
    rlen = ntohl(rlen);
    if (rlen == 0 || rlen > 65536) { close(fd); return nil; }
    NSMutableData *buf = [NSMutableData dataWithLength:rlen];
    ssize_t got = recv(fd, buf.mutableBytes, rlen, 0);
    close(fd);
    if (got != (ssize_t)rlen) return nil;
    return [NSJSONSerialization JSONObjectWithData:buf options:0 error:nil];
}

- (void)checkDaemonStatus {
    NSDictionary *status = [self sendDaemonCommand:@{ @"cmd": @"status" }];
    NSString *message = status ? [NSString stringWithFormat:@"Daemon running: %@\nType: %@\nHost: %@:%@",
                                  [status[@"running"] boolValue] ? @"YES" : @"NO",
                                  status[@"proxyType"] ?: @"-",
                                  status[@"host"] ?: @"-",
                                  status[@"port"] ?: @"-"]
                               : @"Không kết nối được scproxyd. Kiểm tra LaunchDaemon hoặc respring/reinstall.";
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"scproxyd"
                                                                message:message
                                                         preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

@end
