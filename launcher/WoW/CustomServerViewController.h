#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
/// The Forever beta's custom auth server: portal, certificate key and group.
/// Saves to Documents/CustomServer.plist and applies the portal to Config.wtf.
@interface TKCustomServerViewController : UITableViewController
- (instancetype)initWithGameDirectory:(nullable NSString *)directory;
@property(nonatomic, copy, nullable) void (^onSave)(void);
@end
NS_ASSUME_NONNULL_END
