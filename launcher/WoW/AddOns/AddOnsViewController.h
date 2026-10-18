#import <UIKit/UIKit.h>
#import "AddOnsManager.h"
#import "AddOnsSources.h"

NS_ASSUME_NONNULL_BEGIN

@interface TKAddOnsViewController : UIViewController
- (instancetype)initWithManager:(TKAddOnsManager *)manager sources:(TKAddOnsSources *)sources;
@end

NS_ASSUME_NONNULL_END
