#import "SCSpoofViewController.h"
#import "../Models/SCAppConfig.h"
#import "../Models/SCDevicePresetStore.h"

@interface SCGPSSearchViewController : UITableViewController <UISearchBarDelegate>
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) NSArray *results;
@property (nonatomic) BOOL loading;
@property (nonatomic, copy) void (^selectionHandler)(double latitude, double longitude);
@end

@implementation SCGPSSearchViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Tìm địa điểm";
    self.results = @[];
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 56)];
    self.searchBar.placeholder = @"Nhập tên địa điểm...";
    self.searchBar.delegate = self;
    self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.tableView.tableHeaderView = self.searchBar;
}

- (void)viewDidAppear:(BOOL)animated { [super viewDidAppear:animated]; [self.searchBar becomeFirstResponder]; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return MAX((NSInteger)self.results.count, 1); }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    if (self.results.count == 0) {
        cell.textLabel.text = self.loading ? @"Đang tìm địa điểm..." : (self.searchBar.text.length >= 3 ? @"Không tìm thấy kết quả" : @"Nhập ít nhất 3 ký tự để tìm");
        cell.textLabel.textColor = [UIColor secondaryLabelColor];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }
    NSDictionary *r = self.results[indexPath.row];
    cell.textLabel.text = r[@"display_name"] ?: @"";
    cell.textLabel.numberOfLines = 2;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@, %@", r[@"lat"] ?: @"?", r[@"lon"] ?: @"?"];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= (NSInteger)self.results.count) return;
    NSDictionary *r = self.results[indexPath.row];
    if (self.selectionHandler) self.selectionHandler([r[@"lat"] doubleValue], [r[@"lon"] doubleValue]);
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)searchBar:(UISearchBar *)bar textDidChange:(NSString *)searchText {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(searchNow) object:nil];
    if (searchText.length < 3) {
        self.loading = NO;
        self.results = @[];
        [self.tableView reloadData];
        return;
    }
    self.loading = YES;
    self.results = @[];
    [self.tableView reloadData];
    [self performSelector:@selector(searchNow) withObject:nil afterDelay:0.6];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)bar { [self searchNow]; }

- (void)searchNow {
    NSString *query = [self.searchBar.text stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    if (!query.length) return;
    NSString *urlStr = [NSString stringWithFormat:@"https://nominatim.openstreetmap.org/search?format=json&q=%@&limit=10", query];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    [req setValue:@"iOSSpoof/1.0" forHTTPHeaderField:@"User-Agent"];
    [req setValue:@"vi,en;q=0.8" forHTTPHeaderField:@"Accept-Language"];
    [[NSURLSession.sharedSession dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSArray *results = @[];
        if (data) {
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([json isKindOfClass:NSArray.class]) results = json;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self.loading = NO;
            self.results = results;
            [self.tableView reloadData];
        });
    }] resume];
}

@end

@interface SCSpoofViewController ()
@property (nonatomic) BOOL geoIPLoading;
@property (nonatomic) NSInteger carrierPresetIndex;
@property (nonatomic, copy) NSString *proxyCheckResult;
@end

@implementation SCSpoofViewController

- (NSString *)iosVersionDetail {
    NSString *version = self.config.systemVersion.length ? self.config.systemVersion : @"17.5";
    NSString *build = self.config.buildID.length ? self.config.buildID : [SCDevicePresetStore iosVersionOptions][@"iOS 17.5"][@"build"];
    return build.length ? [NSString stringWithFormat:@"%@ (%@)", version, build] : version;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    tap.cancelsTouchesInView = NO;
    [self.tableView addGestureRecognizer:tap];
    self.carrierPresetIndex = -1;
}

