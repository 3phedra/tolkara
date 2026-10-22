#import "AddOnsViewController.h"
#import "SpokenPackagesViewController.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "../../UI/LauncherTheme.h"

typedef NS_ENUM(NSInteger, TKAddOnsMode) { TKAddOnsModeDiscover, TKAddOnsModeInstalled, TKAddOnsModeWorkarounds, TKAddOnsModeBackups };

@interface TKAddOnsViewController () <UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating, UIDocumentPickerDelegate>
@property(nonatomic) TKAddOnsManager *manager;
@property(nonatomic) TKAddOnsSources *sources;
@property(nonatomic) UITableView *table;
@property(nonatomic) UISegmentedControl *modes;
@property(nonatomic) UISearchController *searchController;
@property(nonatomic) TKAddOnsMode mode;
@property(nonatomic, copy) NSString *query;
@property(nonatomic, copy) NSArray<TKAddOnSearchResult *> *searchResults;
@property(nonatomic, copy) NSArray<NSString *> *messages;
@property(nonatomic, copy) NSArray<TKInstalledAddOn *> *installed;
@property(nonatomic, copy) NSArray<TKAddOnBackup *> *backups;
@property(nonatomic, copy) NSArray<TKAddOnWorkaround *> *workarounds;
@property(nonatomic) BOOL busy;
@property(nonatomic) NSUInteger searchGeneration;
@property(nonatomic) NSUInteger loadGeneration;
@property(nonatomic, strong, nullable) UIAlertController *progressAlert;
@property(nonatomic) UIView *loadingView;
@property(nonatomic) UIActivityIndicatorView *loadingSpinner;
@property(nonatomic) UILabel *loadingLabel;
@end

static NSString *const TKCellIdentifier = @"addon.cell";

@implementation TKAddOnsViewController

- (instancetype)initWithManager:(TKAddOnsManager *)manager sources:(TKAddOnsSources *)sources {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _manager = manager; _sources = sources;
        _query = @""; _searchResults = @[]; _messages = @[]; _installed = @[]; _backups = @[]; _workarounds = @[];
        _showsCloseButton = YES;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"";
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.view.backgroundColor = TKLauncherTheme.background;
    if (self.showsCloseButton)
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(close)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"ellipsis.circle"] menu:[self actionMenu]];

    _modes = [[UISegmentedControl alloc] initWithItems:@[@"Discover", @"Installed", @"Workarounds", @"Backups"]];
    _modes.selectedSegmentIndex = 0;
    _modes.selectedSegmentTintColor = TKLauncherTheme.gold;
    _modes.translatesAutoresizingMaskIntoConstraints = NO;
    [_modes setTitleTextAttributes:@{NSForegroundColorAttributeName:TKLauncherTheme.text,
        NSFontAttributeName:[UIFont systemFontOfSize:11 weight:UIFontWeightMedium]} forState:UIControlStateNormal];
    [_modes setTitleTextAttributes:@{NSForegroundColorAttributeName:[UIColor colorWithRed:0.08 green:0.065 blue:0.035 alpha:1],
        NSFontAttributeName:[UIFont systemFontOfSize:11 weight:UIFontWeightSemibold]} forState:UIControlStateSelected];
    [_modes addTarget:self action:@selector(modeChanged) forControlEvents:UIControlEventValueChanged];
    TKPageHeaderView *page = [[TKPageHeaderView alloc] initWithTitle:@"Add-ons"
        subtitle:@"Discover, install and back up add-ons for this edition."];
    page.translatesAutoresizingMaskIntoConstraints = NO;
    UIView *header = [UIView new];
    header.frame = CGRectMake(0, 0, self.view.bounds.size.width, 144);
    [header addSubview:page];
    [header addSubview:_modes];
    [NSLayoutConstraint activateConstraints:@[
        [page.topAnchor constraintEqualToAnchor:header.topAnchor],
        [page.leadingAnchor constraintEqualToAnchor:header.leadingAnchor],
        [page.trailingAnchor constraintEqualToAnchor:header.trailingAnchor],
        [page.heightAnchor constraintEqualToConstant:96],
        [_modes.topAnchor constraintEqualToAnchor:page.bottomAnchor constant:4],
        [_modes.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:20],
        [_modes.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-20],
        [_modes.heightAnchor constraintEqualToConstant:32],
        [_modes.bottomAnchor constraintLessThanOrEqualToAnchor:header.bottomAnchor constant:-8]
    ]];

    _table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _table.translatesAutoresizingMaskIntoConstraints = NO;
    _table.dataSource = self; _table.delegate = self;
    _table.backgroundColor = UIColor.clearColor;
    _table.backgroundView = [TKPageBackgroundView new];
    _table.separatorColor = TKLauncherTheme.hairline;
    _table.tableHeaderView = header;
    _table.rowHeight = UITableViewAutomaticDimension;
    _table.estimatedRowHeight = 64;
    [self.view addSubview:_table];
    [NSLayoutConstraint activateConstraints:@[
        [_table.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_table.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [_table.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_table.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];

    _loadingView = [UIView new];
    _loadingView.translatesAutoresizingMaskIntoConstraints = NO;
    _loadingView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.45];
    _loadingView.hidden = YES;
    _loadingView.userInteractionEnabled = NO;
    [self.view addSubview:_loadingView];
    _loadingSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    _loadingSpinner.translatesAutoresizingMaskIntoConstraints = NO;
    _loadingSpinner.color = UIColor.whiteColor;
    [_loadingView addSubview:_loadingSpinner];
    _loadingLabel = [UILabel new];
    _loadingLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _loadingLabel.textColor = UIColor.whiteColor;
    _loadingLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    _loadingLabel.textAlignment = NSTextAlignmentCenter;
    _loadingLabel.numberOfLines = 0;
    [_loadingView addSubview:_loadingLabel];
    [NSLayoutConstraint activateConstraints:@[
        [_loadingView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_loadingView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_loadingView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_loadingView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_loadingSpinner.centerXAnchor constraintEqualToAnchor:_loadingView.centerXAnchor],
        [_loadingSpinner.centerYAnchor constraintEqualToAnchor:_loadingView.centerYAnchor constant:-16],
        [_loadingLabel.topAnchor constraintEqualToAnchor:_loadingSpinner.bottomAnchor constant:12],
        [_loadingLabel.leadingAnchor constraintEqualToAnchor:_loadingView.leadingAnchor constant:32],
        [_loadingLabel.trailingAnchor constraintEqualToAnchor:_loadingView.trailingAnchor constant:-32]
    ]];

    _searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    _searchController.searchResultsUpdater = self;
    _searchController.obscuresBackgroundDuringPresentation = NO;
    _searchController.searchBar.placeholder = @"Search add-ons";
    _searchController.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.definesPresentationContext = YES;
    self.navigationItem.searchController = _searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;

    [self runSearch:@""];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    UINavigationBarAppearance *appearance = [UINavigationBarAppearance new];
    [appearance configureWithTransparentBackground];
    appearance.shadowColor = UIColor.clearColor;
    self.navigationItem.standardAppearance = appearance;
    self.navigationItem.scrollEdgeAppearance = appearance;
    self.navigationController.navigationBar.tintColor = TKLauncherTheme.gold;
}

- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }

