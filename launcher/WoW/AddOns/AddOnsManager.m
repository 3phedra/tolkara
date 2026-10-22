#import "AddOnsManager.h"
#import "AddOnsTOC.h"
#import "AddOnsZip.h"
#import "../Manifest.h"
#import <sys/file.h>
#import <sys/stat.h>
#import <fcntl.h>
#import <stdio.h>
#import <unistd.h>

NSErrorDomain const TKAddOnsManagerErrorDomain = @"TKAddOnsManagerErrorDomain";

static NSString *const TKAddOnsManifestName = @".wolkara-addons.json";

static NSError *TKAddOnsError(NSString *message) {
    return [NSError errorWithDomain:TKAddOnsManagerErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey:message}];
}

static NSString *TKAddOnsSafeComponent(NSString *value) {
    NSString *result = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    result = [result stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
    result = [result stringByReplacingOccurrencesOfString:@":" withString:@"-"];
    result = [result stringByReplacingOccurrencesOfString:@"\\" withString:@"-"];
    while ([result hasPrefix:@"."]) result = [result substringFromIndex:1];
    if (!result.length) result = @"Addon";
    return result;
}

static NSString *TKAddOnsStamp(void) {
    static NSDateFormatter *formatter;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        formatter = [NSDateFormatter new];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.dateFormat = @"yyyy-MM-dd_HH-mm-ss";
    });
    return [formatter stringFromDate:[NSDate date]];
}

@implementation TKAddOnsManager {
    NSString *_supportDirectory;
}

- (instancetype)initWithGameDirectory:(NSString *)gameDirectory {
    NSString *support = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"Wolkara/AddOns"];
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    return [self initWithGameDirectory:gameDirectory supportDirectory:support backupDirectory:[documents stringByAppendingPathComponent:@"Add-On Backups"]];
}

- (instancetype)initWithGameDirectory:(NSString *)gameDirectory supportDirectory:(NSString *)supportDirectory backupDirectory:(NSString *)backupDirectory {
    if ((self = [super init])) {
        _gameDirectory = gameDirectory.copy;
        _addOnsDirectory = [gameDirectory stringByAppendingPathComponent:@"Interface/AddOns"];
        _wtfDirectory = [gameDirectory stringByAppendingPathComponent:@"WTF"];
        _supportDirectory = supportDirectory.copy;
        _backupDirectory = backupDirectory.copy;
        [self loadGameTarget];
    }
    return self;
}

- (void)loadGameTarget {
    NSDictionary<NSString *, NSString *> *productNames = @{
        @"_retail_": @"Retail",
        @"_classic_": @"Classic",
        @"_classic_era_": @"Classic Era",
        @"_classic_beta_": @"Forever Beta",
        @"_forever_": @"Forever",
    };
    NSDictionary<NSString *, NSString *> *productIDs = @{
        @"_retail_": @"wow",
        @"_classic_": @"wow_classic",
        @"_classic_era_": @"wow_classic_era",
        @"_classic_beta_": @"wow_classic_beta",
        @"_forever_": @"wowf",
    };
    NSString *folder = self.gameDirectory.lastPathComponent;
    _productName = productNames[folder] ?: folder;
    if ([folder isEqualToString:@"_retail_"]) _wagoFlavor = @"retail";
    else if ([folder isEqualToString:@"_classic_era_"]) _wagoFlavor = @"classic";
    else if ([folder isEqualToString:@"_classic_beta_"] || [folder isEqualToString:@"_forever_"]) _wagoFlavor = @"forever";
    NSString *wantedProduct = productIDs[folder];
    NSArray<NSString *> *paths = @[
        [self.gameDirectory.stringByDeletingLastPathComponent stringByAppendingPathComponent:@".build.info"],
        [self.gameDirectory stringByAppendingPathComponent:@".build.info"]
    ];
    for (NSString *path in paths) {
        NSData *data = [NSData dataWithContentsOfFile:path];
        NSArray *rows = data ? TKWoWTable(data, NULL) : nil;
        for (NSDictionary *row in rows) {
            if (wantedProduct.length && ![row[@"Product"] isEqual:wantedProduct]) continue;
            if (![row[@"Active"] isEqual:@"1"] || ![row[@"Version"] length]) continue;
            NSString *version = row[@"Version"];
            NSArray<NSString *> *parts = [version componentsSeparatedByString:@"."];
            if (parts.count < 3) continue;
            NSInteger major = parts[0].integerValue;
            NSInteger minor = parts[1].integerValue;
            NSInteger patch = parts[2].integerValue;
            _gameVersion = [NSString stringWithFormat:@"%ld.%ld.%ld", (long)major, (long)minor, (long)patch];
            _buildVersion = parts.count > 3 ? parts[3] : nil;
            _interfaceVersion = [NSString stringWithFormat:@"%ld", (long)(major * 10000 + minor * 100 + patch)];
            if ([folder isEqualToString:@"_classic_"]) {
                _wagoFlavor = major >= 5 ? @"mop" : major == 4 ? @"cata" : major == 3 ? @"wotlk" : major == 2 ? @"bc" : @"classic";
            }
            return;
        }
    }
}

