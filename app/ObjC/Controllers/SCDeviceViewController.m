#import "SCDeviceViewController.h"
#import "../Models/SCDevicePresetStore.h"

@implementation SCDeviceViewController
- (void)randomizeSystemForSelectedProduct {
    NSDictionary *iosVersions = [SCDevicePresetStore iosVersionOptions];
    NSArray *keys = iosVersions.allKeys;
    NSDictionary *iosInfo = iosVersions[keys[arc4random_uniform((uint32_t)keys.count)]];
    self.config.systemVersion = iosInfo[@"version"];
    self.config.buildID = iosInfo[@"build"];
    NSArray *storage = [SCDevicePresetStore storageOptionsForProductType:self.config.productType];
    self.config.totalStorage = [storage[arc4random_uniform((uint32_t)storage.count)] unsignedIntegerValue];
    self.config.freeStorage = self.config.totalStorage / (2 + arc4random_uniform(3));
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return section == 0 ? [SCDevicePresetStore allPresets].count : 1; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return section == 0 ? @"Chọn Device" : @"Options"; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1) return [self switchCellWithTitle:@"Random mỗi lần mở app" on:self.config.randomizeOnLaunch action:@selector(toggleRandom:)];
    NSDictionary *p = [SCDevicePresetStore allPresets][indexPath.row];
    UITableViewCell *cell = [self cellWithTitle:p[@"marketingName"] detail:p[@"productType"]];
    cell.accessoryType = [self.config.productType isEqualToString:p[@"productType"]] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) { self.config.productType = [SCDevicePresetStore allPresets][indexPath.row][@"productType"]; [self randomizeSystemForSelectedProduct]; [self.config save]; [tableView reloadData]; }
}
- (void)toggleRandom:(UISwitch *)sw { self.config.randomizeOnLaunch = sw.on; [self.config save]; }
@end
