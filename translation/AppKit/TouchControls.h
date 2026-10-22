#import <UIKit/UIKit.h>
@class AKGamepadLayout;

@protocol AKTouchControlsDelegate <NSObject>
- (void)touchMoveBy:(CGPoint)delta;
- (void)touchScrollBy:(CGPoint)delta;
- (void)touchTapAt:(CGPoint)point button:(unsigned)button;
- (void)touchButton:(unsigned)button pressed:(BOOL)pressed;
- (void)touchInsertText:(NSString *)text;
// Explicit user-requested replacement of the focused field; no text is read.
- (void)touchReplaceText:(NSString *)text;
- (void)touchSpecialKey:(unsigned short)code characters:(NSString *)characters;
- (void)touchTrackpadChanged:(BOOL)enabled;
- (void)touchKeyboardVisibilityChanged:(BOOL)visible;
- (void)touchGamepadPreferenceChanged:(BOOL)enabled;
- (void)touchControlSettings;
@end

// Optional: the launcher's On-Screen Controls switch stores this Boolean.
// Without a stored choice they are shown on iPhone and not on iPad. A guest
// that focuses a text field installs them on demand even where they default
// off, unless the switch was explicitly turned off.
extern NSString *const AKTouchControlsDefaultsKey;   // "AKTouchControls"

// Toolbar above the guest layer, with a separate native draft panel above
// the keyboard. The host supplies direct touches; hardware mouse input stays
// on its old path, and only the buttons intercept hit testing.
@interface AKTouchControls : UIView <UIKeyInput>
@property (class, nonatomic, readonly) BOOL enabled;
// The switch was set to "off" by hand: do not install the controls on demand.
@property (class, nonatomic, readonly) BOOL explicitlyDisabled;
- (instancetype)initWithFrame:(CGRect)frame layout:(AKGamepadLayout *)layout;
@property (nonatomic, weak) id<AKTouchControlsDelegate> delegate;
@property (nonatomic) BOOL trackpadEnabled;
@property (nonatomic, readonly) BOOL gamepadEnabled;
- (void)setGamepadVisible:(BOOL)visible;
@property (nonatomic, readonly) BOOL keyboardVisible;
- (void)processTouches:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event;
- (void)cancelTouches;
- (void)toggleKeyboard;
- (void)showKeyboard;
// Drives the optional top-bar move affordance from the gamepad edit mode.
- (void)setToolbarEditing:(BOOL)editing;
- (void)dismissKeyboard;
@end