- (UIMenu *)actionMenu {
    __weak TKAddOnsViewController *weakSelf = self;
    UIAction *import = [UIAction actionWithTitle:@"Import ZIP…" image:[UIImage systemImageNamed:@"square.and.arrow.down"] identifier:nil handler:^(UIAction *action) {
        (void)action; [weakSelf importArchive];
    }];
    UIAction *wago = [UIAction actionWithTitle:@"Add from Wago URL…" image:[UIImage systemImageNamed:@"link"] identifier:nil handler:^(UIAction *action) {
        (void)action; [weakSelf addFromWago];
    }];
    UIAction *key = [UIAction actionWithTitle:@"CurseForge API key…" image:[UIImage systemImageNamed:@"key"] identifier:nil handler:^(UIAction *action) {
        (void)action; [weakSelf configureCurseForge];
    }];
    UIAction *refresh = [UIAction actionWithTitle:@"Refresh" image:[UIImage systemImageNamed:@"arrow.clockwise"] identifier:nil handler:^(UIAction *action) {
        (void)action; [weakSelf reloadForMode];
    }];
    UIAction *updates = [UIAction actionWithTitle:@"Check for updates" image:[UIImage systemImageNamed:@"arrow.triangle.2.circlepath"] identifier:nil handler:^(UIAction *action) {
        (void)action; [weakSelf checkForUpdates];
    }];
    return [UIMenu menuWithChildren:@[import, wago, key, refresh, updates]];
}

- (void)modeChanged {
    _mode = (TKAddOnsMode)_modes.selectedSegmentIndex;
    self.searchGeneration++;
    self.loadGeneration++;
    [self hideLoading];
    if (_mode != TKAddOnsModeDiscover) _searchController.active = NO;
    self.navigationItem.searchController = _mode == TKAddOnsModeDiscover ? _searchController : nil;
    [self.table reloadData];
    [self reloadForMode];
}

- (void)showLoading:(NSString *)message {
    self.loadingLabel.text = message;
    self.loadingView.hidden = NO;
    [self.loadingSpinner startAnimating];
    self.table.userInteractionEnabled = NO;
}

- (void)hideLoading {
    self.loadingView.hidden = YES;
    [self.loadingSpinner stopAnimating];
    self.table.userInteractionEnabled = YES;
}

- (void)reloadForMode {
    if (_mode == TKAddOnsModeDiscover) { [self runSearch:self.query]; return; }
    if (_mode == TKAddOnsModeInstalled) { [self loadInstalled]; return; }
    if (_mode == TKAddOnsModeWorkarounds) { [self loadWorkarounds]; return; }
    [self loadBackups];
}

#pragma mark - Data

- (TKAddOnSearchResult *)spokenPackageResultForQuery:(NSString *)query {
    if (![query.lowercaseString containsString:@"spoken"]) return nil;
    TKAddOnSearchResult *result = [TKAddOnSearchResult new];
    result.source = TKAddOnSourceGitHub;
    result.identifier = @"rusty-key/spoken-wow#spoken-package";
    result.name = @"Spoken (English)";
    result.summary = @"Core add-on plus optional English voice packs. Opens a package chooser.";
    result.author = @"rusty-key";
    result.compatible = YES;
    result.pageURL = @"https://github.com/rusty-key/spoken-wow";
    result.payload = @{@"spokenPackage": @YES};
    return result;
}

- (void)runSearch:(NSString *)query {
    self.query = query ?: @"";
    if (_mode != TKAddOnsModeDiscover) return;
    NSUInteger generation = ++self.searchGeneration;
    self.busy = YES;
    [self updateFooter];
    [self.sources search:self.query completion:^(NSArray<TKAddOnSearchResult *> *results, NSArray<NSString *> *messages) {
        if (generation != self.searchGeneration) return;
        self.busy = NO;
        if (self.mode != TKAddOnsModeDiscover) return;
        TKAddOnSearchResult *spoken = [self spokenPackageResultForQuery:self.query];
        NSMutableArray<TKAddOnSearchResult *> *combined = [NSMutableArray array];
        if (spoken) [combined addObject:spoken];
        for (TKAddOnSearchResult *result in results) {
            if (spoken && result.source == TKAddOnSourceGitHub &&
                [result.identifier isEqualToString:@"rusty-key/spoken-wow"]) continue;
            [combined addObject:result];
        }
        self.searchResults = combined;
        self.messages = messages;
        [self.table reloadData];
        [self updateFooter];
    }];
}

- (void)loadInstalled {
    TKAddOnsManager *manager = self.manager;
    NSUInteger generation = ++self.loadGeneration;
    BOOL visible = self.mode == TKAddOnsModeInstalled;
    if (visible) {
        self.busy = YES;
        [self showLoading:@"Reading installed add-ons…"];
        [self.table reloadData];
        [self updateFooter];
    }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSError *error = nil;
        NSArray<TKInstalledAddOn *> *addons = [manager installedAddOns:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation != self.loadGeneration) return;
            if (visible) {
                self.busy = NO;
                [self hideLoading];
            }
            self.installed = addons ?: @[];
            if (self.mode == TKAddOnsModeInstalled) {
                self.messages = addons ? @[] : @[error.localizedDescription ?: @"Could not read the add-on folder."];
                [self.table reloadData];
                [self updateFooter];
            }
        });
    });
}

