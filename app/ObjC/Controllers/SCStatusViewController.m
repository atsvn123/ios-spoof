#import "SCStatusViewController.h"
#import <spawn.h>

extern char **environ;

@implementation SCStatusViewController

- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self.config load]; [self.tableView reloadData]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 5; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 3;
    if (section == 1) return 8;
    if (section == 2) return 4;
    if (section == 3) return 5;
    return 2;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @[@"Trạng thái", @"Thiết bị đang spoof", @"Carrier", @"GPS", @"Actions"][section];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *p = [self.config resolvedPreset];
    if (indexPath.section == 0) {
        if (indexPath.row == 0) return [self switchCellWithTitle:@"Bật Spoof" on:self.config.enabled action:@selector(toggleEnabled:)];
        if (indexPath.row == 1) return [self cellWithTitle:@"Target Apps" detail:[NSString stringWithFormat:@"%lu app", (unsigned long)self.config.targetBundles.count]];
        return [self cellWithTitle:@"Random IDs mỗi launch" detail:self.config.randomizeOnLaunch ? @"Bật" : @"Tắt"];
    }
    if (indexPath.section == 1) {
        NSArray *keys = @[@"marketingName", @"productType", @"hardwareModel", @"modelNumber", @"chipId", @"cpuArchitecture", @"capacityGB", @"screenWidth"];
        NSArray *labels = @[@"Model", @"Product", @"Hardware", @"Model No", @"Chip", @"CPU", @"Storage", @"Width"];
        id v = p[keys[indexPath.row]] ?: @"-";
        return [self cellWithTitle:labels[indexPath.row] detail:[v description]];
    }
    if (indexPath.section == 2) {
        NSArray *vals = @[self.config.carrierName ?: @"", self.config.carrierMCC ?: @"", self.config.carrierMNC ?: @"", self.config.radioTech ?: @""];
        return [self cellWithTitle:@[@"Name", @"MCC", @"MNC", @"Radio"][indexPath.row] detail:vals[indexPath.row]];
    }
    if (indexPath.section == 3) {
        NSArray *vals = @[self.config.geoEnabled ? @"Bật" : @"Tắt", @(self.config.latitude), @(self.config.longitude), @(self.config.altitude), @(self.config.horizontalAccuracy)];
        return [self cellWithTitle:@[@"GPS", @"Lat", @"Lon", @"Altitude", @"Accuracy"][indexPath.row] detail:[vals[indexPath.row] description]];
    }
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.textLabel.text = indexPath.row == 0 ? @"Randomize All" : @"Respring";
    cell.textLabel.textColor = indexPath.row == 0 ? [UIColor systemPurpleColor] : [UIColor systemOrangeColor];
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section != 4) return;
    if (indexPath.row == 0) { [self.config randomizeAll]; [self.tableView reloadData]; return; }
    NSString *killall = [[NSFileManager defaultManager] isExecutableFileAtPath:@"/var/jb/usr/bin/killall"] ? @"/var/jb/usr/bin/killall" : @"/usr/bin/killall";
    pid_t pid = 0;
    char *args[] = {(char *)killall.UTF8String, "-9", "SpringBoard", NULL};
    posix_spawn(&pid, killall.UTF8String, NULL, NULL, args, environ);
}
- (void)toggleEnabled:(UISwitch *)sw { self.config.enabled = sw.on; [self.config save]; }

@end
