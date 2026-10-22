#import "SpokenPackagesViewController.h"
#import "../../UI/LauncherTheme.h"

@interface TKSpokenPackagesViewController ()
@property(nonatomic) TKAddOnsSources *sources;
@property(nonatomic, copy) NSArray<TKAddOnComponent *> *components;
@property(nonatomic) BOOL loading;
@property(nonatomic, strong, nullable) NSError *loadError;
@property(nonatomic, strong) UILabel *summaryLabel;
@end

@implementation TKSpokenPackagesViewController

- (instancetype)initWithSources:(TKAddOnsSources *)sources {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    _sources = sources;
    self.title = @"Spoken";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.view.backgroundColor = TKLauncherTheme.background;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.backgroundView = [TKPageBackgroundView new];
    self.tableView.separatorColor = TKLauncherTheme.hairline;
    TKPageHeaderView *page = [[TKPageHeaderView alloc] initWithTitle:@"Spoken (English)"
        subtitle:@"One core add-on with Quests, Places and Readables. Voice packs are separate; these are the English packs."];
    page.frame = CGRectMake(0, 0, self.tableView.bounds.size.width, 108);
    self.tableView.tableHeaderView = page;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Install"
        style:UIBarButtonItemStyleDone target:self action:@selector(install)];
    self.navigationItem.rightBarButtonItem.tintColor = TKLauncherTheme.gold;
    self.refreshControl = [UIRefreshControl new];
    [self.refreshControl addTarget:self action:@selector(load) forControlEvents:UIControlEventValueChanged];
    [self load];
}

- (void)load {
    self.loading = YES;
    self.loadError = nil;
    [self.tableView reloadData];
    __weak TKSpokenPackagesViewController *weakSelf = self;
    [self.sources spokenComponentsWithCompletion:^(NSArray<TKAddOnComponent *> *components, NSError *error) {
        TKSpokenPackagesViewController *strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.components = components;
        strongSelf.loadError = error;
        strongSelf.loading = NO;
        [strongSelf.refreshControl endRefreshing];
        [strongSelf updateInstall];
        [strongSelf.tableView reloadData];
    }];
}

