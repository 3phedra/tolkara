#import "CustomServerViewController.h"
#import "../App/CustomServerConfig.h"
#import "../UI/LauncherTheme.h"

static NSString *const TKCustomSwitchCellIdentifier = @"custom.switch";

@interface TKCustomFieldCell : UITableViewCell
@property(nonatomic) UILabel *caption;
@property(nonatomic) UITextField *field;
@end

@implementation TKCustomFieldCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (!(self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) return nil;
    self.backgroundColor = TKLauncherTheme.surface;
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    _caption = [UILabel new];
    _caption.font = TKLauncherTheme.caption;
    _caption.textColor = TKLauncherTheme.muted;
    _field = [UITextField new];
    _field.font = TKLauncherTheme.body;
    _field.textColor = TKLauncherTheme.text;
    _field.tintColor = TKLauncherTheme.gold;
    _field.backgroundColor = TKLauncherTheme.raised;
    _field.layer.cornerRadius = 8;
    _field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 1)];
    _field.leftViewMode = UITextFieldViewModeAlways;
    _field.rightView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 1)];
    _field.rightViewMode = UITextFieldViewModeAlways;
    _field.translatesAutoresizingMaskIntoConstraints = NO;
    _caption.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:_caption];
    [self.contentView addSubview:_field];
    [NSLayoutConstraint activateConstraints:@[
        [_caption.topAnchor constraintEqualToAnchor:self.contentView.layoutMarginsGuide.topAnchor],
        [_caption.leadingAnchor constraintEqualToAnchor:self.contentView.layoutMarginsGuide.leadingAnchor],
        [_caption.trailingAnchor constraintEqualToAnchor:self.contentView.layoutMarginsGuide.trailingAnchor],
        [_field.topAnchor constraintEqualToAnchor:_caption.bottomAnchor constant:6],
        [_field.leadingAnchor constraintEqualToAnchor:_caption.leadingAnchor],
        [_field.trailingAnchor constraintEqualToAnchor:_caption.trailingAnchor],
        [_field.heightAnchor constraintEqualToConstant:38],
        [_field.bottomAnchor constraintEqualToAnchor:self.contentView.layoutMarginsGuide.bottomAnchor]
    ]];
    return self;
}
@end

@interface TKCustomServerViewController ()
@property(nonatomic, copy, nullable) NSString *directory;
@property(nonatomic) TKCustomServerConfig *config;
@property(nonatomic) UISwitch *enabled;
@property(nonatomic) UITextField *portal;
@property(nonatomic) UITextField *key;
@property(nonatomic) UITextField *group;
@end

@implementation TKCustomServerViewController

- (instancetype)initWithGameDirectory:(NSString *)directory {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    _directory = directory.copy;
    _config = [TKCustomServerConfig current];
    self.title = @"Custom Server";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.view.backgroundColor = TKLauncherTheme.background;
    self.tableView.backgroundColor = TKLauncherTheme.background;
    self.tableView.separatorColor = TKLauncherTheme.hairline;
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:TKCustomSwitchCellIdentifier];
    for (NSString *identifier in @[@"custom.portal", @"custom.key", @"custom.group"])
        [self.tableView registerClass:TKCustomFieldCell.class forCellReuseIdentifier:identifier];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Save" style:UIBarButtonItemStyleDone target:self action:@selector(save)];
    self.navigationItem.rightBarButtonItem.tintColor = TKLauncherTheme.gold;
    self.enabled = [UISwitch new];
    self.enabled.onTintColor = TKLauncherTheme.gold;
    self.enabled.on = self.config.enabled;
    [self.enabled addTarget:self action:@selector(enableChanged) forControlEvents:UIControlEventValueChanged];
}

