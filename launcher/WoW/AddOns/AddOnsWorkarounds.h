#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TKAddOnWorkaroundState) {
    TKAddOnWorkaroundStateNotInstalled = 0,
    TKAddOnWorkaroundStateDisabled,
    TKAddOnWorkaroundStateApplied,
    TKAddOnWorkaroundStatePartial,
    TKAddOnWorkaroundStateIncompatible,
};

@interface TKAddOnWorkaroundPatch : NSObject
@property(nonatomic, copy) NSString *path;
@property(nonatomic, copy) NSString *find;
@property(nonatomic, copy) NSString *replace;
@property(nonatomic, copy) NSString *marker;
@property(nonatomic) BOOL optional;
+ (instancetype)patchPath:(NSString *)path
                     find:(NSString *)find
                  replace:(NSString *)replace
                   marker:(NSString *)marker;
+ (instancetype)patchPath:(NSString *)path
                     find:(NSString *)find
                  replace:(NSString *)replace
                   marker:(NSString *)marker
                 optional:(BOOL)optional;
@end

@interface TKAddOnWorkaround : NSObject
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy) NSString *summary;
@property(nonatomic, copy) NSArray<NSString *> *targetFolders;
@property(nonatomic, copy) NSString *targetVersionPrefix;
@property(nonatomic) BOOL defaultEnabled;
@property(nonatomic) BOOL enabled;
@property(nonatomic) TKAddOnWorkaroundState state;
@property(nonatomic, copy, nullable) NSString *stateDetail;
@property(nonatomic, copy) NSArray<TKAddOnWorkaroundPatch *> *patches;

+ (NSArray<TKAddOnWorkaround *> *)builtInWorkarounds;
- (TKAddOnWorkaroundState)stateInDirectory:(NSString *)directory detail:(NSString * _Nullable * _Nullable)detail;
- (BOOL)applyInDirectory:(NSString *)directory error:(NSError **)error;
- (BOOL)revertInDirectory:(NSString *)directory error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