- (BOOL)tocIsCompatible:(TKAddOnTOC *)toc {
    if (!self.interfaceVersion.length || !toc.interfaceVersions.count) return YES;
    return [toc.interfaceVersions containsObject:self.interfaceVersion];
}

- (NSString *)interfaceForTOC:(TKAddOnTOC *)toc {
    if (self.interfaceVersion.length && [toc.interfaceVersions containsObject:self.interfaceVersion]) return self.interfaceVersion;
    return toc.interfaceVersion ?: @"";
}

- (NSString *)manifestPath {
    return [self.addOnsDirectory stringByAppendingPathComponent:TKAddOnsManifestName];
}

- (NSString *)disabledDirectory {
    return [_supportDirectory stringByAppendingPathComponent:@"Disabled"];
}

- (NSString *)previousDirectory {
    return [_supportDirectory stringByAppendingPathComponent:@"Previous"];
}

- (NSString *)stagingDirectory {
    return [_supportDirectory stringByAppendingPathComponent:@"Staging"];
}

- (int)acquireLock:(NSError **)error {
    NSString *gameRoot = self.gameDirectory.stringByDeletingLastPathComponent;
    NSString *documents = gameRoot.stringByDeletingLastPathComponent;
    NSString *work = [documents stringByAppendingPathComponent:@".tolkara-updates"];
    NSError *failure = nil;
    if (![NSFileManager.defaultManager createDirectoryAtPath:work withIntermediateDirectories:YES attributes:nil error:&failure]) {
        if (error) *error = failure;
        return -1;
    }
    NSString *path = [work stringByAppendingPathComponent:@"update.lock"];
    int fd = open(path.fileSystemRepresentation, O_CREAT | O_RDWR | O_NOFOLLOW, 0600);
    if (fd < 0 || flock(fd, LOCK_EX | LOCK_NB)) {
        if (fd >= 0) close(fd);
        if (error) *error = TKAddOnsError(@"The game is updating. Try again when it finishes.");
        return -1;
    }
    return fd;
}

- (void)releaseLock:(int)fd {
    if (fd >= 0) { flock(fd, LOCK_UN); close(fd); }
}

- (NSMutableDictionary *)manifest:(NSError **)error {
    NSData *data = [NSData dataWithContentsOfFile:self.manifestPath];
    if (!data.length) return [@{@"version": @1, @"packages": [NSMutableDictionary dictionary]} mutableCopy];
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (![json isKindOfClass:NSDictionary.class]) {
        if (error && !*error) *error = TKAddOnsError(@"The add-on ownership file is invalid.");
        return nil;
    }
    NSMutableDictionary *manifest = [json mutableCopy];
    if (![manifest[@"packages"] isKindOfClass:NSDictionary.class]) manifest[@"packages"] = [NSMutableDictionary dictionary];
    else manifest[@"packages"] = [manifest[@"packages"] mutableCopy];
    return manifest;
}

- (BOOL)writeManifest:(NSDictionary *)manifest error:(NSError **)error {
    NSData *data = [NSJSONSerialization dataWithJSONObject:manifest options:NSJSONWritingPrettyPrinted error:error];
    if (!data) return NO;
    return [data writeToFile:self.manifestPath options:NSDataWritingAtomic error:error];
}

- (TKAddOnTOC *)primaryTOCForFolders:(NSArray<NSString *> *)folders base:(NSString *)base {
    TKAddOnTOC *fallback = nil;
    for (NSString *folder in folders) {
        NSString *path = [base stringByAppendingPathComponent:folder];
        for (TKAddOnTOC *toc in [TKAddOnTOC tocsInDirectory:path maxDepth:1]) {
            if (!fallback) fallback = toc;
            if (self.interfaceVersion.length && [toc.interfaceVersions containsObject:self.interfaceVersion]) return toc;
        }
    }
    return fallback;
}