- (void)enableChanged {
    BOOL on = self.enabled.isOn;
    for (UITableViewCell *cell in self.tableView.visibleCells) {
        if (![cell isKindOfClass:TKCustomFieldCell.class]) continue;
        TKCustomFieldCell *field = (TKCustomFieldCell *)cell;
        field.field.enabled = on;
        field.field.alpha = on ? 1 : 0.45;
    }
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationNone];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { (void)tableView; return 3; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView; return section == 0 ? 1 : (section == 1 ? 3 : 1);
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView;
    return section == 0 ? @"Server" : (section == 1 ? @"Login Certificate" : nil);
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;
    if (section == 0) return self.enabled.isOn ? @"The portal is written to WTF/Config.wtf and the key is installed in the client's memory for this session. Restart the game after saving." : @"Custom server is off. The client uses its normal portal.";
    if (section == 1) return @"Enter the auth host, the server's 64-digit Ed25519 key, and the certificate group from 1 to 12. The key is public material; it replaces one trusted key in memory only.";
    return @"Only the Forever beta uses this setting. A game session must be closed before changing it.";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 2) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:TKCustomSwitchCellIdentifier forIndexPath:indexPath];
        UIListContentConfiguration *content = [UIListContentConfiguration subtitleCellConfiguration];
        content.text = @"Save and apply";
        content.textProperties.color = TKLauncherTheme.gold;
        content.textProperties.font = TKLauncherTheme.heading;
        content.secondaryText = @"Writes the portal and installs the key on the next start.";
        content.secondaryTextProperties.color = TKLauncherTheme.muted;
        cell.contentConfiguration = content;
        cell.accessoryView = nil;
        cell.backgroundColor = TKLauncherTheme.surface;
        return cell;
    }
    if (indexPath.section == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:TKCustomSwitchCellIdentifier forIndexPath:indexPath];
        UIListContentConfiguration *content = [UIListContentConfiguration cellConfiguration];
        content.text = @"Use a Custom Server";
        content.textProperties.color = TKLauncherTheme.text;
        content.textProperties.font = TKLauncherTheme.body;
        cell.contentConfiguration = content;
        cell.accessoryView = self.enabled;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = TKLauncherTheme.surface;
        return cell;
    }
    NSString *identifier = indexPath.row == 0 ? @"custom.portal" : (indexPath.row == 1 ? @"custom.key" : @"custom.group");
    TKCustomFieldCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier forIndexPath:indexPath];
    if (indexPath.row == 0) {
        cell.caption.text = @"Auth host";
        cell.field.placeholder = @"auth.example.com";
        cell.field.text = self.config.portal;
        cell.field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        cell.field.autocorrectionType = UITextAutocorrectionTypeNo;
        cell.field.keyboardType = UIKeyboardTypeURL;
        cell.field.font = TKLauncherTheme.body;
        self.portal = cell.field;
    } else if (indexPath.row == 1) {
        cell.caption.text = @"Ed25519 key (64 hex digits)";
        cell.field.placeholder = @"02596F0D…";
        cell.field.text = self.config.keyHex;
        cell.field.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
        cell.field.autocorrectionType = UITextAutocorrectionTypeNo;
        cell.field.keyboardType = UIKeyboardTypeASCIICapable;
        cell.field.font = TKLauncherTheme.mono;
        self.key = cell.field;
    } else {
        cell.caption.text = @"Certificate group";
        cell.field.placeholder = @"8";
        cell.field.text = self.config.group > 0 ? [@(self.config.group) stringValue] : @"";
        cell.field.keyboardType = UIKeyboardTypeNumberPad;
        cell.field.font = TKLauncherTheme.mono;
        self.group = cell.field;
    }
    cell.field.enabled = self.enabled.isOn;
    cell.field.alpha = self.enabled.isOn ? 1 : 0.45;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 2) [self save];
}

- (void)save {
    [self.view endEditing:YES];
    NSString *portal = [self.portal.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *key = [self.key.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSInteger group = self.group.text.integerValue;
    BOOL on = self.enabled.isOn;
    if (on && (!portal.length || ![TKCustomServerConfig validKey:key] || group < 1 || group > 12)) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Check the server details" message:@"Enter the auth host, a 64-digit key and a certificate group from 1 to 12." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    if (portal.length) self.config.portal = portal;
    if ([TKCustomServerConfig validKey:key]) self.config.keyHex = key.uppercaseString;
    if (group >= 1 && group <= 12) self.config.group = group;
    self.config.enabled = on;
    NSError *error = nil;
    if (![self.config save:&error]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Could not save" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    if (self.directory && ![self.config applyToGameDirectory:self.directory error:&error]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Could not update the game" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    if (self.onSave) self.onSave();
    [self.navigationController popViewControllerAnimated:YES];
}

@end
