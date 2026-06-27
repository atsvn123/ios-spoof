#import "SCHardwareViewController.h"
@implementation SCHardwareViewController
- (NSInteger)numberOfSectionsInTableView:(UITableView*)t{return 2;}
- (NSInteger)tableView:(UITableView*)t numberOfRowsInSection:(NSInteger)s{return s==0?5:3;}
- (NSString*)tableView:(UITableView*)t titleForHeaderInSection:(NSInteger)s{return s==0?@"Hardware Preview":@"Toggles";}
- (UITableViewCell*)tableView:(UITableView*)t cellForRowAtIndexPath:(NSIndexPath*)i{ NSDictionary*p=[self.config resolvedPreset]; if(i.section==0){NSArray*k=@[@"capacityGB",@"chipId",@"cpuArchitecture",@"deviceClass",@"boardId"];return[self cellWithTitle:@[@"Storage",@"Chip",@"CPU",@"Class",@"Board"][i.row] detail:[p[k[i.row]] description]];} return [self switchCellWithTitle:@[@"Spoof Battery",@"Hide Jailbreak",@"Random IDs mỗi launch"][i.row] on:@[@(self.config.spoofBattery),@(self.config.hideJailbreak),@(self.config.randomizeOnLaunch)][i.row].boolValue action:@selector(toggle:)];}
- (void)toggle:(UISwitch*)s{CGPoint p=[s convertPoint:CGPointZero toView:self.tableView];NSIndexPath*i=[self.tableView indexPathForRowAtPoint:p];if(i.row==0)self.config.spoofBattery=s.on; if(i.row==1)self.config.hideJailbreak=s.on; if(i.row==2)self.config.randomizeOnLaunch=s.on; [self.config save];}
@end