- (void)dismissKeyboard { [self.view endEditing:YES]; }

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.config load];
    [self.tableView reloadData];
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return 6; }

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s {
    switch (s) {
        case 0: return self.config.networkMode == 2 ? 2 : 4;
        case 1: return self.config.proxyEnabled ? 7 : 2;
        case 2: return [self gpsRowCount];
        case 3: return 1 + 5;
        case 4: return 5;
        case 5: return 5; // iOS Version, Total Storage, Free Storage, Low Power, IDFA
        default: return 0;
    }
}

- (NSInteger)gpsRowCount {
    if (self.config.geoFromIP) return 5;
    return 2 + 5; // toggle + search bar + 5 manual fields
}

- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s {
    return @[@"Network Mode", @"Proxy", @"GPS Location", @"Carrier", @"Anti-Detect", @"System & Storage"][s];
}

- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)s {
    switch (s) {
        case 0: return self.config.networkMode == 2 ? @"Cellular: app thấy 4G/5G thay WiFi." : @"WiFi: app thấy đang dùng WiFi (có thể spoof SSID).";
        case 1: return @"Proxy trong suốt. Geo từ IP sẽ lấy vị trí theo IP proxy.";
        case 2: return self.config.geoFromIP ? @"Đang lấy vị trí từ IP. Nhập thủ công đã tắt." : @"Nhập tọa độ thủ công hoặc tìm kiếm địa điểm.";
        case 3: return @"Chọn preset hoặc nhập thủ công.";
        default: return @"";
    }
}

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)i {
    switch (i.section) {
        case 0: return [self networkModeCell:i];
        case 1: return [self proxyCell:i];
        case 2: return [self gpsCell:i];
        case 3: return i.row == 0 ? [self carrierPresetCell] : [self carrierCell:i];
        case 4: return [self antiDetectCell:i];
        case 5: return [self systemCell:i];
    }
    return [self cellWithTitle:@"" detail:@""];
}

#pragma mark - Network Mode

- (UITableViewCell *)networkModeCell:(NSIndexPath *)i {
    if (i.row == 0) {
        UITableViewCell *c = [self switchCellWithTitle:@"WiFi (ảo)" on:self.config.networkMode==1 action:@selector(toggleWifiMode:)];
        UISwitch *sw = (UISwitch *)c.accessoryView; sw.tag = 1;
        return c;
    }
    if (i.row == 1) {
        UITableViewCell *c = [self switchCellWithTitle:@"Cellular (fake 4G/5G)" on:self.config.networkMode==2 action:@selector(toggleCellularMode:)];
        UISwitch *sw = (UISwitch *)c.accessoryView; sw.tag = 2;
        return c;
    }
    // SSID/BSSID only when WiFi mode
    if (i.row == 2) {
        UITableViewCell *c = [self cellWithTitle:@"WiFi SSID" detail:nil];
        c.accessoryView = [self textFieldWithText:self.config.wifiSSID placeholder:@"MyWiFi" tag:500 keyboard:UIKeyboardTypeDefault];
        return c;
    }
    // BSSID row: tap to random
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    c.textLabel.text = @"WiFi BSSID";
    c.detailTextLabel.text = self.config.wifiBSSID ?: @"02:00:00:00:00:00";
    c.detailTextLabel.adjustsFontSizeToFitWidth = YES;
    c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    c.selectionStyle = UITableViewCellSelectionStyleDefault;
    return c;
}

- (void)toggleWifiMode:(UISwitch *)s {
    self.config.networkMode = s.on ? 1 : 0;
    [self.config save];
    [self.tableView reloadData];
}

- (void)toggleCellularMode:(UISwitch *)s {
    self.config.networkMode = s.on ? 2 : 0;
    [self.config save];
    [self.tableView reloadData];
}

#pragma mark - Proxy

