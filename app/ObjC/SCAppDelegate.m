#import "SCAppDelegate.h"
#import "SCTabBarController.h"

@implementation SCAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [SCTabBarController new];
    [self.window makeKeyAndVisible];
    return YES;
}

@end
