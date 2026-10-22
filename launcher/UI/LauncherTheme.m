#import "LauncherTheme.h"

@implementation TKLauncherTheme

+ (UIColor *)background { return [UIColor colorWithRed:0.043 green:0.051 blue:0.063 alpha:1]; }
+ (UIColor *)surface { return [UIColor colorWithRed:0.078 green:0.090 blue:0.110 alpha:1]; }
+ (UIColor *)raised { return [UIColor colorWithRed:0.106 green:0.125 blue:0.153 alpha:1]; }
+ (UIColor *)text { return [UIColor colorWithRed:0.910 green:0.929 blue:0.949 alpha:1]; }
+ (UIColor *)muted { return [UIColor colorWithRed:0.541 green:0.580 blue:0.639 alpha:1]; }
+ (UIColor *)gold { return [UIColor colorWithRed:0.914 green:0.671 blue:0.157 alpha:1]; }
+ (UIColor *)accent { return [UIColor colorWithRed:0.000 green:0.706 blue:1.000 alpha:1]; }
+ (UIColor *)success { return [UIColor colorWithRed:0.298 green:0.686 blue:0.314 alpha:1]; }
+ (UIColor *)danger { return [UIColor colorWithRed:0.898 green:0.451 blue:0.451 alpha:1]; }
+ (UIColor *)hairline { return [UIColor colorWithWhite:1 alpha:0.08]; }

+ (UIFont *)wordmark {
    UIFontDescriptor *serif = [[UIFont systemFontOfSize:38 weight:UIFontWeightBold].fontDescriptor
        fontDescriptorWithDesign:UIFontDescriptorSystemDesignSerif];
    UIFont *font = serif ? [UIFont fontWithDescriptor:serif size:38] : [UIFont systemFontOfSize:38 weight:UIFontWeightBold];
    return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleLargeTitle] scaledFontForFont:font];
}
+ (UIFont *)title { return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleTitle1] scaledFontForFont:[UIFont systemFontOfSize:28 weight:UIFontWeightBold]]; }
+ (UIFont *)heading { return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleHeadline] scaledFontForFont:[UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]]; }
+ (UIFont *)body { return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:[UIFont systemFontOfSize:15 weight:UIFontWeightRegular]]; }
+ (UIFont *)caption { return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1] scaledFontForFont:[UIFont systemFontOfSize:12 weight:UIFontWeightRegular]]; }
+ (UIFont *)mono { return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1] scaledFontForFont:[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular]]; }

+ (CGFloat)screenInset { return 20; }
+ (CGFloat)cardRadius { return 16; }

+ (UIButton *)primaryButtonWithTitle:(NSString *)title {
    UIButtonConfiguration *configuration = [UIButtonConfiguration filledButtonConfiguration];
    configuration.title = title;
    configuration.cornerStyle = UIButtonConfigurationCornerStyleMedium;
    configuration.baseBackgroundColor = self.gold;
    configuration.baseForegroundColor = [UIColor colorWithRed:0.08 green:0.065 blue:0.035 alpha:1];
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(14, 18, 14, 18);
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.configuration = configuration;
    button.titleLabel.font = self.heading;
    return button;
}

+ (UIButton *)secondaryButtonWithTitle:(NSString *)title {
    UIButtonConfiguration *configuration = [UIButtonConfiguration tintedButtonConfiguration];
    configuration.title = title;
    configuration.cornerStyle = UIButtonConfigurationCornerStyleMedium;
    configuration.baseBackgroundColor = self.raised;
    configuration.baseForegroundColor = self.text;
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(10, 14, 10, 14);
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.configuration = configuration;
    button.titleLabel.font = self.body;
    return button;
}

+ (void)styleNavigationController:(UINavigationController *)navigation {
    navigation.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    UINavigationBarAppearance *appearance = [UINavigationBarAppearance new];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = self.background;
    appearance.shadowColor = self.hairline;
    appearance.titleTextAttributes = @{NSForegroundColorAttributeName: self.text};
    appearance.largeTitleTextAttributes = @{NSForegroundColorAttributeName: self.text};
    navigation.navigationBar.standardAppearance = appearance;
    navigation.navigationBar.scrollEdgeAppearance = appearance;
    navigation.navigationBar.compactAppearance = appearance;
    navigation.navigationBar.tintColor = self.gold;
    navigation.navigationBar.prefersLargeTitles = NO;
}