- (void)loadBackups {
    TKAddOnsManager *manager = self.manager;
    NSUInteger generation = ++self.loadGeneration;
    BOOL visible = self.mode == TKAddOnsModeBackups;
    if (visible) {
        self.busy = YES;
        [self showLoading:@"Reading backups…"];
        [self.table reloadData];
        [self updateFooter];
    }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSArray<TKAddOnBackup *> *backups = [manager backups];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation != self.loadGeneration) return;
            if (visible) {
                self.busy = NO;
                [self hideLoading];
            }
            self.backups = backups;
            if (self.mode == TKAddOnsModeBackups) {
                [self.table reloadData];
                [self updateFooter];
            }
        });
    });
}

- (void)loadWorkarounds {
    TKAddOnsManager *manager = self.manager;
    NSUInteger generation = ++self.loadGeneration;
    BOOL visible = self.mode == TKAddOnsModeWorkarounds;
    if (visible) {
        self.busy = YES;
        [self showLoading:@"Reading workarounds…"];
        [self.table reloadData];
        [self updateFooter];
    }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSError *error = nil;
        NSArray<TKAddOnWorkaround *> *workarounds = [manager workarounds:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation != self.loadGeneration) return;
            if (visible) {
                self.busy = NO;
                [self hideLoading];
            }
            self.workarounds = workarounds ?: @[];
            if (self.mode == TKAddOnsModeWorkarounds) {
                self.messages = workarounds ? @[] : @[error.localizedDescription ?: @"Could not read workarounds."];
                [self.table reloadData];
                [self updateFooter];
            }
        });
    });
}

- (NSArray<TKAddOnSearchResult *> *)resultsForSource:(TKAddOnSourceKind)source {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(TKAddOnSearchResult *result, NSDictionary *bindings) {
        (void)bindings; return result.source == source;
    }];
    return [self.searchResults filteredArrayUsingPredicate:predicate];
}

- (NSArray<NSNumber *> *)discoverSources {
    NSMutableArray<NSNumber *> *sources = [NSMutableArray new];
    for (NSNumber *source in @[@(TKAddOnSourceTukui), @(TKAddOnSourceWago), @(TKAddOnSourceCurseForge), @(TKAddOnSourceGitHub)])
        if ([self resultsForSource:source.integerValue].count) [sources addObject:source];
    return sources;
}

- (NSArray<NSDictionary *> *)recommended {
    return @[
        @{@"name": @"Spoken (English)", @"detail": @"Voice-over · core + English packs", @"spoken": @YES},
        @{@"name": @"RestedXP Guides", @"detail": @"Leveling guide · GitHub", @"repo": @"RestedXP/RXPGuides"},
        @{@"name": @"Bagnon", @"detail": @"Bags and inventory · CurseForge", @"query": @"Bagnon"},
        @{@"name": @"Leatrix Plus", @"detail": @"Quality of life · CurseForge", @"query": @"Leatrix Plus"},
        @{@"name": @"Leatrix Maps", @"detail": @"Map improvements · CurseForge", @"query": @"Leatrix Maps"},
        @{@"name": @"TomTom", @"detail": @"Waypoints · CurseForge", @"query": @"TomTom"},
        @{@"name": @"Dialogue UI", @"detail": @"Quest dialogue · CurseForge", @"query": @"Dialogue UI"}
    ];
}

- (NSArray<TKInstalledAddOn *> *)enabledAddOns {
    return [self.installed filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(TKInstalledAddOn *addon, NSDictionary *bindings) {
        (void)bindings; return addon.enabled;
    }]];
}

- (NSArray<TKInstalledAddOn *> *)disabledAddOns {
    return [self.installed filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(TKInstalledAddOn *addon, NSDictionary *bindings) {
        (void)bindings; return !addon.enabled;
    }]];
}

