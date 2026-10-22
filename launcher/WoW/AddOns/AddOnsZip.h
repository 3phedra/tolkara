#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Bounded ZIP support for add-on packages and WTF setting backups.
//
// Extraction rejects traversal, absolute paths, symlinks/special files,
// duplicate (case-insensitive) names, encrypted entries, unsupported methods,
// and archives beyond a conservative size/entry budget. Creation writes a
// normal ZIP with deflate (or store when deflate is larger).
@interface TKAddOnsZip : NSObject
+ (BOOL)extractArchiveAtURL:(NSURL *)archiveURL
                toDirectory:(NSString *)destination
                      error:(NSError **)error;
// Archives the contents of `sourceDirectory` below `rootName` (a non-empty
// path prefix such as "WTF" or an add-on folder name).
+ (BOOL)createArchiveAtURL:(NSURL *)archiveURL
             fromDirectory:(NSString *)sourceDirectory
                  rootName:(NSString *)rootName
                     error:(NSError **)error;
@end

extern NSErrorDomain const TKAddOnsZipErrorDomain;

NS_ASSUME_NONNULL_END
