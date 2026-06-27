#import "SCSpoofViewController.h"
#import "../Models/SCAppConfig.h"

@interface SCSpoofViewController () <UISearchBarDelegate>
@property (nonatomic) BOOL geoIPLoading;
@property (nonatomic, strong) UISearchBar *gpsSearchBar;
@property (nonatomic, strong) NSArray *gpsSearchResults;
@property (nonatomic) BOOL gpsSearching;
@property (nonatomic) NSInteger carrierPresetIndex;
@property (nonatomic, copy) NSString *proxyCheckResult;
@end

@implementation SCSpoofViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    tap.cancelsTouchesInView = NO;
    [self.tableView addGestureRecognizer:tap];
    self.gpsSearchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    self.gpsSearchBar.placeholder = @"Tìm địa điểm (OpenStreetMap)...";
    self.gpsSearchBar.delegate = self;
    self.gpsSearchResults = @[];
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
        case 0: return self.config.networkMode == 2 ? 2 : 4; // Network: hide SSID/BSSID when cellular
        case 1: return self.config.proxyEnabled ? 7 : 2; // Proxy + check
        case 2: return [self gpsRowCount]; // GPS
        case 3: return 1 + 5; // Carrier: preset row + 5 fields
        case 4: return 5; // Anti-detect
        case 5: return 6; // System
        default: return 0;
    }
}

- (NSInteger)gpsRowCount {
    if (self.config.geoFromIP) return 5;
    if (self.gpsSearching) return 2 + self.gpsSearchResults.count;
    return 2 + 5; // toggle + search bar + 5 manual fields
}

- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s {
    return @[@"Network Mode", @"Proxy", @"GPS Location", @"Carrier", @"Anti-Detect", @"System & Storage"][s];
}

- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)s {
    switch (s) {
        case 0: return self.config.networkMode == 2 ? @"Cellular: app thấy 4G/5G thay WiFi." : @"WiFi: app thấy đang dùng WiFi (có thể spoof SSID).";
        case 1: return @"Proxy trong suốt. Geo từ IP sẽ lấy vị trí theo IP proxy.";
        case 2: return self.config.geoFromIP ? @"Đang lấy vị trí từ IP. Nhập thủ công đã tắt." : (self.gpsSearching ? @"Chọn địa điểm từ kết quả tìm kiếm." : @"Nhập tọa độ thủ công hoặc tìm kiếm địa điểm.");
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
    UITableViewCell *c = [self cellWithTitle:@"WiFi BSSID" detail:nil];
    c.accessoryView = [self textFieldWithText:self.config.wifiBSSID placeholder:@"02:00:00:00:00:00" tag:501 keyboard:UIKeyboardTypeDefault];
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
        UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        c.accessoryView = self.gpsSearchBar;
        c.selectionStyle = UITableViewCellSelectionStyleNone;
        c.backgroundColor = [UIColor clearColor];
        return c;
    }
    if (self.gpsSearching && self.gpsSearchResults.count > 0) {
        NSDictionary *r = self.gpsSearchResults[i.row - 2];
        NSString *name = r[@"display_name"] ?: @"";
        if (name.length > 60) name = [name substringToIndex:60];
        return [self cellWithTitle:name detail:@""];
    }
    // Manual fields
    NSArray *titles = @[@"Latitude", @"Longitude", @"Altitude", @"Accuracy", @"Heading"];
    NSInteger fieldIdx = self.gpsSearching ? -1 : (i.row - 2);
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

#pragma mark - GPS Search (Nominatim)

- (void)searchBar:(UISearchBar *)bar textDidChange:(NSString *)searchText {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(gpsSearch) object:nil];
    if (searchText.length < 3) {
        self.gpsSearching = NO;
        self.gpsSearchResults = @[];
        [self.tableView reloadData];
        return;
    }
    self.gpsSearching = YES;
    [self.tableView reloadData];
    [self performSelector:@selector(gpsSearch) withObject:nil afterDelay:0.6];
}

- (void)gpsSearch {
    NSString *query = [self.gpsSearchBar.text stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    if (!query) return;
    NSString *urlStr = [NSString stringWithFormat:@"https://nominatim.openstreetmap.org/search?format=json&q=%@&limit=8", query];
    NSURL *url = [NSURL URLWithString:urlStr];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    [req setValue:@"iOSSpoof/1.0" forHTTPHeaderField:@"User-Agent"];
    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!data) return;
        NSArray *results = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![results isKindOfClass:[NSArray class]]) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            self.gpsSearchResults = results;
            [self.tableView reloadData];
        });
    }] resume];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)bar {
    [bar resignFirstResponder];
}

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
    if (i.section == 2 && self.gpsSearching && i.row >= 2 && i.row - 2 < (NSInteger)self.gpsSearchResults.count) {
        NSDictionary *r = self.gpsSearchResults[i.row - 2];
        self.config.latitude = [r[@"lat"] doubleValue];
        self.config.longitude = [r[@"lon"] doubleValue];
        self.config.geoEnabled = YES;
        [self.config save];
        self.gpsSearching = NO;
        self.gpsSearchResults = @[];
        self.gpsSearchBar.text = @"";
        [self.tableView reloadData];
        return;
    }
    if (i.section == 3 && i.row == 0) { [self showCarrierPresets]; return; }
}

