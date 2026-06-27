#import "SCDeviceViewController.h"
#import "../Models/SCDevicePresetStore.h"

@implementation SCDeviceViewController
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
    if (indexPath.section == 0) { self.config.productType = [SCDevicePresetStore allPresets][indexPath.row][@"productType"]; [self.config save]; [tableView reloadData]; }
}
- (void)toggleRandom:(UISwitch *)sw { self.config.randomizeOnLaunch = sw.on; [self.config save]; }
@end
