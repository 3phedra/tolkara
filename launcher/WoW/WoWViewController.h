#import <UIKit/UIKit.h>
#import "../App/AppLibrary.h"
#import "../App/ExecutionMode.h"

NS_ASSUME_NONNULL_BEGIN
@class TKLaunchProgressView;
@class TKWoWInstallation;
extern NSNotificationName const TKWoWStateDidChangeNotification;
@interface TKWoWViewController : UIViewController
- (instancetype)initWithLibrary:(TKAppLibrary *)library;
@property(nonatomic, copy, nullable) void (^startApp)(TKApp *app);
@property(nonatomic, copy, nullable) void (^showDiagnostics)(void);
@property(nonatomic, copy, nullable) void (^showSettings)(void);
@property(nonatomic, copy, nullable) void (^showAddOns)(void);
@property(nonatomic, copy, nullable) void (^showExecutionMode)(void);
@property(nonatomic, copy, nullable) void (^showTouchControls)(void);
@property(nonatomic, copy, nullable) void (^showCustomServer)(void);
@property(nonatomic) TKExecutionMode executionMode;
@property(nonatomic) BOOL sessionUsed;
@property(nonatomic, readonly) NSDictionary *product;
@property(nonatomic, readonly, nullable) TKWoWInstallation *installation;
@property(nonatomic, readonly, getter=isBusy) BOOL busy;
@property(nonatomic, readonly, getter=isUpdating) BOOL updating;
@property(nonatomic, readonly) NSString *region;
@property(nonatomic, readonly) NSString *locale;
// Reuse this home screen throughout startup; the runtime retains its execution path.
@property(nonatomic, readonly) UILabel *startupStatusLabel;
@property(nonatomic, readonly) TKLaunchProgressView *launchProgress;
@property(nonatomic, readonly) UIButton *diagnosticsButton;
- (void)beginStartup;
- (void)finishStartupWithMessage:(NSString *)message failed:(BOOL)failed;
- (void)selectProduct:(NSDictionary *)product;
- (void)refresh;
- (void)checkForUpdatesNow;
- (void)repairInstallation;
- (void)performRemovalOfProduct:(NSDictionary *)product;
- (void)performRemoveAllDownloadedData;
- (NSString *)selectedGameDirectory;
- (BOOL)hasDownloadedFilesForProduct:(NSDictionary *)product;
- (BOOL)hasDownloadedData;
- (void)setDownloadRegion:(NSString *)region locale:(NSString *)locale;
@end
NS_ASSUME_NONNULL_END