- (UITableViewCell *)proxyCell:(NSIndexPath *)i {
    if (i.row == 0) return [self switchCellWithTitle:@"Bật Proxy" on:self.config.proxyEnabled action:@selector(toggleProxy:)];
    if (!self.config.proxyEnabled || i.row == 6) {
        UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
        c.textLabel.text = @"Check Proxy";
        c.textLabel.textColor = [UIColor systemBlueColor];
        c.detailTextLabel.text = self.proxyCheckResult ?: @"Tap to check";
        c.selectionStyle = UITableViewCellSelectionStyleDefault;
        return c;
    }
    NSArray *titles = @[@"Type", @"Host", @"Port", @"User", @"Password"];
    NSArray *vals = @[self.config.proxyType, self.config.proxyHost, @(self.config.proxyPort).stringValue, self.config.proxyUser, self.config.proxyPass];
    UITableViewCell *c = [self cellWithTitle:titles[i.row-1] detail:nil];
    c.accessoryView = [self textFieldWithText:vals[i.row-1] placeholder:@"" tag:600+i.row keyboard:i.row==3?UIKeyboardTypeNumberPad:UIKeyboardTypeDefault];
    return c;
}

- (void)toggleProxy:(UISwitch *)s { self.config.proxyEnabled = s.on; [self.config save]; [self.tableView reloadData]; }

#pragma mark - GPS

- (UITableViewCell *)gpsCell:(NSIndexPath *)i {
    if (i.row == 0) {
        if (self.geoIPLoading) {
            UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            UIActivityIndicatorView *av = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
            [av startAnimating];
            c.accessoryView = av;
            c.textLabel.text = @"Đang lấy vị trí từ IP...";
            c.selectionStyle = UITableViewCellSelectionStyleNone;
            return c;
        }
        return [self switchCellWithTitle:@"Lấy GPS từ IP" on:self.config.geoFromIP action:@selector(toggleGeoFromIP:)];
    }
    if (self.config.geoFromIP) {
        NSArray *titles = @[@"City", @"Country", @"ISP", @"Lat/Lon"];
        NSArray *vals = @[self.config.geoIPCity.length ? self.config.geoIPCity : @"Chưa có",
                          self.config.geoIPCountry.length ? self.config.geoIPCountry : @"Chưa có",
                          self.config.geoIPIsp.length ? self.config.geoIPIsp : @"Chưa có",
                          [NSString stringWithFormat:@"%.4f, %.4f", self.config.latitude, self.config.longitude]];
        UITableViewCell *c = [self cellWithTitle:titles[i.row-1] detail:vals[i.row-1]];
        c.selectionStyle = UITableViewCellSelectionStyleNone;
        if (!self.config.geoIPCity.length) c.textLabel.textColor = [UIColor secondaryLabelColor];
        return c;
    }
    if (i.row == 1) {
        UITableViewCell *c = [self cellWithTitle:@"Tìm địa điểm" detail:@"OpenStreetMap"];
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        c.selectionStyle = UITableViewCellSelectionStyleDefault;
        return c;
    }
    // Manual fields
    NSArray *titles = @[@"Latitude", @"Longitude", @"Altitude", @"Accuracy", @"Heading"];
    NSInteger fieldIdx = i.row - 2;
    if (fieldIdx < 0 || fieldIdx >= titles.count) return [self cellWithTitle:@"" detail:@""];
    NSArray *vals = @[@(self.config.latitude), @(self.config.longitude), @(self.config.altitude), @(self.config.horizontalAccuracy), @(self.config.heading)];
    UITableViewCell *c = [self cellWithTitle:titles[fieldIdx] detail:nil];
    c.accessoryView = [self textFieldWithText:[vals[fieldIdx] description] placeholder:@"" tag:700+fieldIdx+2 keyboard:UIKeyboardTypeDecimalPad];
    return c;
}

- (void)toggleGeoFromIP:(UISwitch *)s {
    self.config.geoFromIP = s.on;
    if (s.on) {
        self.config.geoEnabled = YES;
        self.geoIPLoading = YES;
        [self.tableView reloadData];
        [self.config fetchGeoFromIP];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.geoIPLoading = NO;
            [self.tableView reloadData];
        });
    }
    [self.config save];
    [self.tableView reloadData];
}

