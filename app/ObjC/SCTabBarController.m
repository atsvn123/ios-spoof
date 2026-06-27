#import "SCTabBarController.h"
#import "Controllers/SCStatusViewController.h"
#import "Controllers/SCDeviceViewController.h"
#import "Controllers/SCAppsViewController.h"
#import "Controllers/SCNetworkViewController.h"
#import "Controllers/SCGPSViewController.h"
#import "Controllers/SCCellularViewController.h"
#import "Controllers/SCHardwareViewController.h"

static UINavigationController *SCNav(UIViewController *vc, NSString *title, NSString *imageName) {
    vc.title = title;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.tabBarItem = [[UITabBarItem alloc] initWithTitle:title image:[UIImage systemImageNamed:imageName] tag:0];
    return nav;
}

@implementation SCTabBarController

- (instancetype)init {
    self = [super init];
    if (self) {
        if (@available(iOS 13.0, *)) {
            self.tabBar.tintColor = [UIColor systemTealColor];
        }
        self.viewControllers = @[
            SCNav([SCStatusViewController new], @"Status", @"shield.lefthalf.fill"),
            SCNav([SCDeviceViewController new], @"Device", @"iphone"),
            SCNav([SCAppsViewController new], @"Apps", @"app.badge"),
            SCNav([SCNetworkViewController new], @"Network", @"network"),
            SCNav([SCGPSViewController new], @"GPS", @"location.fill"),
            SCNav([SCCellularViewController new], @"Cellular", @"antenna.radiowaves.left.and.right"),
            SCNav([SCHardwareViewController new], @"Hardware", @"cpu")
        ];
    }
    return self;
}

@end