- (NSArray<TKInstalledAddOn *> *)installedAddOns:(NSError **)error {
    NSFileManager *fm = NSFileManager.defaultManager;
    BOOL isDirectory = NO;
    if (![fm fileExistsAtPath:self.addOnsDirectory isDirectory:&isDirectory] || !isDirectory) return @[];
    NSMutableDictionary *manifest = [self manifest:error];
    if (!manifest) return nil;
    NSMutableArray<TKInstalledAddOn *> *result = [NSMutableArray new];
    NSMutableSet<NSString *> *claimed = [NSMutableSet new];
    NSDictionary *packages = manifest[@"packages"];
    for (NSString *packageID in packages) {
        NSDictionary *entry = packages[packageID];
        if (![entry isKindOfClass:NSDictionary.class]) continue;
        BOOL enabled = [entry[@"enabled"] boolValue];
        NSArray *folders = [entry[@"folders"] isKindOfClass:NSArray.class] ? entry[@"folders"] : @[];
        NSString *base = enabled ? self.addOnsDirectory : [self.disabledDirectory stringByAppendingPathComponent:packageID];
        NSMutableArray<NSString *> *existing = [NSMutableArray new];
        for (NSString *folder in folders) {
            if (![folder isKindOfClass:NSString.class] || !folder.length) continue;
            if ([fm fileExistsAtPath:[base stringByAppendingPathComponent:folder]]) {
                [existing addObject:folder];
                if (enabled) [claimed addObject:folder];
            }
        }
        if (!existing.count) continue;
        TKAddOnTOC *toc = [self primaryTOCForFolders:existing base:base];
        TKInstalledAddOn *addon = [TKInstalledAddOn new];
        addon.packageID = packageID;
        addon.folders = existing;
        addon.enabled = enabled;
        addon.managed = YES;
        addon.source = TKAddOnSourceFromKey([entry[@"source"] isKindOfClass:NSString.class] ? entry[@"source"] : @"local");
        addon.identifier = [entry[@"identifier"] isKindOfClass:NSString.class] ? entry[@"identifier"] : @"";
        addon.name = [entry[@"name"] isKindOfClass:NSString.class] && [entry[@"name"] length] ? entry[@"name"] : (toc.title ?: existing.firstObject);
        addon.version = [entry[@"version"] isKindOfClass:NSString.class] && [entry[@"version"] length] ? entry[@"version"] : (toc.version ?: @"");
        addon.interfaceVersion = [self interfaceForTOC:toc];
        addon.compatible = [self tocIsCompatible:toc];
        addon.pageURL = [entry[@"pageURL"] isKindOfClass:NSString.class] ? entry[@"pageURL"] : nil;
        [result addObject:addon];
    }
    for (NSString *folder in [fm contentsOfDirectoryAtPath:self.addOnsDirectory error:NULL]) {
        if ([folder hasPrefix:@"."] || [claimed containsObject:folder]) continue;
        BOOL folderIsDirectory = NO;
        NSString *path = [self.addOnsDirectory stringByAppendingPathComponent:folder];
        if (![fm fileExistsAtPath:path isDirectory:&folderIsDirectory] || !folderIsDirectory) continue;
        TKAddOnTOC *toc = [self primaryTOCForFolders:@[folder] base:self.addOnsDirectory];
        if (!toc) continue;
        TKInstalledAddOn *addon = [TKInstalledAddOn new];
        addon.packageID = folder;
        addon.name = toc.title;
        addon.version = toc.version;
        addon.interfaceVersion = [self interfaceForTOC:toc];
        addon.folders = @[folder];
        addon.enabled = YES;
        addon.managed = NO;
        addon.compatible = [self tocIsCompatible:toc];
        if (toc.curseProjectID.length) { addon.source = TKAddOnSourceCurseForge; addon.identifier = toc.curseProjectID; }
        else if (toc.tukuiProjectID.length) { addon.source = TKAddOnSourceTukui; addon.identifier = toc.tukuiProjectID; }
        else { addon.source = TKAddOnSourceLocal; addon.identifier = @""; }
        [result addObject:addon];
    }
    [result sortUsingComparator:^NSComparisonResult(TKInstalledAddOn *a, TKInstalledAddOn *b) {
        return [a.name localizedCaseInsensitiveCompare:b.name];
    }];
    return result;
}

