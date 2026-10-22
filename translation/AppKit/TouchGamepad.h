#import <UIKit/UIKit.h>
#import <GameController/GameController.h>
@class AKGamepadLayout;

NS_ASSUME_NONNULL_BEGIN
// Radial analog mapping with a small dead zone and clamped magnitude.
CGPoint AKTouchGamepadStickPosition(CGPoint point, CGSize size);
// Owns only our virtual device. Physical controllers and their handlers stay
// with GameController/the guest. No game events or memory are inspected.
@interface AKTouchGamepad : NSObject
- (instancetype)initWithHostView:(UIView *)host;
- (instancetype)initWithHostView:(UIView *)host layout:(nullable AKGamepadLayout *)layout;
@property(nonatomic) BOOL enabled;
// Normally a physical controller takes priority and removes the touch gamepad.
// A controller that reconnects but stops delivering input leaves no fallback,
// so the settings can keep the touch pad available beside it.
@property(nonatomic) BOOL showWithPhysicalController;
@property(nonatomic) BOOL keyboardVisible;
@property(nonatomic, readonly) BOOL visible;
@property(nonatomic, readonly) BOOL configuring;
@property(nonatomic, copy, nullable) void (^visibilityChanged)(BOOL visible);
@property(nonatomic, copy, nullable) void (^toolbarEditingChanged)(BOOL editing);
- (void)refresh;
- (void)toggleSettings;
- (void)invalidate;
@end
NS_ASSUME_NONNULL_END