- (void)toggleGeo:(UISwitch *)s { self.config.geoEnabled = s.on; [self.config save]; }

#pragma mark - Carrier (preset at top, empty fields below)

- (UITableViewCell *)carrierPresetCell {
    NSString *detail = self.carrierPresetIndex >= 0 ? @[@"Viettel 4G",@"Mobifone 4G",@"Vinaphone 4G",@"Viettel 5G"][self.carrierPresetIndex] : @"Chọn preset";
    UITableViewCell *c = [self cellWithTitle:@"Preset" detail:detail];
    c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    c.selectionStyle = UITableViewCellSelectionStyleDefault;
    return c;
}

- (UITableViewCell *)carrierCell:(NSIndexPath *)i {
    NSArray *titles = @[@"Name", @"MCC", @"MNC", @"ISO", @"Radio"];
    NSArray *vals = @[self.config.carrierName ?: @"", self.config.carrierMCC ?: @"", self.config.carrierMNC ?: @"", self.config.carrierISO ?: @"", self.config.radioTech ?: @""];
    UITableViewCell *c = [self cellWithTitle:titles[i.row-1] detail:nil];
    c.accessoryView = [self textFieldWithText:vals[i.row-1] placeholder:@"" tag:800+i.row keyboard:(i.row==1||i.row==2)?UIKeyboardTypeNumberPad:UIKeyboardTypeDefault];
    return c;
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)i {
    [t deselectRowAtIndexPath:i animated:YES];
    [self dismissKeyboard];
    if (i.section == 1 && (!self.config.proxyEnabled || i.row == 6)) { [self checkProxy]; return; }
    if (i.section == 2 && !self.config.geoFromIP && i.row == 1) {
        SCGPSSearchViewController *vc = [SCGPSSearchViewController new];
        vc.selectionHandler = ^(double latitude, double longitude) {
            self.config.latitude = latitude;
            self.config.longitude = longitude;
            self.config.geoEnabled = YES;
            [self.config save];
            [self.tableView reloadData];
        };
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }
    if (i.section == 3 && i.row == 0) { [self showCarrierPresets]; return; }
    if (i.section == 0 && i.row == 3) { [self randomBSSID]; return; }
    if (i.section == 5) { [self showSystemPicker:i.row]; return; }
}

- (void)randomBSSID {
    // Generate locally administered, unicast MAC
    uint8_t b[6];
    for (int j = 0; j < 6; j++) b[j] = (uint8_t)arc4random_uniform(256);
    b[0] = (b[0] & 0xFE) | 0x02; // locally administered, unicast
    self.config.wifiBSSID = [NSString stringWithFormat:@"%02X:%02X:%02X:%02X:%02X:%02X", b[0], b[1], b[2], b[3], b[4], b[5]];
    [self.config save];
    [self.tableView reloadData];
}

