#import "TouchControlsViewController.h"
#import "LauncherTheme.h"

static NSString *const TKTouchControlsKey = @"AKTouchControls";
static NSString *const TKTouchGamepadKey = @"TKTouchGamepadEnabled";
static NSString *const TKTouchGamepadWithControllerKey = @"TKTouchGamepadWithController";
static NSString *const TKSwitchCell = @"touch.switch";

@interface TKTouchControlsViewController ()
@property(nonatomic) UISwitch *controls;
@property(nonatomic) UISwitch *gamepad;
@property(nonatomic) UISwitch *withController;
@end

@implementation TKTouchControlsViewController

- (instancetype)init {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = @"Touch Controls";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.view.backgroundColor = TKLauncherTheme.background;
    self.tableView.backgroundColor = TKLauncherTheme.background;
    self.tableView.separatorColor = TKLauncherTheme.hairline;
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:TKSwitchCell];
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    BOOL controls = [defaults objectForKey:TKTouchControlsKey] ?
        [defaults boolForKey:TKTouchControlsKey] : UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone;
    self.controls = [self makeSwitch:controls action:@selector(controlsChanged)];
    self.gamepad = [self makeSwitch:[defaults objectForKey:TKTouchGamepadKey] ? [defaults boolForKey:TKTouchGamepadKey] : YES
                             action:@selector(gamepadChanged)];
    self.withController = [self makeSwitch:[defaults boolForKey:TKTouchGamepadWithControllerKey]
                                    action:@selector(withControllerChanged)];
}

- (UISwitch *)makeSwitch:(BOOL)on action:(SEL)action {
    UISwitch *toggle = [UISwitch new];
    toggle.onTintColor = TKLauncherTheme.gold;
    toggle.on = on;
    [toggle addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    return toggle;
}

- (void)controlsChanged {
    BOOL on = self.controls.isOn;
    [NSUserDefaults.standardUserDefaults setBool:on forKey:TKTouchControlsKey];
    if (on) {
        [NSUserDefaults.standardUserDefaults setBool:YES forKey:TKTouchGamepadKey];
        self.gamepad.on = YES;
    } else {
        [NSUserDefaults.standardUserDefaults setBool:NO forKey:TKTouchGamepadWithControllerKey];
        self.withController.on = NO;
    }
}

- (void)gamepadChanged {
    BOOL on = self.gamepad.isOn;
    [NSUserDefaults.standardUserDefaults setBool:on forKey:TKTouchGamepadKey];
    if (on) {
        [NSUserDefaults.standardUserDefaults setBool:YES forKey:TKTouchControlsKey];
        self.controls.on = YES;
    } else {
        [NSUserDefaults.standardUserDefaults setBool:NO forKey:TKTouchGamepadWithControllerKey];
        self.withController.on = NO;
    }
}

- (void)withControllerChanged {
    BOOL on = self.withController.isOn;
    [NSUserDefaults.standardUserDefaults setBool:on forKey:TKTouchGamepadWithControllerKey];
    if (on) {
        [NSUserDefaults.standardUserDefaults setBool:YES forKey:TKTouchGamepadKey];
        [NSUserDefaults.standardUserDefaults setBool:YES forKey:TKTouchControlsKey];
        self.gamepad.on = YES;
        self.controls.on = YES;
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { (void)tableView; return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { (void)tableView; (void)section; return 3; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { (void)tableView; (void)section; return @"On-Screen Controls"; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView; (void)section;
    return @"These settings apply the next time the game starts. Closing Tolkara completely and reopening it makes sure the adapter sees the change.";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:TKSwitchCell forIndexPath:indexPath];
    UIListContentConfiguration *content = [UIListContentConfiguration cellConfiguration];
    content.textProperties.color = TKLauncherTheme.text;
    content.textProperties.font = TKLauncherTheme.body;
    UISwitch *toggle = nil;
    if (indexPath.row == 0) { content.text = @"Show On-Screen Controls"; toggle = self.controls; }
    else if (indexPath.row == 1) { content.text = @"Automatic Touch Gamepad"; toggle = self.gamepad; }
    else { content.text = @"Touch Gamepad With a Controller"; toggle = self.withController; }
    cell.contentConfiguration = content;
    cell.accessoryView = toggle;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = TKLauncherTheme.surface;
    return cell;
}

@end
