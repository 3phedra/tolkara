#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@class TKWoWViewController;

/// The launcher's persistent settings destination. It reads the same WoW
/// controller the Play tab uses, so edition changes and update state are not
/// duplicated here.
@interface TKSettingsViewController : UITableViewController
- (instancetype)initWithWoWController:(TKWoWViewController *)wow;
@property(nonatomic, copy, nullable) void (^showDiagnostics)(void);
@property(nonatomic, copy, nullable) void (^showExecutionMode)(void);
@property(nonatomic, copy, nullable) void (^showLibrary)(void);
@property(nonatomic, copy, nullable) void (^showAddOns)(void);
@property(nonatomic, copy, nullable) void (^showPlay)(void);
@end
NS_ASSUME_NONNULL_END
