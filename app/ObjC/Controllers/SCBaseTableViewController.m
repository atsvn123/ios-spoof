#import "SCBaseTableViewController.h"

@implementation SCBaseTableViewController

- (SCAppConfig *)config { return [SCAppConfig shared]; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
}

- (UITableViewCell *)cellWithTitle:(NSString *)title detail:(NSString *)detail {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.textLabel.text = title;
    cell.detailTextLabel.text = detail ?: @"";
    cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (UITableViewCell *)switchCellWithTitle:(NSString *)title on:(BOOL)on action:(SEL)action {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.textLabel.text = title;
    UISwitch *sw = [UISwitch new];
    sw.on = on;
    [sw addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = sw;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (UITextField *)textFieldWithText:(NSString *)text placeholder:(NSString *)placeholder tag:(NSInteger)tag keyboard:(UIKeyboardType)keyboard {
    UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 190, 34)];
    tf.text = text ?: @"";
    tf.placeholder = placeholder;
    tf.textAlignment = NSTextAlignmentRight;
    tf.keyboardType = keyboard;
    tf.autocorrectionType = UITextAutocorrectionTypeNo;
    tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
    tf.clearButtonMode = UITextFieldViewModeWhileEditing;
    tf.tag = tag;
    [tf addTarget:self action:@selector(saveAndReload) forControlEvents:UIControlEventEditingDidEnd];
    return tf;
}

- (void)saveAndReload { [[SCAppConfig shared] save]; }

@end
