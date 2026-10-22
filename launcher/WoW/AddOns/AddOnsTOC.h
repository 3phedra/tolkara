#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// The metadata in an add-on's .toc file. The manager uses it to name an
// installed add-on, show its version and match it to a download source.
@interface TKAddOnTOC : NSObject
@property(nonatomic, readonly) NSString *path;
@property(nonatomic, readonly) NSString *folder;
@property(nonatomic, readonly) NSString *title;
@property(nonatomic, readonly) NSString *version;
@property(nonatomic, readonly) NSString *interfaceVersion;
@property(nonatomic, readonly) NSArray<NSString *> *interfaceVersions;
@property(nonatomic, readonly, nullable) NSString *curseProjectID;
@property(nonatomic, readonly, nullable) NSString *tukuiProjectID;
@property(nonatomic, readonly, nullable) NSString *wowiID;
@property(nonatomic, readonly) NSDictionary<NSString *, NSString *> *fields;

// The path of `fullPath` below `rootPath`, tolerating the /private firmlink
// prefix the filesystem enumerator may add. Returns nil when it is not below.
NSString * _Nullable TKAddOnsRelativePath(NSString *fullPath, NSString *rootPath);

+ (nullable instancetype)tocAtPath:(NSString *)path;
// TOCs under `directory`, at most `depth` directory levels below it. Hidden
// files are skipped. The result is sorted by path.
+ (NSArray<TKAddOnTOC *> *)tocsInDirectory:(NSString *)directory maxDepth:(NSInteger)depth;
@end

NS_ASSUME_NONNULL_END
