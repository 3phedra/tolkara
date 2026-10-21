#import "WoWViewController.h"
#import "Client.h"
#import "Installation.h"
#import "Updater.h"
#import "../App/LaunchProgressView.h"
#import "../App/CustomServerConfig.h"
#import "../App/AboutViewController.h"
#import "../UI/LauncherTheme.h"
#import "AddOns/AddOnsManager.h"
#import "AddOns/AddOnsSources.h"
#import "AddOns/AddOnsViewController.h"

NSNotificationName const TKWoWStateDidChangeNotification = @"TKWoWStateDidChangeNotification";

static UIColor *Gold(void) { return [UIColor colorWithRed:0.88 green:0.73 blue:0.43 alpha:1]; }
static UIColor *Muted(void) { return [UIColor colorWithRed:0.66 green:0.72 blue:0.78 alpha:1]; }
static UILabel *Label(CGFloat size, UIFontWeight weight, UIColor *color) {
    UILabel *label=[UILabel new]; label.numberOfLines=0; label.textColor=color;
    label.font=[[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:[UIFont systemFontOfSize:size weight:weight]];
    label.adjustsFontForContentSizeCategory=YES;
    [label setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    return label;
}
static UIStackView *Stack(NSArray<UIView *> *views, CGFloat spacing) {
    UIStackView *stack=[[UIStackView alloc] initWithArrangedSubviews:views];
    stack.axis=UILayoutConstraintAxisVertical; stack.spacing=spacing; return stack;
}

@implementation TKWoWViewController {
    TKAppLibrary *_library;
    TKWoWClient *_client;
    NSDictionary *_product, *_plan;
    TKWoWInstallation *_installation;
    NSString *_region, *_locale;
    NSError *_error;
    NSDate *_checkedAt;
    NSUInteger _generation;
    BOOL _busy, _updating, _updateError, _starting;
    NSString *_startupFailure;
    UILabel *_updatesLabel;
    NSString *_updatePhase;
    uint64_t _updateDone, _updateTotal;
    UIProgressView *_progressBar;
    UIImageView *_heroImage;
    UIView *_heroShade;
    UIView *_actionBar;
    UILabel *_stateLabel, *_detailLabel, *_versionLabel, *_startupLabel, *_compatibilityLabel, *_heroTitleLabel;
    UIButton *_editionButton, *_preferencesButton, *_primaryButton, *_customLink, *_touchLink, *_addOnsLink;
    UIBarButtonItem *_refreshItem;
    UIActivityIndicatorView *_activity;
}
- (instancetype)initWithLibrary:(TKAppLibrary *)library {
    if (!(self=[super initWithNibName:nil bundle:nil])) return nil;
    _library=library; self.title=@"";
    NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
    _product=TKWoWProducts()[0];
    for (NSDictionary *p in TKWoWProducts()) if ([p[@"id"] isEqual:[defaults stringForKey:@"WoWProduct"]]) _product=p;
    _region=[defaults stringForKey:@"WoWRegion"]?:@"eu";
    if (![@[@"eu",@"us",@"kr",@"tw"] containsObject:_region]) _region=@"eu";
    _locale=[defaults stringForKey:@"WoWLocale"]?:@"enUS";
    if (![@[@"enUS",@"esES"] containsObject:_locale]) _locale=@"enUS";
    return self;
}
- (UIButton *)button:(NSString *)identifier action:(SEL)action {
    UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];
    button.accessibilityIdentifier=identifier;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;
    self.view.backgroundColor=[UIColor colorWithRed:0.025 green:0.045 blue:0.075 alpha:1];
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"gearshape"]
        style:UIBarButtonItemStylePlain target:self action:@selector(settings)];
    self.navigationItem.rightBarButtonItem.accessibilityLabel=@"Settings";
    self.navigationItem.rightBarButtonItem.accessibilityIdentifier=@"wow.settings";
    self.navigationItem.backButtonTitle=@"Back";
    _refreshItem=[[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"arrow.clockwise"]
        style:UIBarButtonItemStylePlain target:self action:@selector(refresh)];
    _refreshItem.accessibilityLabel=@"Check for updates";
    _refreshItem.accessibilityIdentifier=@"wow.refresh";
    self.navigationItem.leftBarButtonItem=_refreshItem;

    _heroImage=[[UIImageView alloc] initWithImage:TKLauncherHeroImage()];
    _heroImage.contentMode=UIViewContentModeScaleAspectFill;
    _heroImage.clipsToBounds=YES;
    _heroImage.translatesAutoresizingMaskIntoConstraints=NO;
    [self.view insertSubview:_heroImage atIndex:0];
    [NSLayoutConstraint activateConstraints:@[
        [_heroImage.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_heroImage.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_heroImage.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_heroImage.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];
    _heroShade=[UIView new];
    _heroShade.translatesAutoresizingMaskIntoConstraints=NO;
    _heroShade.userInteractionEnabled=NO;
    CAGradientLayer *shade=[CAGradientLayer layer];
    shade.colors=@[(id)[UIColor colorWithWhite:0 alpha:0.30].CGColor,
        (id)[UIColor colorWithWhite:0 alpha:0.02].CGColor,
        (id)[UIColor colorWithWhite:0 alpha:0.55].CGColor,
        (id)[UIColor colorWithWhite:0 alpha:0.82].CGColor];
    shade.locations=@[@0,@0.28,@0.62,@1];
    [_heroShade.layer addSublayer:shade];
    shade.name=@"heroShade";
    [self.view insertSubview:_heroShade aboveSubview:_heroImage];
    [NSLayoutConstraint activateConstraints:@[
        [_heroShade.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_heroShade.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_heroShade.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_heroShade.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];

    UILabel *world=Label(11,UIFontWeightSemibold,Gold());
    world.text=@"WORLD OF WARCRAFT";
    world.textAlignment=NSTextAlignmentLeft;
    world.attributedText=[[NSAttributedString alloc] initWithString:@"WORLD OF WARCRAFT"
        attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:11 weight:UIFontWeightSemibold],
            NSForegroundColorAttributeName:Gold(),NSKernAttributeName:@3.2}];
    _heroTitleLabel=Label(50,UIFontWeightBold,Gold());
    UIFontDescriptor *serif=[[UIFont systemFontOfSize:50 weight:UIFontWeightBold].fontDescriptor fontDescriptorWithDesign:UIFontDescriptorSystemDesignSerif];
    if (serif) _heroTitleLabel.font=[UIFont fontWithDescriptor:serif size:50];
    _heroTitleLabel.textColor=Gold();
    _heroTitleLabel.textAlignment=NSTextAlignmentLeft;
    _heroTitleLabel.accessibilityIdentifier=@"wow.title";
    _heroTitleLabel.layer.shadowColor=[UIColor blackColor].CGColor;
    _heroTitleLabel.layer.shadowOpacity=0.65;
    _heroTitleLabel.layer.shadowRadius=24;
    _heroTitleLabel.layer.shadowOffset=CGSizeMake(0,6);
    UILabel *tagline=Label(13,UIFontWeightRegular,Muted());
    tagline.text=@"World of Warcraft, on iPad.";
    tagline.textAlignment=NSTextAlignmentLeft;
    UILabel *editionLabel=Label(10,UIFontWeightSemibold,Muted()); editionLabel.text=@"GAME EDITION";
    editionLabel.textAlignment=NSTextAlignmentLeft;
    _editionButton=[self button:@"wow.edition" action:@selector(chooseEdition)];
    _preferencesButton=[self button:@"wow.preferences" action:@selector(preferences)];
    UIStackView *editionRow=Stack(@[_editionButton,_preferencesButton],8);
    editionRow.axis=UILayoutConstraintAxisHorizontal; editionRow.distribution=UIStackViewDistributionFillEqually;
    [editionRow.widthAnchor constraintEqualToConstant:460].active=YES;
    editionLabel.hidden=YES;
    editionRow.hidden=YES;
    _compatibilityLabel=Label(11,UIFontWeightRegular,Muted());
    _compatibilityLabel.textAlignment=NSTextAlignmentLeft;

    _updatesLabel=Label(9,UIFontWeightRegular,Muted()); _updatesLabel.accessibilityIdentifier=@"wow.updates";
    _updatesLabel.text=@"Updates automatically. Keep this app open while downloading.";
    _updatesLabel.numberOfLines=1;
    _startupLabel=Label(9,UIFontWeightRegular,Muted()); _startupLabel.accessibilityIdentifier=@"wow.startup";
    _startupLabel.numberOfLines=1;
    UIScrollView *scroll=[UIScrollView new]; scroll.accessibilityIdentifier=@"wow.scroll";
    scroll.translatesAutoresizingMaskIntoConstraints=NO; [self.view addSubview:scroll];
    UIStackView *hero=Stack(@[world,_heroTitleLabel,tagline,editionLabel,editionRow,_compatibilityLabel,_updatesLabel,_startupLabel],6);
    hero.alignment=UIStackViewAlignmentLeading;
    [hero setCustomSpacing:2 afterView:world];
    [hero setCustomSpacing:8 afterView:_heroTitleLabel];
        hero.translatesAutoresizingMaskIntoConstraints=NO;
    [scroll addSubview:hero];
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [hero.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:24],
        [hero.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-24],
        [hero.leadingAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.leadingAnchor constant:64],
        [hero.trailingAnchor constraintLessThanOrEqualToAnchor:scroll.frameLayoutGuide.trailingAnchor constant:-32],
        [hero.widthAnchor constraintLessThanOrEqualToConstant:720]
    ]];
    scroll.contentInset=UIEdgeInsetsMake(0,0,150,0);

    _activity=[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _activity.color=Gold(); _activity.hidesWhenStopped=YES;
    _stateLabel=Label(20,UIFontWeightSemibold,UIColor.whiteColor); _stateLabel.accessibilityIdentifier=@"wow.status";
    UIStackView *stateRow=[[UIStackView alloc] initWithArrangedSubviews:@[_activity,_stateLabel]];
    stateRow.axis=UILayoutConstraintAxisHorizontal; stateRow.spacing=9;
    stateRow.alignment=UIStackViewAlignmentCenter;
    [_activity setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    _detailLabel=Label(12,UIFontWeightRegular,Muted()); _detailLabel.accessibilityIdentifier=@"wow.detail";
    _versionLabel=Label(10,UIFontWeightRegular,Muted()); _versionLabel.accessibilityIdentifier=@"wow.version";
    _progressBar=[[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    _progressBar.progressTintColor=Gold(); _progressBar.accessibilityIdentifier=@"wow.progress";
    _launchProgress=[TKLaunchProgressView new];
    _launchProgress.accessibilityIdentifier=@"wow.elapsed";
    _diagnosticsButton=[self button:@"wow.diagnostics" action:@selector(diagnostics)];
    [_diagnosticsButton setTitle:@"Diagnostics and logs" forState:UIControlStateNormal];
    _diagnosticsButton.tintColor=Gold(); _diagnosticsButton.hidden=YES;
    _diagnosticsButton.titleLabel.font=[UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];

    _addOnsLink=[self linkButton:@"wow.addons" title:@"Add-ons" symbol:@"puzzlepiece.extension" action:@selector(addOns)];
    _touchLink=[self linkButton:@"wow.touch" title:@"Touch" symbol:@"hand.tap" action:@selector(touchLinkTapped)];
    _customLink=[self linkButton:@"wow.custom" title:@"Server" symbol:@"network" action:@selector(customLinkTapped)];
    UIStackView *links=[[UIStackView alloc] initWithArrangedSubviews:@[_addOnsLink,_touchLink,_customLink]];
    links.axis=UILayoutConstraintAxisHorizontal; links.spacing=12; links.alignment=UIStackViewAlignmentCenter;

    _primaryButton=[self button:@"wow.primary" action:@selector(primaryAction)];
    [_primaryButton.heightAnchor constraintGreaterThanOrEqualToConstant:52].active=YES;
    [_primaryButton.widthAnchor constraintEqualToConstant:190].active=YES;
    UIButton *gear=[self button:@"wow.settings" action:@selector(settings)];
    [gear setImage:[UIImage systemImageNamed:@"gearshape.fill"] forState:UIControlStateNormal];
    gear.tintColor=Gold();
    gear.backgroundColor=[UIColor colorWithWhite:1 alpha:0.08];
    gear.layer.cornerRadius=12;
    [gear.widthAnchor constraintEqualToConstant:48].active=YES;
    [gear.heightAnchor constraintEqualToConstant:52].active=YES;
    UIStackView *playRow=[[UIStackView alloc] initWithArrangedSubviews:@[_primaryButton,gear]];
    playRow.axis=UILayoutConstraintAxisHorizontal; playRow.spacing=8; playRow.alignment=UIStackViewAlignmentCenter;
    UILabel *launchNote=Label(9,UIFontWeightRegular,Muted());
    launchNote.text=@"Launch locally";
    launchNote.textAlignment=NSTextAlignmentCenter;
    UIStackView *right=Stack(@[playRow,launchNote],5);
    right.alignment=UIStackViewAlignmentCenter;

    UIStackView *left=Stack(@[stateRow,_detailLabel,_progressBar,_launchProgress,_versionLabel,_diagnosticsButton,links],5);
    left.alignment=UIStackViewAlignmentLeading;
    UIView *flex=[UIView new];
    [flex setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    UIStackView *barContent=[[UIStackView alloc] initWithArrangedSubviews:@[left,flex,right]];
    barContent.axis=UILayoutConstraintAxisHorizontal; barContent.spacing=20; barContent.alignment=UIStackViewAlignmentCenter;
    barContent.translatesAutoresizingMaskIntoConstraints=NO;

    _actionBar=[UIView new];
    _actionBar.translatesAutoresizingMaskIntoConstraints=NO;
    _actionBar.backgroundColor=[UIColor colorWithWhite:0.025 alpha:0.88];
    _actionBar.layer.cornerRadius=18;
    _actionBar.layer.borderWidth=1;
    _actionBar.layer.borderColor=[UIColor colorWithWhite:1 alpha:0.10].CGColor;
    _actionBar.layer.shadowColor=[UIColor blackColor].CGColor;
    _actionBar.layer.shadowOpacity=0.55;
    _actionBar.layer.shadowRadius=24;
    _actionBar.layer.shadowOffset=CGSizeMake(0,10);
    [_actionBar addSubview:barContent];
    [self.view addSubview:_actionBar];
    [NSLayoutConstraint activateConstraints:@[
        [_actionBar.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16],
        [_actionBar.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16],
        [_actionBar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12],
        [barContent.topAnchor constraintEqualToAnchor:_actionBar.topAnchor constant:16],
        [barContent.bottomAnchor constraintEqualToAnchor:_actionBar.bottomAnchor constant:-14],
        [barContent.leadingAnchor constraintEqualToAnchor:_actionBar.leadingAnchor constant:18],
        [barContent.trailingAnchor constraintEqualToAnchor:_actionBar.trailingAnchor constant:-18]
    ]];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(foreground:)
        name:UIApplicationDidBecomeActiveNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(background:)
        name:UIApplicationWillResignActiveNotification object:nil];
    [self render];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    UINavigationBarAppearance *appearance=[UINavigationBarAppearance new]; [appearance configureWithOpaqueBackground];
    appearance.backgroundColor=[UIColor colorWithRed:0.025 green:0.045 blue:0.075 alpha:1];
    appearance.titleTextAttributes=@{NSForegroundColorAttributeName:Gold()};
    self.navigationItem.standardAppearance=appearance; self.navigationItem.scrollEdgeAppearance=appearance;
    self.navigationItem.compactAppearance=appearance;
    self.navigationController.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;
    self.navigationController.navigationBar.prefersLargeTitles=NO;
    self.navigationItem.largeTitleDisplayMode=UINavigationItemLargeTitleDisplayModeNever;
    self.navigationController.navigationBar.tintColor=Gold();
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    for (CALayer *layer in _heroShade.layer.sublayers)
        if ([layer.name isEqualToString:@"heroShade"]) layer.frame=_heroShade.bounds;
}
- (void)viewDidAppear:(BOOL)animated { [super viewDidAppear:animated]; if (!_busy && !_sessionUsed && !_starting) [self inspectLocal]; }
- (void)viewDidDisappear:(BOOL)animated { [super viewDidDisappear:animated]; if(!_updating)[self cancel]; }
- (void)foreground:(NSNotification *)note {
    (void)note;
    [_client foregrounded];
    if (self.isViewLoaded && self.view.window && self.navigationController.topViewController==self && !_busy && !_sessionUsed && !_starting) [self inspectLocal];
}
- (void)background:(NSNotification *)note { (void)note; [_client backgrounded]; if(!_updating)[self cancel]; }
- (void)cancel { [_client cancel]; _client=nil; _generation++; _busy=NO; }
- (void)setExecutionMode:(TKExecutionMode)mode { _executionMode=mode; if (self.isViewLoaded) [self render]; }
- (void)setSessionUsed:(BOOL)used { _sessionUsed=used; if (used) [self cancel]; if (self.isViewLoaded) [self render]; }
- (void)selectProduct:(NSDictionary *)product {
    if (_starting || _sessionUsed) return;
    if (![TKWoWProducts() containsObject:product]) return;
    _product=product;
    [NSUserDefaults.standardUserDefaults setObject:product[@"id"] forKey:@"WoWProduct"];
    [self refresh];
}
- (void)refresh { [self checkForUpdatesAndLaunch:NO]; }
- (void)inspectLocal {
    _plan=nil; _error=nil; _updateError=NO; _installation=TKWoWLocalInspection(_library,_product);
    [self render];
}
- (void)checkForUpdatesAndLaunch:(BOOL)launch { [self checkForUpdatesAndLaunch:launch install:NO]; }
- (void)checkForUpdatesAndLaunch:(BOOL)launch install:(BOOL)install {
    if (_starting || _sessionUsed) return;
    NSString *installKey=[@"WoWInstallRequested." stringByAppendingString:_product[@"id"]];
    NSString *repairKey=[@"WoWRepairRequested." stringByAppendingString:_product[@"id"]];
    if(install && _installation.state==TKWoWInstallationNeedsRepair)
        [NSUserDefaults.standardUserDefaults setBool:YES forKey:repairKey];
    if(install)[NSUserDefaults.standardUserDefaults setBool:YES forKey:installKey];
    install=install || [NSUserDefaults.standardUserDefaults boolForKey:installKey];
    BOOL repair=[NSUserDefaults.standardUserDefaults boolForKey:repairKey];
    [self cancel]; _plan=nil; _installation=nil; _error=nil; _checkedAt=nil; _startupFailure=nil;
    _updating=NO; _updateError=NO; _updatePhase=nil; _updateDone=0; _updateTotal=0;
    _client=[TKWoWClient new]; _busy=YES; [self render];
    TKWoWClient *client=_client; NSUInteger generation=_generation;
    NSDictionary *product=_product; NSString *region=_region, *locale=_locale;
    dispatch_async(TKWoWUpdateQueue(),^{
        [self->_library discover];
        NSError *error=nil;
        NSDictionary *plan=[client planForProduct:product[@"id"] region:region locale:locale error:&error];
        TKWoWInstallation *installation=plan?TKWoWInspectInstallation(self->_library,product,plan):nil;
        BOOL updateAttempted=plan && (install || installation.state==TKWoWInstallationOutdated) && !client.cancelled;
        if(updateAttempted) {
            __block NSString *lastPhase=nil;
            void (^progress)(NSString *,uint64_t,uint64_t)=^(NSString *phase,uint64_t done,uint64_t total) {
                if(![lastPhase isEqual:phase]) {
                    lastPhase=phase;NSLog(@"[wow-update] Phase: %@",phase);
                }
                dispatch_async(dispatch_get_main_queue(),^{
                    if(generation!=self->_generation)return;
                    self->_plan=plan;self->_installation=installation;self->_updating=YES;
                    self->_updatePhase=phase;self->_updateDone=done;self->_updateTotal=total;[self render];
                });
            };
            progress(@"snapshot",0,0);
            NSString *directory=installation.app?[self->_library workingDirectoryForApp:installation.app error:&error]:nil;
            NSString *root=directory?directory.stringByDeletingLastPathComponent:
                [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"World of Warcraft"];
            TKWoWUpdater *updater=[[TKWoWUpdater alloc] initWithClient:client];
            updater.fullVerification=repair;
            if([updater updatePlan:plan root:root progress:progress error:&error]) {
                [self->_library discover];installation=TKWoWInspectInstallation(self->_library,product,plan);error=nil;
                // Editions without a bundled compatibility profile still need a
                // library entry after their first download. Register only the
                // original executable already verified by the install manifest.
                if(installation.state==TKWoWInstallationMissing) {
                    NSMutableArray *executables=[NSMutableArray new];
                    for(NSDictionary *file in plan[@"files"])if([file[@"path"] hasSuffix:@".app/Contents/MacOS/World of Warcraft"])
                        [executables addObject:[[root stringByAppendingPathComponent:product[@"folder"]] stringByAppendingPathComponent:file[@"path"]]];
                    if(executables.count==1 && [self->_library importExecutable:executables[0] copy:NO error:&error])
                        installation=TKWoWInspectInstallation(self->_library,product,plan);
                }
                if(installation.state==TKWoWInstallationReady) {
                    [NSUserDefaults.standardUserDefaults removeObjectForKey:installKey];
                    [NSUserDefaults.standardUserDefaults removeObjectForKey:repairKey];
                }
                else error=error?:installation.error?:TKWoWError(@"The downloaded installation could not be registered in the library.");
            }
            if(error)NSLog(@"[wow-update] Interrupted during %@: %@ (%@:%ld)",lastPhase?:@"preparation",
                error.localizedDescription,error.domain,(long)error.code);
            NSLog(@"[wow-update] Verification bytes read=%llu reused=%llu",updater.verificationBytesRead,updater.verificationBytesReused);
        }

        dispatch_async(dispatch_get_main_queue(),^{
            if (generation!=self->_generation) return;
            self->_plan=plan; self->_installation=installation; self->_error=error;
            self->_checkedAt=plan?NSDate.date:nil; self->_busy=NO; self->_updating=NO; self->_updateError=updateAttempted && error; [self render];
            // Returning from the background or changing edition invalidates this request.
            if (launch && !error && !client.cancelled && installation.state==TKWoWInstallationReady && installation.app && !self->_sessionUsed &&
                self.view.window && self.navigationController.topViewController==self && self.startApp) self.startApp(installation.app);
        });
    });
}
- (void)primaryAction {
    if (_busy || _sessionUsed || _starting) return;
    if (_startupFailure) { _startupFailure=nil; [self render]; }
    // A present installation starts immediately. Checking for updates and
    // downloading them are explicit actions (Settings, Install, Update).
    if (_installation.state==TKWoWInstallationReady && _installation.app) {
        if (_executionMode==TKExecutionModeNone) return;
        if (self.startApp) self.startApp(_installation.app);
        return;
    }
    if (_installation.state==TKWoWInstallationMissing || _installation.state==TKWoWInstallationNeedsRepair ||
        _installation.state==TKWoWInstallationOutdated) {
        [self checkForUpdatesAndLaunch:NO install:YES]; return;
    }
    [self checkForUpdatesAndLaunch:NO];
}
- (void)repairInstallation {
    if(_busy || _starting || _sessionUsed || !_installation.app)return;
    [NSUserDefaults.standardUserDefaults setBool:YES forKey:[@"WoWRepairRequested." stringByAppendingString:_product[@"id"]]];
    [self checkForUpdatesAndLaunch:NO install:YES];
}
- (void)touchLinkTapped { if (self.showTouchControls) self.showTouchControls(); else [self touchControlsSettings]; }
- (void)customLinkTapped { if (self.showCustomServer) self.showCustomServer(); else [self configureCustomServer]; }
- (UIButton *)linkButton:(NSString *)identifier title:(NSString *)title symbol:(NSString *)symbol action:(SEL)action {
    UIButton *button=[self button:identifier action:action];
    UIButtonConfiguration *configuration=[UIButtonConfiguration plainButtonConfiguration];
    configuration.title=title;
    configuration.image=[UIImage systemImageNamed:symbol];
    configuration.preferredSymbolConfigurationForImage=[UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightMedium];
    configuration.imagePadding=5;
    configuration.baseForegroundColor=Muted();
    configuration.titleLineBreakMode=NSLineBreakByTruncatingTail;
    configuration.titleTextAttributesTransformer=^NSDictionary<NSAttributedStringKey,id> *(NSDictionary<NSAttributedStringKey,id> *attributes) {
        NSMutableDictionary<NSAttributedStringKey,id> *result=[attributes mutableCopy];
        result[NSFontAttributeName]=[UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
        return result;
    };
    configuration.contentInsets=NSDirectionalEdgeInsetsMake(2,0,2,0);
    button.configuration=configuration;
    button.titleLabel.font=[UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
    button.titleLabel.numberOfLines=1;
    return button;
}
- (void)configureButton:(UIButton *)button title:(NSString *)title filled:(BOOL)filled {
    UIButtonConfiguration *configuration=filled?UIButtonConfiguration.filledButtonConfiguration:UIButtonConfiguration.plainButtonConfiguration;
    configuration.title=title; configuration.cornerStyle=UIButtonConfigurationCornerStyleMedium;
    configuration.baseBackgroundColor=Gold(); configuration.baseForegroundColor=filled?[UIColor colorWithRed:0.08 green:0.065 blue:0.035 alpha:1]:Gold();
    configuration.contentInsets=NSDirectionalEdgeInsetsMake(filled?14:6,12,filled?14:6,12);
    button.configuration=configuration;
}
- (void)render {
    if (!self.isViewLoaded) return;
    // Keep the screen on while an update runs so the system does not suspend
    // the decode/store work between background download completions.
    UIApplication.sharedApplication.idleTimerDisabled=_updating;
    [self configureButton:_editionButton title:[_product[@"name"] stringByAppendingString:@"  ▾"] filled:NO];
    _editionButton.contentHorizontalAlignment=UIControlContentHorizontalAlignmentLeading;
    _editionButton.backgroundColor=[UIColor colorWithWhite:1 alpha:0.055]; _editionButton.layer.cornerRadius=10;
    [self configureButton:_preferencesButton title:[NSString stringWithFormat:@"%@  ·  %@  ▾",_region.uppercaseString,[_locale isEqual:@"esES"]?@"Spanish":@"English"] filled:NO];
    _preferencesButton.contentHorizontalAlignment=UIControlContentHorizontalAlignmentLeading;
    NSArray<NSString *> *nameParts=[(_product[@"name"] ?: @"World of Warcraft") componentsSeparatedByString:@"·"];
    NSMutableArray<NSString *> *nameWords=[NSMutableArray new];
    for (NSString *part in nameParts) {
        NSString *word=[part stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (word.length) [nameWords addObject:word];
    }
    _heroTitleLabel.text=[nameWords componentsJoinedByString:@" "].uppercaseString;
    _compatibilityLabel.text=([_product[@"id"] isEqual:@"wow"] || [_product[@"id"] isEqual:@"wow_beta"] || [_product[@"id"] isEqual:@"wow_classic"])?
        @"Compatibility with this edition is not yet verified.":
        @"";
    _compatibilityLabel.hidden=!_compatibilityLabel.text.length;
    _customLink.hidden=![_product[@"id"] isEqualToString:@"wow_classic_beta"];
    _editionButton.enabled=!_busy && !_starting && !_sessionUsed;
    _preferencesButton.enabled=_editionButton.enabled;
    self.navigationItem.rightBarButtonItem.enabled=!_updating && !_starting;
    _primaryButton.hidden=_starting || _sessionUsed;
    _updatesLabel.hidden=_starting || _sessionUsed;
    _startupLabel.hidden=_starting || _sessionUsed;
    _progressBar.hidden=!_updating || !_updateTotal;
    _progressBar.progress=_updateTotal?(float)((double)_updateDone/_updateTotal):0;
    NSString *title=nil, *detail=nil, *action=nil;
    BOOL enabled=NO;
    if (_starting) {
        title=@"Starting…";
        detail=_detailLabel.text.length?_detailLabel.text:@"Preparing to launch. Keep this app open.";
        action=@"Starting…";
    } else if (_startupFailure) {
        title=@"Could not start";
        detail=_sessionUsed?@"Close this app from the app switcher, then reopen it to try again. Details are available in Diagnostics and logs.":@"Try again. Details are available in Diagnostics and logs.";
        action=_sessionUsed?@"Reopen to retry":@"Try again"; enabled=!_sessionUsed;
    } else if (_sessionUsed) {
        title=@"Reopen to start again";
        detail=@"Close the app from the app switcher before starting another session.";
        action=@"Session ended";
    } else if (_busy && _updating) {
        title=@"Updating your game…";
        NSDictionary *phases=@{@"snapshot":@"Preparing the installation",
            @"manifests":@"Reading the update",
            @"verify":@"Checking existing data",
            @"reuse":@"Comparing installed content",
            @"indices":@"Locating download files",
            @"download":@"Downloading new data",
            @"files":@"Installing game files",
            @"activate":@"Finishing the update",
            @"complete":@"Update complete"};
        detail=phases[_updatePhase]?:@"Preparing…";
        if(_updateTotal) {
            BOOL bytes=[_updatePhase isEqual:@"verify"] || [_updatePhase isEqual:@"download"];
            NSString *done=bytes?[NSByteCountFormatter stringFromByteCount:(int64_t)_updateDone countStyle:NSByteCountFormatterCountStyleFile]:@(_updateDone).stringValue;
            NSString *total=bytes?[NSByteCountFormatter stringFromByteCount:(int64_t)_updateTotal countStyle:NSByteCountFormatterCountStyleFile]:@(_updateTotal).stringValue;
            detail=[detail stringByAppendingFormat:@" · %@ / %@",done,total];
        }
        action=@"Updating…";
    } else if (_busy) {
        title=@"Checking for updates…";
        detail=@"Checking the latest version and your installed copy.";
        action=@"Checking…";
    } else if (_error) {
        title=_updateError?@"Update interrupted":@"Could not check this edition";
        detail=_updateError?@"Your installed copy is preserved. Try again to resume the update; see Settings for details.":@"We cannot confirm that your game is up to date. Check your connection and try again.";
        action=@"Try again"; enabled=YES;
    } else {
        switch (_installation.state) {
        case TKWoWInstallationMissing:
            title=@"Not installed";
            detail=@"Install this edition on your device. The download may require several gigabytes.";
            action=@"Install"; enabled=YES; break;
        case TKWoWInstallationOutdated:
            title=@"Update required";
            detail=@"A newer build is available. The update starts automatically.";
            action=@"Update"; enabled=YES; break;
        case TKWoWInstallationNeedsRepair:
            title=@"Your copy needs attention";
            detail=@"We could not verify all game files. Repair downloads the original files and keeps your settings and addons.";
            action=@"Repair installation"; enabled=YES; break;
        case TKWoWInstallationReady:
            title=@"Ready to play";
            detail=@"Your installed copy is ready. Use Settings to check for updates.";
            action=_executionMode==TKExecutionModeNone?@"Startup unavailable":@"Play"; enabled=_executionMode!=TKExecutionModeNone; break;
        }
    }
    _stateLabel.text=title; _detailLabel.text=detail;
    [self configureButton:_primaryButton title:action filled:YES]; _primaryButton.enabled=enabled;
    _refreshItem.enabled=!_busy && !_sessionUsed && !_starting;
    if (_busy) [_activity startAnimating]; else [_activity stopAnimating];
    if (_checkedAt) {
        NSString *time=[NSDateFormatter localizedStringFromDate:_checkedAt dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterShortStyle];
        NSString *available=_plan[@"version"][@"VersionsName"];
        _versionLabel.text=[_installation.installedVersion isEqual:available]?
            [NSString stringWithFormat:@"Version %@ · Checked %@",available,time]:
            [NSString stringWithFormat:@"Installed %@ · Available %@",_installation.installedVersion?:@"—",available];
    } else _versionLabel.text=nil;
    _versionLabel.hidden=!_versionLabel.text.length;
    switch (_executionMode) {
    case TKExecutionModeDeveloperService:
        _startupLabel.text=@"Starting can take a few minutes each time."; break;
    case TKExecutionModeLocalSigning:
        _startupLabel.text=@"Startup requires a signed container matching this version."; break;
    case TKExecutionModeExternalJIT:
        _startupLabel.text=@"Enable JIT before starting a new session."; break;
    case TKExecutionModeNone:
        _startupLabel.text=@"This build cannot start the game. See Diagnostics and logs."; break;
    }
    [NSNotificationCenter.defaultCenter postNotificationName:TKWoWStateDidChangeNotification object:self];
}
- (void)presentSheet:(UIAlertController *)sheet anchor:(UIView *)anchor {
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    if (anchor) { sheet.popoverPresentationController.sourceView=anchor; sheet.popoverPresentationController.sourceRect=anchor.bounds; }
    else sheet.popoverPresentationController.barButtonItem=self.navigationItem.rightBarButtonItem;
    [self presentViewController:sheet animated:YES completion:nil];
}
- (void)chooseEdition {
    UIAlertController *sheet=[UIAlertController alertControllerWithTitle:@"Choose your edition" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary *product in TKWoWProducts()) [sheet addAction:[UIAlertAction actionWithTitle:product[@"name"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action; [self selectProduct:product];
    }]];
    [self presentSheet:sheet anchor:_editionButton];
}
- (void)choosePreference:(BOOL)region {
    UIAlertController *sheet=[UIAlertController alertControllerWithTitle:region?@"Region":@"Download language" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *values=region?@[@"eu",@"us",@"kr",@"tw"]:@[@"enUS",@"esES"];
    NSDictionary *names=@{@"eu":@"Europe",@"us":@"Americas",@"kr":@"Korea",@"tw":@"Taiwan",@"enUS":@"English",@"esES":@"Spanish"};
    for (NSString *value in values) [sheet addAction:[UIAlertAction actionWithTitle:names[value] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action; if (region) self->_region=value; else self->_locale=value;
        [NSUserDefaults.standardUserDefaults setObject:value forKey:region?@"WoWRegion":@"WoWLocale"]; [self refresh];
    }]];
    [self presentSheet:sheet anchor:_preferencesButton];
}
- (void)preferences {
    UIAlertController *sheet=[UIAlertController alertControllerWithTitle:@"Download preferences"
        message:@"These settings do not change your game's login region." preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Region" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { (void)a; [self choosePreference:YES]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Language" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { (void)a; [self choosePreference:NO]; }]];
    [self presentSheet:sheet anchor:_preferencesButton];
}
// The AppKit adapter reads these when the guest starts. The library's hand
// button sets the first one, but the public home does not include the library,
// so the same switch lives here.
static NSString *const TKTouchControlsKey=@"AKTouchControls";
static NSString *const TKTouchGamepadKey=@"TKTouchGamepadEnabled";
static NSString *const TKTouchGamepadWithControllerKey=@"TKTouchGamepadWithController";
static BOOL TKTouchControlsOn(void) {
    NSNumber *saved=[NSUserDefaults.standardUserDefaults objectForKey:TKTouchControlsKey];
    return saved ? saved.boolValue : UIDevice.currentDevice.userInterfaceIdiom==UIUserInterfaceIdiomPhone;
}
static BOOL TKTouchGamepadOn(void) {
    NSNumber *saved=[NSUserDefaults.standardUserDefaults objectForKey:TKTouchGamepadKey];
    return saved ? saved.boolValue : YES;
}
static BOOL TKTouchGamepadWithControllerOn(void) {
    NSNumber *saved=[NSUserDefaults.standardUserDefaults objectForKey:TKTouchGamepadWithControllerKey];
    return saved ? saved.boolValue : NO;
}
- (void)touchControlsMessage:(NSString *)message {
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Touch controls" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)touchControlsSettings {
    BOOL controls=TKTouchControlsOn(), gamepad=TKTouchGamepadOn();
    BOOL withController=TKTouchGamepadWithControllerOn();
    UIAlertController *sheet=[UIAlertController alertControllerWithTitle:@"Touch controls"
        message:@"Applied from the next game start. The toolbar stays at the top center. The touch gamepad appears when no physical controller is connected, or always with the last switch on."
        preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"On-Screen Controls: %@",controls?@"On":@"Off"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action;
        BOOL enable=!controls;
        [NSUserDefaults.standardUserDefaults setBool:enable forKey:TKTouchControlsKey];
        if(enable) [NSUserDefaults.standardUserDefaults setBool:YES forKey:TKTouchGamepadKey];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.35*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            [self touchControlsMessage:enable?@"On-screen controls are on. Close Tolkara completely and start the game again.":@"On-screen controls are off. Close Tolkara completely and start the game again."];
        });
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Automatic Touch Gamepad: %@",gamepad?@"On":@"Off"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action;
        BOOL enable=!gamepad;
        [NSUserDefaults.standardUserDefaults setBool:enable forKey:TKTouchGamepadKey];
        if(enable) [NSUserDefaults.standardUserDefaults setBool:YES forKey:TKTouchControlsKey];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.35*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            [self touchControlsMessage:enable?@"Automatic touch gamepad is on and on-screen controls are on. Close Tolkara completely and start the game again.":@"Automatic touch gamepad is off. Close Tolkara completely and start the game again."];
        });
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Touch Gamepad With a Controller: %@",withController?@"On":@"Off"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action;
        BOOL enable=!withController;
        [NSUserDefaults.standardUserDefaults setBool:enable forKey:TKTouchGamepadWithControllerKey];
        if(enable) {
            [NSUserDefaults.standardUserDefaults setBool:YES forKey:TKTouchGamepadKey];
            [NSUserDefaults.standardUserDefaults setBool:YES forKey:TKTouchControlsKey];
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.35*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            [self touchControlsMessage:enable?@"The touch gamepad will stay available beside a physical controller. Close Tolkara completely and start the game again.":@"The touch gamepad hides while a physical controller is connected. Close Tolkara completely and start the game again."];
        });
    }]];
    [self presentSheet:sheet anchor:nil];
}
- (NSString *)selectedGameDirectory {
    NSError *error=nil;
    TKApp *app=_installation.app;
    NSString *directory=app?[_library workingDirectoryForApp:app error:&error]:nil;
    if (directory) return directory;
    NSString *folder=_product[@"folder"];
    if (!folder.length) return nil;
    NSString *candidate=[[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/World of Warcraft"] stringByAppendingPathComponent:folder];
    return [NSFileManager.defaultManager fileExistsAtPath:candidate] ? candidate : nil;
}
- (NSString *)wowForeverDirectory {
    if (![_product[@"id"] isEqualToString:@"wow_classic_beta"]) return nil;
    return [self selectedGameDirectory];
}
- (void)customServerError:(NSString *)message {
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Custom server" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)configureCustomServer {
    TKCustomServerConfig *config=[TKCustomServerConfig current];
    UIAlertController *sheet=[UIAlertController alertControllerWithTitle:@"Custom server"
        message:@"Connects the Forever beta to a custom auth server. Enter its auth host, the 64-digit Ed25519 key used by its login certificate, and the client certificate group. The portal is written to WTF/Config.wtf; the key is installed in the game's memory for this session only. Restart the game after changing this."
        preferredStyle:UIAlertControllerStyleAlert];
    [sheet addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text=config.portal;
        field.placeholder=@"auth.example.com";
        field.autocapitalizationType=UITextAutocapitalizationTypeNone;
        field.autocorrectionType=UITextAutocorrectionTypeNo;
        field.keyboardType=UIKeyboardTypeURL;
        field.clearButtonMode=UITextFieldViewModeWhileEditing;
    }];
    [sheet addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text=config.keyHex;
        field.placeholder=@"64 hex digits";
        field.autocapitalizationType=UITextAutocapitalizationTypeAllCharacters;
        field.autocorrectionType=UITextAutocorrectionTypeNo;
        field.keyboardType=UIKeyboardTypeASCIICapable;
        field.clearButtonMode=UITextFieldViewModeWhileEditing;
        field.font=[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    }];
    [sheet addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text=[@(config.group) stringValue];
        field.placeholder=@"8";
        field.autocorrectionType=UITextAutocorrectionTypeNo;
        field.keyboardType=UIKeyboardTypeNumberPad;
        field.clearButtonMode=UITextFieldViewModeWhileEditing;
    }];
    __weak TKWoWViewController *weakSelf=self;
    __weak UIAlertController *weakSheet=sheet;
    void (^save)(BOOL)=^(BOOL enable) {
        TKWoWViewController *strongSelf=weakSelf;
        UIAlertController *strongSheet=weakSheet;
        if (!strongSelf || !strongSheet.textFields.count) return;
        NSString *portal=[strongSheet.textFields[0].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSString *key=[strongSheet.textFields[1].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSInteger group=[strongSheet.textFields[2].text integerValue];
        if (enable && (!portal.length || ![TKCustomServerConfig validKey:key] || group < 1 || group > 12)) {
            [strongSelf customServerError:@"Enter the auth host, the server's 64-digit key and a certificate group from 1 to 12."];
            return;
        }
        if (portal.length) config.portal=portal;
        if ([TKCustomServerConfig validKey:key]) config.keyHex=key.uppercaseString;
        if (group >= 1 && group <= 12) config.group=group;
        config.enabled=enable;
        NSError *error=nil;
        if (![config save:&error]) { [strongSelf customServerError:error.localizedDescription]; return; }
        NSString *directory=[strongSelf wowForeverDirectory];
        if (directory && (![config applyToGameDirectory:directory error:&error]))
            [strongSelf customServerError:error.localizedDescription];
        [strongSelf refresh];
    };
    [sheet addAction:[UIAlertAction actionWithTitle:config.enabled?@"Save":@"Save and enable" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action; save(YES);
    }]];
    if (config.enabled) [sheet addAction:[UIAlertAction actionWithTitle:@"Disable" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        (void)action; save(NO);
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}
- (void)addOns {
    if (self.showAddOns) { self.showAddOns(); return; }
    if (_busy || _starting) {
        UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Add-ons" message:@"Wait for the current update or startup to finish." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    if (_sessionUsed) {
        UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Add-ons" message:@"Close and reopen Tolkara after a game session before managing add-ons." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    NSString *directory=[self selectedGameDirectory];
    if (!directory.length) {
        UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Add-ons" message:@"Install the selected game edition before managing add-ons." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    TKAddOnsManager *manager=[[TKAddOnsManager alloc] initWithGameDirectory:directory];
    TKAddOnsSources *sources=[[TKAddOnsSources alloc] initWithGameVersion:manager.gameVersion wagoFlavor:manager.wagoFlavor];
    TKAddOnsViewController *addons=[[TKAddOnsViewController alloc] initWithManager:manager sources:sources];
    UINavigationController *nav=[[UINavigationController alloc] initWithRootViewController:addons];
    nav.modalPresentationStyle=UIModalPresentationPageSheet;
    [self presentViewController:nav animated:YES completion:nil];
}
- (void)settings {
    if (self.showSettings) { self.showSettings(); return; }
    UIAlertController *sheet=[UIAlertController alertControllerWithTitle:@"Settings"
        message:@"Updates install automatically while this app is open. Settings and addons are preserved. Startup preparation is separate from downloading updates." preferredStyle:UIAlertControllerStyleActionSheet];
    if(!_busy && !_starting && !_sessionUsed) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"Check for updates now" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            (void)a; [self checkForUpdatesAndLaunch:NO];
        }]];
    }
    if(!_busy && !_starting && !_sessionUsed && _installation.app) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"Verify and repair game files" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            (void)a; [self repairInstallation];
        }]];
    }
    if(!_busy && !_starting && !_sessionUsed && [self hasDownloadedFilesForProduct:_product]) {
        [sheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Remove downloaded files for %@",_product[@"name"]] style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
            (void)a; [self removeInstallation];
        }]];
    }
    if(!_busy && !_starting && !_sessionUsed && [self hasDownloadedData]) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"Remove all downloaded game data" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
            (void)a; [self removeAllDownloadedData];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Touch controls" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        (void)a; [self touchControlsSettings];
    }]];
    TKCustomServerConfig *customServer=[TKCustomServerConfig current];
    NSString *customTitle=[customServer isUsable]?[NSString stringWithFormat:@"Custom server: %@",customServer.portal]:@"Custom server: off";
    [sheet addAction:[UIAlertAction actionWithTitle:customTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        (void)a; [self configureCustomServer];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Diagnostics and logs" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        (void)a; [self diagnostics];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"About and open-source licenses" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        (void)a; [self about];
    }]];
    if (_startupFailure || _error || _installation.error) [sheet addAction:[UIAlertAction actionWithTitle:@"Technical details" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        (void)a;
        UIAlertController *details=[UIAlertController alertControllerWithTitle:@"Details" message:self->_startupFailure?:(self->_error?:self->_installation.error).localizedDescription preferredStyle:UIAlertControllerStyleAlert];
        [details addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:details animated:YES completion:nil];
    }]];
    [self presentSheet:sheet anchor:nil];
}
- (NSString *)installationRoot {
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/World of Warcraft"];
}
- (BOOL)hasDownloadedFilesForProduct:(NSDictionary *)product {
    if(!product)return NO;
    NSFileManager *fm=NSFileManager.defaultManager;
    NSString *root=[self installationRoot];
    if([fm fileExistsAtPath:[root stringByAppendingPathComponent:product[@"folder"]]])return YES;
    NSString *work=[root.stringByDeletingLastPathComponent stringByAppendingPathComponent:@".tolkara-updates"];
    NSString *prefix=[product[@"id"] stringByAppendingString:@"-"];
    for(NSString *entry in [fm contentsOfDirectoryAtPath:work error:NULL]) if([entry hasPrefix:prefix])return YES;
    return NO;
}
- (void)removeInstallation {
    NSDictionary *product=_product;
    UIAlertController *confirm=[UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Remove %@ files?",product[@"name"]]
        message:@"This deletes this edition's downloaded game files from the iPad, including its in-game settings. Other editions and their files are not touched." preferredStyle:UIAlertControllerStyleAlert];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Remove" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        (void)action; [self performRemovalOfProduct:product];
    }]];
    [self presentViewController:confirm animated:YES completion:nil];
}
- (void)performRemovalOfProduct:(NSDictionary *)product {
    [self cancel]; _busy=YES; [self render];
    TKAppLibrary *library=_library;
    NSString *root=[self installationRoot];
    NSString *work=[root.stringByDeletingLastPathComponent stringByAppendingPathComponent:@".tolkara-updates"];
    NSString *folder=product[@"folder"];
    NSString *relative=[@"World of Warcraft" stringByAppendingPathComponent:folder];
    NSString *folderPath=[root stringByAppendingPathComponent:folder];
    NSString *prefix=[product[@"id"] stringByAppendingString:@"-"];
    NSFileManager *fm=NSFileManager.defaultManager;
    // Runs on the update queue so it can never overlap an in-flight update.
    dispatch_async(TKWoWUpdateQueue(),^{
        NSError *failure=nil;
        // Only this edition's folder, entries and staged downloads are
        // removed. The shared Data pool and every other edition stay in place.
        if([fm fileExistsAtPath:folderPath]) {
            if(![library removeApplicationFolder:relative error:&failure])
                [fm removeItemAtPath:folderPath error:&failure];
        }
        // Entries left behind by a manual deletion point at nothing: drop them
        // so the edition shows as not installed instead of needing repair.
        for(TKApp *app in library.apps.copy)
            if(app.source==TKAppSourceDocuments && [app.workingDirectory.lastPathComponent isEqual:folder])
                [library removeApp:app error:NULL];
        for(NSString *entry in [fm contentsOfDirectoryAtPath:work error:NULL])
            if([entry hasPrefix:prefix])[fm removeItemAtPath:[work stringByAppendingPathComponent:entry] error:NULL];
        dispatch_async(dispatch_get_main_queue(),^{
            [NSUserDefaults.standardUserDefaults removeObjectForKey:[@"WoWInstallRequested." stringByAppendingString:product[@"id"]]];
            [NSUserDefaults.standardUserDefaults removeObjectForKey:[@"WoWRepairRequested." stringByAppendingString:product[@"id"]]];
            self->_busy=NO;
            if(failure) {
                UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Could not remove all files" message:failure.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            }
            [self inspectLocal];
        });
    });
}
- (BOOL)hasDownloadedData {
    return [NSFileManager.defaultManager fileExistsAtPath:[self installationRoot]];
}
- (void)removeAllDownloadedData {
    UIAlertController *confirm=[UIAlertController alertControllerWithTitle:@"Remove all downloaded game data?"
        message:@"Deletes every edition's files, the shared data cache, staged downloads, and recently deleted game files inside this app. The app itself and anything else you keep in its folder are not touched." preferredStyle:UIAlertControllerStyleAlert];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Remove all" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        (void)action; [self performRemoveAllDownloadedData];
    }]];
    [self presentViewController:confirm animated:YES completion:nil];
}
- (void)performRemoveAllDownloadedData {
    [self cancel]; _busy=YES; [self render];
    TKAppLibrary *library=_library;
    NSString *root=[self installationRoot];
    NSString *documents=root.stringByDeletingLastPathComponent;
    NSString *work=[documents stringByAppendingPathComponent:@".tolkara-updates"];
    NSString *trash=[documents stringByAppendingPathComponent:@".Trash"];
    dispatch_async(TKWoWUpdateQueue(),^{
        NSError *failure=nil;
        NSFileManager *fm=NSFileManager.defaultManager;
        // The whole shared tree: every edition folder and the data cache.
        if([fm fileExistsAtPath:root] && ![library removeApplicationFolder:@"World of Warcraft" error:&failure])
            [fm removeItemAtPath:root error:&failure];
        for(NSString *entry in [fm contentsOfDirectoryAtPath:work error:NULL])
            [fm removeItemAtPath:[work stringByAppendingPathComponent:entry] error:NULL];
        // The Files app moves deletions into the container's own .Trash, so
        // deleted game data keeps occupying space until it is emptied. Remove
        // only entries that are downloaded game data, never anything else.
        NSSet *names=[NSSet setWithArray:@[@"World of Warcraft",@".build.info",@".flavor.info",@"Data",@"data",
            @"indices",@"config",@"_classic_beta_",@"_classic_era_",@"_classic_",@"_retail_",@"_beta_",
            @"WTF",@"Interface",@"Logs",@"Cache"]];
        for(NSString *entry in [fm contentsOfDirectoryAtPath:trash error:NULL])
            if([names containsObject:entry]) [fm removeItemAtPath:[trash stringByAppendingPathComponent:entry] error:NULL];
        dispatch_async(dispatch_get_main_queue(),^{
            for(NSDictionary *p in TKWoWProducts()) {
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:[@"WoWInstallRequested." stringByAppendingString:p[@"id"]]];
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:[@"WoWRepairRequested." stringByAppendingString:p[@"id"]]];
            }
            self->_busy=NO;
            if(failure) {
                UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Could not remove all files" message:failure.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            }
            [self inspectLocal];
        });
    });
}
- (UILabel *)startupStatusLabel { [self loadViewIfNeeded]; return _detailLabel; }- (void)beginStartup {
    [self loadViewIfNeeded];
    [self cancel]; _starting=YES; _startupFailure=nil;
    _detailLabel.text=@"Preparing to launch. Keep this app open.";
    _diagnosticsButton.hidden=YES;
    [self render]; [_launchProgress start];
    [self.view layoutIfNeeded];
}
- (void)finishStartupWithMessage:(NSString *)message failed:(BOOL)failed {
    _starting=NO; _startupFailure=failed?message:nil;
    [_launchProgress stop]; _diagnosticsButton.hidden=!failed;
    [self render];
}
- (void)diagnostics { if (self.showDiagnostics) self.showDiagnostics(); }
- (NSDictionary *)product { return _product; }
- (TKWoWInstallation *)installation { return _installation; }
- (BOOL)isBusy { return _busy; }
- (BOOL)isUpdating { return _updating; }
- (NSString *)region { return _region; }
- (NSString *)locale { return _locale; }
- (void)checkForUpdatesNow { [self checkForUpdatesAndLaunch:NO]; }
- (void)setDownloadRegion:(NSString *)region locale:(NSString *)locale {
    if (![@[@"eu",@"us",@"kr",@"tw"] containsObject:region]) return;
    if (![@[@"enUS",@"esES"] containsObject:locale]) return;
    _region=region.copy; _locale=locale.copy;
    [NSUserDefaults.standardUserDefaults setObject:_region forKey:@"WoWRegion"];
    [NSUserDefaults.standardUserDefaults setObject:_locale forKey:@"WoWLocale"];
    [self refresh];
}
- (void)about {
    [self.navigationController pushViewController:[TKAboutViewController new] animated:YES];
}

@end