#pragma mark - Table

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    (void)tableView; (void)section;
    if (![view isKindOfClass:UITableViewHeaderFooterView.class]) return;
    UITableViewHeaderFooterView *header=(UITableViewHeaderFooterView *)view;
    header.textLabel.font=[UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    header.textLabel.textColor=TKLauncherTheme.muted;
    header.textLabel.text=header.textLabel.text.uppercaseString;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (self.mode == TKAddOnsModeDiscover) return (self.query.length ? 0 : 1) + self.discoverSources.count;
    if (self.mode == TKAddOnsModeInstalled) return 2;
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.mode == TKAddOnsModeDiscover) {
        if (!self.query.length) {
            if (section == 0) return self.recommended.count;
            section--;
        }
        NSArray<NSNumber *> *sources = self.discoverSources;
        if (section < 0 || section >= (NSInteger)sources.count) return 0;
        return [self resultsForSource:sources[section].integerValue].count;
    }
    if (self.mode == TKAddOnsModeInstalled) return section == 0 ? self.enabledAddOns.count : self.disabledAddOns.count;
    if (self.mode == TKAddOnsModeWorkarounds) return self.workarounds.count;
    return 1 + self.backups.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (self.mode == TKAddOnsModeDiscover) {
        if (!self.query.length) {
            if (section == 0) return @"Recommended";
            section--;
            if (section < 0) return nil;
        }
        NSArray<NSNumber *> *sources = self.discoverSources;
        if (section < (NSInteger)sources.count) return TKAddOnSourceName(sources[section].integerValue);
        return nil;
    }
    if (self.mode == TKAddOnsModeInstalled) return section == 0 ? @"Installed" : @"Disabled";
    if (self.mode == TKAddOnsModeWorkarounds) return @"Workarounds";
    return @"Backups";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:TKCellIdentifier];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:TKCellIdentifier];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.accessoryView = nil;
    cell.detailTextLabel.numberOfLines = 2;
    cell.backgroundColor = [TKLauncherTheme.surface colorWithAlphaComponent:0.86];
    cell.textLabel.textColor = TKLauncherTheme.text;
    cell.detailTextLabel.textColor = TKLauncherTheme.muted;
    NSString *symbol = self.mode == TKAddOnsModeDiscover ? @"arrow.down.circle" :
        (self.mode == TKAddOnsModeInstalled ? @"checkmark.circle" :
        (self.mode == TKAddOnsModeWorkarounds ? @"wrench.and.screwdriver" : @"clock.arrow.circlepath"));
    cell.imageView.image = [UIImage systemImageNamed:symbol withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightMedium]];
    cell.imageView.tintColor = TKLauncherTheme.gold;
    if (self.mode == TKAddOnsModeDiscover) {
        NSInteger section = indexPath.section;
        if (!self.query.length) {
            if (section == 0) {
                NSDictionary *item = self.recommended[indexPath.row];
                cell.textLabel.text = item[@"name"];
                cell.detailTextLabel.text = item[@"detail"];
                cell.accessoryType = (item[@"repo"] || item[@"spoken"]) ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
                return cell;
            }
            section--;
        }
        NSArray<NSNumber *> *sources = self.discoverSources;
        if (section < 0 || section >= (NSInteger)sources.count) return cell;
        NSArray<TKAddOnSearchResult *> *results = [self resultsForSource:sources[section].integerValue];
        if (indexPath.row >= (NSInteger)results.count) return cell;
        TKAddOnSearchResult *result = results[indexPath.row];
        cell.textLabel.text = result.name;
        NSMutableArray *bits = [NSMutableArray array];
        if (result.author.length) [bits addObject:result.author];
        if (result.version.length) [bits addObject:result.version];
        if (!result.compatible) [bits addObject:[NSString stringWithFormat:@"Not for game %@", self.manager.gameVersion ?: @"version"]];
        NSString *summary = result.summary.length > 160 ? [result.summary substringToIndex:160] : result.summary;
        cell.detailTextLabel.text = bits.count ? [NSString stringWithFormat:@"%@\n%@", [bits componentsJoinedByString:@" · "], summary ?: @""] : summary;
        if (!result.compatible) cell.accessoryType = UITableViewCellAccessoryNone;
        return cell;
    }
    if (self.mode == TKAddOnsModeInstalled) {
        NSArray<TKInstalledAddOn *> *addons = indexPath.section == 0 ? self.enabledAddOns : self.disabledAddOns;
        if (indexPath.row >= (NSInteger)addons.count) return cell;
        TKInstalledAddOn *addon = addons[indexPath.row];
        cell.textLabel.text = addon.name;
        NSMutableArray *bits = [NSMutableArray array];
        if (addon.version.length) [bits addObject:addon.version];
        [bits addObject:TKAddOnSourceName(addon.source)];
        if (!addon.enabled) [bits addObject:@"Disabled"];
        if (addon.update) [bits addObject:[NSString stringWithFormat:@"Update %@", addon.update.version.length ? addon.update.version : @"available"]];
        if (!addon.compatible) [bits addObject:[NSString stringWithFormat:@"Incompatible with game %@ (Interface %@)", self.manager.gameVersion ?: @"version", addon.interfaceVersion.length ? addon.interfaceVersion : @"?"]];
        cell.detailTextLabel.text = [bits componentsJoinedByString:@" · "];
        cell.accessoryType = addon.update ? UITableViewCellAccessoryDetailDisclosureButton : UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }
    if (self.mode == TKAddOnsModeWorkarounds) {
        if (indexPath.row >= (NSInteger)self.workarounds.count) return cell;
        TKAddOnWorkaround *workaround = self.workarounds[indexPath.row];
        cell.textLabel.text = workaround.name;
        NSString *target = workaround.targetFolders.firstObject ?: @"Add-on";
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@", target, [self workaroundStatusText:workaround]];
        cell.accessoryType = UITableViewCellAccessoryNone;
        UISwitch *toggle = [UISwitch new];
        toggle.on = workaround.enabled;
        toggle.tag = indexPath.row;
        [toggle addTarget:self action:@selector(workaroundToggled:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
        return cell;
    }
    if (indexPath.row == 0) {
        cell.textLabel.text = @"Create backup";
        cell.detailTextLabel.text = @"Save the game's WTF settings, including addon saved variables";
        cell.accessoryType = UITableViewCellAccessoryNone;
        return cell;
    }
    TKAddOnBackup *backup = self.backups[indexPath.row - 1];
    static NSDateFormatter *formatter;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ formatter = [NSDateFormatter new]; formatter.dateStyle = NSDateFormatterMediumStyle; formatter.timeStyle = NSDateFormatterShortStyle; });
    cell.textLabel.text = [formatter stringFromDate:backup.date];
    cell.detailTextLabel.text = [NSByteCountFormatter stringFromByteCount:(long long)backup.size countStyle:NSByteCountFormatterCountStyleFile];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.mode == TKAddOnsModeDiscover) {
        NSInteger section = indexPath.section;
        if (!self.query.length) {
            if (section == 0) {
                NSDictionary *item = self.recommended[indexPath.row];
                if ([item[@"spoken"] boolValue]) { [self showSpokenPackages]; return; }
                if (item[@"repo"]) {
                    TKAddOnSearchResult *result = [self.sources githubRepositoryResult:item[@"repo"] name:item[@"name"]];
                    result.summary = item[@"detail"];
                    [self showResult:result];
                } else {
                    NSString *query = item[@"query"];
                    self.searchController.active = YES;
                    self.searchController.searchBar.text = query;
                    [self runSearch:query];
                }
                return;
            }
            section--;
        }
        NSArray<NSNumber *> *sources = self.discoverSources;
        if (section < 0 || section >= (NSInteger)sources.count) return;
        NSArray<TKAddOnSearchResult *> *results = [self resultsForSource:sources[section].integerValue];
        if (indexPath.row < (NSInteger)results.count) [self showResult:results[indexPath.row]];
        return;
    }
    if (self.mode == TKAddOnsModeInstalled) {
        NSArray<TKInstalledAddOn *> *addons = indexPath.section == 0 ? self.enabledAddOns : self.disabledAddOns;
        if (indexPath.row < (NSInteger)addons.count) [self addonActions:addons[indexPath.row] fromCell:[tableView cellForRowAtIndexPath:indexPath]];
        return;
    }
    if (self.mode == TKAddOnsModeWorkarounds) {
        if (indexPath.row < (NSInteger)self.workarounds.count)
            [self workaroundActions:self.workarounds[indexPath.row]];
        return;
    }
    if (indexPath.row == 0) [self createBackup];
    else [self backupActions:self.backups[indexPath.row - 1] fromCell:[tableView cellForRowAtIndexPath:indexPath]];
}

