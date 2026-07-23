#import "SCKernelViewController.h"
#import "../Models/SCKernelCapabilityManager.h"

@interface SCKernelViewController ()
@property (nonatomic, readonly) SCKernelCapabilityManager *kernelManager;
@end

@implementation SCKernelViewController

- (SCKernelCapabilityManager *)kernelManager { return SCKernelCapabilityManager.shared; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Kernel";
    self.refreshControl = [UIRefreshControl new];
    [self.refreshControl addTarget:self action:@selector(refreshStatus) forControlEvents:UIControlEventValueChanged];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshStatus];
}

- (BOOL)isViewVisible {
    return self.isViewLoaded && self.view.window != nil;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 4; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 7;
    if (section == 1) return 4;
    if (section == 2) return 1;
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @[@"Kernel Capabilities", @"Environment", @"Read-only Action", @"Phase 1B Self-Test"][section];
}

- (NSString *)stateText:(BOOL)enabled trueText:(NSString *)trueText falseText:(NSString *)falseText {
    return enabled ? trueText : falseText;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SCKernelCapabilityManager *manager = self.kernelManager;
    if (indexPath.section == 0) {
        switch (indexPath.row) {
            case 0: return [self cellWithTitle:@"Status" detail:manager.statusMessage];
            case 1: return [self cellWithTitle:@"libkrw Provider" detail:[self stateText:manager.isKernelRWAvailable trueText:@"Available" falseText:@"Unavailable"]];
            case 2: return [self cellWithTitle:@"Kernel Read" detail:[self stateText:manager.isKernelReadAvailable trueText:@"Verified" falseText:@"Unverified"]];
            case 3: return [self cellWithTitle:@"Kernel Write" detail:[self stateText:manager.isKernelWriteExported trueText:@"Exported / Untested" falseText:@"Unavailable"]];
            case 4: return [self cellWithTitle:@"Kernel Call" detail:[self stateText:manager.isKernelCallExported trueText:@"Exported / Untested" falseText:@"Unavailable"]];
            case 5: return [self cellWithTitle:@"Mutation" detail:@"Disabled (Phase 1A)"];
            default: return [self cellWithTitle:@"Transaction State" detail:manager.transactionState.length ? manager.transactionState : @"-"];
        }
    }

    if (indexPath.section == 1) {
        switch (indexPath.row) {
            case 0: return [self cellWithTitle:@"Provider" detail:manager.providerName.length ? manager.providerName : @"-"];
            case 1: return [self cellWithTitle:@"Device" detail:manager.realDevice.length ? manager.realDevice : @"-"];
            case 2: return [self cellWithTitle:@"OS Build" detail:manager.realOSBuild.length ? manager.realOSBuild : @"-"];
            default: return [self cellWithTitle:@"Kernel UUID" detail:manager.kernelUUID.length ? manager.kernelUUID : @"-"];
        }
    }

    if (indexPath.section == 3) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
        if (manager.isPrimitiveSelfTestVerified) {
            cell.textLabel.text = @"Self-Test Verified";
            cell.detailTextLabel.text = @"kmalloc + kwrite + kdealloc đã xác minh trên vùng nhớ test.";
            cell.textLabel.textColor = UIColor.systemGreenColor;
        } else if (manager.isLoading) {
            cell.textLabel.text = @"Đang chạy…";
            cell.detailTextLabel.text = @"";
            cell.textLabel.textColor = UIColor.secondaryLabelColor;
        } else {
            cell.textLabel.text = @"Run Primitive Self-Test";
            cell.detailTextLabel.text = @"Tạo vùng nhớ test, ghi/đọc/khôi phục/giải phóng. Không chạm vnode hay kernel live data.";
            cell.textLabel.textColor = UIColor.systemBlueColor;
        }
        cell.selectionStyle = manager.isLoading ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleDefault;
        return cell;
    }

    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.textLabel.text = manager.isLoading ? @"Đang chạy…" : @"Run Read-Only Probe";
    cell.detailTextLabel.text = @"Chỉ gọi kbase và kread; không sửa kernel.";
    cell.textLabel.textColor = manager.isLoading ? UIColor.secondaryLabelColor : UIColor.systemBlueColor;
    cell.selectionStyle = manager.isLoading ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleDefault;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.kernelManager.isLoading) return;

    __weak typeof(self) weakSelf = self;
    SCKernelCapabilityCompletion completion = ^(BOOL success, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf.tableView reloadData];
        if (!success && error && [strongSelf isViewVisible]) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Kernel Probe" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [strongSelf presentViewController:alert animated:YES completion:nil];
        }
    };

    if (indexPath.section == 2) {
        [self.tableView reloadData];
        [self.kernelManager runReadOnlyProbeWithCompletion:completion];
    } else if (indexPath.section == 3) {
        [self.tableView reloadData];
        [self.kernelManager runPrimitiveSelfTestWithCompletion:completion];
    }
}

- (void)refreshStatus {
    __weak typeof(self) weakSelf = self;
    [self.kernelManager refreshStatusWithCompletion:^(BOOL success, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf.refreshControl endRefreshing];
        [strongSelf.tableView reloadData];
    }];
}

@end
