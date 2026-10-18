#import <Foundation/Foundation.h>
#import "AddOnsModel.h"

NS_ASSUME_NONNULL_BEGIN

extern NSErrorDomain const TKAddOnsSourcesErrorDomain;

typedef void (^TKAddOnSearchCompletion)(NSArray<TKAddOnSearchResult *> *results, NSArray<NSString *> *messages);

// Network providers. The CurseForge API key is optional and stored in the
// device Keychain; GitHub and Tukui need no credentials. All completions are
// delivered on the main queue.
@interface TKAddOnsSources : NSObject
// The selected game's version (for example 1.60.1). Provider results are
// marked with the interface/version they declare.
@property(nonatomic, copy, nullable) NSString *gameVersion;
// Wago's flavor key for the selected edition: retail, classic, bc, wotlk,
// cata, mop or forever.
@property(nonatomic, copy, nullable) NSString *wagoFlavor;
- (instancetype)initWithGameVersion:(NSString * _Nullable)gameVersion;
- (instancetype)initWithGameVersion:(NSString * _Nullable)gameVersion wagoFlavor:(NSString * _Nullable)wagoFlavor;
+ (nullable NSString *)curseForgeKey;
+ (BOOL)setCurseForgeKey:(nullable NSString *)key error:(NSError **)error;

- (void)search:(NSString *)query completion:(TKAddOnSearchCompletion)completion;
- (void)resolveResult:(TKAddOnSearchResult *)result completion:(void (^)(TKAddOnDownload * _Nullable download, NSError * _Nullable error))completion;
- (void)latestForInstalled:(TKInstalledAddOn *)installed completion:(void (^)(TKAddOnSearchResult * _Nullable result, NSError * _Nullable error))completion;
// A direct GitHub repository row for the curated list, without a search.
- (TKAddOnSearchResult *)githubRepositoryResult:(NSString *)fullName name:(NSString *)name;
@end

NS_ASSUME_NONNULL_END
