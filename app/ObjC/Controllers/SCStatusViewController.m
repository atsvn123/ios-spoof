#import "SCStatusViewController.h"
#import "../Models/SCAppConfig.h"
#import "../Models/SCDevicePresetStore.h"

@implementation SCStatusViewController

- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self.config load]; [self.tableView reloadData]; }

- (NSString *)effectiveBuildID {
    if (self.config.buildID.length) return self.config.buildID;
    NSString *version = self.config.systemVersion.length ? self.config.systemVersion : @"17.5";
    NSDictionary *versions = [SCDevicePresetStore iosVersionOptions];
    for (NSString *key in versions) {
        NSDictionary *info = versions[key];
        if ([info[@"version"] isEqualToString:version]) return info[@"build"];
    }
    return @"21F90";
}

- (NSUInteger)effectiveTotalStorage {
    if (self.config.totalStorage > 0) return self.config.totalStorage;
    NSDictionary *p = [self.config resolvedPreset];
    return [p[@"capacityGB"] unsignedIntegerValue];
}

- (NSUInteger)effectiveFreeStorage {
    if (self.config.freeStorage > 0) return self.config.freeStorage;
    NSUInteger total = [self effectiveTotalStorage];
    return total > 0 ? total / 3 : 0;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return 9; }

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s {
    switch (s) {
        case 0: return 3;
        case 1: return 14; // Device info
        case 2: return 4;  // Carrier
        case 3: return 6;  // GPS
        case 4: return 6;  // Network mode
        case 5: return 9;  // System spoof
        case 6: return 4;  // Bluetooth & Signal
        case 7: return 3;  // Locale & Timezone
        case 8: return 2;  // Actions
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s {
    return @[@"Trạng thái", @"Thiết bị đang spoof", @"Carrier", @"GPS", @"Network Mode", @"System & IDs", @"Bluetooth & Signal", @"Locale & Timezone", @"Actions"][s];
}

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)i {
    NSDictionary *p = [self.config resolvedPreset];
    switch (i.section) {
        case 0: {
            if (i.row == 0) return [self switchCellWithTitle:@"Bật Spoof" on:self.config.enabled action:@selector(toggleEnabled:)];
            if (i.row == 1) {
                BOOL installed = [SCAppConfig systemhookInstalled];
                UITableViewCell *c = [self cellWithTitle:@"Systemhook" detail:installed ? @"Đã cài đặt" : @"Chưa cài đặt"];
                c.detailTextLabel.textColor = installed ? [UIColor systemGreenColor] : [UIColor systemRedColor];
                return c;
            }
            return [self cellWithTitle:@"Target Apps" detail:[NSString stringWithFormat:@"%lu app", (unsigned long)self.config.targetBundles.count]];
        }
        case 1: {
            NSArray *keys = @[@"marketingName", @"productType", @"hardwareModel", @"modelNumber", @"chipId", @"cpuArchitecture", @"capacityGB", @"screenWidth", @"screenHeight", @"screenScale", @"screenInches", @"ppi", @"boardId", @"deviceClass"];
            NSArray *labels = @[@"Model", @"Product", @"Hardware", @"Model No", @"Chip", @"CPU", @"Storage", @"Width", @"Height", @"Scale", @"Inches", @"PPI", @"Board ID", @"Class"];
            id v = p[keys[i.row]] ?: @"-";
            NSString *detail = [v description];
            if (i.row == 0 && self.config.deviceName.length) detail = [NSString stringWithFormat:@"%@ → %@", detail, self.config.deviceName];
            return [self cellWithTitle:labels[i.row] detail:detail];
        }
        case 2: {
            NSArray *vals = @[self.config.carrierName ?: @"", self.config.carrierMCC ?: @"", self.config.carrierMNC ?: @"", self.config.radioTech ?: @""];
            return [self cellWithTitle:@[@"Name", @"MCC", @"MNC", @"Radio"][i.row] detail:vals[i.row]];
        }
        case 3: {
            NSArray *vals = @[self.config.geoEnabled ? @"Bật" : @"Tắt",
                              [NSString stringWithFormat:@"%.6f", self.config.latitude],
                              [NSString stringWithFormat:@"%.6f", self.config.longitude],
                              [NSString stringWithFormat:@"%.1f m", self.config.altitude],
                              [NSString stringWithFormat:@"%.1f m", self.config.horizontalAccuracy],
                              self.config.geoFromIP ? @"Từ IP" : @"Thủ công"];
            return [self cellWithTitle:@[@"GPS", @"Lat", @"Lon", @"Altitude", @"Accuracy", @"Mode"][i.row] detail:vals[i.row]];
        }
        case 4: {
            NSString *mode = self.config.networkMode == 1 ? @"WiFi (ảo)" : (self.config.networkMode == 2 ? @"Cellular (fake)" : @"Mặc định");
            if (i.row == 0) return [self cellWithTitle:@"Network Mode" detail:mode];
            if (i.row == 1) return [self cellWithTitle:@"WiFi SSID" detail:self.config.wifiSSID];
            if (i.row == 2) return [self cellWithTitle:@"WiFi BSSID" detail:self.config.wifiBSSID];
            if (i.row == 3) return [self cellWithTitle:@"Cell Service" detail:self.config.cellularServiceID];
            if (i.row == 4) return [self cellWithTitle:@"Cell IPv4" detail:self.config.cellularIPv4];
            return [self cellWithTitle:@"Cell Router" detail:self.config.cellularRouter];
        }
        case 5: {
            switch (i.row) {
                case 0: return [self cellWithTitle:@"iOS Version" detail:self.config.systemVersion ?: @"17.5"];
                case 1: return [self cellWithTitle:@"Build ID" detail:[self effectiveBuildID]];
                case 2: return [self cellWithTitle:@"Total Storage" detail:[NSString stringWithFormat:@"%lu GB%@", (unsigned long)[self effectiveTotalStorage], self.config.totalStorage > 0 ? @"" : @" (Auto)"]];
                case 3: return [self cellWithTitle:@"Free Storage" detail:[NSString stringWithFormat:@"%lu GB%@", (unsigned long)[self effectiveFreeStorage], self.config.freeStorage > 0 ? @"" : @" (Auto)"]];
                case 4: return [self cellWithTitle:@"Low Power Mode" detail:self.config.lowPowerMode ? @"Bật" : @"Tắt"];
                case 5: return [self cellWithTitle:@"IDFA/IDFV" detail:self.config.spoofIDFA ? @"Spoofing" : @"Off"];
                case 6: return [self cellWithTitle:@"Unique ID" detail:self.config.uniqueID.length ? self.config.uniqueID : @"Auto"];
                case 7: return [self cellWithTitle:@"Spoof Battery" detail:self.config.spoofBattery ? @"Bật" : @"Tắt"];
                case 8: return [self cellWithTitle:@"Hide Jailbreak" detail:self.config.hideJailbreak ? @"Bật" : @"Tắt"];
            }
        }
        case 6: {
            switch (i.row) {
                case 0: return [self cellWithTitle:@"BT MAC" detail:self.config.bluetoothMAC.length ? self.config.bluetoothMAC : @"Auto"];
                case 1: return [self cellWithTitle:@"BT Device" detail:self.config.bluetoothDeviceName.length ? self.config.bluetoothDeviceName : @"None"];
                case 2: return [self cellWithTitle:@"BT Connected" detail:self.config.bluetoothConnected ? @"Bật" : @"Tắt"];
                case 3: return [self cellWithTitle:@"Signal" detail:[NSString stringWithFormat:@"%ld bars", (long)self.config.signalStrength]];
            }
        }
        case 7: {
            switch (i.row) {
                case 0: return [self cellWithTitle:@"Locale" detail:self.config.localeIdentifier.length ? self.config.localeIdentifier : @"System"];
                case 1: return [self cellWithTitle:@"Timezone" detail:self.config.timezoneIdentifier.length ? self.config.timezoneIdentifier : @"System"];
                case 2: return [self cellWithTitle:@"Timestamp" detail:self.config.timestampOffset == 0 ? @"Off" : [NSString stringWithFormat:@"%+ldh", (long)(self.config.timestampOffset / 3600)]];
            }
        }
        case 8: {
            UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
            if (i.row == 0) {
                cell.textLabel.text = @"Randomize All";
                cell.detailTextLabel.text = @"Đổi ngẫu nhiên model/carrier/GPS/IDs";
                cell.textLabel.textColor = [UIColor systemPurpleColor];
            } else {
                cell.textLabel.text = @"Không cần Respring";
                cell.detailTextLabel.text = @"Thay đổi có hiệu lực khi app mục tiêu mở lại.";
                cell.textLabel.textColor = [UIColor secondaryLabelColor];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            }
            return cell;
        }
    }
    return [self cellWithTitle:@"" detail:@""];
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)i {
    [t deselectRowAtIndexPath:i animated:YES];
    if (i.section == 8 && i.row == 0) { [self.config randomizeAll]; [t reloadData]; }
}

- (void)toggleEnabled:(UISwitch *)sw { self.config.enabled = sw.on; [self.config save]; }

@end