// A package can contain nested .toc files (libraries inside an add-on, or
// Questie's Libs). They belong to the containing add-on; only the shallowest
// TOC level identifies the folders to install. This also prevents two nested
// libraries with the same folder name from looking like conflicting add-ons.
- (NSArray<TKAddOnTOC *> *)topLevelTOCs:(NSArray<TKAddOnTOC *> *)tocs staging:(NSString *)staging {
    NSUInteger minimum = NSUIntegerMax;
    NSMutableArray<NSNumber *> *depths = [NSMutableArray new];
    for (TKAddOnTOC *toc in tocs) {
        NSString *relative = TKAddOnsRelativePath(toc.path.stringByDeletingLastPathComponent, staging);
        if (!relative) { [depths addObject:@(NSUIntegerMax)]; continue; }
        NSUInteger depth = relative.length ? relative.pathComponents.count : 0;
        [depths addObject:@(depth)];
        if (depth < minimum) minimum = depth;
    }
    NSMutableArray<TKAddOnTOC *> *result = [NSMutableArray new];
    for (NSUInteger index = 0; index < tocs.count; index++) {
        if (depths[index].unsignedIntegerValue == minimum) [result addObject:tocs[index]];
    }
    return result;
}

- (NSString *)workaroundsPath {
    return [_supportDirectory stringByAppendingPathComponent:@"Workarounds.json"];
}

- (NSMutableDictionary<NSString *, NSNumber *> *)workaroundEnabledMap {
    NSData *data = [NSData dataWithContentsOfFile:self.workaroundsPath];
    if (!data.length) return [NSMutableDictionary new];
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    if (![json isKindOfClass:NSDictionary.class]) return [NSMutableDictionary new];
    id enabled = json[@"enabled"];
    return [enabled isKindOfClass:NSDictionary.class] ? [enabled mutableCopy] : [NSMutableDictionary new];
}

- (BOOL)writeWorkaroundEnabledMap:(NSDictionary *)map error:(NSError **)error {
    if (![NSFileManager.defaultManager createDirectoryAtPath:_supportDirectory withIntermediateDirectories:YES attributes:nil error:error]) return NO;
    NSData *data = [NSJSONSerialization dataWithJSONObject:@{@"version": @1, @"enabled": map} options:NSJSONWritingPrettyPrinted error:error];
    if (!data) return NO;
    return [data writeToFile:self.workaroundsPath options:NSDataWritingAtomic error:error];
}

- (BOOL)workaround:(TKAddOnWorkaround *)workaround matchesFolders:(NSArray<NSString *> *)folders {
    NSString *target = workaround.targetFolders.firstObject;
    return target.length && [folders containsObject:target];
}

- (void)applyEnabledWorkaroundsForPackageInDirectory:(NSString *)directory folders:(NSArray<NSString *> *)folders {
    NSDictionary<NSString *, NSNumber *> *enabled = [self workaroundEnabledMap];
    for (TKAddOnWorkaround *workaround in [TKAddOnWorkaround builtInWorkarounds]) {
        NSNumber *value = enabled[workaround.identifier];
        BOOL on = value ? value.boolValue : workaround.defaultEnabled;
        if (!on || ![self workaround:workaround matchesFolders:folders]) continue;
        NSError *failure = nil;
        if (![workaround applyInDirectory:directory error:&failure])
            fprintf(stderr, "Tolkara add-ons: workaround %s not applied: %s\n", workaround.identifier.UTF8String, failure.localizedDescription.UTF8String);
    }
}

- (NSArray<TKAddOnWorkaround *> *)workarounds:(NSError **)error {
    NSDictionary<NSString *, NSNumber *> *enabled = [self workaroundEnabledMap];
    NSArray<TKInstalledAddOn *> *installed = [self installedAddOns:error];
    if (!installed) return nil;
    NSMutableArray<TKAddOnWorkaround *> *result = [NSMutableArray new];
    for (TKAddOnWorkaround *workaround in [TKAddOnWorkaround builtInWorkarounds]) {
        NSNumber *value = enabled[workaround.identifier];
        workaround.enabled = value ? value.boolValue : workaround.defaultEnabled;
        TKInstalledAddOn *target = nil;
        for (TKInstalledAddOn *addon in installed) {
            if ([self workaround:workaround matchesFolders:addon.folders]) { target = addon; break; }
        }
        if (!target) {
            workaround.state = TKAddOnWorkaroundStateNotInstalled;
            workaround.stateDetail = @"The target add-on is not installed.";
        } else {
            NSString *base = target.enabled ? self.addOnsDirectory : [self.disabledDirectory stringByAppendingPathComponent:target.packageID];
            NSString *detail = nil;
            workaround.state = [workaround stateInDirectory:base detail:&detail];
            workaround.stateDetail = detail;
        }
        [result addObject:workaround];
    }
    return result;
}

