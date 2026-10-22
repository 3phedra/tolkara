#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Colours, type and the few shapes every launcher screen shares.
/// Screens read tokens from here instead of inventing their own palette.
@interface TKLauncherTheme : NSObject
@property(class, nonatomic, readonly) UIColor *background;
@property(class, nonatomic, readonly) UIColor *surface;
@property(class, nonatomic, readonly) UIColor *raised;
@property(class, nonatomic, readonly) UIColor *text;
@property(class, nonatomic, readonly) UIColor *muted;
@property(class, nonatomic, readonly) UIColor *gold;
@property(class, nonatomic, readonly) UIColor *accent;
@property(class, nonatomic, readonly) UIColor *success;
@property(class, nonatomic, readonly) UIColor *danger;
@property(class, nonatomic, readonly) UIColor *hairline;

@property(class, nonatomic, readonly) UIFont *wordmark;
@property(class, nonatomic, readonly) UIFont *title;
@property(class, nonatomic, readonly) UIFont *heading;
@property(class, nonatomic, readonly) UIFont *body;
@property(class, nonatomic, readonly) UIFont *caption;
@property(class, nonatomic, readonly) UIFont *mono;

@property(class, nonatomic, readonly) CGFloat screenInset;
@property(class, nonatomic, readonly) CGFloat cardRadius;

+ (UIButton *)primaryButtonWithTitle:(NSString *)title;
+ (UIButton *)secondaryButtonWithTitle:(NSString *)title;
+ (void)styleNavigationController:(UINavigationController *)navigation;
+ (void)styleTabBar:(UITabBar *)tabBar;
@end

/// A surface card. Add subviews to `contentView`, not the card itself, so the
/// internal padding stays consistent when the card grows.
@interface TKCardView : UIView
@property(nonatomic, readonly) UIView *contentView;
@property(nonatomic) UIEdgeInsets contentInsets;
@end

/// A large serif page title with a muted subtitle, used as a table header by
/// the Add-ons, Library and Settings destinations so they match the shell.
@interface TKPageHeaderView : UIView
- (instancetype)initWithTitle:(NSString *)title subtitle:(NSString *)subtitle;
@end

/// A dimmed copy of the Play artwork for the content destinations, so the
/// Add-ons, Library and Settings pages share the same visual language.
@interface TKPageBackgroundView : UIView
@end

/// The background artwork. It is copied as a plain bundle resource so it
/// loads on every device scale without relying on an asset-catalog rendition.
FOUNDATION_EXPORT UIImage * _Nullable TKLauncherHeroImage(void);

NS_ASSUME_NONNULL_END