+ (void)styleTabBar:(UITabBar *)tabBar {
    UITabBarAppearance *appearance = [UITabBarAppearance new];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = self.surface;
    appearance.shadowColor = self.hairline;
    tabBar.standardAppearance = appearance;
    tabBar.scrollEdgeAppearance = appearance;
    tabBar.tintColor = self.gold;
    tabBar.unselectedItemTintColor = self.muted;
}

@end

@implementation TKPageHeaderView
- (instancetype)initWithTitle:(NSString *)title subtitle:(NSString *)subtitle {
    if (!(self = [super initWithFrame:CGRectMake(0, 0, 320, 92)])) return nil;
    UILabel *heading = [UILabel new];
    UIFontDescriptor *serif = [[UIFont systemFontOfSize:32 weight:UIFontWeightBold].fontDescriptor
        fontDescriptorWithDesign:UIFontDescriptorSystemDesignSerif];
    heading.font = serif ? [UIFont fontWithDescriptor:serif size:32] : [UIFont systemFontOfSize:32 weight:UIFontWeightBold];
    heading.text = title;
    heading.textColor = TKLauncherTheme.text;
    heading.numberOfLines = 1;
    UILabel *detail = [UILabel new];
    detail.font = TKLauncherTheme.body;
    detail.text = subtitle;
    detail.textColor = TKLauncherTheme.muted;
    detail.numberOfLines = 0;
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[heading, detail]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 4;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:self.topAnchor constant:18],
        [stack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-10],
        [stack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20]
    ]];
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    return self;
}
@end

UIImage *TKLauncherHeroImage(void) {
    static UIImage *image;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *path=[NSBundle.mainBundle pathForResource:@"HeroForever" ofType:@"jpg"];
        if (!path) path=[NSBundle.mainBundle pathForResource:@"HeroForever" ofType:@"png"];
        image=path?[UIImage imageWithContentsOfFile:path]:[UIImage imageNamed:@"HeroForever"];
    });
    return image;
}

@implementation TKPageBackgroundView {
    UIImageView *_image;
    UIView *_overlay;
    CAGradientLayer *_shade;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.backgroundColor = TKLauncherTheme.background;
    _image = [[UIImageView alloc] initWithImage:TKLauncherHeroImage()];
    _image.contentMode = UIViewContentModeScaleAspectFill;
    _image.clipsToBounds = YES;
    _image.alpha = 0.55;
    [self addSubview:_image];
    _overlay = [UIView new];
    _overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.56];
    [self addSubview:_overlay];
    CAGradientLayer *base = [CAGradientLayer layer];
    base.colors = @[(id)[UIColor colorWithRed:0.035 green:0.055 blue:0.11 alpha:1].CGColor,
        (id)[UIColor colorWithRed:0.10 green:0.075 blue:0.18 alpha:1].CGColor,
        (id)[UIColor colorWithRed:0.03 green:0.04 blue:0.08 alpha:1].CGColor];
    base.locations = @[@0, @0.46, @1];
    [self.layer addSublayer:base];
    _shade = [CAGradientLayer layer];
    _shade.colors = @[(id)[UIColor colorWithWhite:0 alpha:0.30].CGColor,
        (id)[UIColor colorWithWhite:0 alpha:0.06].CGColor,
        (id)[UIColor colorWithWhite:0 alpha:0.74].CGColor];
    _shade.locations = @[@0, @0.42, @1];
    [self.layer addSublayer:_shade];
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _image.frame = self.bounds;
    _overlay.frame = self.bounds;
    for (CALayer *layer in self.layer.sublayers) layer.frame = self.bounds;
}

@end

@implementation TKCardView

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.backgroundColor = TKLauncherTheme.surface;
    self.layer.cornerRadius = TKLauncherTheme.cardRadius;
    self.layer.borderWidth = 1;
    self.layer.borderColor = TKLauncherTheme.hairline.CGColor;
    self.layoutMargins = UIEdgeInsetsMake(20, 20, 20, 20);
    _contentView = [UIView new];
    _contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_contentView];
    UILayoutGuide *margins = self.layoutMarginsGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_contentView.topAnchor constraintEqualToAnchor:margins.topAnchor],
        [_contentView.bottomAnchor constraintEqualToAnchor:margins.bottomAnchor],
        [_contentView.leadingAnchor constraintEqualToAnchor:margins.leadingAnchor],
        [_contentView.trailingAnchor constraintEqualToAnchor:margins.trailingAnchor]
    ]];
    return self;
}

- (void)setContentInsets:(UIEdgeInsets)contentInsets {
    _contentInsets = contentInsets;
    self.layoutMargins = contentInsets;
}

@end
