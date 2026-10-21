#import "SettingsViewController.h"
#import "AboutViewController.h"
#import "../UI/LauncherTheme.h"
#import "../UI/TouchControlsViewController.h"
#import "../UI/MenuViewController.h"
#import "../WoW/WoWViewController.h"
#import "../WoW/Installation.h"
#import "../WoW/Manifest.h"
#import "CustomServerConfig.h"
#import "../WoW/CustomServerViewController.h"
#import "DiagnosticsViewController.h"
#import "ExecutionMode.h"

typedef NS_ENUM(NSInteger, TKSettingsSection) {
    TKSettingsSectionGame,
    TKSettingsSectionInstallation,
    TKSettingsSectionStartup,
    TKSettingsSectionDiagnostics,
    TKSettingsSectionAdvanced,
    TKSettingsSectionCount
};

static NSString *const TKSettingsCell = @"settings.cell";

@interface TKSettingsViewController ()
@property(nonatomic) TKWoWViewController *wow;
@end

@implementation TKSettingsViewController

- (instancetype)initWithWoWController:(TKWoWViewController *)wow {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    _wow = wow;
    self.title = @"";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.view.backgroundColor = TKLauncherTheme.background;
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.backgroundView = [TKPageBackgroundView new];
    self.tableView.separatorColor = TKLauncherTheme.hairline;
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:TKSettingsCell];
    self.tableView.sectionHeaderTopPadding = 18;
    TKPageHeaderView *header = [[TKPageHeaderView alloc] initWithTitle:@"Settings"
        subtitle:@"Game, startup, diagnostics and advanced options."];
    header.frame = CGRectMake(0, 0, self.tableView.bounds.size.width, 96);
    self.tableView.tableHeaderView = header;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(stateChanged:)
        name:TKWoWStateDidChangeNotification object:self.wow];
}

- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    UINavigationBarAppearance *appearance=[UINavigationBarAppearance new];
    [appearance configureWithTransparentBackground];
    appearance.shadowColor=UIColor.clearColor;
    self.navigationController.navigationBar.standardAppearance=appearance;
    self.navigationController.navigationBar.scrollEdgeAppearance=appearance;
    self.navigationController.navigationBar.compactAppearance=appearance;
    [self.tableView reloadData];
}

- (void)stateChanged:(NSNotification *)note {
    (void)note;
    if (self.isViewLoaded && self.view.window) [self.tableView reloadData];
}

