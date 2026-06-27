#import "SCDeviceViewController.h"
#import "../Models/SCDevicePresetStore.h"

@implementation SCDeviceViewController
- (void)randomizeSystemForSelectedProduct {
    NSDictionary *iosVersions = [SCDevicePresetStore iosVersionOptionsForProductType:self.config.productType];
    NSArray *keys = iosVersions.allKeys;
    NSDictionary *iosInfo = iosVersions[keys[arc4random_uniform((uint32_t)keys.count)]];
    self.config.systemVersion = iosInfo[@"version"];
    self.config.buildID = iosInfo[@"build"];
    NSArray *storage = [SCDevicePresetStore storageOptionsForProductType:self.config.productType];
    self.config.totalStorage = [storage[arc4random_uniform((uint32_t)storage.count)] unsignedIntegerValue];
    self.config.freeStorage = self.config.totalStorage / (2 + arc4random_uniform(3));
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return section == 0 ? [SCDevicePresetStore allPresets].count : (section == 1 ? 1 : 1); }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return section == 0 ? @"Chọn Device" : (section == 1 ? @"Options" : @"Device Name"); }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1) return [self switchCellWithTitle:@"Random mỗi lần mở app" on:self.config.randomizeOnLaunch action:@selector(toggleRandom:)];
    if (indexPath.section == 2) {
        UITableViewCell *c = [self cellWithTitle:@"Custom Name" detail:nil];
        c.accessoryView = [self textFieldWithText:self.config.deviceName placeholder:@"VD: iPhone của tôi" tag:1000 keyboard:UIKeyboardTypeDefault];
        return c;
    }
    NSDictionary *p = [SCDevicePresetStore allPresets][indexPath.row];
    UITableViewCell *cell = [self cellWithTitle:p[@"marketingName"] detail:p[@"productType"]];
    cell.accessoryType = [self.config.productType isEqualToString:p[@"productType"]] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) { self.config.productType = [SCDevicePresetStore allPresets][indexPath.row][@"productType"]; [self randomizeSystemForSelectedProduct]; [self.config save]; [tableView reloadData]; }
}
- (void)toggleRandom:(UISwitch *)sw { self.config.randomizeOnLaunch = sw.on; [self.config save]; }
- (void)saveAndReload {
    for (UITableViewCell *c in self.tableView.visibleCells) {
        if ([c.accessoryView isKindOfClass:UITextField.class]) {
            UITextField *t = (id)c.accessoryView;
            if (t.tag == 1000) self.config.deviceName = t.text;
        }
    }
    [self.config save];
}
@end