- (BOOL)setWorkaround:(TKAddOnWorkaround *)workaround enabled:(BOOL)enabled error:(NSError **)error {
    int lock = [self acquireLock:error];
    if (lock < 0) return NO;
    @try {
        NSError *failure = nil;
        NSArray<TKInstalledAddOn *> *installed = [self installedAddOns:&failure];
        if (!installed) { if (error) *error = failure; return NO; }
        for (TKInstalledAddOn *addon in installed) {
            if (![self workaround:workaround matchesFolders:addon.folders]) continue;
            NSString *base = addon.enabled ? self.addOnsDirectory : [self.disabledDirectory stringByAppendingPathComponent:addon.packageID];
            BOOL ok = enabled ? [workaround applyInDirectory:base error:&failure] : [workaround revertInDirectory:base error:&failure];
            if (!ok) { if (error) *error = failure; return NO; }
        }
        NSMutableDictionary<NSString *, NSNumber *> *map = [self workaroundEnabledMap];
        map[workaround.identifier] = @(enabled);
        if (![self writeWorkaroundEnabledMap:map error:error]) return NO;
        workaround.enabled = enabled;
        TKInstalledAddOn *target = nil;
        for (TKInstalledAddOn *addon in installed) if ([self workaround:workaround matchesFolders:addon.folders]) { target = addon; break; }
        if (target) {
            NSString *base = target.enabled ? self.addOnsDirectory : [self.disabledDirectory stringByAppendingPathComponent:target.packageID];
            NSString *detail = nil;
            workaround.state = [workaround stateInDirectory:base detail:&detail];
            workaround.stateDetail = detail;
        }
        return YES;
    } @finally {
        [self releaseLock:lock];
    }
}