- (void)updateFooter {
    NSString *target = self.manager.gameVersion.length ?
        [NSString stringWithFormat:@"%@ %@ · Interface %@", self.manager.productName ?: @"Game", self.manager.gameVersion, self.manager.interfaceVersion ?: @"?"] :
        @"Game version unknown; add-on compatibility is not checked.";
    if (self.mode == TKAddOnsModeDiscover) {
        NSMutableArray *lines = [self.messages mutableCopy];
        if (self.busy) [lines insertObject:@"Searching…" atIndex:0];
        else if (!self.query.length) [lines insertObject:@"Search Tukui, GitHub, CurseForge and Wago, or pick a recommendation. CurseForge needs an API key; Wago looks up exact names and URLs." atIndex:0];
        [lines addObject:target];
        self.table.tableFooterView = [self footerWithLines:lines];
    } else if (self.mode == TKAddOnsModeInstalled) {
        NSMutableArray *lines = [self.messages mutableCopy];
        if (self.busy) [lines insertObject:@"Reading add-ons…" atIndex:0];
        else [lines addObject:@"Settings in WTF are kept when an add-on is disabled or removed."];
        [lines addObject:target];
        self.table.tableFooterView = [self footerWithLines:lines];
    } else if (self.mode == TKAddOnsModeWorkarounds) {
        NSMutableArray *lines = [self.messages mutableCopy];
        if (self.busy) [lines insertObject:@"Reading workarounds…" atIndex:0];
        else [lines addObject:@"Workarounds patch installed add-ons for this game client. They are reapplied after an add-on update and can be turned off at any time."];
        [lines addObject:target];
        self.table.tableFooterView = [self footerWithLines:lines];
    } else {
        NSMutableArray *lines = [NSMutableArray array];
        if (self.busy) [lines addObject:@"Working…"];
        [lines addObject:@"Backups contain the game's WTF folder: addon saved variables, per-character settings and Config.wtf. Add-on files are not included."];
        [lines addObject:target];
        self.table.tableFooterView = [self footerWithLines:lines];
    }
}

- (UIView *)footerWithLines:(NSArray<NSString *> *)lines {
    UILabel *label = [UILabel new];
    label.text = [lines componentsJoinedByString:@"\n"];
    label.numberOfLines = 0;
    label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    label.textColor = UIColor.secondaryLabelColor;
    label.textAlignment = NSTextAlignmentCenter;
    CGFloat width = MAX(1, self.table.bounds.size.width - 48);
    CGSize size = [label sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];
    label.frame = CGRectMake(0, 0, width, size.height + 28);
    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, size.height + 28)];
    label.frame = CGRectMake(0, 14, width, size.height);
    [footer addSubview:label];
    return footer;
}

- (NSString *)workaroundStatusText:(TKAddOnWorkaround *)workaround {
    if (!workaround.enabled) return @"Off";
    switch (workaround.state) {
        case TKAddOnWorkaroundStateNotInstalled: return @"Add-on not installed";
        case TKAddOnWorkaroundStateDisabled: return @"Enabled · not applied";
        case TKAddOnWorkaroundStateApplied: return @"Applied";
        case TKAddOnWorkaroundStatePartial: return @"Partially applied";
        case TKAddOnWorkaroundStateIncompatible: return @"Not compatible";
    }
    return @"Unknown";
}

- (void)setWorkaround:(TKAddOnWorkaround *)workaround enabled:(BOOL)enabled {
    self.busy = YES;
    [self showLoading:enabled ? @"Applying workaround…" : @"Removing workaround…"];
    __weak TKAddOnsViewController *weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSError *error = nil;
        BOOL ok = [weakSelf.manager setWorkaround:workaround enabled:enabled error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            TKAddOnsViewController *strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf.busy = NO;
            [strongSelf hideLoading];
            if (!ok) {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Workaround failed" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [strongSelf presentViewController:alert animated:YES completion:nil];
            }
            [strongSelf loadWorkarounds];
        });
    });
}

- (void)workaroundToggled:(UISwitch *)toggle {
    if (toggle.tag < 0 || toggle.tag >= (NSInteger)self.workarounds.count) return;
    TKAddOnWorkaround *workaround = self.workarounds[toggle.tag];
    toggle.enabled = NO;
    [self setWorkaround:workaround enabled:toggle.on];
}

- (void)workaroundActions:(TKAddOnWorkaround *)workaround {
    NSString *detail = workaround.stateDetail.length ? [NSString stringWithFormat:@"\n\n%@", workaround.stateDetail] : @"";
    NSString *message = [NSString stringWithFormat:@"%@\n\nTarget: %@\nStatus: %@%@", workaround.summary,
        workaround.targetFolders.firstObject ?: @"Add-on", [self workaroundStatusText:workaround], detail];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:workaround.name message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:workaround.enabled ? @"Disable" : @"Enable" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action; [self setWorkaround:workaround enabled:!workaround.enabled];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reapply" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action; [self setWorkaround:workaround enabled:YES];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Search

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    if (self.mode != TKAddOnsModeDiscover) return;
    NSString *query = [searchController.searchBar.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSUInteger generation = self.searchGeneration + 1;
    self.searchGeneration = generation;
    __weak TKAddOnsViewController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        TKAddOnsViewController *strongSelf = weakSelf;
        if (!strongSelf || strongSelf.searchGeneration != generation || strongSelf.mode != TKAddOnsModeDiscover) return;
        [strongSelf runSearch:query];
    });
}

#pragma mark - Result detail and installation

