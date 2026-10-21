#import "LauncherTabController.h"
#import "LibraryViewController.h"
#import "SettingsViewController.h"
#import "../UI/LauncherTheme.h"
#import "../UI/MenuViewController.h"
#import "../UI/TouchControlsViewController.h"
#import "../WoW/CustomServerViewController.h"
#import "../WoW/WoWViewController.h"
#import "../WoW/Manifest.h"
#import "CustomServerConfig.h"
#import "../WoW/AddOns/AddOnsManager.h"
#import "../WoW/AddOns/AddOnsSources.h"
#import "../WoW/AddOns/AddOnsViewController.h"

static const CGFloat TKHeaderBrandHeight = 52;
static const CGFloat TKHeaderStripHeight = 56;
static const CGFloat TKHeaderContentHeight = TKHeaderBrandHeight + TKHeaderStripHeight;

@interface TKAddOnsEmptyViewController : UIViewController
@property(nonatomic, copy) void (^openPlay)(void);
@end

@implementation TKAddOnsEmptyViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Add-ons";
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.view.backgroundColor = TKLauncherTheme.background;
    UILabel *title = [UILabel new];
    title.text = @"No Game Installed";
    title.font = TKLauncherTheme.title;
    title.textColor = TKLauncherTheme.text;
    title.textAlignment = NSTextAlignmentCenter;
    UILabel *detail = [UILabel new];
    detail.text = @"Install a game edition from Play before managing its add-ons.";
    detail.font = TKLauncherTheme.body;
    detail.textColor = TKLauncherTheme.muted;
    detail.textAlignment = NSTextAlignmentCenter;
    detail.numberOfLines = 0;
    UIButton *button = [TKLauncherTheme secondaryButtonWithTitle:@"Open Play"];
    [button addAction:[UIAction actionWithHandler:^(UIAction *action) {
        (void)action;
        if (self.openPlay) self.openPlay();
    }] forControlEvents:UIControlEventTouchUpInside];
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[title, detail, button]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 16;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:32],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-32]
    ]];
}
@end

@interface TKLauncherTabController ()
@property(nonatomic) TKWoWViewController *wow;
@property(nonatomic) TKLibraryViewController *library;
@property(nonatomic) UINavigationController *playNavigation;
@property(nonatomic) UINavigationController *addOnsNavigation;
@property(nonatomic) UINavigationController *libraryNavigation;
@property(nonatomic) UINavigationController *settingsNavigation;
@property(nonatomic) NSArray<UINavigationController *> *navigations;
@property(nonatomic) TKAddOnsEmptyViewController *addOnsEmpty;
@property(nonatomic, copy) NSString *addOnsDirectory;
@property(nonatomic) UIView *content;
@property(nonatomic) UIVisualEffectView *header;
@property(nonatomic) UIStackView *navStack;
@property(nonatomic) NSArray<UIButton *> *navButtons;
@property(nonatomic) UIScrollView *gameScroll;
@property(nonatomic) UIStackView *gameStrip;
@property(nonatomic) UIButton *customServerButton;
@property(nonatomic) UILabel *editionCaption;
@property(nonatomic) NSArray<UIButton *> *gameTiles;
@property(nonatomic) UIViewController *currentChild;
@property(nonatomic) NSInteger selectedSection;
- (NSArray<NSLayoutConstraint *> *)pin:(UIView *)view to:(UIView *)other;
- (UIFont *)brandFont:(CGFloat)size;
- (UIColor *)colorForProduct:(NSString *)product;
- (NSString *)initialsForProduct:(NSString *)product;
- (void)updateGameStripSelection;
@end

@implementation TKLauncherTabController