- (BOOL)installArchive:(NSURL *)archive source:(TKAddOnSourceKind)source identifier:(NSString *)identifier
                  name:(NSString *)name version:(NSString *)version pageURL:(NSString *)pageURL error:(NSError **)error {
    NSFileManager *fm = NSFileManager.defaultManager;
    for (NSString *directory in @[self.addOnsDirectory, self.disabledDirectory, self.previousDirectory, self.stagingDirectory])
        if (![fm createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:error]) return NO;
    int lock = [self acquireLock:error];
    if (lock < 0) return NO;
    NSString *staging = [self.stagingDirectory stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    @try {
        if (![TKAddOnsZip extractArchiveAtURL:archive toDirectory:staging error:error]) return NO;
        NSArray<TKAddOnTOC *> *allTOCs = [TKAddOnTOC tocsInDirectory:staging maxDepth:4];
        if (!allTOCs.count) { if (error) *error = TKAddOnsError(@"The package has no .toc file."); return NO; }
        NSArray<TKAddOnTOC *> *tocs = [self topLevelTOCs:allTOCs staging:staging];
        if (!tocs.count) { if (error) *error = TKAddOnsError(@"The package has no usable add-on folder."); return NO; }
        BOOL declaredInterface = NO, matchingInterface = NO;
        for (TKAddOnTOC *toc in tocs) {
            if (!toc.interfaceVersions.count) continue;
            declaredInterface = YES;
            if ([toc.interfaceVersions containsObject:self.interfaceVersion]) { matchingInterface = YES; break; }
        }
        if (self.interfaceVersion.length && declaredInterface && !matchingInterface) {
            NSMutableArray<NSString *> *declared = [NSMutableArray new];
            for (TKAddOnTOC *toc in tocs) if (toc.interfaceVersions.count) [declared addObject:[toc.interfaceVersions componentsJoinedByString:@"/"]];
            if (error) *error = TKAddOnsError([NSString stringWithFormat:@"This package declares Interface %@; the selected game uses Interface %@.",
                [declared componentsJoinedByString:@", "], self.interfaceVersion]);
            return NO;
        }
        NSMutableDictionary<NSString *, NSMutableArray<TKAddOnTOC *> *> *groups = [NSMutableDictionary new];
        for (TKAddOnTOC *toc in tocs) {
            NSString *parent = toc.path.stringByDeletingLastPathComponent;
            NSString *relative = TKAddOnsRelativePath(parent, staging);
            if (!relative) { if (error) *error = TKAddOnsError(@"The package contains an unsafe path."); return NO; }
            if (!groups[relative]) groups[relative] = [NSMutableArray new];
            [groups[relative] addObject:toc];
        }
        NSMutableArray<NSString *> *folders = [NSMutableArray new];
        NSMutableDictionary<NSString *, NSString *> *sources = [NSMutableDictionary new];
        for (NSString *relative in groups) {
            TKAddOnTOC *toc = groups[relative].firstObject;
            NSString *folder = relative.length ? relative.lastPathComponent : TKAddOnsSafeComponent(toc.title ?: archive.URLByDeletingPathExtension.lastPathComponent);
            folder = TKAddOnsSafeComponent(folder);
            if (sources[folder]) { if (error) *error = TKAddOnsError(@"The package contains two add-ons with the same folder name."); return NO; }
            sources[folder] = relative.length ? [staging stringByAppendingPathComponent:relative] : staging;
            [folders addObject:folder];
        }
        if (!folders.count) { if (error) *error = TKAddOnsError(@"The package contains no add-on folders."); return NO; }
        TKAddOnTOC *primary = nil;
        for (TKAddOnTOC *candidate in tocs) {
            if (self.interfaceVersion.length && [candidate.interfaceVersions containsObject:self.interfaceVersion]) { primary = candidate; break; }
        }
        if (!primary) primary = groups.allValues.firstObject.firstObject;
        if (!name.length) name = primary.title;
        if (!version.length) version = primary.version;
        if (!identifier.length) identifier = [@"import:" stringByAppendingString:folders.firstObject];

        NSMutableDictionary *manifest = [self manifest:error];
        if (!manifest) return NO;
        NSMutableDictionary *packages = manifest[@"packages"];
        NSString *packageID = nil;
        NSDictionary *previousEntry = nil;
        NSString *sourceKey = TKAddOnSourceKey(source);
        for (NSString *candidate in packages) {
            NSDictionary *entry = packages[candidate];
            if (![entry isKindOfClass:NSDictionary.class]) continue;
            if ([entry[@"source"] isEqual:sourceKey] && [entry[@"identifier"] isEqual:identifier]) {
                packageID = candidate; previousEntry = entry; break;
            }
        }
        BOOL enabled = previousEntry ? [previousEntry[@"enabled"] boolValue] : YES;
        if (!packageID) packageID = NSUUID.UUID.UUIDString;
        NSString *target = enabled ? self.addOnsDirectory : [self.disabledDirectory stringByAppendingPathComponent:packageID];
        NSString *other = enabled ? [self.disabledDirectory stringByAppendingPathComponent:packageID] : self.addOnsDirectory;
        if (![fm createDirectoryAtPath:target withIntermediateDirectories:YES attributes:nil error:error]) return NO;
        NSString *previous = [self.previousDirectory stringByAppendingPathComponent:packageID];
        [fm removeItemAtPath:previous error:NULL];
        if (![fm createDirectoryAtPath:previous withIntermediateDirectories:YES attributes:nil error:error]) return NO;
        NSMutableArray<NSArray<NSString *> *> *moved = [NSMutableArray new];
        NSMutableArray<NSString *> *copied = [NSMutableArray new];
        NSArray<NSString *> *oldFolders = [previousEntry[@"folders"] isKindOfClass:NSArray.class] ? previousEntry[@"folders"] : @[];
        for (NSString *folder in folders) {
            for (NSString *base in @[target, other]) {
                NSString *existing = [base stringByAppendingPathComponent:folder];
                if (![fm fileExistsAtPath:existing]) continue;
                NSString *destination = [previous stringByAppendingPathComponent:folder];
                if ([fm fileExistsAtPath:destination]) { if (error) *error = TKAddOnsError(@"The previous package copy already exists."); return NO; }
                if (![fm moveItemAtPath:existing toPath:destination error:error]) return NO;
                [moved addObject:@[existing, destination]];
            }
        }
        for (NSString *folder in oldFolders) {
            if ([folders containsObject:folder]) continue;
            NSString *existing = [target stringByAppendingPathComponent:folder];
            if (![fm fileExistsAtPath:existing]) continue;
            NSString *destination = [previous stringByAppendingPathComponent:folder];
            if ([fm fileExistsAtPath:destination]) continue;
            if (![fm moveItemAtPath:existing toPath:destination error:error]) return NO;
            [moved addObject:@[existing, destination]];
        }
        for (NSString *folder in folders) {
            NSString *destination = [target stringByAppendingPathComponent:folder];
            if (![fm copyItemAtPath:sources[folder] toPath:destination error:error]) {
                for (NSString *path in copied) [fm removeItemAtPath:path error:NULL];
                for (NSArray<NSString *> *pair in moved.reverseObjectEnumerator) [fm moveItemAtPath:pair[1] toPath:pair[0] error:NULL];
                return NO;
            }
            [copied addObject:destination];
        }
        [self applyEnabledWorkaroundsForPackageInDirectory:target folders:folders];
        NSMutableDictionary *entry = [@{@"source": sourceKey, @"identifier": identifier,
            @"name": name ?: folders.firstObject, @"version": version ?: @"",
            @"folders": folders, @"enabled": @(enabled), @"installedAt": @([[NSDate date] timeIntervalSince1970])} mutableCopy];
        if (pageURL.length) entry[@"pageURL"] = pageURL;
        packages[packageID] = entry;
        if (![self writeManifest:manifest error:error]) {
            for (NSString *path in copied) [fm removeItemAtPath:path error:NULL];
            for (NSArray<NSString *> *pair in moved.reverseObjectEnumerator) [fm moveItemAtPath:pair[1] toPath:pair[0] error:NULL];
            return NO;
        }
        return YES;
    } @finally {
        [fm removeItemAtPath:staging error:NULL];
        [self releaseLock:lock];
    }
}

- (BOOL)removeAddOn:(TKInstalledAddOn *)addOn error:(NSError **)error {
    int lock = [self acquireLock:error];
    if (lock < 0) return NO;
    @try {
        NSFileManager *fm = NSFileManager.defaultManager;
        if (!addOn.managed) {
            for (NSString *folder in addOn.folders)
                if (![fm removeItemAtPath:[self.addOnsDirectory stringByAppendingPathComponent:folder] error:error]) return NO;
            return YES;
        }
        NSMutableDictionary *manifest = [self manifest:error];
        if (!manifest) return NO;
        NSMutableDictionary *packages = manifest[@"packages"];
        NSDictionary *entry = packages[addOn.packageID];
        NSArray *folders = [entry isKindOfClass:NSDictionary.class] && [entry[@"folders"] isKindOfClass:NSArray.class] ? entry[@"folders"] : addOn.folders;
        for (NSString *folder in folders) {
            [fm removeItemAtPath:[self.addOnsDirectory stringByAppendingPathComponent:folder] error:NULL];
            [fm removeItemAtPath:[[self.disabledDirectory stringByAppendingPathComponent:addOn.packageID] stringByAppendingPathComponent:folder] error:NULL];
        }
        [fm removeItemAtPath:[self.previousDirectory stringByAppendingPathComponent:addOn.packageID] error:NULL];
        [packages removeObjectForKey:addOn.packageID];
        return [self writeManifest:manifest error:error];
    } @finally {
        [self releaseLock:lock];
    }
}

- (BOOL)setEnabled:(BOOL)enabled forAddOn:(TKInstalledAddOn *)addOn error:(NSError **)error {
    if (addOn.enabled == enabled) return YES;
    int lock = [self acquireLock:error];
    if (lock < 0) return NO;
    @try {
        NSFileManager *fm = NSFileManager.defaultManager;
        NSMutableDictionary *manifest = [self manifest:error];
        if (!manifest) return NO;
        NSMutableDictionary *packages = manifest[@"packages"];
        NSString *packageID = addOn.packageID;
        NSMutableDictionary *entry = [packages[packageID] isKindOfClass:NSDictionary.class] ? [packages[packageID] mutableCopy] : nil;
        if (!addOn.managed) {
            entry = [@{@"source": @"local", @"identifier": [@"local:" stringByAppendingString:addOn.folders.firstObject],
                @"name": addOn.name, @"version": addOn.version, @"folders": addOn.folders,
                @"enabled": @(YES), @"installedAt": @([[NSDate date] timeIntervalSince1970])} mutableCopy];
            packageID = NSUUID.UUID.UUIDString;
            packages[packageID] = entry;
        }
        NSString *from = enabled ? [self.disabledDirectory stringByAppendingPathComponent:packageID] : self.addOnsDirectory;
        NSString *to = enabled ? self.addOnsDirectory : [self.disabledDirectory stringByAppendingPathComponent:packageID];
        if (![fm createDirectoryAtPath:to withIntermediateDirectories:YES attributes:nil error:error]) return NO;
        NSMutableArray<NSArray<NSString *> *> *moved = [NSMutableArray new];
        for (NSString *folder in addOn.folders) {
            NSString *source = [from stringByAppendingPathComponent:folder];
            NSString *destination = [to stringByAppendingPathComponent:folder];
            if (![fm fileExistsAtPath:source]) continue;
            if ([fm fileExistsAtPath:destination]) {
                for (NSArray<NSString *> *pair in moved.reverseObjectEnumerator) [fm moveItemAtPath:pair[1] toPath:pair[0] error:NULL];
                if (error) *error = TKAddOnsError([NSString stringWithFormat:@"%@ already exists.", folder]);
                return NO;
            }
            if (![fm moveItemAtPath:source toPath:destination error:error]) {
                for (NSArray<NSString *> *pair in moved.reverseObjectEnumerator) [fm moveItemAtPath:pair[1] toPath:pair[0] error:NULL];
                return NO;
            }
            [moved addObject:@[source, destination]];
        }
        entry[@"enabled"] = @(enabled);
        packages[packageID] = entry;
        if (![self writeManifest:manifest error:error]) {
            for (NSArray<NSString *> *pair in moved.reverseObjectEnumerator) [fm moveItemAtPath:pair[1] toPath:pair[0] error:NULL];
            return NO;
        }
        return YES;
    } @finally {
        [self releaseLock:lock];
    }
}

- (TKAddOnBackup *)createBackupLocked:(NSError **)error {
    NSFileManager *fm = NSFileManager.defaultManager;
    BOOL isDirectory = NO;
    if (![fm fileExistsAtPath:self.wtfDirectory isDirectory:&isDirectory] || !isDirectory) {
        if (error) *error = TKAddOnsError(@"The game has not created its WTF settings folder yet.");
        return nil;
    }
    if (![fm createDirectoryAtPath:self.backupDirectory withIntermediateDirectories:YES attributes:nil error:error]) return nil;
    NSString *name = [NSString stringWithFormat:@"WTF-%@.zip", TKAddOnsStamp()];
    NSURL *url = [NSURL fileURLWithPath:[self.backupDirectory stringByAppendingPathComponent:name]];
    if (![TKAddOnsZip createArchiveAtURL:url fromDirectory:self.wtfDirectory rootName:@"WTF" error:error]) return nil;
    TKAddOnBackup *backup = [TKAddOnBackup new];
    backup.url = url;
    backup.date = [NSDate date];
    backup.size = [fm attributesOfItemAtPath:url.path error:NULL].fileSize;
    return backup;
}

- (TKAddOnBackup *)createBackup:(NSError **)error {
    int lock = [self acquireLock:error];
    if (lock < 0) return nil;
    @try {
        return [self createBackupLocked:error];
    } @finally {
        [self releaseLock:lock];
    }
}

- (NSArray<TKAddOnBackup *> *)backups {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSMutableArray<TKAddOnBackup *> *result = [NSMutableArray new];
    for (NSString *name in [fm contentsOfDirectoryAtPath:self.backupDirectory error:NULL]) {
        if (![name.pathExtension.lowercaseString isEqualToString:@"zip"]) continue;
        NSString *path = [self.backupDirectory stringByAppendingPathComponent:name];
        NSDictionary *attributes = [fm attributesOfItemAtPath:path error:NULL];
        TKAddOnBackup *backup = [TKAddOnBackup new];
        backup.url = [NSURL fileURLWithPath:path];
        backup.date = attributes[NSFileModificationDate] ?: [NSDate date];
        backup.size = [attributes[NSFileSize] unsignedLongLongValue];
        [result addObject:backup];
    }
    [result sortUsingComparator:^NSComparisonResult(TKAddOnBackup *a, TKAddOnBackup *b) { return [b.date compare:a.date]; }];
    return result;
}

- (BOOL)restoreBackup:(TKAddOnBackup *)backup error:(NSError **)error {
    NSFileManager *fm = NSFileManager.defaultManager;
    if (![fm fileExistsAtPath:backup.url.path]) { if (error) *error = TKAddOnsError(@"The backup no longer exists."); return NO; }
    int lock = [self acquireLock:error];
    if (lock < 0) return NO;
    NSString *staging = [self.stagingDirectory stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    NSString *current = [self.stagingDirectory stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingString:@"-current"]];
    @try {
        if (![fm createDirectoryAtPath:self.stagingDirectory withIntermediateDirectories:YES attributes:nil error:error]) return NO;
        if (![TKAddOnsZip extractArchiveAtURL:backup.url toDirectory:staging error:error]) return NO;
        NSString *restored = [staging stringByAppendingPathComponent:@"WTF"];
        BOOL isDirectory = NO;
        if (![fm fileExistsAtPath:restored isDirectory:&isDirectory] || !isDirectory) {
            if (error) *error = TKAddOnsError(@"The backup does not contain a WTF folder.");
            return NO;
        }
        if (![self createBackupLocked:error]) return NO;
        BOOL hadCurrent = [fm fileExistsAtPath:self.wtfDirectory];
        if (hadCurrent && ![fm moveItemAtPath:self.wtfDirectory toPath:current error:error]) return NO;
        if (![fm moveItemAtPath:restored toPath:self.wtfDirectory error:error]) {
            if (hadCurrent) [fm moveItemAtPath:current toPath:self.wtfDirectory error:NULL];
            return NO;
        }
        [fm removeItemAtPath:current error:NULL];
        return YES;
    } @finally {
        [fm removeItemAtPath:staging error:NULL];
        [fm removeItemAtPath:current error:NULL];
        [self releaseLock:lock];
    }
}

- (BOOL)deleteBackup:(TKAddOnBackup *)backup error:(NSError **)error {
    return [NSFileManager.defaultManager removeItemAtURL:backup.url error:error];
}

@end
