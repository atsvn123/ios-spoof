#import "SCSpoofViewController.h"
#import "../Models/SCAppConfig.h"

@interface SCSpoofViewController ()
@property (nonatomic) BOOL geoIPLoading;
@end

@implementation SCSpoofViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    tap.cancelsTouchesInView = NO;
    [self.tableView addGestureRecognizer:tap];
}

- (void)dismissKeyboard { [self.view endEditing:YES]; }

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.config load];
    [self.tableView reloadData];
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return 5; }

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s {
    switch (s) {
        case 0: return 4; // Network mode
        case 1: return self.config.proxyEnabled ? 6 : 1; // Proxy
        case 2: return self.config.geoFromIP ? 5 : 7; // GPS
        case 3: return 5 + 4; // Carrier + quick presets merged
        case 4: return 5; // Anti-detect
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s {
    return @[@"Network Mode", @"Proxy", @"GPS Location", @"Carrier", @"Anti-Detect"][s];
}

- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)s {
    switch (s) {
        case 0: return @"WiFi: app thấy đang dùng WiFi. Cellular: app thấy 4G/5G thay WiFi.";
        case 1: return @"Proxy trong suốt. Geo từ IP sẽ lấy vị trí theo IP proxy.";
        case 2: return self.config.geoFromIP ? @"Đang lấy vị trí từ IP. Lat/Lon đã tắt." : @"Nhập tọa độ thủ công.";
        case 3: return @"Chọn preset nhà mạng hoặc nhập thủ công.";
        default: return @"";
    }
}

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)i {
    switch (i.section) {
        case 0: return [self networkModeCell:i];
        case 1: return [self proxyCell:i];
        case 2: return [self gpsCell:i];
        case 3: return i.row < 5 ? [self carrierCell:i] : [self presetCell:i];
        case 4: return [self antiDetectCell:i];
    }
    return [self cellWithTitle:@"" detail:@""];
}

#pragma mark - Network Mode

- (UITableViewCell *)networkModeCell:(NSIndexPath *)i {
    if (i.row == 0) {
        // WiFi toggle (exclusive with Cellular)
        UITableViewCell *c = [self switchCellWithTitle:@"WiFi (ảo)" on:self.config.networkMode==1 action:@selector(toggleWifiMode:)];
        UISwitch *sw = (UISwitch *)c.accessoryView;
        sw.tag = 1;
        return c;
    }
    if (i.row == 1) {
        // Cellular toggle (exclusive with WiFi)
        UITableViewCell *c = [self switchCellWithTitle:@"Cellular (fake 4G/5G)" on:self.config.networkMode==2 action:@selector(toggleCellularMode:)];
        UISwitch *sw = (UISwitch *)c.accessoryView;
        sw.tag = 2;
        return c;
    }
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
    if (i.row == 1) return [self switchCellWithTitle:@"Bật GPS Spoof" on:self.config.geoEnabled action:@selector(toggleGeo:)];
    NSArray *titles = @[@"Latitude", @"Longitude", @"Altitude", @"Accuracy", @"Heading"];
    NSArray *vals = @[@(self.config.latitude), @(self.config.longitude), @(self.config.altitude), @(self.config.horizontalAccuracy), @(self.config.heading)];
    UITableViewCell *c = [self cellWithTitle:titles[i.row-2] detail:nil];
    c.accessoryView = [self textFieldWithText:[vals[i.row-2] description] placeholder:@"" tag:700+i.row keyboard:UIKeyboardTypeDecimalPad];
    return c;
}

- (void)toggleGeoFromIP:(UISwitch *)s {
    self.config.geoFromIP = s.on;
    if (s.on) {
        self.config.geoEnabled = YES;
        self.geoIPLoading = YES;
        [self.tableView reloadData];
        [self.config fetchGeoFromIP];
        // Reload after 3 seconds to show results
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.geoIPLoading = NO;
            [self.tableView reloadData];
        });
    }
    [self.config save];
    [self.tableView reloadData];
}

- (void)toggleGeo:(UISwitch *)s { self.config.geoEnabled = s.on; [self.config save]; }

#pragma mark - Carrier (with presets merged)

- (UITableViewCell *)carrierCell:(NSIndexPath *)i {
    NSArray *titles = @[@"Name", @"MCC", @"MNC", @"ISO", @"Radio"];
    NSArray *vals = @[self.config.carrierName, self.config.carrierMCC, self.config.carrierMNC, self.config.carrierISO, self.config.radioTech];
    UITableViewCell *c = [self cellWithTitle:titles[i.row] detail:nil];
    c.accessoryView = [self textFieldWithText:vals[i.row] placeholder:@"" tag:800+i.row keyboard:(i.row==1||i.row==2)?UIKeyboardTypeNumberPad:UIKeyboardTypeDefault];
    return c;
}

- (UITableViewCell *)presetCell:(NSIndexPath *)i {
    NSArray *names = @[@"Viettel 4G", @"Mobifone 4G", @"Vinaphone 4G", @"Viettel 5G"];
    UITableViewCell *c = [self cellWithTitle:names[i.row-5] detail:@""];
    c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return c;
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)i {
    [t deselectRowAtIndexPath:i animated:YES];
    [self dismissKeyboard];
    if (i.section == 3 && i.row >= 5) {
        NSArray *p = @[
            @[@"Viettel",@"452",@"04",@"vn",@"CTRadioAccessTechnologyLTE"],
            @[@"Mobifone",@"452",@"01",@"vn",@"CTRadioAccessTechnologyLTE"],
            @[@"Vinaphone",@"452",@"02",@"vn",@"CTRadioAccessTechnologyLTE"],
            @[@"Viettel",@"452",@"04",@"vn",@"CTRadioAccessTechnologyNRNSA"]
        ];
        NSInteger idx = i.row - 5;
        self.config.carrierName = p[idx][0];
        self.config.carrierMCC = p[idx][1];
        self.config.carrierMNC = p[idx][2];
        self.config.carrierISO = p[idx][3];
        self.config.radioTech = p[idx][4];
        [self.config save];
        [t reloadData];
    }
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
            }
        }
    }
    [self.config save];
}

@end
