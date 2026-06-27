#import "SCStatusViewController.h"
#import "../Models/SCAppConfig.h"
#import "../Models/SCDevicePresetStore.h"

@implementation SCStatusViewController

- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self.config load]; [self.tableView reloadData]; }

- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return 7; }

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s {
    switch (s) {
        case 0: return 3;  // Status
        case 1: return 14; // Device info
        case 2: return 4;  // Carrier
        case 3: return 6;  // GPS
        case 4: return 3;  // Network mode
        case 5: return 9;  // System spoof
        case 6: return 2;  // Actions
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s {
    return @[@"Trạng thái", @"Thiết bị đang spoof", @"Carrier", @"GPS", @"Network Mode", @"System & IDs", @"Actions"][s];
}

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)i {
    NSDictionary *p = [self.config resolvedPreset];
    switch (i.section) {
        case 0: {
            if (i.row == 0) return [self switchCellWithTitle:@"Bật Spoof" on:self.config.enabled action:@selector(toggleEnabled:)];
            if (i.row == 1) return [self cellWithTitle:@"Target Apps" detail:[NSString stringWithFormat:@"%lu app", (unsigned long)self.config.targetBundles.count]];
            return [self cellWithTitle:@"Random IDs mỗi launch" detail:self.config.randomizeOnLaunch ? @"Bật" : @"Tắt"];
        }
        case 1: {
            NSArray *keys = @[@"marketingName", @"productType", @"hardwareModel", @"modelNumber", @"chipId", @"cpuArchitecture", @"capacityGB", @"screenWidth", @"screenHeight", @"screenScale", @"screenInches", @"ppi", @"boardId", @"deviceClass"];
            NSArray *labels = @[@"Model", @"Product", @"Hardware", @"Model No", @"Chip", @"CPU", @"Storage", @"Width", @"Height", @"Scale", @"Inches", @"PPI", @"Board ID", @"Class"];
            id v = p[keys[i.row]] ?: @"-";
            return [self cellWithTitle:labels[i.row] detail:[v description]];
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
            return [self cellWithTitle:@"WiFi BSSID" detail:self.config.wifiBSSID];
        }
        case 5: {
            switch (i.row) {
                case 0: return [self cellWithTitle:@"iOS Version" detail:self.config.systemVersion ?: @"17.5"];
                case 1: return [self cellWithTitle:@"Build ID" detail:self.config.buildID.length ? self.config.buildID : @"21F90"];
                case 2: return [self cellWithTitle:@"Total Storage" detail:self.config.totalStorage > 0 ? [NSString stringWithFormat:@"%lu GB", (unsigned long)self.config.totalStorage] : @"-"];
                case 3: return [self cellWithTitle:@"Free Storage" detail:self.config.freeStorage > 0 ? [NSString stringWithFormat:@"%lu GB", (unsigned long)self.config.freeStorage] : @"-"];
                case 4: return [self cellWithTitle:@"Low Power Mode" detail:self.config.lowPowerMode ? @"Bật" : @"Tắt"];
                case 5: return [self cellWithTitle:@"IDFA/IDFV" detail:self.config.spoofIDFA ? @"Spoofing" : @"Off"];
                case 6: return [self cellWithTitle:@"Unique ID" detail:self.config.uniqueID.length ? self.config.uniqueID : @"Auto"];
                case 7: return [self cellWithTitle:@"Spoof Battery" detail:self.config.spoofBattery ? @"Bật" : @"Tắt"];
                case 8: return [self cellWithTitle:@"Hide Jailbreak" detail:self.config.hideJailbreak ? @"Bật" : @"Tắt"];
            }
        }
        case 6: {
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
    if (i.section == 6 && i.row == 0) { [self.config randomizeAll]; [t reloadData]; }
}

- (void)toggleEnabled:(UISwitch *)sw { self.config.enabled = sw.on; [self.config save]; }

@end
