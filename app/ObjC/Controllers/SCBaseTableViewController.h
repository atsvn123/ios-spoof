#import <UIKit/UIKit.h>
#import "../Models/SCAppConfig.h"

@interface SCBaseTableViewController : UITableViewController
@property (nonatomic, readonly) SCAppConfig *config;
- (UITableViewCell *)cellWithTitle:(NSString *)title detail:(NSString *)detail;
- (UITableViewCell *)switchCellWithTitle:(NSString *)title on:(BOOL)on action:(SEL)action;
- (UITextField *)textFieldWithText:(NSString *)text placeholder:(NSString *)placeholder tag:(NSInteger)tag keyboard:(UIKeyboardType)keyboard;
- (void)saveAndReload;
@end
