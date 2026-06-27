#import "SCSpoofViewController.h"
#import "../Models/SCAppConfig.h"

@interface SCSpoofViewController ()
@property (nonatomic, strong) UISwitch *geoFromIPSwitch;
@end

@implementation SCSpoofViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.geoFromIPSwitch = [UISwitch new];
    [self.geoFromIPSwitch addTarget:self action:@selector(toggleGeoFromIP:) forControlEvents:UIControlEventValueChanged];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.config load];
    [self.tableView reloadData];
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return 6; }

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s {
    switch (s) {
        case 0: return 4; // Network mode
        case 1: return self.config.proxyEnabled ? 6 : 1; // Proxy
        case 2: return self.config.geoFromIP ? 5 : 7; // GPS (hide lat/lon if from IP)
        case 3: return 5; // Carrier
        case 4: return 4; // Quick carrier
        case 5: return 5; // Anti-detect
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s {
    return @[@"Network Mode", @"Proxy", @"GPS Location", @"Carrier", @"Quick Carrier", @"Anti-Detect"][s];
}

- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)s {
    switch (s) {
        case 0: return @"WiFi: app thấy đang dùng WiFi (có thể spoof SSID). Cellular: app thấy 4G/5G thay WiFi.";
        case 1: return @"Proxy trong suốt. Nếu bật Geo từ IP, request sẽ qua proxy.";
        case 2: return self.config.geoFromIP ? @"Tự lấy vị trí từ IP proxy. Lat/Lon đã disable." : @"Nhập tọa độ thủ công.";
        default: return @"";
    }
}

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)i {
    switch (i.section) {
        case 0: return [self networkModeCell:i];
        case 1: return [self proxyCell:i];
        case 2: return [self gpsCell:i];
        case 3: return [self carrierCell:i];
        case 4: return [self quickCarrierCell:i];
        case 5: return [self antiDetectCell:i];
    }
    return [self cellWithTitle:@"" detail:@""];
}

#pragma mark - Network Mode

- (UITableViewCell *)networkModeCell:(NSIndexPath *)i {
    if (i.row == 0) return [self switchCellWithTitle:@"WiFi (ảo)" on:self.config.networkMode==1 action:@selector(networkModeChanged:)];
    if (i.row == 1) return [self switchCellWithTitle:@"Cellular (fake 4G/5G)" on:self.config.networkMode==2 action:@selector(networkModeChanged:)];
    if (i.row == 2) {
        UITableViewCell *c = [self cellWithTitle:@"WiFi SSID" detail:nil];
        c.accessoryView = [self textFieldWithText:self.config.wifiSSID placeholder:@"MyWiFi" tag:500 keyboard:UIKeyboardTypeDefault];
        return c;
    }
    UITableViewCell *c = [self cellWithTitle:@"WiFi BSSID" detail:nil];
    c.accessoryView = [self textFieldWithText:self.config.wifiBSSID placeholder:@"02:00:00:00:00:00" tag:501 keyboard:UIKeyboardTypeDefault];
    return c;
}

- (void)networkModeChanged:(UISwitch *)s {
    if (s.on) {
        // Toggle between WiFi(1) and Cellular(2) based on which row
        // We use tag to distinguish: tag 0 = wifi, tag 1 = cellular
        self.config.networkMode = s.tag == 0 ? 1 : 2;
    } else {
        self.config.networkMode = 0;
    }
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
        self.geoFromIPSwitch.on = self.config.geoFromIP;
        UITableViewCell *c = [self switchCellWithTitle:@"Lấy GPS từ IP" on:self.config.geoFromIP action:@selector(toggleGeoFromIP:)];
        return c;
    }
    if (self.config.geoFromIP) {
        // Show IP geo info only
        NSArray *titles = @[@"City", @"Country", @"ISP", @"Lat/Lon"];
        NSArray *vals = @[self.config.geoIPCity ?: @"...", self.config.geoIPCountry ?: @"...", self.config.geoIPIsp ?: @"...",
                          [NSString stringWithFormat:@"%.4f, %.4f", self.config.latitude, self.config.longitude]];
        return [self cellWithTitle:titles[i.row-1] detail:vals[i.row-1]];
    }
    // Manual mode
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
        [self.config fetchGeoFromIP];
    }
    [self.config save];
    [self.tableView reloadData];
}

- (void)toggleGeo:(UISwitch *)s { self.config.geoEnabled = s.on; [self.config save]; }

#pragma mark - Carrier

- (UITableViewCell *)carrierCell:(NSIndexPath *)i {
    NSArray *titles = @[@"Name", @"MCC", @"MNC", @"ISO", @"Radio"];
    NSArray *vals = @[self.config.carrierName, self.config.carrierMCC, self.config.carrierMNC, self.config.carrierISO, self.config.radioTech];
    UITableViewCell *c = [self cellWithTitle:titles[i.row] detail:nil];
    c.accessoryView = [self textFieldWithText:vals[i.row] placeholder:@"" tag:800+i.row keyboard:(i.row==1||i.row==2)?UIKeyboardTypeNumberPad:UIKeyboardTypeDefault];
    return c;
}

#pragma mark - Quick Carrier

- (UITableViewCell *)quickCarrierCell:(NSIndexPath *)i {
    NSArray *names = @[@"Viettel 4G", @"Mobifone 4G", @"Vinaphone 4G", @"Viettel 5G"];
    return [self cellWithTitle:names[i.row] detail:@""];
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)i {
    [t deselectRowAtIndexPath:i animated:YES];
    if (i.section == 4) {
        NSArray *p = @[
            @[@"Viettel",@"452",@"04",@"vn",@"CTRadioAccessTechnologyLTE"],
            @[@"Mobifone",@"452",@"01",@"vn",@"CTRadioAccessTechnologyLTE"],
            @[@"Vinaphone",@"452",@"02",@"vn",@"CTRadioAccessTechnologyLTE"],
            @[@"Viettel",@"452",@"04",@"vn",@"CTRadioAccessTechnologyNRNSA"]
        ];
        self.config.carrierName = p[i.row][0];
        self.config.carrierMCC = p[i.row][1];
        self.config.carrierMNC = p[i.row][2];
        self.config.carrierISO = p[i.row][3];
        self.config.radioTech = p[i.row][4];
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