- (void)showResult:(TKAddOnSearchResult *)result {
    if ([result.payload[@"spokenPackage"] boolValue]) {
        UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Spoken (English)"
            message:@"Spoken is one core add-on with Quests, Places and Readables. The English voice packs are separate and large; choose what to install."
            preferredStyle:UIAlertControllerStyleAlert];
        __weak TKAddOnsViewController *weakSelf = self;
        [sheet addAction:[UIAlertAction actionWithTitle:@"Choose packs" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            (void)action; [weakSelf showSpokenPackages];
        }]];
        if (result.pageURL.length) [sheet addAction:[UIAlertAction actionWithTitle:@"Open source page" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            (void)action; [weakSelf openURL:result.pageURL];
        }]];
        [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:sheet animated:YES completion:nil];
        return;
    }
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    if (result.summary.length) [lines addObject:result.summary];
    NSMutableArray *bits = [NSMutableArray arrayWithObject:TKAddOnSourceName(result.source)];
    if (result.author.length) [bits addObject:result.author];
    if (result.version.length) [bits addObject:result.version];
    [lines addObject:[bits componentsJoinedByString:@" · "]];
    if (!result.compatible) {
        [lines addObject:result.compatibilityNote ?: [NSString stringWithFormat:@"This package is not listed for game %@.", self.manager.gameVersion ?: @"version"]];
    }
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:result.name message:[lines componentsJoinedByString:@"\n\n"] preferredStyle:UIAlertControllerStyleAlert];
    __weak TKAddOnsViewController *weakSelf = self;
    if (result.compatible) [sheet addAction:[UIAlertAction actionWithTitle:@"Install" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action; [weakSelf installResult:result];
    }]];
    if (result.pageURL.length) [sheet addAction:[UIAlertAction actionWithTitle:@"Open source page" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action; [weakSelf openURL:result.pageURL];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)showSpokenPackages {
    TKSpokenPackagesViewController *controller = [[TKSpokenPackagesViewController alloc] initWithSources:self.sources];
    __weak TKAddOnsViewController *weakSelf = self;
    controller.onInstall = ^(NSArray<TKAddOnComponent *> *components) {
        [weakSelf installSpokenComponents:components];
    };
    [self.navigationController pushViewController:controller animated:YES];
}

- (void)installSpokenComponents:(NSArray<TKAddOnComponent *> *)components {
    if (self.busy || !components.count) return;
    [self beginProgress:@"Installing Spoken" message:@"Preparing packages…"];
    __weak TKAddOnsViewController *weakSelf = self;
    [self.sources downloadSpokenComponents:components progress:^(NSString *message) {
        dispatch_async(dispatch_get_main_queue(), ^{
            TKAddOnsViewController *strongSelf = weakSelf;
            if (strongSelf.progressAlert) strongSelf.progressAlert.message = message;
        });
    } completion:^(TKAddOnDownload *download, NSError *error) {
        // The Spoken download chain runs on its own queue. Start unpacking
        // immediately on a background queue; a busy main runloop must not
        // stall a multi-gigabyte install again.
        if (!download) {
            dispatch_async(dispatch_get_main_queue(), ^{
                TKAddOnsViewController *strongSelf = weakSelf;
                [strongSelf endProgressWithError:error message:nil];
            });
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            TKAddOnsViewController *strongSelf = weakSelf;
            if (strongSelf.progressAlert) strongSelf.progressAlert.message = @"Installing Spoken and the selected voice packs…";
        });
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            TKAddOnsViewController *strongSelf = weakSelf;
            if (!strongSelf) return;
            NSError *installError = nil;
            [strongSelf installTree:download error:&installError progress:^(NSString *message) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (strongSelf.progressAlert) strongSelf.progressAlert.message = message;
                });
            }];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (installError) [strongSelf endProgressWithError:installError message:nil];
                else [strongSelf endProgressWithError:nil message:@"Spoken and the selected voice packs are installed. Enable the two Spoken workarounds if the settings or sound look wrong on Forever."];
                [strongSelf loadInstalled];
            });
        });
    }];
}

- (void)installResult:(TKAddOnSearchResult *)result {
    if ([result.payload[@"spokenPackage"] boolValue]) { [self showSpokenPackages]; return; }
    if (self.busy) return;
    if (!result.compatible) {
        [self alertTitle:@"Not for this game version" message:result.compatibilityNote ?: [NSString stringWithFormat:@"This package is not listed for game %@.", self.manager.gameVersion ?: @"version"]];
        return;
    }
    [self beginProgress:[NSString stringWithFormat:@"Installing %@", result.name] message:@"Downloading package… Large add-ons can take a minute."];
    __weak TKAddOnsViewController *weakSelf = self;
    [self.sources resolveResult:result completion:^(TKAddOnDownload *download, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
        TKAddOnsViewController *strongSelf = weakSelf;
        if (!strongSelf) return;
        if (!download) { [strongSelf endProgressWithError:error message:nil]; return; }
        strongSelf.progressAlert.message = @"Downloading…";
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            NSError *installError = nil;
            [strongSelf installTree:download error:&installError progress:^(NSString *message) {
                dispatch_async(dispatch_get_main_queue(), ^{ if (strongSelf.progressAlert) strongSelf.progressAlert.message = message; });
            }];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (installError) [strongSelf endProgressWithError:installError message:nil];
                else [strongSelf endProgressWithError:nil message:[NSString stringWithFormat:@"%@ is installed. It appears in WoW's AddOns menu on the next launch.", download.name]];
                [strongSelf loadInstalled];
            });
        });
        });
    }];
}

- (BOOL)installTree:(TKAddOnDownload *)download error:(NSError **)error progress:(void (^)(NSString *))progress {
    for (TKAddOnDownload *dependency in download.dependencies) {
        if (![self installTree:dependency error:error progress:progress]) return NO;
    }
    progress([NSString stringWithFormat:@"Installing %@…", download.name]);
    BOOL ok = [self.manager installArchive:download.archiveURL source:download.source identifier:download.identifier name:download.name version:download.version pageURL:download.pageURL error:error];
    [NSFileManager.defaultManager removeItemAtURL:download.archiveURL error:NULL];
    return ok;
}

- (void)installImportedArchive:(NSURL *)url {
    NSString *name = [url.lastPathComponent stringByDeletingPathExtension];
    [self beginProgress:[NSString stringWithFormat:@"Importing %@", name] message:@"Reading package…"];
    TKAddOnsManager *manager = self.manager;
    __weak TKAddOnsViewController *weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSError *error = nil;
        BOOL ok = [manager installArchive:url source:TKAddOnSourceImport identifier:@"" name:@"" version:@"" pageURL:nil error:&error];
        [NSFileManager.defaultManager removeItemAtURL:url error:NULL];
        dispatch_async(dispatch_get_main_queue(), ^{
            TKAddOnsViewController *strongSelf = weakSelf;
            if (!strongSelf) return;
            if (ok) [strongSelf endProgressWithError:nil message:@"The package is installed. It appears in WoW's AddOns menu on the next launch."];
            else [strongSelf endProgressWithError:error message:nil];
            [strongSelf loadInstalled];
        });
    });
}