- (instancetype)initWithWoWController:(TKWoWViewController *)wow libraryController:(TKLibraryViewController *)library {
    if (!(self = [super initWithNibName:nil bundle:nil])) return nil;
    _wow = wow;
    _library = library;
    _playNavigation = [[UINavigationController alloc] initWithRootViewController:wow];
    [_playNavigation setNavigationBarHidden:YES animated:NO];
    library.title = @"Library";
    _libraryNavigation = [[UINavigationController alloc] initWithRootViewController:library];
    _addOnsEmpty = [TKAddOnsEmptyViewController new];
    __weak TKLauncherTabController *weakSelf = self;
    _addOnsEmpty.openPlay = ^{ [weakSelf selectPlayTab]; };
    _addOnsNavigation = [[UINavigationController alloc] initWithRootViewController:_addOnsEmpty];
    TKSettingsViewController *settings = [[TKSettingsViewController alloc] initWithWoWController:wow];
    settings.showDiagnostics = ^{ if (weakSelf.showDiagnostics) weakSelf.showDiagnostics(); };
    settings.showExecutionMode = ^{ if (weakSelf.showExecutionMode) weakSelf.showExecutionMode(); };
    settings.showLibrary = ^{ [weakSelf selectSection:2]; };
    settings.showAddOns = ^{ [weakSelf selectSection:1]; };
    settings.showPlay = ^{ [weakSelf selectPlayTab]; };
    _settingsNavigation = [[UINavigationController alloc] initWithRootViewController:settings];
    _navigations = @[_playNavigation, _addOnsNavigation, _libraryNavigation, _settingsNavigation];
    for (UINavigationController *nav in _navigations) [TKLauncherTheme styleNavigationController:nav];
    wow.showSettings = ^{ [weakSelf selectSection:3]; };
    wow.showAddOns = ^{ [weakSelf selectSection:1]; };
    wow.showExecutionMode = ^{ if (weakSelf.showExecutionMode) weakSelf.showExecutionMode(); };
    wow.showTouchControls = ^{
        [weakSelf selectSection:3];
        [weakSelf.settingsNavigation pushViewController:[TKTouchControlsViewController new] animated:YES];
    };
    wow.showCustomServer = ^{
        [weakSelf selectSection:3];
        TKCustomServerViewController *controller = [[TKCustomServerViewController alloc] initWithGameDirectory:[weakSelf.wow selectedGameDirectory]];
        __weak TKLauncherTabController *inner = weakSelf;
        controller.onSave = ^{ [inner.wow refresh]; };
        [weakSelf.settingsNavigation pushViewController:controller animated:YES];
    };
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(wowStateChanged:)
        name:TKWoWStateDidChangeNotification object:wow];
    return self;
}

- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.view.backgroundColor = TKLauncherTheme.background;

    _content = [UIView new];
    _content.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_content];
    [NSLayoutConstraint activateConstraints:@[
        [_content.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_content.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_content.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_content.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    _header = [[UIVisualEffectView alloc] initWithEffect:blur];
    _header.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_header];
    UIView *tint = [UIView new];
    tint.translatesAutoresizingMaskIntoConstraints = NO;
    tint.backgroundColor = [UIColor colorWithWhite:0 alpha:0.34];
    [_header.contentView addSubview:tint];
    [NSLayoutConstraint activateConstraints:[self pin:tint to:_header.contentView]];

    UIView *hairline = [UIView new];
    hairline.translatesAutoresizingMaskIntoConstraints = NO;
    hairline.backgroundColor = TKLauncherTheme.hairline;
    [_header.contentView addSubview:hairline];
    [NSLayoutConstraint activateConstraints:@[
        [hairline.leadingAnchor constraintEqualToAnchor:_header.contentView.leadingAnchor],
        [hairline.trailingAnchor constraintEqualToAnchor:_header.contentView.trailingAnchor],
        [hairline.bottomAnchor constraintEqualToAnchor:_header.contentView.bottomAnchor],
        [hairline.heightAnchor constraintEqualToConstant:0.5]
    ]];

    UIView *mark = [UIView new];
    mark.translatesAutoresizingMaskIntoConstraints = NO;
    mark.backgroundColor = [UIColor colorWithRed:0.035 green:0.075 blue:0.13 alpha:1];
    mark.layer.cornerRadius = 15;
    mark.layer.masksToBounds = YES;
    mark.layer.borderWidth = 1;
    mark.layer.borderColor = [TKLauncherTheme.gold colorWithAlphaComponent:0.55].CGColor;
    UILabel *markLabel = [UILabel new];
    markLabel.text = @"WK";
    markLabel.font = [self brandFont:11];
    markLabel.textColor = TKLauncherTheme.gold;
    markLabel.textAlignment = NSTextAlignmentCenter;
    markLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [mark addSubview:markLabel];
    [NSLayoutConstraint activateConstraints:@[
        [mark.widthAnchor constraintEqualToConstant:30],
        [mark.heightAnchor constraintEqualToConstant:30],
        [markLabel.centerXAnchor constraintEqualToAnchor:mark.centerXAnchor],
        [markLabel.centerYAnchor constraintEqualToAnchor:mark.centerYAnchor]
    ]];
    UILabel *brand = [UILabel new];
    brand.text = @"WOLKARA";
    brand.font = [self brandFont:23];
    brand.textColor = TKLauncherTheme.gold;
    UIImageView *chevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.down"]];
    chevron.tintColor = TKLauncherTheme.muted;
    chevron.contentMode = UIViewContentModeScaleAspectFit;
    [chevron.widthAnchor constraintEqualToConstant:10].active = YES;
    [chevron.heightAnchor constraintEqualToConstant:10].active = YES;
    UIStackView *brandStack = [[UIStackView alloc] initWithArrangedSubviews:@[mark, brand, chevron]];
    brandStack.axis = UILayoutConstraintAxisHorizontal;
    brandStack.spacing = 9;
    brandStack.alignment = UIStackViewAlignmentCenter;

    NSMutableArray<UIButton *> *navButtons = [NSMutableArray new];
    NSArray<NSString *> *titles = @[@"PLAY", @"ADD-ONS", @"LIBRARY", @"SETTINGS"];
    _navStack = [UIStackView new];
    _navStack.axis = UILayoutConstraintAxisHorizontal;
    _navStack.spacing = 22;
    _navStack.alignment = UIStackViewAlignmentCenter;
    for (NSUInteger i = 0; i < titles.count; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        [button setTitle:titles[i] forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
        button.tag = (NSInteger)i;
        [button addTarget:self action:@selector(navTapped:) forControlEvents:UIControlEventTouchUpInside];
        [navButtons addObject:button];
        [_navStack addArrangedSubview:button];
    }
    _navButtons = navButtons;

    _customServerButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _customServerButton.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    _customServerButton.tintColor = TKLauncherTheme.text;
    _customServerButton.backgroundColor = [UIColor colorWithWhite:1 alpha:0.06];
    _customServerButton.layer.cornerRadius = 13;
    _customServerButton.contentEdgeInsets = UIEdgeInsetsMake(7, 11, 7, 11);
    [_customServerButton setImage:[UIImage systemImageNamed:@"network"] forState:UIControlStateNormal];
    _customServerButton.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 6);
    [_customServerButton addTarget:self action:@selector(customServerTapped) forControlEvents:UIControlEventTouchUpInside];

    UIButton *refresh = [UIButton buttonWithType:UIButtonTypeSystem];
    [refresh setImage:[UIImage systemImageNamed:@"arrow.clockwise"] forState:UIControlStateNormal];
    refresh.tintColor = TKLauncherTheme.muted;
    refresh.accessibilityLabel = @"Check for updates";
    [refresh addTarget:self action:@selector(refreshTapped) forControlEvents:UIControlEventTouchUpInside];
    [refresh.widthAnchor constraintEqualToConstant:32].active = YES;
    [refresh.heightAnchor constraintEqualToConstant:32].active = YES;

    UIView *flex = [UIView new];
    [flex setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    UIStackView *brandRow = [[UIStackView alloc] initWithArrangedSubviews:@[brandStack, _navStack, flex, _customServerButton, refresh]];
    brandRow.axis = UILayoutConstraintAxisHorizontal;
    brandRow.spacing = 18;
    brandRow.alignment = UIStackViewAlignmentCenter;
    [brandRow.heightAnchor constraintEqualToConstant:TKHeaderBrandHeight].active = YES;

    _gameScroll = [UIScrollView new];
    _gameScroll.showsHorizontalScrollIndicator = NO;
    _gameScroll.contentInset = UIEdgeInsetsZero;
    _gameStrip = [UIStackView new];
    _gameStrip.axis = UILayoutConstraintAxisHorizontal;
    _gameStrip.spacing = 10;
    _gameStrip.alignment = UIStackViewAlignmentCenter;
    _gameStrip.translatesAutoresizingMaskIntoConstraints = NO;
    [_gameScroll addSubview:_gameStrip];
    [NSLayoutConstraint activateConstraints:@[
        [_gameStrip.topAnchor constraintEqualToAnchor:_gameScroll.contentLayoutGuide.topAnchor],
        [_gameStrip.bottomAnchor constraintEqualToAnchor:_gameScroll.contentLayoutGuide.bottomAnchor],
        [_gameStrip.leadingAnchor constraintEqualToAnchor:_gameScroll.contentLayoutGuide.leadingAnchor],
        [_gameStrip.trailingAnchor constraintEqualToAnchor:_gameScroll.contentLayoutGuide.trailingAnchor],
        [_gameStrip.heightAnchor constraintEqualToAnchor:_gameScroll.frameLayoutGuide.heightAnchor]
    ]];
    [_gameScroll.heightAnchor constraintEqualToConstant:TKHeaderStripHeight].active = YES;

    _editionCaption = [UILabel new];
    _editionCaption.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    _editionCaption.textColor = TKLauncherTheme.muted;
    [_editionCaption setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [_gameStrip addArrangedSubview:_editionCaption];
    [self rebuildGameStrip];

    UIStackView *headerContent = [[UIStackView alloc] initWithArrangedSubviews:@[brandRow, _gameScroll]];
    headerContent.axis = UILayoutConstraintAxisVertical;
    headerContent.spacing = 0;
    headerContent.layoutMargins = UIEdgeInsetsMake(0, 18, 0, 18);
    headerContent.layoutMarginsRelativeArrangement = YES;
    headerContent.translatesAutoresizingMaskIntoConstraints = NO;
    [_header.contentView addSubview:headerContent];
    [NSLayoutConstraint activateConstraints:@[
        [headerContent.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [headerContent.leadingAnchor constraintEqualToAnchor:_header.contentView.leadingAnchor],
        [headerContent.trailingAnchor constraintEqualToAnchor:_header.contentView.trailingAnchor],
        [headerContent.bottomAnchor constraintEqualToAnchor:_header.contentView.bottomAnchor]
    ]];
    [NSLayoutConstraint activateConstraints:@[
        [_header.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_header.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_header.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];

    [self updateNav];
    [self updateHeaderState];
    [self selectSection:0];
    [self refreshAddOns:NO];
}

- (NSArray<NSLayoutConstraint *> *)pin:(UIView *)view to:(UIView *)other {
    return @[
        [view.topAnchor constraintEqualToAnchor:other.topAnchor],
        [view.bottomAnchor constraintEqualToAnchor:other.bottomAnchor],
        [view.leadingAnchor constraintEqualToAnchor:other.leadingAnchor],
        [view.trailingAnchor constraintEqualToAnchor:other.trailingAnchor]
    ];
}

- (UIFont *)brandFont:(CGFloat)size {
    UIFontDescriptor *serif = [[UIFont systemFontOfSize:size weight:UIFontWeightBold].fontDescriptor
        fontDescriptorWithDesign:UIFontDescriptorSystemDesignSerif];
    return serif ? [UIFont fontWithDescriptor:serif size:size] : [UIFont systemFontOfSize:size weight:UIFontWeightBold];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateHeaderState];
}

- (UINavigationController *)playNavigation { return _playNavigation; }

- (void)selectPlayTab { [self selectSection:0]; }

- (void)navTapped:(UIButton *)sender { [self selectSection:sender.tag]; }

- (void)selectSection:(NSInteger)section {
    if (section < 0 || section >= _navigations.count) return;
    _selectedSection = section;
    [self updateNav];
    UINavigationController *navigation = _navigations[(NSUInteger)section];
    if (_currentChild == navigation) return;
    if (_currentChild) {
        [_currentChild willMoveToParentViewController:nil];
        [_currentChild.view removeFromSuperview];
        [_currentChild removeFromParentViewController];
    }
    [self addChildViewController:navigation];
    navigation.view.translatesAutoresizingMaskIntoConstraints = NO;
    [_content addSubview:navigation.view];
    if (section == 0) {
        [navigation setNavigationBarHidden:YES animated:NO];
        [NSLayoutConstraint activateConstraints:@[
            [navigation.view.topAnchor constraintEqualToAnchor:_content.topAnchor],
            [navigation.view.bottomAnchor constraintEqualToAnchor:_content.bottomAnchor],
            [navigation.view.leadingAnchor constraintEqualToAnchor:_content.leadingAnchor],
            [navigation.view.trailingAnchor constraintEqualToAnchor:_content.trailingAnchor]
        ]];
        self.wow.additionalSafeAreaInsets = UIEdgeInsetsMake(TKHeaderContentHeight, 0, 0, 0);
    } else {
        [navigation setNavigationBarHidden:NO animated:NO];
        [NSLayoutConstraint activateConstraints:@[
            [navigation.view.topAnchor constraintEqualToAnchor:_header.bottomAnchor],
            [navigation.view.bottomAnchor constraintEqualToAnchor:_content.bottomAnchor],
            [navigation.view.leadingAnchor constraintEqualToAnchor:_content.leadingAnchor],
            [navigation.view.trailingAnchor constraintEqualToAnchor:_content.trailingAnchor]
        ]];
        self.wow.additionalSafeAreaInsets = UIEdgeInsetsZero;
    }
    [navigation didMoveToParentViewController:self];
    _currentChild = navigation;
}

- (void)updateNav {
    for (UIButton *button in _navButtons) {
        BOOL active = button.tag == _selectedSection;
        [button setTitleColor:active ? TKLauncherTheme.gold : TKLauncherTheme.muted forState:UIControlStateNormal];
        button.alpha = active ? 1 : 0.9;
    }
}

- (void)rebuildGameStrip {
    for (UIView *view in _gameStrip.arrangedSubviews.copy) {
        if (view != _editionCaption) {
            [_gameStrip removeArrangedSubview:view];
            [view removeFromSuperview];
        }
    }
    NSMutableArray<UIButton *> *tiles = [NSMutableArray new];
    NSArray *products = TKWoWProducts();
    for (NSUInteger i = 0; i < products.count; i++) {
        NSDictionary *product = products[i];
        UIButton *tile = [UIButton buttonWithType:UIButtonTypeSystem];
        tile.tag = (NSInteger)i;
        tile.accessibilityLabel = product[@"name"];
        tile.layer.cornerRadius = 21;
        tile.clipsToBounds = YES;
        tile.layer.borderWidth = 1;
        tile.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.16].CGColor;
        tile.backgroundColor = [self colorForProduct:product[@"id"]];
        [tile setTitle:[self initialsForProduct:product[@"id"]] forState:UIControlStateNormal];
        [tile setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        tile.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
        [tile.widthAnchor constraintEqualToConstant:42].active = YES;
        [tile.heightAnchor constraintEqualToConstant:42].active = YES;
        [tile addTarget:self action:@selector(tileTapped:) forControlEvents:UIControlEventTouchUpInside];
        [_gameStrip insertArrangedSubview:tile atIndex:_gameStrip.arrangedSubviews.count - 1];
        [tiles addObject:tile];
    }
    UIButton *plus = [UIButton buttonWithType:UIButtonTypeSystem];
    [plus setImage:[UIImage systemImageNamed:@"plus"] forState:UIControlStateNormal];
    plus.tintColor = TKLauncherTheme.muted;
    plus.backgroundColor = [UIColor colorWithWhite:1 alpha:0.04];
    plus.layer.cornerRadius = 21;
    plus.layer.borderWidth = 1;
    plus.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.2].CGColor;
    [plus.widthAnchor constraintEqualToConstant:42].active = YES;
    [plus.heightAnchor constraintEqualToConstant:42].active = YES;
    plus.accessibilityLabel = @"Add or select a game edition";
    [plus addTarget:self action:@selector(addEdition) forControlEvents:UIControlEventTouchUpInside];
    [_gameStrip insertArrangedSubview:plus atIndex:_gameStrip.arrangedSubviews.count - 1];
    _gameTiles = tiles;
    [self updateGameStripSelection];
}

- (UIColor *)colorForProduct:(NSString *)product {
    if ([product isEqualToString:@"wow_classic_beta"]) return [UIColor colorWithRed:0.72 green:0.55 blue:0.20 alpha:1];
    if ([product isEqualToString:@"wow_classic_era"]) return [UIColor colorWithRed:0.24 green:0.44 blue:0.28 alpha:1];
    if ([product isEqualToString:@"wow_classic"]) return [UIColor colorWithRed:0.42 green:0.30 blue:0.20 alpha:1];
    if ([product isEqualToString:@"wow_beta"]) return [UIColor colorWithRed:0.36 green:0.24 blue:0.52 alpha:1];
    return [UIColor colorWithRed:0.18 green:0.36 blue:0.56 alpha:1];
}

- (NSString *)initialsForProduct:(NSString *)product {
    if ([product isEqualToString:@"wow_classic_beta"]) return @"FB";
    if ([product isEqualToString:@"wow_classic_era"]) return @"CE";
    if ([product isEqualToString:@"wow_classic"]) return @"C";
    if ([product isEqualToString:@"wow_beta"]) return @"RB";
    if ([product isEqualToString:@"wow"]) return @"R";
    return @"?";
}

- (void)updateGameStripSelection {
    NSString *selected = self.wow.product[@"id"];
    for (UIButton *tile in _gameTiles) {
        NSDictionary *product = TKWoWProducts()[(NSUInteger)tile.tag];
        BOOL active = [product[@"id"] isEqualToString:selected];
        tile.layer.borderWidth = active ? 2 : 1;
        tile.layer.borderColor = active ? TKLauncherTheme.gold.CGColor : [UIColor colorWithWhite:1 alpha:0.16].CGColor;
        tile.layer.masksToBounds = YES;
    }
    _editionCaption.text = self.wow.product[@"name"];
}

- (void)tileTapped:(UIButton *)sender {
    NSArray *products = TKWoWProducts();
    if (sender.tag < 0 || (NSUInteger)sender.tag >= products.count) return;
    [self.wow selectProduct:products[(NSUInteger)sender.tag]];
    [self updateGameStripSelection];
}

- (void)addEdition {
    NSMutableArray<TKMenuItem *> *items=[NSMutableArray new];
    for (NSDictionary *product in TKWoWProducts()) {
        BOOL selected=[product[@"id"] isEqual:self.wow.product[@"id"]];
        [items addObject:[TKMenuItem itemWithTitle:product[@"name"] subtitle:nil symbol:@"gamecontroller"
            selected:selected destructive:NO handler:^{
                [self.wow selectProduct:product];
                [self updateGameStripSelection];
            }]];
    }
    [TKMenuViewController presentFrom:self sourceView:_gameScroll sourceRect:_gameScroll.bounds
        title:@"Choose a game edition" message:nil items:items];
}

- (void)customServerTapped { [self selectSection:3]; }
- (void)refreshTapped { [self.wow checkForUpdatesNow]; }

- (void)updateHeaderState {
    [self updateGameStripSelection];
    TKCustomServerConfig *config = [TKCustomServerConfig current];
    BOOL on = [self.wow.product[@"id"] isEqualToString:@"wow_classic_beta"] && config.isUsable;
    [_customServerButton setTitle:on ? @"Custom Server" : @"Custom Server" forState:UIControlStateNormal];
    _customServerButton.tintColor = on ? TKLauncherTheme.gold : TKLauncherTheme.muted;
    _customServerButton.layer.borderWidth = on ? 1 : 0;
    _customServerButton.layer.borderColor = [TKLauncherTheme.gold colorWithAlphaComponent:0.5].CGColor;
}

- (void)wowStateChanged:(NSNotification *)note {
    (void)note;
    [self updateHeaderState];
    [self refreshAddOns:NO];
}

- (void)refreshAddOns:(BOOL)force {
    NSString *directory = [self.wow selectedGameDirectory];
    if (!force && (directory == self.addOnsDirectory ||
        (directory.length && [directory isEqualToString:self.addOnsDirectory]))) return;
    self.addOnsDirectory = directory.copy;
    if (!directory.length) {
        self.addOnsNavigation.viewControllers = @[self.addOnsEmpty];
        return;
    }
    TKAddOnsManager *manager = [[TKAddOnsManager alloc] initWithGameDirectory:directory];
    TKAddOnsSources *sources = [[TKAddOnsSources alloc] initWithGameVersion:manager.gameVersion wagoFlavor:manager.wagoFlavor];
    TKAddOnsViewController *addons = [[TKAddOnsViewController alloc] initWithManager:manager sources:sources];
    addons.showsCloseButton = NO;
    self.addOnsNavigation.viewControllers = @[addons];
}

@end
