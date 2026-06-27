#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <unistd.h>

#define PREFS_PATH @"/var/mobile/Library/Preferences/com.iosspoof.tweak.plist"
#define PREFS_PATH_RL @"/var/jb/var/mobile/Library/Preferences/com.iosspoof.tweak.plist"

@interface SCAppListController : PSListController
@end

@implementation SCAppListController

- (NSString *)prefsPath {
    return access("/var/jb", F_OK) == 0 ? PREFS_PATH_RL : PREFS_PATH;
}

- (NSMutableDictionary *)loadPrefs {
    return [NSMutableDictionary dictionaryWithContentsOfFile:[self prefsPath]] ?: [NSMutableDictionary dictionary];
}

- (void)savePrefs:(NSDictionary *)prefs {
    [[NSFileManager defaultManager] createDirectoryAtPath:[[self prefsPath] stringByDeletingLastPathComponent]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    [prefs writeToFile:[self prefsPath] atomically:YES];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.iosspoof.tweak.prefs-changed"), NULL, NULL, TRUE);
}

- (NSArray<NSString *> *)selectedBundles {
    id value = [self loadPrefs][@"targetBundles"];
    if ([value isKindOfClass:[NSArray class]]) return value;
    if ([value isKindOfClass:[NSString class]]) {
        NSMutableArray *items = [NSMutableArray array];
        for (NSString *part in [(NSString *)value componentsSeparatedByString:@","]) {
            NSString *trimmed = [part stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (trimmed.length) [items addObject:trimmed];
        }
        return items;
    }
    return @[];
}

- (NSArray *)installedApplications {
    Class workspaceClass = objc_getClass("LSApplicationWorkspace");
    id workspace = [workspaceClass respondsToSelector:@selector(defaultWorkspace)] ? [workspaceClass performSelector:@selector(defaultWorkspace)] : nil;
    NSArray *apps = [workspace respondsToSelector:@selector(allInstalledApplications)] ? [workspace performSelector:@selector(allInstalledApplications)] : @[];

    NSMutableArray *result = [NSMutableArray array];
    for (id app in apps) {
        NSString *bundleID = nil;
        NSString *name = nil;
        UIImage *icon = nil;
        @try {
            if ([app respondsToSelector:@selector(applicationIdentifier)]) bundleID = [app performSelector:@selector(applicationIdentifier)];
            if ([app respondsToSelector:@selector(localizedName)]) name = [app performSelector:@selector(localizedName)];
            if (!name && [app respondsToSelector:@selector(itemName)]) name = [app performSelector:@selector(itemName)];
            if ([app respondsToSelector:@selector(iconDataForVariant:)]) {
                NSData *data = [app performSelector:@selector(iconDataForVariant:) withObject:@(2)];
                if ([data isKindOfClass:[NSData class]]) icon = [UIImage imageWithData:data];
            }
        } @catch (__unused id e) {}
        if (!bundleID.length) continue;
        if ([bundleID hasPrefix:@"com.apple.WebKit"] || [bundleID hasPrefix:@"com.apple.internal"]) continue;
        if (!name.length) name = bundleID;
        [result addObject:@{ @"name": name, @"bundleID": bundleID, @"icon": icon ?: [NSNull null] }];
    }
    [result sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"name"] localizedCaseInsensitiveCompare:b[@"name"]];
    }];
    return result;
}

- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;

    NSMutableArray *specs = [NSMutableArray array];
    PSSpecifier *group = [PSSpecifier preferenceSpecifierNamed:@"Ứng dụng được spoof"
                                                        target:self
                                                           set:nil
                                                           get:nil
                                                        detail:nil
                                                          cell:PSGroupCell
                                                          edit:nil];
    [group setProperty:@"Bật switch cho app muốn spoof. Sau khi thay đổi, quay lại màn hình chính và bấm Áp dụng & Respring." forKey:@"footerText"];
    [specs addObject:group];

    NSArray *selected = [self selectedBundles];
    for (NSDictionary *app in [self installedApplications]) {
        NSString *name = app[@"name"];
        NSString *bundleID = app[@"bundleID"];
        PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:name
                                                           target:self
                                                              set:@selector(setAppEnabled:forSpecifier:)
                                                              get:@selector(readAppEnabled:)
                                                           detail:nil
                                                             cell:PSSwitchCell
                                                             edit:nil];
        [spec setProperty:bundleID forKey:@"bundleID"];
        [spec setProperty:bundleID forKey:@"footerText"];
        if (app[@"icon"] != [NSNull null]) {
            [spec setProperty:app[@"icon"] forKey:@"iconImage"];
        }
        [specs addObject:spec];
        (void)selected;
    }

    _specifiers = specs;
    return _specifiers;
}

- (id)readAppEnabled:(PSSpecifier *)specifier {
    NSString *bundleID = [specifier propertyForKey:@"bundleID"];
    return @([[self selectedBundles] containsObject:bundleID]);
}

- (void)setAppEnabled:(id)value forSpecifier:(PSSpecifier *)specifier {
    NSString *bundleID = [specifier propertyForKey:@"bundleID"];
    if (!bundleID.length) return;

    NSMutableDictionary *prefs = [self loadPrefs];
    NSMutableArray *selected = [[self selectedBundles] mutableCopy];
    if ([value boolValue]) {
        if (![selected containsObject:bundleID]) [selected addObject:bundleID];
    } else {
        [selected removeObject:bundleID];
    }
    prefs[@"targetBundles"] = selected;
    [self savePrefs:prefs];
}

@end
