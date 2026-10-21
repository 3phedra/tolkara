#import "MenuViewController.h"
#import "LauncherTheme.h"

@class TKMenuViewController;

@implementation TKMenuItem
+ (instancetype)itemWithTitle:(NSString *)title subtitle:(NSString *)subtitle symbol:(NSString *)symbol
    selected:(BOOL)selected destructive:(BOOL)destructive handler:(void (^)(void))handler {
    TKMenuItem *item = [TKMenuItem new];
    item.title = title; item.subtitle = subtitle; item.symbolName = symbol;
    item.selected = selected; item.destructive = destructive; item.handler = handler;
    return item;
}
@end

@interface TKMenuRowView : UIControl
@property(nonatomic) TKMenuItem *item;
@property(nonatomic) UIImageView *icon;
@property(nonatomic) UILabel *title;
@property(nonatomic) UILabel *subtitle;
@property(nonatomic) UIImageView *mark;
@end

@implementation TKMenuRowView
- (instancetype)initWithItem:(TKMenuItem *)item {
    if (!(self = [super initWithFrame:CGRectZero])) return nil;
    _item = item;
    self.backgroundColor = UIColor.clearColor;
    _icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:item.symbolName ?: @"circle" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightMedium]]];
    _icon.tintColor = item.destructive ? TKLauncherTheme.danger : TKLauncherTheme.gold;
    _icon.contentMode = UIViewContentModeScaleAspectFit;
    _title = [UILabel new];
    _title.text = item.title;
    _title.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    _title.textColor = item.destructive ? TKLauncherTheme.danger : TKLauncherTheme.text;
    _subtitle = [UILabel new];
    _subtitle.text = item.subtitle;
    _subtitle.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
    _subtitle.textColor = TKLauncherTheme.muted;
    _subtitle.numberOfLines = 2;
    _subtitle.hidden = item.subtitle.length == 0;
    UIStackView *text = [[UIStackView alloc] initWithArrangedSubviews:@[_title, _subtitle]];
    text.axis = UILayoutConstraintAxisVertical;
    text.spacing = 2;
    _mark = [[UIImageView alloc] initWithImage:item.selected ? [UIImage systemImageNamed:@"checkmark"] : nil];
    _mark.tintColor = TKLauncherTheme.gold;
    _mark.contentMode = UIViewContentModeScaleAspectFit;
    for (UIView *view in @[_icon, text, _mark]) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:view];
    }
    [NSLayoutConstraint activateConstraints:@[
        [_icon.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [_icon.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_icon.widthAnchor constraintEqualToConstant:22],
        [_icon.heightAnchor constraintEqualToConstant:22],
        [text.leadingAnchor constraintEqualToAnchor:_icon.trailingAnchor constant:12],
        [text.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [text.trailingAnchor constraintLessThanOrEqualToAnchor:_mark.leadingAnchor constant:-10],
        [_mark.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [_mark.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_mark.widthAnchor constraintEqualToConstant:18],
        [_mark.heightAnchor constraintEqualToConstant:18],
        [self.heightAnchor constraintGreaterThanOrEqualToConstant:52]
    ]];
    UIView *line = [UIView new];
    line.backgroundColor = TKLauncherTheme.hairline;
    line.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:line];
    [NSLayoutConstraint activateConstraints:@[
        [line.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [line.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [line.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [line.heightAnchor constraintEqualToConstant:0.5]
    ]];
    [self addTarget:self action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
    return self;
}
- (void)tapped {
    void (^handler)(void) = self.item.handler;
    UIResponder *responder = self.nextResponder;
    while (responder && ![responder isKindOfClass:TKMenuViewController.class]) responder = responder.nextResponder;
    TKMenuViewController *controller = (TKMenuViewController *)responder;
    [controller dismissViewControllerAnimated:YES completion:^{ if (handler) handler(); }];
}
- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.backgroundColor = highlighted ? TKLauncherTheme.raised : UIColor.clearColor;
}
@end

@interface TKMenuViewController ()
@property(nonatomic, copy) NSString *menuTitle;
@property(nonatomic, copy) NSString *menuMessage;
@property(nonatomic, copy) NSArray<TKMenuItem *> *items;
@end

@implementation TKMenuViewController
+ (void)presentFrom:(UIViewController *)presenter sourceView:(UIView *)sourceView sourceRect:(CGRect)sourceRect
    title:(NSString *)title message:(NSString *)message items:(NSArray<TKMenuItem *> *)items {
    TKMenuViewController *menu = [[TKMenuViewController alloc] initWithTitle:title message:message items:items];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad && sourceView) {
        menu.modalPresentationStyle = UIModalPresentationPopover;
        UIPopoverPresentationController *popover = menu.popoverPresentationController;
        popover.sourceView = sourceView;
        popover.sourceRect = sourceRect;
        popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
        popover.backgroundColor = TKLauncherTheme.surface;
    } else {
        menu.modalPresentationStyle = UIModalPresentationPageSheet;
        UISheetPresentationController *sheet = menu.sheetPresentationController;
        sheet.detents = @[UISheetPresentationControllerDetent.mediumDetent];
        sheet.prefersGrabberVisible = YES;
        sheet.preferredCornerRadius = 18;
    }
    [presenter presentViewController:menu animated:YES completion:nil];
}

- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message items:(NSArray<TKMenuItem *> *)items {
    if (!(self = [super initWithNibName:nil bundle:nil])) return nil;
    _menuTitle = title.copy; _menuMessage = message.copy; _items = items.copy;
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.preferredContentSize = CGSizeMake(340, 24 + (title.length ? 30 : 0) + (message.length ? 28 : 0) + items.count * 54 + 44);
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = TKLauncherTheme.surface;
    self.view.layer.cornerRadius = 18;
    self.view.clipsToBounds = YES;
    UIStackView *content = [UIStackView new];
    content.axis = UILayoutConstraintAxisVertical;
    content.spacing = 0;
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [content.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:10],
        [content.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [content.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-8]
    ]];
    if (_menuTitle.length) {
        UILabel *title = [UILabel new];
        UIFontDescriptor *serif = [[UIFont systemFontOfSize:20 weight:UIFontWeightBold].fontDescriptor
            fontDescriptorWithDesign:UIFontDescriptorSystemDesignSerif];
        title.font = serif ? [UIFont fontWithDescriptor:serif size:20] : [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
        title.text = _menuTitle;
        title.textColor = TKLauncherTheme.text;
        UIView *wrapper = [UIView new];
        title.translatesAutoresizingMaskIntoConstraints = NO;
        [wrapper addSubview:title];
        [NSLayoutConstraint activateConstraints:@[
            [title.leadingAnchor constraintEqualToAnchor:wrapper.leadingAnchor constant:16],
            [title.trailingAnchor constraintEqualToAnchor:wrapper.trailingAnchor constant:-16],
            [title.topAnchor constraintEqualToAnchor:wrapper.topAnchor constant:6],
            [title.bottomAnchor constraintEqualToAnchor:wrapper.bottomAnchor constant:-6]
        ]];
        [content addArrangedSubview:wrapper];
    }
    if (_menuMessage.length) {
        UILabel *message = [UILabel new];
        message.font = TKLauncherTheme.caption;
        message.textColor = TKLauncherTheme.muted;
        message.text = _menuMessage;
        message.numberOfLines = 0;
        message.translatesAutoresizingMaskIntoConstraints = NO;
        UIView *wrapper = [UIView new];
        [wrapper addSubview:message];
        [NSLayoutConstraint activateConstraints:@[
            [message.leadingAnchor constraintEqualToAnchor:wrapper.leadingAnchor constant:16],
            [message.trailingAnchor constraintEqualToAnchor:wrapper.trailingAnchor constant:-16],
            [message.topAnchor constraintEqualToAnchor:wrapper.topAnchor constant:0],
            [message.bottomAnchor constraintEqualToAnchor:wrapper.bottomAnchor constant:-10]
        ]];
        [content addArrangedSubview:wrapper];
    }
    for (TKMenuItem *item in _items) [content addArrangedSubview:[[TKMenuRowView alloc] initWithItem:item]];
    UIButton *cancel = [UIButton buttonWithType:UIButtonTypeSystem];
    [cancel setTitle:@"Cancel" forState:UIControlStateNormal];
    cancel.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [cancel setTitleColor:TKLauncherTheme.muted forState:UIControlStateNormal];
    [cancel.heightAnchor constraintEqualToConstant:44].active = YES;
    __weak TKMenuViewController *weakSelf = self;
    [cancel addAction:[UIAction actionWithHandler:^(UIAction *action) {
        (void)action;
        [weakSelf dismissViewControllerAnimated:YES completion:nil];
    }] forControlEvents:UIControlEventTouchUpInside];
    [content addArrangedSubview:cancel];
}
@end