- (void)showCarrierPresets {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Carrier Preset" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *names = @[@"Viettel 4G", @"Mobifone 4G", @"Vinaphone 4G", @"Viettel 5G"];
    NSArray *presets = @[
        @[@"Viettel",@"452",@"04",@"vn",@"CTRadioAccessTechnologyLTE"],
        @[@"Mobifone",@"452",@"01",@"vn",@"CTRadioAccessTechnologyLTE"],
        @[@"Vinaphone",@"452",@"02",@"vn",@"CTRadioAccessTechnologyLTE"],
        @[@"Viettel",@"452",@"04",@"vn",@"CTRadioAccessTechnologyNRNSA"]
    ];
    for (NSUInteger j = 0; j < names.count; j++) {
        [alert addAction:[UIAlertAction actionWithTitle:names[j] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            self.carrierPresetIndex = j;
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
        case 0: { UITableViewCell *c = [self cellWithTitle:@"iOS Version" detail:nil]; c.accessoryView = [self textFieldWithText:self.config.systemVersion ?: @"17.5" placeholder:@"17.5" tag:900 keyboard:UIKeyboardTypeDefault]; return c; }
        case 1: { UITableViewCell *c = [self cellWithTitle:@"Build ID" detail:nil]; c.accessoryView = [self textFieldWithText:self.config.buildID ?: @"21F90" placeholder:@"21F90" tag:901 keyboard:UIKeyboardTypeDefault]; return c; }
        case 2: { UITableViewCell *c = [self cellWithTitle:@"Total Storage (GB)" detail:nil]; c.accessoryView = [self textFieldWithText:@(self.config.totalStorage).stringValue placeholder:@"256" tag:902 keyboard:UIKeyboardTypeNumberPad]; return c; }
        case 3: { UITableViewCell *c = [self cellWithTitle:@"Free Storage (GB)" detail:nil]; c.accessoryView = [self textFieldWithText:@(self.config.freeStorage).stringValue placeholder:@"128" tag:903 keyboard:UIKeyboardTypeNumberPad]; return c; }
        case 4: return [self switchCellWithTitle:@"Low Power Mode" on:self.config.lowPowerMode action:@selector(toggleLowPower:)];
        case 5: return [self switchCellWithTitle:@"Spoof IDFA/IDFV" on:self.config.spoofIDFA action:@selector(toggleIDFA:)];
    }
    return [self cellWithTitle:@"" detail:@""];
}

- (void)toggleLowPower:(UISwitch *)s { self.config.lowPowerMode = s.on; [self.config save]; }
- (void)toggleIDFA:(UISwitch *)s { self.config.spoofIDFA = s.on; [self.config save]; }

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
                case 5: if (t.tag==500) self.config.wifiSSID=t.text; if (t.tag==501) self.config.wifiBSSID=t.text; break;
                case 6: if (t.tag==601) self.config.proxyType=t.text; if (t.tag==602) self.config.proxyHost=t.text; if (t.tag==603) self.config.proxyPort=t.text.integerValue; if (t.tag==604) self.config.proxyUser=t.text; if (t.tag==605) self.config.proxyPass=t.text; break;
                case 7: if (t.tag==702) self.config.latitude=t.text.doubleValue; if (t.tag==703) self.config.longitude=t.text.doubleValue; if (t.tag==704) self.config.altitude=t.text.doubleValue; if (t.tag==705) self.config.horizontalAccuracy=t.text.doubleValue; if (t.tag==706) self.config.heading=t.text.doubleValue; break;
                case 8: if (t.tag==800) self.config.carrierName=t.text; if (t.tag==801) self.config.carrierMCC=t.text; if (t.tag==802) self.config.carrierMNC=t.text; if (t.tag==803) self.config.carrierISO=t.text; if (t.tag==804) self.config.radioTech=t.text; break;
                case 9: if (t.tag==900) self.config.systemVersion=t.text; if (t.tag==901) self.config.buildID=t.text; if (t.tag==902) self.config.totalStorage=t.text.integerValue; if (t.tag==903) self.config.freeStorage=t.text.integerValue; break;
            }
        }
    }
    [self.config save];
}

@end
