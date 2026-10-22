#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// A custom server's auth portal, the Ed25519 key its login certificate uses,
// and the client certificate group to replace. There are no built-in server
// values: the user enters all three in Settings, and they are stored at
// Documents/CustomServer.plist. The key is public material; it replaces one
// of the client's trusted server keys in memory for this session only. The
// launcher writes the portal into the game's WTF/Config.wtf and keeps the
// previous value to restore.
@interface TKCustomServerConfig : NSObject
@property(nonatomic) BOOL enabled;
@property(nonatomic, copy) NSString *portal;
@property(nonatomic, copy) NSString *keyHex;
@property(nonatomic) NSInteger group;
// The portal value from before the first enable, if one was found.
@property(nonatomic, copy, nullable) NSString *originalPortal;

+ (instancetype)current;
+ (NSString *)configurationPath;
+ (BOOL)validKey:(NSString *)key;
// Enabled and fully configured: a portal is present, the key is 64 hex digits
// and the group is 1..12.
- (BOOL)isUsable;
- (BOOL)save:(NSError **)error;
// Edits WTF/Config.wtf in `directory` (the game's working directory): when
// enabled, sets the portal and remembers the old one; when disabled, restores
// it. Creates the file with the beta's locale defaults when absent.
- (BOOL)applyToGameDirectory:(NSString *)directory error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
