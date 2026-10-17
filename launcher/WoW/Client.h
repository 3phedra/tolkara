#import <Foundation/Foundation.h>
#import "Manifest.h"

NS_ASSUME_NONNULL_BEGIN
// Identifier of the app-wide background download session. The app delegate
// forwards application:handleEventsForBackgroundURLSession:completionHandler:
// for this identifier so pending downloads are adopted after a relaunch.
extern NSString *const TKWoWBackgroundSessionIdentifier;
// Synchronous, bounded requests: call on a worker queue, never UIKit's main thread.
// A client performs one operation at a time. cancel is safe from another thread.
@interface TKWoWClient : NSObject
+ (void)handleBackgroundEventsWithCompletion:(void (^)(void))completion;
- (void)cancel;
// Session hand-off: foreground transfers run at full speed, background ones
// keep running while the app is suspended. No-op while a client is idle.
- (void)backgrounded;
- (void)foregrounded;
@property(nonatomic, readonly) BOOL cancelled;
@property(nonatomic, copy, nullable) void (^progress)(NSString *phase, uint64_t done, uint64_t total);
- (nullable NSData *)configuration:(NSString *)key cdn:(NSString *)cdn error:(NSError **)error;
- (nullable NSData *)manifest:(NSString *)name config:(NSDictionary *)config cdn:(NSString *)cdn error:(NSError **)error;
- (nullable NSData *)encodingForPlan:(NSDictionary *)plan directory:(NSString *)directory error:(NSError **)error;
- (nullable NSData *)encodedKey:(NSString *)key size:(uint64_t)size plan:(NSDictionary *)plan
    indices:(NSString *)indices error:(NSError **)error;
// Groups adjacent archive objects into bounded ranges. The consumer receives
// only checksum-verified original encoded bytes, serially on the calling queue.
- (BOOL)downloadEntries:(NSData *)entries plan:(NSDictionary *)plan indices:(NSString *)indices
    consume:(BOOL (^)(NSData *data, NSString *key, NSError **error))consume error:(NSError **)error;
- (nullable NSDictionary *)versionForProduct:(NSString *)product region:(NSString *)region error:(NSError **)error;
// Fetches and verifies the build configuration and install manifest. Does not install a game.
- (nullable NSDictionary *)planForProduct:(NSString *)product region:(NSString *)region
    locale:(NSString *)locale error:(NSError **)error;
// Experimental extraction of one original install file to an isolated staging directory.
// Fetches the encoding manifest (can be large), with verified archive-range fallback.
- (nullable NSString *)stageFile:(NSDictionary *)file plan:(NSDictionary *)plan
    directory:(NSString *)directory error:(NSError **)error;
@end
NS_ASSUME_NONNULL_END