#pragma mark - Installed actions

- (void)addonActions:(TKInstalledAddOn *)addon fromCell:(UITableViewCell *)cell {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:addon.name message:[NSString stringWithFormat:@"%@ · %@", addon.version.length ? addon.version : @"unknown version", TKAddOnSourceName(addon.source)] preferredStyle:UIAlertControllerStyleActionSheet];
    __weak TKAddOnsViewController *weakSelf = self;
    if (addon.update) [sheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Update to %@", addon.update.version.length ? addon.update.version : @"latest"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action; [weakSelf installResult:addon.update];
    }]];
    if (addon.source != TKAddOnSourceLocal && addon.source != TKAddOnSourceImport) [sheet addAction:[UIAlertAction actionWithTitle:@"Check for update" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action; [weakSelf checkUpdateForAddon:addon];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:addon.enabled ? @"Disable" : @"Enable" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action; [weakSelf setAddon:addon enabled:!addon.enabled];
    }]];
    if (addon.pageURL.length) [sheet addAction:[UIAlertAction actionWithTitle:@"Open source page" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action; [weakSelf openURL:addon.pageURL];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Remove" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        (void)action; [weakSelf confirmRemoveAddon:addon];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentSheet:sheet fromCell:cell];
}

- (void)checkUpdateForAddon:(TKInstalledAddOn *)addon {
    if (self.busy) return;
    self.busy = YES; [self updateFooter];
    __weak TKAddOnsViewController *weakSelf = self;
    [self.sources latestForInstalled:addon completion:^(TKAddOnSearchResult *result, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
        TKAddOnsViewController *strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.busy = NO;
        if (!result) {
            [strongSelf alertTitle:@"Update check" message:error.localizedDescription ?: @"No update information is available."];
        } else if (result.version.length && ![result.version isEqualToString:addon.version]) {
            addon.update = result;
            [strongSelf.table reloadData];
            [strongSelf alertTitle:@"Update available" message:[NSString stringWithFormat:@"%@ %@ is available.", addon.name, result.version]];
        } else {
            [strongSelf alertTitle:@"Up to date" message:[NSString stringWithFormat:@"%@ is up to date.", addon.name]];
        }
        [strongSelf updateFooter];
        });
    }];
}

- (void)checkForUpdates {
    if (self.busy) return;
    NSArray<TKInstalledAddOn *> *addons = [self.installed filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(TKInstalledAddOn *addon, NSDictionary *bindings) {
        (void)bindings; return addon.source != TKAddOnSourceLocal && addon.source != TKAddOnSourceImport;
    }]];
    if (!addons.count) { [self alertTitle:@"Check for updates" message:@"There are no add-ons with an online source."]; return; }
    self.busy = YES; [self updateFooter];
    dispatch_group_t group = dispatch_group_create();
    __block NSUInteger found = 0;
    __weak TKAddOnsViewController *weakSelf = self;
    for (TKInstalledAddOn *addon in addons) {
        dispatch_group_enter(group);
        [self.sources latestForInstalled:addon completion:^(TKAddOnSearchResult *result, NSError *error) {
            (void)error;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (result.version.length && ![result.version isEqualToString:addon.version]) { addon.update = result; found++; }
                dispatch_group_leave(group);
            });
        }];
    }
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        TKAddOnsViewController *strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.busy = NO;
        [strongSelf.table reloadData];
        [strongSelf updateFooter];
        [strongSelf alertTitle:@"Check for updates" message:found ? [NSString stringWithFormat:@"%lu update(s) available.", (unsigned long)found] : @"All add-ons are up to date."];
    });
}

- (void)setAddon:(TKInstalledAddOn *)addon enabled:(BOOL)enabled {
    [self beginProgress:enabled ? @"Enabling add-on" : @"Disabling add-on" message:addon.name];
    TKAddOnsManager *manager = self.manager;
    __weak TKAddOnsViewController *weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSError *error = nil;
        BOOL ok = [manager setEnabled:enabled forAddOn:addon error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            TKAddOnsViewController *strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf endProgressWithError:ok ? nil : error message:ok ? (enabled ? @"Enabled." : @"Disabled. Its settings are kept.") : nil];
            [strongSelf loadInstalled];
        });
    });
}

- (void)confirmRemoveAddon:(TKInstalledAddOn *)addon {
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Remove %@?", addon.name] message:@"The add-on files are removed. Its WTF saved variables are kept." preferredStyle:UIAlertControllerStyleAlert];
    __weak TKAddOnsViewController *weakSelf = self;
    [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Remove" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        (void)action; [weakSelf removeAddon:addon];
    }]];
    [self presentViewController:confirm animated:YES completion:nil];
}

- (void)removeAddon:(TKInstalledAddOn *)addon {
    [self beginProgress:@"Removing add-on" message:addon.name];
    TKAddOnsManager *manager = self.manager;
    __weak TKAddOnsViewController *weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSError *error = nil;
        BOOL ok = [manager removeAddOn:addon error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            TKAddOnsViewController *strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf endProgressWithError:ok ? nil : error message:ok ? @"Removed. Its settings are kept." : nil];
            [strongSelf loadInstalled];
        });
    });
}

#pragma mark - Backups

- (void)createBackup {
    [self beginProgress:@"Backing up settings" message:@"Reading WTF…"];
    TKAddOnsManager *manager = self.manager;
    __weak TKAddOnsViewController *weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSError *error = nil;
        TKAddOnBackup *backup = [manager createBackup:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            TKAddOnsViewController *strongSelf = weakSelf;
            if (!strongSelf) return;
            if (backup) [strongSelf endProgressWithError:nil message:[NSString stringWithFormat:@"Backup created: %@", backup.url.lastPathComponent]];
            else [strongSelf endProgressWithError:error message:nil];
            [strongSelf loadBackups];
        });
    });
}

