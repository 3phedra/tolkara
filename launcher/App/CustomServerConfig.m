#import "CustomServerConfig.h"

// Defined by Diagnostics.m in the app; a test links its own definition.
extern NSString *TKDocumentsPath(NSString *name);

static const NSInteger TKCustomServerDefaultGroup = 8;

@implementation TKCustomServerConfig

+ (NSString *)configurationPath {
    // The tests keep their fixture out of the user's Documents.
    const char *override = getenv("TOLKARA_CUSTOM_SERVER_CONFIG");
    if (override && *override) return @(override);
    return TKDocumentsPath(@"CustomServer.plist");
}

+ (instancetype)current {
    TKCustomServerConfig *config = [self new];
    NSDictionary *values = [NSDictionary dictionaryWithContentsOfFile:self.configurationPath];
    config.enabled = [values[@"Enabled"] boolValue];
    NSString *portal = values[@"Portal"];
    config.portal = [portal isKindOfClass:NSString.class] ? portal : @"";
    NSString *key = values[@"Key"];
    config.keyHex = [key isKindOfClass:NSString.class] && [self validKey:key] ? key.uppercaseString : @"";
    NSInteger group = [values[@"Group"] integerValue];
    config.group = group >= 1 && group <= 12 ? group : TKCustomServerDefaultGroup;
    NSString *original = values[@"OriginalPortal"];
    config.originalPortal = [original isKindOfClass:NSString.class] && original.length ? original : nil;
    return config;
}

+ (BOOL)validKey:(NSString *)key {
    if (![key isKindOfClass:NSString.class] || key.length != 64) return NO;
    for (NSUInteger i = 0; i < key.length; i++) {
        unichar c = [key characterAtIndex:i];
        if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F'))) return NO;
    }
    return YES;
}

- (BOOL)isUsable {
    return self.enabled && self.portal.length && [TKCustomServerConfig validKey:self.keyHex] &&
        self.group >= 1 && self.group <= 12;
}

static NSString *NormalizedPortal(NSString *portal) {
    if (![portal isKindOfClass:NSString.class]) return @"";
    NSString *value = [portal stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if ([value.lowercaseString hasPrefix:@"https://"]) value = [value substringFromIndex:8];
    else if ([value.lowercaseString hasPrefix:@"http://"]) value = [value substringFromIndex:7];
    NSRange slash = [value rangeOfString:@"/"];
    if (slash.location != NSNotFound) value = [value substringToIndex:slash.location];
    return value;
}

- (BOOL)save:(NSError **)error {
    self.portal = NormalizedPortal(self.portal ?: @"");
    NSMutableDictionary *values = [@{@"Enabled": @(self.enabled),
                                     @"Portal": self.portal ?: @"",
                                     @"Key": self.keyHex ?: @"",
                                     @"Group": @(self.group)} mutableCopy];
    if (self.originalPortal.length) values[@"OriginalPortal"] = self.originalPortal;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:values format:NSPropertyListXMLFormat_v1_0 options:0 error:error];
    if (!data) return NO;
    return [data writeToFile:self.class.configurationPath options:NSDataWritingAtomic error:error];
}

static NSArray<NSString *> *Lines(NSString *contents) {
    NSMutableArray<NSString *> *lines = [contents componentsSeparatedByString:@"\n"].mutableCopy;
    for (NSUInteger i = 0; i < lines.count; i++)
        if ([lines[i] hasSuffix:@"\r"]) lines[i] = [lines[i] substringToIndex:lines[i].length - 1];
    if (lines.count && lines.lastObject.length == 0) [lines removeLastObject];
    return lines;
}

static NSString *PortalValue(NSString *contents) {
    for (NSString *line in Lines(contents)) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (trimmed.length < 12 || ![trimmed.uppercaseString hasPrefix:@"SET PORTAL "]) continue;
        NSString *value = [[trimmed substringFromIndex:11] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (value.length >= 2 && [value hasPrefix:@"\""] && [value hasSuffix:@"\""])
            value = [value substringWithRange:NSMakeRange(1, value.length - 2)];
        if (value.length) return value;
    }
    return nil;
}

static NSString *ContentsWithPortal(NSString *contents, NSString *portal) {
    NSString *newline = [contents rangeOfString:@"\r\n"].location != NSNotFound ? @"\r\n" : @"\n";
    NSMutableArray<NSString *> *lines = Lines(contents).mutableCopy;
    BOOL replaced = NO, hasTextLocale = NO, hasAudioLocale = NO, hasAgent = NO;
    for (NSUInteger i = 0; i < lines.count; i++) {
        NSString *trimmed = [lines[i] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        NSString *upper = trimmed.uppercaseString;
        if ([upper hasPrefix:@"SET PORTAL "]) {
            if (!replaced) { lines[i] = [NSString stringWithFormat:@"SET portal \"%@\"", portal]; replaced = YES; }
            else lines[i] = @"";
        } else if ([upper hasPrefix:@"SET TEXTLOCALE "]) {
            hasTextLocale = YES;
        } else if ([upper hasPrefix:@"SET AUDIOLOCALE "]) {
            hasAudioLocale = YES;
        } else if ([upper hasPrefix:@"SET AGENTUID "]) {
            hasAgent = YES;
        }
    }
    if (!replaced) [lines addObject:[NSString stringWithFormat:@"SET portal \"%@\"", portal]];
    if (!hasTextLocale) [lines addObject:@"SET textLocale \"enUS\""];
    if (!hasAudioLocale) [lines addObject:@"SET audioLocale \"enUS\""];
    // The beta's product identifier; Battle.net writes it on a Mac, and a
    // fresh config from this launcher otherwise leaves the client to default it.
    if (!hasAgent) [lines addObject:@"SET agentUID \"wow_classic_beta\""];
    return [[lines componentsJoinedByString:newline] stringByAppendingString:newline];
}

- (BOOL)applyToGameDirectory:(NSString *)directory error:(NSError **)error {
    if (!directory.length) return YES;
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *wtf = [directory stringByAppendingPathComponent:@"WTF"];
    NSString *path = [wtf stringByAppendingPathComponent:@"Config.wtf"];
    BOOL exists = [fm fileExistsAtPath:path];
    NSString *contents = exists ? [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL] : nil;
    if (!contents) contents = @"";
    if (self.enabled) {
        self.portal = NormalizedPortal(self.portal ?: @"");
        if (!self.portal.length) return YES;   // not configured: leave Config.wtf alone
        if (!self.originalPortal) {
            // A fresh beta config has no portal yet; "test" is the value the
            // launcher writes for this product, so disabling returns to it.
            self.originalPortal = PortalValue(contents) ?: @"test";
            if (![self save:error]) return NO;
        }
        contents = ContentsWithPortal(contents, self.portal);
    } else {
        if (!self.originalPortal || !exists) return YES;
        contents = ContentsWithPortal(contents, self.originalPortal);
        self.originalPortal = nil;
        if (![self save:error]) return NO;
    }
    if (![fm createDirectoryAtPath:wtf withIntermediateDirectories:YES attributes:nil error:error]) return NO;
    return [contents writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:error];
}

@end
