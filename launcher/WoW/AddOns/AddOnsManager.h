#import <Foundation/Foundation.h>
#import "AddOnsModel.h"
#import "AddOnsWorkarounds.h"

NS_ASSUME_NONNULL_BEGIN

extern NSErrorDomain const TKAddOnsManagerErrorDomain;

// Owns the game's AddOns/WTF folders, the ownership manifest, disabled and
// previous copies, and WTF setting backups. Every mutation takes the same
// update lock as the game updater. Call from a background queue.
@interface TKAddOnsManager : NSObject
@property(nonatomic, readonly) NSString *gameDirectory;
@property(nonatomic, readonly) NSString *addOnsDirectory;
@property(nonatomic, readonly) NSString *wtfDirectory;
@property(nonatomic, readonly) NSString *backupDirectory;
// Read from the selected installation's .build.info. The interface is the
// client's add-on API level (for example 1.60.1 -> 16001).
@property(nonatomic, readonly, nullable) NSString *productName;
@property(nonatomic, readonly, nullable) NSString *gameVersion;
@property(nonatomic, readonly, nullable) NSString *buildVersion;
@property(nonatomic, readonly, nullable) NSString *interfaceVersion;
// The flavor key Wago uses for the selected edition: retail, classic, bc,
// wotlk, cata, mop or forever.
@property(nonatomic, readonly, nullable) NSString *wagoFlavor;

- (instancetype)initWithGameDirectory:(NSString *)gameDirectory;
// Injectable paths used by tests; the app uses the initializer above.
- (instancetype)initWithGameDirectory:(NSString *)gameDirectory
                      supportDirectory:(NSString *)supportDirectory
                       backupDirectory:(NSString *)backupDirectory NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (NSArray<TKInstalledAddOn *> *)installedAddOns:(NSError **)error;
// Installs or updates from a local ZIP. `name`/`version` may be empty and are
// then filled from the package's TOC. A disabled package stays disabled.
- (BOOL)installArchive:(NSURL *)archive
                source:(TKAddOnSourceKind)source
            identifier:(NSString *)identifier
                  name:(NSString * _Nullable)name
               version:(NSString * _Nullable)version
               pageURL:(NSString * _Nullable)pageURL
                 error:(NSError **)error;
- (BOOL)removeAddOn:(TKInstalledAddOn *)addOn error:(NSError **)error;
- (BOOL)setEnabled:(BOOL)enabled forAddOn:(TKInstalledAddOn *)addOn error:(NSError **)error;

// Local compatibility patches for installed add-ons. State is kept beside the
// manager, not in the add-on manifest, so it survives add-on updates.
- (NSArray<TKAddOnWorkaround *> *)workarounds:(NSError **)error;
- (BOOL)setWorkaround:(TKAddOnWorkaround *)workaround enabled:(BOOL)enabled error:(NSError **)error;

- (nullable TKAddOnBackup *)createBackup:(NSError **)error;
- (NSArray<TKAddOnBackup *> *)backups;
- (BOOL)restoreBackup:(TKAddOnBackup *)backup error:(NSError **)error;
- (BOOL)deleteBackup:(TKAddOnBackup *)backup error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
