#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TKAddOnSourceKind) {
    TKAddOnSourceLocal = 0,
    TKAddOnSourceTukui,
    TKAddOnSourceCurseForge,
    TKAddOnSourceGitHub,
    TKAddOnSourceImport,
    TKAddOnSourceWago,
};

NSString *TKAddOnSourceName(TKAddOnSourceKind source);
NSString *TKAddOnSourceKey(TKAddOnSourceKind source);
TKAddOnSourceKind TKAddOnSourceFromKey(NSString *key);

// One row in Discover. `payload` is source-private JSON used to resolve the
// immutable download later; never display it.
@interface TKAddOnSearchResult : NSObject
@property(nonatomic) TKAddOnSourceKind source;
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy) NSString *author;
@property(nonatomic, copy) NSString *summary;
@property(nonatomic, copy) NSString *version;
@property(nonatomic, copy, nullable) NSString *pageURL;
@property(nonatomic, strong, nullable) NSURL *directURL;
@property(nonatomic, strong, nullable) NSDictionary *payload;
@property(nonatomic, copy) NSArray<NSString *> *dependencyNames;
@property(nonatomic) BOOL compatible;
@property(nonatomic, copy, nullable) NSString *compatibilityNote;
@end

// A resolved package with a local archive, plus required packages that must be
// installed first.
@interface TKAddOnDownload : NSObject
@property(nonatomic, strong) NSURL *archiveURL;
@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy) NSString *version;
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy, nullable) NSString *pageURL;
@property(nonatomic) TKAddOnSourceKind source;
@property(nonatomic, copy) NSArray<TKAddOnDownload *> *dependencies;
@end

@interface TKInstalledAddOn : NSObject
@property(nonatomic, copy) NSString *packageID;
@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy) NSString *version;
@property(nonatomic, copy) NSString *interfaceVersion;
@property(nonatomic, copy) NSArray<NSString *> *folders;
@property(nonatomic) TKAddOnSourceKind source;
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy, nullable) NSString *pageURL;
@property(nonatomic) BOOL managed;
@property(nonatomic) BOOL enabled;
@property(nonatomic, strong, nullable) TKAddOnSearchResult *update;
@property(nonatomic) BOOL compatible;
@end

@interface TKAddOnBackup : NSObject
@property(nonatomic, strong) NSURL *url;
@property(nonatomic, strong) NSDate *date;
@property(nonatomic) unsigned long long size;
@end

NS_ASSUME_NONNULL_END
