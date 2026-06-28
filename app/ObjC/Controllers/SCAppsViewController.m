#import "SCAppsViewController.h"

@interface SCAppsViewController ()
@property (nonatomic, copy) NSArray<NSDictionary *> *apps;
@property (nonatomic, strong) NSMutableSet<NSString *> *selected;
@end

@implementation SCAppsViewController

- (void)viewDidLoad { [super viewDidLoad]; self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(loadApps)]; [self loadApps]; }
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; self.selected=[NSMutableSet setWithArray:self.config.targetBundles ?: @[]]; }
- (void)loadApps { dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0), ^{ NSArray *a=[self fetchApps]; dispatch_async(dispatch_get_main_queue(), ^{ self.apps=a; [self.tableView reloadData]; }); }); }
- (NSArray *)fetchApps {
    NSSet *protectedBundles = [NSSet setWithArray:@[
        @"com.iosspoof.app",
        @"org.coolstar.SileoStore",
        @"org.coolstar.Sileo",
        @"com.saurik.Cydia",
        @"xyz.willy.Zebra",
        @"me.apptapp.Installer",
        @"com.opa334.Dopamine",
        @"com.opa334.TrollStore",
        @"com.opa334.TrollStorePersistenceHelper"
    ]];
    Class cls=NSClassFromString(@"LSApplicationWorkspace"); id ws=[cls performSelector:NSSelectorFromString(@"defaultWorkspace")];
    NSArray *raw=[ws performSelector:NSSelectorFromString(@"allInstalledApplications")]; NSMutableArray *out=[NSMutableArray array];
    NSSet *allowedSystemBundles = [NSSet setWithArray:@[@"com.apple.Preferences", @"com.apple.mobilesafari", @"com.apple.AppStore", @"com.apple.AppStore.Search", @"com.apple.MobileStore"]];
    for(id app in raw){ NSString*b=[app valueForKey:@"applicationIdentifier"]; if(!b || [protectedBundles containsObject:b]) continue; NSString*n=[app valueForKey:@"localizedName"] ?: b; NSString*t=[app valueForKey:@"applicationType"] ?: @""; if([t isEqualToString:@"System"] && ![allowedSystemBundles containsObject:b]) continue; [out addObject:@{@"name":n,@"bundle":b}]; }
    return [out sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)]]];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return section==0?2:self.apps.count; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return section==0?@"Selection":@"Installed Apps"; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)i { if(i.section==0){ UITableViewCell*c=[self cellWithTitle:i.row==0?@"Đã chọn":@"Bỏ chọn tất cả" detail:i.row==0?[NSString stringWithFormat:@"%lu app",(unsigned long)self.selected.count]:@""]; c.selectionStyle=UITableViewCellSelectionStyleDefault; return c;} NSDictionary*a=self.apps[i.row]; UITableViewCell*c=[self cellWithTitle:a[@"name"] detail:a[@"bundle"]]; c.accessoryType=[self.selected containsObject:a[@"bundle"]]?UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone; return c; }
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)i { [tableView deselectRowAtIndexPath:i animated:YES]; if(i.section==0){ if(i.row==1)[self.selected removeAllObjects]; } else { NSString*b=self.apps[i.row][@"bundle"]; [self.selected containsObject:b]?[self.selected removeObject:b]:[self.selected addObject:b]; } self.config.targetBundles=self.selected.allObjects; [self.config save]; [tableView reloadData]; }
@end