- (void)showCarrierPresets {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Carrier Preset" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *names = @[
        @"Viettel 4G", @"Mobifone 4G", @"Vinaphone 4G", @"Viettel 5G",
        @"T-Mobile US", @"AT&T US", @"Verizon US", @"Sprint US",
        @"Vodafone UK", @"O2 UK", @"EE UK", @"Three UK",
        @"Orange FR", @"SFR FR", @"Bouygues FR",
        @"Docomo JP", @"SoftBank JP", @"au JP",
        @"SK Telecom KR", @"KT KR", @"LG U+ KR",
        @"Movistar ES", @"Vodafone ES", @"Orange ES",
        @"Telstra AU", @"Optus AU",
        @"Jio IN", @"Airtel IN", @"Vi IN",
        @"China Mobile", @"China Unicom", @"China Telecom"
    ];
    NSArray *presets = @[
        @[@"Viettel",@"452",@"04",@"vn",@"CTRadioAccessTechnologyLTE"],
        @[@"Mobifone",@"452",@"01",@"vn",@"CTRadioAccessTechnologyLTE"],
        @[@"Vinaphone",@"452",@"02",@"vn",@"CTRadioAccessTechnologyLTE"],
        @[@"Viettel",@"452",@"04",@"vn",@"CTRadioAccessTechnologyNRNSA"],
        @[@"T-Mobile",@"310",@"260",@"us",@"CTRadioAccessTechnologyLTE"],
        @[@"AT&T",@"310",@"410",@"us",@"CTRadioAccessTechnologyLTE"],
        @[@"Verizon",@"311",@"480",@"us",@"CTRadioAccessTechnologyLTE"],
        @[@"Sprint",@"310",@"120",@"us",@"CTRadioAccessTechnologyLTE"],
        @[@"Vodafone",@"234",@"15",@"gb",@"CTRadioAccessTechnologyLTE"],
        @[@"O2",@"234",@"10",@"gb",@"CTRadioAccessTechnologyLTE"],
        @[@"EE",@"234",@"30",@"gb",@"CTRadioAccessTechnologyLTE"],
        @[@"Three",@"234",@"20",@"gb",@"CTRadioAccessTechnologyLTE"],
        @[@"Orange",@"208",@"01",@"fr",@"CTRadioAccessTechnologyLTE"],
        @[@"SFR",@"208",@"10",@"fr",@"CTRadioAccessTechnologyLTE"],
        @[@"Bouygues",@"208",@"20",@"fr",@"CTRadioAccessTechnologyLTE"],
        @[@"NTT DoCoMo",@"440",@"10",@"jp",@"CTRadioAccessTechnologyLTE"],
        @[@"SoftBank",@"440",@"20",@"jp",@"CTRadioAccessTechnologyLTE"],
        @[@"au",@"440",@"50",@"jp",@"CTRadioAccessTechnologyLTE"],
        @[@"SK Telecom",@"450",@"05",@"kr",@"CTRadioAccessTechnologyLTE"],
        @[@"KT",@"450",@"02",@"kr",@"CTRadioAccessTechnologyLTE"],
        @[@"LG U+",@"450",@"06",@"kr",@"CTRadioAccessTechnologyLTE"],
        @[@"Movistar",@"214",@"07",@"es",@"CTRadioAccessTechnologyLTE"],
        @[@"Vodafone",@"214",@"01",@"es",@"CTRadioAccessTechnologyLTE"],
        @[@"Orange",@"214",@"03",@"es",@"CTRadioAccessTechnologyLTE"],
        @[@"Telstra",@"505",@"01",@"au",@"CTRadioAccessTechnologyLTE"],
        @[@"Optus",@"505",@"02",@"au",@"CTRadioAccessTechnologyLTE"],
        @[@"Jio",@"404",@"857",@"in",@"CTRadioAccessTechnologyLTE"],
        @[@"Airtel",@"404",@"10",@"in",@"CTRadioAccessTechnologyLTE"],
        @[@"Vi",@"404",@"20",@"in",@"CTRadioAccessTechnologyLTE"],
        @[@"China Mobile",@"460",@"00",@"cn",@"CTRadioAccessTechnologyLTE"],
        @[@"China Unicom",@"460",@"01",@"cn",@"CTRadioAccessTechnologyLTE"],
        @[@"China Telecom",@"460",@"11",@"cn",@"CTRadioAccessTechnologyLTE"]
    ];
    for (NSUInteger j = 0; j < names.count; j++) {
        [alert addAction:[UIAlertAction actionWithTitle:names[j] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            self.carrierPresetIndex = (NSInteger)j;
            self.config.carrierName = presets[j][0];
            self.config.carrierMCC = presets[j][1];
            self.config.carrierMNC = presets[j][2];
            self.config.carrierISO = presets[j][3];
            self.config.radioTech = presets[j][4];
            [self.config save];
            [self.tableView reloadData];
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    if (self.traitCollection.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = self.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2, 1, 1);
    }
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - System & Storage

- (UITableViewCell *)systemCell:(NSIndexPath *)i {
    switch (i.row) {
        case 0: { UITableViewCell *c = [self cellWithTitle:@"iOS Version" detail:[self iosVersionDetail]]; c.accessoryType = UITableViewCellAccessoryDisclosureIndicator; c.selectionStyle = UITableViewCellSelectionStyleDefault; return c; }
        case 1: { UITableViewCell *c = [self cellWithTitle:@"Total Storage" detail:self.config.totalStorage > 0 ? [NSString stringWithFormat:@"%lu GB", (unsigned long)self.config.totalStorage] : @"Auto"]; c.accessoryType = UITableViewCellAccessoryDisclosureIndicator; c.selectionStyle = UITableViewCellSelectionStyleDefault; return c; }
        case 2: { UITableViewCell *c = [self cellWithTitle:@"Free Storage" detail:self.config.freeStorage > 0 ? [NSString stringWithFormat:@"%lu GB", (unsigned long)self.config.freeStorage] : @"Auto"]; c.selectionStyle = UITableViewCellSelectionStyleDefault; return c; }
        case 3: return [self switchCellWithTitle:@"Low Power Mode" on:self.config.lowPowerMode action:@selector(toggleLowPower:)];
        case 4: return [self switchCellWithTitle:@"Spoof IDFA/IDFV" on:self.config.spoofIDFA action:@selector(toggleIDFA:)];
    }
    return [self cellWithTitle:@"" detail:@""];
}

- (void)toggleLowPower:(UISwitch *)s { self.config.lowPowerMode = s.on; [self.config save]; }
- (void)toggleIDFA:(UISwitch *)s { self.config.spoofIDFA = s.on; [self.config save]; }

- (void)showSystemPicker:(NSInteger)row {
    if (row == 0) {
        // iOS Version picker
        NSDictionary *versions = [SCDevicePresetStore iosVersionOptionsForProductType:self.config.productType];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"iOS Version" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        for (NSString *key in [versions.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            NSDictionary *info = versions[key];
            [alert addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%@ (Build %@)", info[@"version"], info[@"build"]] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
                self.config.systemVersion = info[@"version"];
                self.config.buildID = info[@"build"];
                [self.config save];
                [self.tableView reloadData];
            }]];
        }
        [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
        if (self.traitCollection.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            alert.popoverPresentationController.sourceView = self.view;
            alert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2, 1, 1);
        }
        [self presentViewController:alert animated:YES completion:nil];
    } else if (row == 1) {
        // Total Storage picker
        NSArray *opts = [SCDevicePresetStore storageOptionsForProductType:self.config.productType];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Total Storage" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        for (NSNumber *size in opts) {
            [alert addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%lu GB", (unsigned long)size.unsignedIntegerValue] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
                self.config.totalStorage = size.unsignedIntegerValue;
                if (self.config.freeStorage == 0 || self.config.freeStorage > self.config.totalStorage) {
                    self.config.freeStorage = self.config.totalStorage / 3;
                }
                [self.config save];
                [self.tableView reloadData];
            }]];
        }
        [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
        if (self.traitCollection.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            alert.popoverPresentationController.sourceView = self.view;
            alert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2, 1, 1);
        }
        [self presentViewController:alert animated:YES completion:nil];
    } else if (row == 2) {
        // Free Storage: random button
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Free Storage" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        if (self.config.totalStorage > 0) {
            [alert addAction:[UIAlertAction actionWithTitle:@"Random" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
                NSUInteger total = self.config.totalStorage;
                NSUInteger min = total / 5;
                NSUInteger max = total * 4 / 5;
                self.config.freeStorage = min + arc4random_uniform((uint32_t)(max - min));
                [self.config save];
                [self.tableView reloadData];
            }]];
            for (NSUInteger pct = 10; pct <= 80; pct += 10) {
                NSUInteger val = self.config.totalStorage * pct / 100;
                [alert addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%lu GB (%ld%%)", (unsigned long)val, (long)pct] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
                    self.config.freeStorage = val;
                    [self.config save];
                    [self.tableView reloadData];
                }]];
            }
        }
        [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
        if (self.traitCollection.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            alert.popoverPresentationController.sourceView = self.view;
            alert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2, 1, 1);
        }
        [self presentViewController:alert animated:YES completion:nil];
    }
}

