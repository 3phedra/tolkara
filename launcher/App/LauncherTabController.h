#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@class TKWoWViewController;
@class TKLibraryViewController;

/// The public launcher shell. A Battle.net-style header carries the brand,
/// section navigation and the edition strip; the selected section fills the
/// space below it. Play keeps the artwork behind a translucent header.
@interface TKLauncherTabController : UIViewController
- (instancetype)initWithWoWController:(TKWoWViewController *)wow
                    libraryController:(TKLibraryViewController *)library;
@property(nonatomic, readonly) UINavigationController *playNavigation;
@property(nonatomic, copy, nullable) void (^showDiagnostics)(void);
@property(nonatomic, copy, nullable) void (^showExecutionMode)(void);
- (void)selectPlayTab;
@end
NS_ASSUME_NONNULL_END
