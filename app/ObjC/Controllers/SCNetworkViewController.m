#import "SCNetworkViewController.h"
@implementation SCNetworkViewController
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return section == 0 ? 5 : (section == 1 ? 3 : 3); }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return @[@"Proxy", @"Anti-Detect", @"IDs"][section]; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)i {
    if (i.section == 0) {
        if (i.row == 0) return [self switchCellWithTitle:@"Bật Proxy" on:self.config.proxyEnabled action:@selector(toggleProxy:)];
        NSArray *titles=@[@"Type",@"Host",@"Port",@"User"];
        NSArray *vals=@[self.config.proxyType,self.config.proxyHost,@(self.config.proxyPort).stringValue,self.config.proxyUser];
        UITableViewCell *c=[self cellWithTitle:titles[i.row-1] detail:nil]; c.accessoryView=[self textFieldWithText:vals[i.row-1] placeholder:@"" tag:100+i.row keyboard:i.row==3?UIKeyboardTypeNumberPad:UIKeyboardTypeDefault]; return c;
    }
    if (i.section == 1) return [self switchCellWithTitle:@[@"Ẩn Proxy",@"Ẩn VPN",@"Ẩn Jailbreak"][i.row] on:@[@(self.config.hideProxy),@(self.config.hideVPN),@(self.config.hideJailbreak)][i.row].boolValue action:@selector(toggleAnti:)];
    return [self switchCellWithTitle:@[@"Spoof IDFA",@"Spoof IDFV",@"Spoof Battery"][i.row] on:@[@(self.config.spoofIDFA),@(self.config.spoofIDFV),@(self.config.spoofBattery)][i.row].boolValue action:@selector(toggleIDs:)];
}
- (void)saveAndReload { for (UITableViewCell *c in self.tableView.visibleCells) if ([c.accessoryView isKindOfClass:UITextField.class]) { UITextField *t=(id)c.accessoryView; if(t.tag==101) self.config.proxyType=t.text; if(t.tag==102) self.config.proxyHost=t.text; if(t.tag==103) self.config.proxyPort=t.text.integerValue; if(t.tag==104) self.config.proxyUser=t.text; } [self.config save]; }
- (void)toggleProxy:(UISwitch*)s{self.config.proxyEnabled=s.on;[self.config save];}
- (void)toggleAnti:(UISwitch*)s{CGPoint p=[s convertPoint:CGPointZero toView:self.tableView]; NSIndexPath*i=[self.tableView indexPathForRowAtPoint:p]; if(i.row==0)self.config.hideProxy=s.on; if(i.row==1)self.config.hideVPN=s.on; if(i.row==2)self.config.hideJailbreak=s.on; [self.config save];}
- (void)toggleIDs:(UISwitch*)s{CGPoint p=[s convertPoint:CGPointZero toView:self.tableView]; NSIndexPath*i=[self.tableView indexPathForRowAtPoint:p]; if(i.row==0)self.config.spoofIDFA=s.on; if(i.row==1)self.config.spoofIDFV=s.on; if(i.row==2)self.config.spoofBattery=s.on; [self.config save];}
@end