#pragma mark - Proxy Check

- (void)checkProxy {
    NSIndexPath *ip = [NSIndexPath indexPathForRow:(self.config.proxyEnabled ? 6 : 1) inSection:1];
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:ip];
    cell.detailTextLabel.text = @"Checking...";
    NSURL *url = [NSURL URLWithString:@"https://ipwho.is/"];
    [[NSURLSession.sharedSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSString *result = @"Error";
        if (data) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (json && [json[@"success"] boolValue]) {
                result = [NSString stringWithFormat:@"%@, %@ - %@", json[@"ip"] ?: @"?", json[@"city"] ?: @"?", json[@"connection"][@"isp"] ?: @"?"];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self.proxyCheckResult = result;
            [self.tableView reloadData];
        });
    }] resume];
}

#pragma mark - Anti-Detect

- (UITableViewCell *)antiDetectCell:(NSIndexPath *)i {
    NSArray *titles = @[@"Ẩn Proxy", @"Ẩn VPN", @"Ẩn Jailbreak", @"Spoof IDFA", @"Spoof Battery"];
    NSArray *vals = @[@(self.config.hideProxy), @(self.config.hideVPN), @(self.config.hideJailbreak), @(self.config.spoofIDFA), @(self.config.spoofBattery)];
    return [self switchCellWithTitle:titles[i.row] on:[vals[i.row] boolValue] action:@selector(toggleAnti:)];
}