- (BOOL)isForever { NSString *identifier=self.wow.product[@"id"]; return [identifier isEqualToString:@"wowf"] || [identifier isEqualToString:@"wow_classic_beta"]; }
- (BOOL)locked { return self.wow.isBusy || self.wow.isUpdating || self.wow.sessionUsed; }
- (NSString *)editionName { return self.wow.product[@"name"] ?: @"—"; }
- (NSString *)regionName {
    NSDictionary *names = @{@"eu": @"Europe", @"us": @"Americas", @"kr": @"Korea", @"tw": @"Taiwan"};
    return names[self.wow.region] ?: self.wow.region.uppercaseString ?: @"—";
}
- (NSString *)localeName { return [self.wow.locale isEqualToString:@"esES"] ? @"Spanish" : @"English"; }
- (NSString *)installedVersion {
    if (self.wow.installation.state == TKWoWInstallationReady && self.wow.installation.installedVersion.length)
        return self.wow.installation.installedVersion;
    if (self.wow.installation.state == TKWoWInstallationOutdated && self.wow.installation.installedVersion.length)
        return [self.wow.installation.installedVersion stringByAppendingString:@" (update available)"];
    return @"Not installed";
}
- (NSString *)customServerName {
    TKCustomServerConfig *config = [TKCustomServerConfig current];
    if (![self isForever]) return @"Forever only";
    return config.isUsable ? [NSString stringWithFormat:@"On · %@", config.portal] : @"Off";
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    (void)section;
    if (![view isKindOfClass:UITableViewHeaderFooterView.class]) return;
    UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
    header.textLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    header.textLabel.textColor = TKLauncherTheme.muted;
    header.textLabel.text = header.textLabel.text.uppercaseString;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { (void)tableView; return TKSettingsSectionCount; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    switch (section) {
        case TKSettingsSectionGame: return 4;
        case TKSettingsSectionInstallation: return 5;
        case TKSettingsSectionStartup: return 3;
        case TKSettingsSectionDiagnostics: return 2;
        default: return 2;
    }
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView;
    switch (section) {
        case TKSettingsSectionGame: return @"Game";
        case TKSettingsSectionInstallation: return @"Installation";
        case TKSettingsSectionStartup: return @"Startup";
        case TKSettingsSectionDiagnostics: return @"Diagnostics";
        default: return @"Advanced";
    }
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;
    switch (section) {
        case TKSettingsSectionGame: return @"The edition changes the game and the update plan. Add-ons are kept per edition.";
        case TKSettingsSectionInstallation: return @"Updates install while Tolkara is open. Settings and add-ons are preserved. Verify and repair checks every file; removal deletes downloaded game data only.";
        case TKSettingsSectionStartup: return @"Execution mode and touch controls apply to the next game start. The custom server is only used by the Forever beta.";
        case TKSettingsSectionDiagnostics: return @"Diagnostics runs only Tolkara's own checks. The native log is the guest runtime's most recent output.";
        default: return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:TKSettingsCell forIndexPath:indexPath];
    UIListContentConfiguration *content = [UIListContentConfiguration valueCellConfiguration];
    content.textProperties.font = TKLauncherTheme.body;
    content.textProperties.color = TKLauncherTheme.text;
    content.secondaryTextProperties.font = TKLauncherTheme.caption;
    content.secondaryTextProperties.color = TKLauncherTheme.muted;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.backgroundColor = [TKLauncherTheme.surface colorWithAlphaComponent:0.86];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    BOOL enabled = YES;
    BOOL goldValue = NO;

    if (indexPath.section == TKSettingsSectionGame) {
        if (indexPath.row == 0) { content.text = @"Edition"; content.secondaryText = self.editionName; goldValue = YES; }
        else if (indexPath.row == 1) { content.text = @"Download Region"; content.secondaryText = self.regionName; goldValue = YES; }
        else if (indexPath.row == 2) { content.text = @"Download Language"; content.secondaryText = self.localeName; goldValue = YES; }
        else { content.text = @"Add-ons"; content.secondaryText = @"Browse installed and available"; }
        enabled = indexPath.row == 3 ? !self.locked : !self.wow.isBusy;
    } else if (indexPath.section == TKSettingsSectionInstallation) {
        if (indexPath.row == 0) { content.text = @"Installed Version"; content.secondaryText = self.installedVersion; cell.accessoryType = UITableViewCellAccessoryNone; enabled = NO; }
        else if (indexPath.row == 1) { content.text = @"Check for Updates"; enabled = !self.locked; }
        else if (indexPath.row == 2) { content.text = @"Verify and Repair Files"; enabled = !self.locked && self.wow.installation.app != nil; }
        else if (indexPath.row == 3) { content.text = @"Remove This Edition"; content.textProperties.color = TKLauncherTheme.danger; enabled = !self.locked && [self.wow hasDownloadedFilesForProduct:self.wow.product]; }
        else { content.text = @"Remove All Game Data"; content.textProperties.color = TKLauncherTheme.danger; enabled = !self.locked && [self.wow hasDownloadedData]; }
    } else if (indexPath.section == TKSettingsSectionStartup) {
        if (indexPath.row == 0) { content.text = @"Execution Mode"; content.secondaryText = TKExecutionModeName(self.wow.executionMode) ?: @"Not chosen"; enabled = !self.wow.isBusy; goldValue = YES; }
        else if (indexPath.row == 1) { content.text = @"Touch Controls"; content.secondaryText = @"On-screen controls and gamepad"; enabled = !self.wow.isBusy; }
        else { content.text = @"Custom Server"; content.secondaryText = self.customServerName; enabled = [self isForever] && !self.locked; goldValue = YES; }
    } else if (indexPath.section == TKSettingsSectionDiagnostics) {
        if (indexPath.row == 0) { content.text = @"Diagnostics and Logs"; content.secondaryText = @"Checks, reports and shader tools"; enabled = !self.wow.isBusy; }
        else { content.text = @"Native Runtime Log"; content.secondaryText = @"Most recent game session"; enabled = !self.wow.isBusy; }
    } else {
        if (indexPath.row == 0) { content.text = @"App Library"; content.secondaryText = @"Imported apps and development runs"; }
        else { content.text = @"About and Open-Source Licenses"; }
    }
    [self configureIcon:content indexPath:indexPath enabled:enabled];
    if (goldValue && enabled) content.secondaryTextProperties.color = TKLauncherTheme.gold;
    if (!enabled) {
        content.textProperties.color = TKLauncherTheme.muted;
        content.secondaryTextProperties.color = TKLauncherTheme.muted;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    cell.contentConfiguration = content;
    return cell;
}

- (void)configureIcon:(UIListContentConfiguration *)content indexPath:(NSIndexPath *)indexPath enabled:(BOOL)enabled {
    NSString *symbol = nil;
    UIColor *tint = TKLauncherTheme.gold;
    if (indexPath.section == TKSettingsSectionGame) {
        symbol = @[@"gamecontroller", @"globe", @"character.bubble", @"puzzlepiece.extension"][indexPath.row];
    } else if (indexPath.section == TKSettingsSectionInstallation) {
        symbol = @[@"shippingbox", @"arrow.clockwise", @"checkmark.shield", @"trash", @"trash.slash"][indexPath.row];
        if (indexPath.row >= 3) tint = TKLauncherTheme.danger;
    } else if (indexPath.section == TKSettingsSectionStartup) {
        symbol = @[@"bolt", @"hand.tap", @"network"][indexPath.row];
    } else if (indexPath.section == TKSettingsSectionDiagnostics) {
        symbol = indexPath.row == 0 ? @"stethoscope" : @"doc.text.magnifyingglass";
    } else {
        symbol = indexPath.row == 0 ? @"square.grid.2x2" : @"info.circle";
    }
    content.image = symbol ? [UIImage systemImageNamed:symbol] : nil;
    content.imageProperties.tintColor = enabled ? tint : TKLauncherTheme.muted;
    content.imageProperties.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightMedium];
    content.imageToTextPadding = 12;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    BOOL enabled = cell.selectionStyle != UITableViewCellSelectionStyleNone;
    if (!enabled) return;
    if (indexPath.section == TKSettingsSectionGame) {
        if (indexPath.row == 0) [self chooseEdition:cell];
        else if (indexPath.row == 1) [self chooseRegion:cell];
        else if (indexPath.row == 2) [self chooseLanguage:cell];
        else if (self.showAddOns) self.showAddOns();
    } else if (indexPath.section == TKSettingsSectionInstallation) {
        if (indexPath.row == 1) { [self.wow checkForUpdatesNow]; if (self.showPlay) self.showPlay(); }
        else if (indexPath.row == 2) [self confirm:@"Verify and repair?" message:@"Tolkara checks every installed file and downloads originals where needed. Settings and add-ons are kept." action:@"Verify" handler:^{ [self.wow repairInstallation]; if (self.showPlay) self.showPlay(); }];
        else if (indexPath.row == 3) [self confirm:[NSString stringWithFormat:@"Remove %@ files?", self.editionName] message:@"This deletes this edition's downloaded game files, including its in-game settings. Other editions are not touched." action:@"Remove" handler:^{ [self.wow performRemovalOfProduct:self.wow.product]; if (self.showPlay) self.showPlay(); }];
        else if (indexPath.row == 4) [self confirm:@"Remove all downloaded game data?" message:@"Deletes every edition's files, the shared data cache and staged downloads. The app itself is not touched." action:@"Remove All" handler:^{ [self.wow performRemoveAllDownloadedData]; if (self.showPlay) self.showPlay(); }];
    } else if (indexPath.section == TKSettingsSectionStartup) {
        if (indexPath.row == 0) { if (self.showExecutionMode) self.showExecutionMode(); }
        else if (indexPath.row == 1) [self.navigationController pushViewController:[TKTouchControlsViewController new] animated:YES];
        else {
            TKCustomServerViewController *controller = [[TKCustomServerViewController alloc] initWithGameDirectory:[self.wow selectedGameDirectory]];
            __weak TKSettingsViewController *weakSelf = self;
            controller.onSave = ^{ [weakSelf.wow refresh]; };
            [self.navigationController pushViewController:controller animated:YES];
        }
    } else if (indexPath.section == TKSettingsSectionDiagnostics) {
        if (indexPath.row == 0) { if (self.showDiagnostics) self.showDiagnostics(); }
        else {
            NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/native-guest.log"];
            [self.navigationController pushViewController:[[TKReportViewController alloc] initWithTitle:@"Native Log" file:path] animated:YES];
        }
    } else {
        if (indexPath.row == 0) { if (self.showLibrary) self.showLibrary(); }
        else [self.navigationController pushViewController:[TKAboutViewController new] animated:YES];
    }
}

- (void)chooseEdition:(UIView *)anchor {
    NSMutableArray<TKMenuItem *> *items=[NSMutableArray new];
    for (NSDictionary *product in TKWoWProducts()) {
        BOOL selected=[product[@"id"] isEqual:self.wow.product[@"id"]];
        [items addObject:[TKMenuItem itemWithTitle:product[@"name"] subtitle:nil symbol:@"gamecontroller"
            selected:selected destructive:NO handler:^{
                [self.wow selectProduct:product];
                [self.tableView reloadData];
            }]];
    }
    [TKMenuViewController presentFrom:self sourceView:anchor sourceRect:anchor.bounds
        title:@"Choose your edition" message:nil items:items];
}

- (void)chooseRegion:(UIView *)anchor {
    NSDictionary *names = @{@"eu": @"Europe", @"us": @"Americas", @"kr": @"Korea", @"tw": @"Taiwan"};
    NSMutableArray<TKMenuItem *> *items=[NSMutableArray new];
    for (NSString *region in @[@"eu", @"us", @"kr", @"tw"]) {
        [items addObject:[TKMenuItem itemWithTitle:names[region] subtitle:nil symbol:@"globe"
            selected:[self.wow.region isEqualToString:region] destructive:NO handler:^{
                [self.wow setDownloadRegion:region locale:self.wow.locale];
                [self.tableView reloadData];
            }]];
    }
    [TKMenuViewController presentFrom:self sourceView:anchor sourceRect:anchor.bounds
        title:@"Download Region" message:@"This does not change your game's login region." items:items];
}

- (void)chooseLanguage:(UIView *)anchor {
    NSDictionary *names = @{@"enUS": @"English", @"esES": @"Spanish"};
    NSMutableArray<TKMenuItem *> *items=[NSMutableArray new];
    for (NSString *locale in @[@"enUS", @"esES"]) {
        [items addObject:[TKMenuItem itemWithTitle:names[locale] subtitle:nil symbol:@"character.bubble"
            selected:[self.wow.locale isEqualToString:locale] destructive:NO handler:^{
                [self.wow setDownloadRegion:self.wow.region locale:locale];
                [self.tableView reloadData];
            }]];
    }
    [TKMenuViewController presentFrom:self sourceView:anchor sourceRect:anchor.bounds
        title:@"Download Language" message:nil items:items];
}

- (void)confirm:(NSString *)title message:(NSString *)message action:(NSString *)action handler:(void (^)(void))handler {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    alert.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;
    alert.view.tintColor=TKLauncherTheme.gold;
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:action style:UIAlertActionStyleDestructive handler:^(UIAlertAction *item) {
        (void)item; handler();
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
