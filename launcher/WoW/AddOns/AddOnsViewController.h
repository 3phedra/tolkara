#import <UIKit/UIKit.h>
#import "AddOnsManager.h"
#import "AddOnsSources.h"

NS_ASSUME_NONNULL_BEGIN

@interface TKAddOnsViewController : UIViewController
- (instancetype)initWithManager:(TKAddOnsManager *)manager sources:(TKAddOnsSources *)sources;
/// The tab shell owns the navigation stack; hide the modal Close button there.
@property(nonatomic) BOOL showsCloseButton;
@end

NS_ASSUME_NONNULL_END