- (void)toggleAnti:(UISwitch *)s {
    CGPoint p = [s convertPoint:CGPointZero toView:self.tableView];
    NSIndexPath *i = [self.tableView indexPathForRowAtPoint:p];
    switch (i.row) {
        case 0: self.config.hideProxy = s.on; break;
        case 1: self.config.hideVPN = s.on; break;
        case 2: self.config.hideJailbreak = s.on; break;
        case 3: self.config.spoofIDFA = s.on; break;
        case 4: self.config.spoofBattery = s.on; break;
    }
    [self.config save];
}

- (void)saveAndReload {
    for (UITableViewCell *c in self.tableView.visibleCells) {
        if ([c.accessoryView isKindOfClass:UITextField.class]) {
            UITextField *t = (id)c.accessoryView;
            switch (t.tag / 100) {
                case 5: if (t.tag==500) self.config.wifiSSID=t.text; break;
                case 6: if (t.tag==601) self.config.proxyType=t.text; if (t.tag==602) self.config.proxyHost=t.text; if (t.tag==603) self.config.proxyPort=t.text.integerValue; if (t.tag==604) self.config.proxyUser=t.text; if (t.tag==605) self.config.proxyPass=t.text; break;
                case 7: if (t.tag==702) self.config.latitude=t.text.doubleValue; if (t.tag==703) self.config.longitude=t.text.doubleValue; if (t.tag==704) self.config.altitude=t.text.doubleValue; if (t.tag==705) self.config.horizontalAccuracy=t.text.doubleValue; if (t.tag==706) self.config.heading=t.text.doubleValue; break;
                case 8: if (t.tag==800) self.config.carrierName=t.text; if (t.tag==801) self.config.carrierMCC=t.text; if (t.tag==802) self.config.carrierMNC=t.text; if (t.tag==803) self.config.carrierISO=t.text; if (t.tag==804) self.config.radioTech=t.text; break;
            }
        }
    }
    [self.config save];
}

@end