- (void)backupActions:(TKAddOnBackup *)backup fromCell:(UITableViewCell *)cell {
    static NSDateFormatter *formatter;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ formatter = [NSDateFormatter new]; formatter.dateStyle = NSDateFormatterMediumStyle; formatter.timeStyle = NSDateFormatterShortStyle; });
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:[formatter stringFromDate:backup.date] message:@"Restoring replaces the game's WTF settings. Add-on files are untouched." preferredStyle:UIAlertControllerStyleActionSheet];
    __weak TKAddOnsViewController *weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:@"Restore" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        (void)action; [weakSelf confirmRestoreBackup:backup];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Share" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action; [weakSelf shareBackup:backup fromCell:cell];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        (void)action; [weakSelf confirmDeleteBackup:backup];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentSheet:sheet fromCell:cell];
}

- (void)confirmRestoreBackup:(TKAddOnBackup *)backup {
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Restore this backup?" message:@"This replaces WTF/Account saved variables and Config.wtf. Close the game first. A safety backup of the current settings is made automatically." preferredStyle:UIAlertControllerStyleAlert];
    __weak TKAddOnsViewController *weakSelf = self;
    [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Restore" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        (void)action; [weakSelf restoreBackup:backup];
    }]];
    [self presentViewController:confirm animated:YES completion:nil];
}

- (void)restoreBackup:(TKAddOnBackup *)backup {
    [self beginProgress:@"Restoring settings" message:@"Unpacking WTF…"];
    TKAddOnsManager *manager = self.manager;
    __weak TKAddOnsViewController *weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSError *error = nil;
        BOOL ok = [manager restoreBackup:backup error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            TKAddOnsViewController *strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf endProgressWithError:ok ? nil : error message:ok ? @"Settings restored. Start the game to apply them." : nil];
            [strongSelf loadBackups];
        });
    });
}

- (void)confirmDeleteBackup:(TKAddOnBackup *)backup {
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Delete this backup?" message:@"The ZIP file is removed from Tolkara. This cannot be undone." preferredStyle:UIAlertControllerStyleAlert];
    __weak TKAddOnsViewController *weakSelf = self;
    [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        (void)action;
        NSError *error = nil;
        if (![weakSelf.manager deleteBackup:backup error:&error]) [weakSelf alertTitle:@"Could not delete" message:error.localizedDescription];
        [weakSelf loadBackups];
    }]];
    [self presentViewController:confirm animated:YES completion:nil];
}

- (void)shareBackup:(TKAddOnBackup *)backup fromCell:(UITableViewCell *)cell {
    UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:@[backup.url] applicationActivities:nil];
    share.popoverPresentationController.sourceView = cell;
    share.popoverPresentationController.sourceRect = cell.bounds;
    [self presentViewController:share animated:YES completion:nil];
}

#pragma mark - Import and provider settings

- (void)importArchive {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeZIP] asCopy:YES];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    (void)controller;
    if (urls.count) [self installImportedArchive:urls.firstObject];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller { (void)controller; }

- (void)addFromWago {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Add from Wago" message:@"Paste a wago.io add-on URL, or its exact name. Wago's own search is web-only: browse wago.io to find the add-on, then paste its URL here or use Import ZIP." preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"https://addons.wago.io/addons/…";
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    __weak TKAddOnsViewController *weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Look up" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action;
        NSString *value = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (!value.length) return;
        weakSelf.mode = TKAddOnsModeDiscover;
        weakSelf.modes.selectedSegmentIndex = 0;
        weakSelf.navigationItem.searchController = weakSelf.searchController;
        weakSelf.searchController.active = YES;
        weakSelf.searchController.searchBar.text = value;
        [weakSelf runSearch:value];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Open wago.io" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action; [weakSelf openURL:@"https://addons.wago.io/"];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)configureCurseForge {
    NSString *current = TKAddOnsSources.curseForgeKey;
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"CurseForge API key" message:@"CurseForge issues API keys to third-party applications after review. Use Get a key for the application instructions. The key is stored in the device Keychain and sent only to CurseForge. Without a key, CurseForge entries open their source page and packages can be imported as ZIPs." preferredStyle:UIAlertControllerStyleAlert];
    [sheet addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = current.length ? @"A key is saved; paste a new one" : @"Paste your API key";
        field.secureTextEntry = YES;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    __weak TKAddOnsViewController *weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:@"Get a key" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action;
        [weakSelf openURL:@"https://support.curseforge.com/support/solutions/articles/9000208346-about-the-curseforge-api-and-how-to-apply-for-a-key"];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action;
        NSString *key = [sheet.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (!key.length) { [weakSelf alertTitle:@"CurseForge API key" message:@"Paste a key or choose Remove."]; return; }
        NSError *error = nil;
        if (![TKAddOnsSources setCurseForgeKey:key error:&error]) [weakSelf alertTitle:@"Could not save the key" message:error.localizedDescription];
        else [weakSelf runSearch:weakSelf.query];
    }]];
    if (current.length) [sheet addAction:[UIAlertAction actionWithTitle:@"Remove key" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        (void)action; [TKAddOnsSources setCurseForgeKey:nil error:NULL]; [weakSelf runSearch:weakSelf.query];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - Progress and alerts

- (void)beginProgress:(NSString *)title message:(NSString *)message {
    if (self.progressAlert) return;
    self.busy = YES;
    [self updateFooter];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [alert.view addSubview:spinner];
    [NSLayoutConstraint activateConstraints:@[
        [spinner.centerXAnchor constraintEqualToAnchor:alert.view.centerXAnchor],
        [spinner.bottomAnchor constraintEqualToAnchor:alert.view.bottomAnchor constant:-20]
    ]];
    [spinner startAnimating];
    self.progressAlert = alert;
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)endProgressWithError:(NSError *)error message:(NSString *)message {
    UIAlertController *alert = self.progressAlert;
    self.progressAlert = nil;
    self.busy = NO;
    [alert dismissViewControllerAnimated:YES completion:^{
        if (error) [self alertTitle:@"Add-ons" message:error.localizedDescription];
        else if (message.length) [self alertTitle:@"Add-ons" message:message];
    }];
}

- (void)alertTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)presentSheet:(UIAlertController *)sheet fromCell:(UITableViewCell *)cell {
    sheet.popoverPresentationController.sourceView = cell;
    sheet.popoverPresentationController.sourceRect = cell.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)openURL:(NSString *)string {
    NSURL *url = [NSURL URLWithString:string];
    if (url) [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
}

@end