- (TKAddOnComponent *)core { for (TKAddOnComponent *c in self.components) if ([c.componentID isEqualToString:@"spoken"]) return c; return nil; }
- (NSArray<TKAddOnComponent *> *)voices {
    NSMutableArray *result = [NSMutableArray new];
    for (TKAddOnComponent *c in self.components) if (![c.componentID isEqualToString:@"spoken"]) [result addObject:c];
    return result;
}
- (void)updateInstall {
    self.navigationItem.rightBarButtonItem.enabled = self.core.assetURL.length && !self.loading;
    [self updateSummary];
}
- (void)updateSummary {
    unsigned long long total = self.core.size;
    unsigned long long coreSize = total;
    for (TKAddOnComponent *c in self.voices) if (c.selected) total += c.size;
    NSByteCountFormatter *formatter = [NSByteCountFormatter new];
    formatter.countStyle = NSByteCountFormatterCountStyleFile;
    self.summaryLabel.text = [NSString stringWithFormat:@"Selected: %@ — core %@, voice packs %@. Voice packs are large and hosted on GitHub.",
        [formatter stringFromByteCount:(long long)total],
        [formatter stringFromByteCount:(long long)coreSize],
        [formatter stringFromByteCount:(long long)(total-coreSize)]];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { (void)tableView; return 2; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    if (section == 0) return self.loading && !self.components.count ? 1 : ((self.core || self.loadError) ? 1 : 0);
    return self.loading && !self.components.count ? 1 : MAX((NSInteger)self.voices.count, 1);
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView; return section == 0 ? @"Core" : @"English Voice Packs";
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;
    if (section == 0) return @"The core contains Spoken, Spoken Quests, Spoken Places and Spoken Readables. Every module is silent until its voice pack is installed.";
    return nil;
}
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    (void)tableView; return section == 1 ? 64 : UITableViewAutomaticDimension;
}
- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    (void)tableView;
    if (section != 1) return nil;
    UIView *wrapper = [UIView new];
    self.summaryLabel = [UILabel new];
    self.summaryLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    self.summaryLabel.textColor = TKLauncherTheme.muted;
    self.summaryLabel.numberOfLines = 0;
    self.summaryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [wrapper addSubview:self.summaryLabel];
    [NSLayoutConstraint activateConstraints:@[
        [self.summaryLabel.leadingAnchor constraintEqualToAnchor:wrapper.leadingAnchor constant:20],
        [self.summaryLabel.trailingAnchor constraintEqualToAnchor:wrapper.trailingAnchor constant:-20],
        [self.summaryLabel.topAnchor constraintEqualToAnchor:wrapper.topAnchor constant:8],
        [self.summaryLabel.bottomAnchor constraintEqualToAnchor:wrapper.bottomAnchor constant:-10]
    ]];
    [self updateSummary];
    return wrapper;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"spoken.component";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    cell.backgroundColor = [TKLauncherTheme.surface colorWithAlphaComponent:0.86];
    cell.textLabel.textColor = TKLauncherTheme.text;
    cell.detailTextLabel.textColor = TKLauncherTheme.muted;
    cell.detailTextLabel.numberOfLines = 2;
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    NSByteCountFormatter *formatter = [NSByteCountFormatter new];
    formatter.countStyle = NSByteCountFormatterCountStyleFile;
    if (self.loading && !self.components.count) {
        cell.textLabel.text = @"Loading release information…";
        cell.detailTextLabel.text = @"Checking the current GitHub release assets.";
        UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        spinner.color = TKLauncherTheme.gold;
        [spinner startAnimating];
        cell.accessoryView = spinner;
        return cell;
    }
    if (indexPath.section == 0) {
        TKAddOnComponent *component = self.core;
        if (!component) {
            cell.textLabel.text = @"Could not load Spoken";
            cell.detailTextLabel.text = self.loadError.localizedDescription ?: @"The GitHub release could not be read. Pull to refresh.";
            return cell;
        }
        cell.textLabel.text = component.name ?: @"Spoken";
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@", component.detail ?: @"Core add-on",
            component.size ? [formatter stringFromByteCount:(long long)component.size] : @"size unknown"];
        UIImageView *check = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark.circle.fill"]];
        check.tintColor = TKLauncherTheme.gold;
        cell.accessoryView = check;
        return cell;
    }
    if (!self.voices.count) {
        cell.textLabel.text = self.loadError ? @"Could not load the packs" : @"No English voice packs found";
        cell.detailTextLabel.text = self.loadError.localizedDescription ?: @"The current release has no English packs.";
        return cell;
    }
    TKAddOnComponent *component = self.voices[indexPath.row];
    cell.textLabel.text = component.name;
    NSString *status = component.assetURL.length
        ? [NSString stringWithFormat:@"%@ · %@", component.detail, [formatter stringFromByteCount:(long long)component.size]]
        : [NSString stringWithFormat:@"%@ · unavailable", component.detail];
    cell.detailTextLabel.text = status;
    UISwitch *toggle = [UISwitch new];
    toggle.onTintColor = TKLauncherTheme.gold;
    toggle.on = component.selected;
    toggle.enabled = component.assetURL.length > 0;
    toggle.tag = indexPath.row;
    [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;
    return cell;
}

- (void)toggleChanged:(UISwitch *)sender {
    NSArray<TKAddOnComponent *> *voices = self.voices;
    if (sender.tag < 0 || sender.tag >= (NSInteger)voices.count) return;
    voices[(NSUInteger)sender.tag].selected = sender.isOn;
    [self updateSummary];
}

- (void)install {
    if (self.loading || !self.core.assetURL.length) return;
    NSMutableArray<TKAddOnComponent *> *selected = [NSMutableArray new];
    [selected addObject:self.core];
    for (TKAddOnComponent *component in self.voices) if (component.selected && component.assetURL.length) [selected addObject:component];
    void (^installBlock)(NSArray<TKAddOnComponent *> *) = self.onInstall;
    [self.navigationController popViewControllerAnimated:YES];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (installBlock) installBlock(selected);
    });
}

@end
