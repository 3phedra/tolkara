#import "CustomServerConfig.h"
#include <assert.h>
#include <stdlib.h>

// The launcher test links this file without Diagnostics.m; the override above
// keeps the fixture out of the real Documents.
NSString *TKDocumentsPath(NSString *name) {
    return [NSTemporaryDirectory() stringByAppendingPathComponent:name];
}

static NSString *Read(NSString *path) {
    return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
}

int main(void) {
    @autoreleasepool {
        NSFileManager *fm = NSFileManager.defaultManager;
        NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        NSString *configPath = [tmp stringByAppendingPathComponent:@"CustomServer.plist"];
        NSString *game = [tmp stringByAppendingPathComponent:@"game"];
        NSString *wtf = [game stringByAppendingPathComponent:@"WTF"];
        NSString *settings = [wtf stringByAppendingPathComponent:@"Config.wtf"];
        assert([fm createDirectoryAtPath:wtf withIntermediateDirectories:YES attributes:nil error:NULL]);
        setenv("TOLKARA_CUSTOM_SERVER_CONFIG", configPath.fileSystemRepresentation, 1);
        [@"SET portal \"eu\"\r\nSET textLocale \"enUS\"\r\nSET gxWindowed \"1\"\r\n"
            writeToFile:settings atomically:YES encoding:NSUTF8StringEncoding error:NULL];

        NSString *key = @"00112233445566778899AABBCCDDEEFF00112233445566778899AABBCCDDEEFF";

        TKCustomServerConfig *config = [TKCustomServerConfig current];
        assert(!config.enabled);
        assert(config.portal.length == 0);
        assert(config.keyHex.length == 0);
        assert(config.group == 8);
        assert(![config isUsable]);
        assert([TKCustomServerConfig validKey:key]);
        assert(![TKCustomServerConfig validKey:@"0259"]);
        NSString *badKey = [[key substringToIndex:63] stringByAppendingString:@"G"];
        assert(![TKCustomServerConfig validKey:badKey]);

        NSError *error = nil;
        config.enabled = YES;
        config.portal = @"https://auth.example.com/";
        config.keyHex = key;
        assert([config isUsable]);
        assert([config save:&error]);
        assert([config.portal isEqualToString:@"auth.example.com"]);
        assert([config applyToGameDirectory:game error:&error]);
        NSString *customContents = Read(settings);
        assert([customContents containsString:@"SET portal \"auth.example.com\"\r\n"]);
        assert([customContents containsString:@"SET gxWindowed \"1\"\r\n"]);
        assert([customContents containsString:@"SET textLocale \"enUS\"\r\n"]);
        assert(config.originalPortal != nil && [config.originalPortal isEqualToString:@"eu"]);

        // What is on disk reloads as the same enabled configuration.
        TKCustomServerConfig *reloaded = [TKCustomServerConfig current];
        assert(reloaded.enabled);
        assert([reloaded.portal isEqualToString:@"auth.example.com"]);
        assert([reloaded.keyHex isEqualToString:key]);
        assert(reloaded.group == 8);
        assert([reloaded isUsable]);
        assert([reloaded.originalPortal isEqualToString:@"eu"]);

        config.enabled = NO;
        assert([config save:&error]);
        assert([config applyToGameDirectory:game error:&error]);
        NSString *restored = Read(settings);
        assert([restored containsString:@"SET portal \"eu\"\r\n"]);
        assert([restored containsString:@"SET gxWindowed \"1\"\r\n"]);
        assert(config.originalPortal == nil);

        // A missing file is created with the beta's required locale settings.
        [fm removeItemAtPath:settings error:NULL];
        config.enabled = YES;
        config.portal = @"auth.example.com";
        config.keyHex = key;
        assert([config applyToGameDirectory:game error:&error]);
        NSString *created = Read(settings);
        assert([created containsString:@"SET portal \"auth.example.com\""]);
        assert([created containsString:@"SET textLocale \"enUS\""]);
        assert([created containsString:@"SET audioLocale \"enUS\""]);
        assert([created containsString:@"SET agentUID \"wow_classic_beta\""]);

        [fm removeItemAtPath:tmp error:NULL];
        printf("custom server config: ok\n");
    }
    return 0;
}
