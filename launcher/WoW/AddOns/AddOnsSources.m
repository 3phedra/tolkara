#import "AddOnsSources.h"
#import <Security/Security.h>

NSErrorDomain const TKAddOnsSourcesErrorDomain = @"TKAddOnsSourcesErrorDomain";

static NSError *TKSourcesError(NSString *message) {
    return [NSError errorWithDomain:TKAddOnsSourcesErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey:message}];
}


static NSString *TKSourcesKeychainService = @"local.tolkara.addons";
static NSString *TKSourcesKeychainAccount = @"curseforge-api-key";

@interface TKAddOnsSources ()
@property(nonatomic) NSURLSession *session;
@property(nonatomic) NSURLSession *downloadSession;
@property(nonatomic) dispatch_queue_t spokenQueue;
@property(nonatomic, strong, nullable) NSArray<NSDictionary *> *tukuiItems;
@property(nonatomic, strong, nullable) NSDate *tukuiDate;
@end

@implementation TKAddOnsSources

- (instancetype)init { return [self initWithGameVersion:nil]; }
- (instancetype)initWithGameVersion:(NSString *)gameVersion { return [self initWithGameVersion:gameVersion wagoFlavor:nil]; }

- (instancetype)initWithGameVersion:(NSString *)gameVersion wagoFlavor:(NSString *)wagoFlavor {
    if ((self = [super init])) {
        _gameVersion = gameVersion.copy;
        _wagoFlavor = wagoFlavor.copy;
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        configuration.timeoutIntervalForRequest = 30;
        configuration.timeoutIntervalForResource = 3600;
        configuration.HTTPMaximumConnectionsPerHost = 4;
        _session = [NSURLSession sessionWithConfiguration:configuration];
        NSURLSessionConfiguration *downloadConfiguration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        downloadConfiguration.timeoutIntervalForRequest = 180;
        downloadConfiguration.timeoutIntervalForResource = 1800;
        downloadConfiguration.HTTPMaximumConnectionsPerHost = 2;
        _downloadSession = [NSURLSession sessionWithConfiguration:downloadConfiguration];
        _spokenQueue = dispatch_queue_create("local.tolkara.spoken", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

+ (nullable NSString *)curseForgeKey {
    NSDictionary *query = @{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: TKSourcesKeychainService,
        (__bridge id)kSecAttrAccount: TKSourcesKeychainAccount,
        (__bridge id)kSecReturnData: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne};
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status != errSecSuccess || !result) return nil;
    NSData *data = CFBridgingRelease(result);
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

+ (BOOL)setCurseForgeKey:(nullable NSString *)key error:(NSError **)error {
    NSDictionary *query = @{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: TKSourcesKeychainService,
        (__bridge id)kSecAttrAccount: TKSourcesKeychainAccount};
    SecItemDelete((__bridge CFDictionaryRef)query);
    if (!key.length) return YES;
    NSDictionary *item = @{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: TKSourcesKeychainService,
        (__bridge id)kSecAttrAccount: TKSourcesKeychainAccount,
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        (__bridge id)kSecValueData: [key dataUsingEncoding:NSUTF8StringEncoding]};
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)item, NULL);
    if (status != errSecSuccess) {
        if (error) *error = TKSourcesError(@"Could not save the CurseForge key in the Keychain.");
        return NO;
    }
    return YES;
}

- (void)getJSON:(NSURL *)url headers:(NSDictionary<NSString *, NSString *> *)headers completion:(void (^)(id _Nullable json, NSError * _Nullable error))completion {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 30;
    [request setValue:@"Wolkara-AddOns" forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    for (NSString *key in headers) [request setValue:headers[key] forHTTPHeaderField:key];
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) { if (completion) completion(nil, error); return; }
        NSInteger status = [(NSHTTPURLResponse *)response statusCode];
        if (status == 403 || status == 429) {
            if (completion) completion(nil, TKSourcesError(@"The provider is rate limiting requests. Try again shortly."));
            return;
        }
        if (status < 200 || status >= 300) {
            if (completion) completion(nil, TKSourcesError([NSString stringWithFormat:@"The provider returned HTTP %ld.", (long)status]));
            return;
        }
        if (!data.length) { if (completion) completion(nil, TKSourcesError(@"The provider returned an empty response.")); return; }
        NSError *parse = nil;
        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parse];
        if (!json) { if (completion) completion(nil, TKSourcesError(@"The provider returned invalid JSON.")); return; }
        if (completion) completion(json, nil);
    }];
    [task resume];
}

- (void)downloadURL:(NSURL *)url completion:(void (^)(NSURL * _Nullable localURL, NSError * _Nullable error))completion {
    [self downloadURL:url queue:dispatch_get_main_queue() completion:completion];
}

- (void)downloadURL:(NSURL *)url queue:(dispatch_queue_t)queue
    completion:(void (^)(NSURL * _Nullable localURL, NSError * _Nullable error))completion {
    if (!url) { dispatch_async(queue, ^{ if (completion) completion(nil, TKSourcesError(@"The provider did not return a download link.")); }); return; }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 180;
    [request setValue:@"Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1" forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"https://addons.wago.io/" forHTTPHeaderField:@"Referer"];
    [request setValue:@"application/zip,application/octet-stream,*/*" forHTTPHeaderField:@"Accept"];
    NSURLSessionDownloadTask *task = [self.downloadSession downloadTaskWithRequest:request completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        if (error || !location) { if (completion) completion(nil, error ?: TKSourcesError(@"The download failed.")); return; }
        NSInteger status = [(NSHTTPURLResponse *)response statusCode];
        if (status < 200 || status >= 300) { if (completion) completion(nil, TKSourcesError([NSString stringWithFormat:@"The download returned HTTP %ld.", (long)status])); return; }
        NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:@"WolkaraAddOns"];
        if (![NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL]) {
            if (completion) completion(nil, TKSourcesError(@"Could not prepare the download folder.")); return;
        }
        NSString *destination = [directory stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingString:@".zip"]];
        NSError *move = nil;
        if (![NSFileManager.defaultManager moveItemAtURL:location toURL:[NSURL fileURLWithPath:destination] error:&move]) {
            if (completion) completion(nil, move ?: TKSourcesError(@"Could not keep the download.")); return;
        }
        dispatch_async(queue, ^{ if (completion) completion([NSURL fileURLWithPath:destination], nil); });
    }];
    [task resume];
}

#pragma mark - Tukui

- (void)fetchTukui:(void (^)(NSArray<NSDictionary *> * _Nullable items, NSError * _Nullable error))completion {
    if (self.tukuiItems && self.tukuiDate && -[self.tukuiDate timeIntervalSinceNow] < 600) {
        if (completion) completion(self.tukuiItems, nil);
        return;
    }
    NSURL *url = [NSURL URLWithString:@"https://api.tukui.org/v1/addons"];
    [self getJSON:url headers:nil completion:^(id json, NSError *error) {
        NSArray *items = [json isKindOfClass:NSArray.class] ? json : ([json isKindOfClass:NSDictionary.class] ? json[@"addons"] : nil);
        if (![items isKindOfClass:NSArray.class]) { if (completion) completion(nil, error ?: TKSourcesError(@"Tukui returned an unexpected response.")); return; }
        NSMutableArray<NSDictionary *> *filtered = [NSMutableArray new];
        for (id item in items) if ([item isKindOfClass:NSDictionary.class]) [filtered addObject:item];
        self.tukuiItems = filtered; self.tukuiDate = [NSDate date];
        if (completion) completion(filtered, nil);
    }];
}

- (void)searchTukui:(NSString *)term results:(NSMutableArray<TKAddOnSearchResult *> *)results messages:(NSMutableArray<NSString *> *)messages done:(void (^)(void))done {
    [self fetchTukui:^(NSArray<NSDictionary *> *items, NSError *error) {
        if (error) {
            @synchronized (messages) { [messages addObject:[NSString stringWithFormat:@"Tukui: %@", error.localizedDescription]]; }
            if (done) done();
            return;
        }
        NSString *lower = term.lowercaseString;
        for (NSDictionary *item in items) {
            NSString *name = [item[@"name"] isKindOfClass:NSString.class] ? item[@"name"] : @"";
            NSString *summary = [item[@"small_desc"] isKindOfClass:NSString.class] ? item[@"small_desc"] : ([item[@"desc"] isKindOfClass:NSString.class] ? item[@"desc"] : @"");
            NSString *author = [item[@"author"] isKindOfClass:NSString.class] ? item[@"author"] : @"";
            if (lower.length) {
                NSString *haystack = [@[name, summary, author] componentsJoinedByString:@" "].lowercaseString;
                if ([haystack rangeOfString:lower].location == NSNotFound) continue;
            }
            TKAddOnSearchResult *result = [TKAddOnSearchResult new];
            result.source = TKAddOnSourceTukui;
            NSString *slug = [item[@"slug"] isKindOfClass:NSString.class] ? item[@"slug"] : nil;
            NSNumber *itemID = [item[@"id"] isKindOfClass:NSNumber.class] ? item[@"id"] : nil;
            result.identifier = slug.length ? slug : (itemID ? itemID.stringValue : name);
            result.name = name; result.author = author; result.summary = summary;
            result.version = [item[@"version"] isKindOfClass:NSString.class] ? item[@"version"] : @"";
            result.pageURL = [item[@"web_url"] isKindOfClass:NSString.class] ? item[@"web_url"] : nil;
            NSString *download = [item[@"url"] isKindOfClass:NSString.class] ? item[@"url"] : nil;
            if (download.length) result.directURL = [NSURL URLWithString:download];
            result.payload = item;
            NSArray *patches = [item[@"patch"] isKindOfClass:NSArray.class] ? item[@"patch"] : @[];
            if (patches.count && self.gameVersion.length) {
                BOOL match = NO;
                for (NSString *patch in patches) if ([patch isKindOfClass:NSString.class] && [patch isEqualToString:self.gameVersion]) { match = YES; break; }
                result.compatible = match;
                if (!match) result.compatibilityNote = [NSString stringWithFormat:@"Tukui lists game versions %@, not %@.", [patches componentsJoinedByString:@", "], self.gameVersion];
            }
            @synchronized (results) { [results addObject:result]; }
        }
        if (done) done();
    }];
}

#pragma mark - GitHub

- (NSDictionary *)bestGitHubAssetInRelease:(NSDictionary *)release {
    if (![release isKindOfClass:NSDictionary.class] || [release[@"draft"] boolValue]) return nil;
    for (NSDictionary *asset in release[@"assets"]) {
        if (![asset isKindOfClass:NSDictionary.class]) continue;
        NSString *name = [asset[@"name"] isKindOfClass:NSString.class] ? asset[@"name"] : @"";
        if (![name.pathExtension.lowercaseString isEqualToString:@"zip"]) continue;
        return @{@"release": release, @"asset": asset};
    }
    return nil;
}

- (NSString *)githubComponentKey:(NSString *)value {
    NSMutableString *key = [NSMutableString new];
    for (NSUInteger index = 0; index < value.length; index++) {
        unichar character = [value characterAtIndex:index];
        if (character >= 'A' && character <= 'Z') character = (unichar)(character - 'A' + 'a');
        if ((character >= 'a' && character <= 'z') || (character >= '0' && character <= '9')) [key appendFormat:@"%C", character];
    }
    return key;
}

- (BOOL)githubRelease:(NSDictionary *)release matchesRepository:(NSString *)repository {
    NSString *tag = [release[@"tag_name"] isKindOfClass:NSString.class] ? release[@"tag_name"] : @"";
    NSRange slash = [tag rangeOfString:@"/"];
    if (slash.location == NSNotFound) return YES;
    NSString *prefix = [self githubComponentKey:[tag substringToIndex:slash.location]];
    NSString *name = [self githubComponentKey:repository.lastPathComponent];
    if (!prefix.length || !name.length) return NO;
    return [name hasPrefix:prefix] || [prefix hasPrefix:name];
}

- (BOOL)githubRelease:(NSDictionary *)release matchesComponent:(NSString *)component {
    NSString *tag = [release[@"tag_name"] isKindOfClass:NSString.class] ? release[@"tag_name"] : @"";
    NSRange slash = [tag rangeOfString:@"/"];
    NSString *prefix = slash.location == NSNotFound ? tag : [tag substringToIndex:slash.location];
    NSString *wanted = [self githubComponentKey:component];
    return wanted.length && [[self githubComponentKey:prefix] isEqualToString:wanted];
}

- (NSDictionary *)githubIdentifierParts:(NSString *)identifier {
    NSRange hash = [identifier rangeOfString:@"#"];
    if (hash.location == NSNotFound) return @{@"repository": identifier ?: @""};
    return @{@"repository": [identifier substringToIndex:hash.location],
             @"component": [identifier substringFromIndex:hash.location + 1]};
}

- (NSDictionary *)bestGitHubReleaseInReleases:(NSArray *)releases repository:(NSString *)repository component:(NSString *)component {
    NSDictionary *best = nil;
    NSInteger bestScore = NSIntegerMin;
    BOOL wantsComponent = component.length > 0;
    for (NSDictionary *release in releases) {
        if (![release isKindOfClass:NSDictionary.class]) continue;
        NSDictionary *info = [self bestGitHubAssetInRelease:release];
        if (!info) continue;
        BOOL matches = wantsComponent ? [self githubRelease:release matchesComponent:component] : [self githubRelease:release matchesRepository:repository];
        if (wantsComponent && !matches) continue;
        NSInteger score = matches ? 4 : 0;
        if ([release[@"prerelease"] boolValue]) score -= 1;
        if (score > bestScore) { best = info; bestScore = score; }
    }
    return best;
}

- (NSDictionary *)bestGitHubReleaseInReleases:(NSArray *)releases repository:(NSString *)repository {
    return [self bestGitHubReleaseInReleases:releases repository:repository component:nil];
}

- (void)fetchGitHubReleases:(NSString *)repository component:(NSString *)component page:(NSInteger)page
    completion:(void (^)(NSDictionary * _Nullable assetInfo, NSError * _Nullable error))completion {
    NSString *encoded = [repository stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.github.com/repos/%@/releases?per_page=100&page=%ld", encoded, (long)page]];
    [self getJSON:url headers:@{@"X-GitHub-Api-Version": @"2022-11-28"} completion:^(id json, NSError *error) {
        if (![json isKindOfClass:NSArray.class]) { if (completion) completion(nil, error ?: TKSourcesError(@"GitHub returned an unexpected response.")); return; }
        NSDictionary *info = [self bestGitHubReleaseInReleases:json repository:repository component:component];
        if (info) { if (completion) completion(info, nil); return; }
        // Release lists are chronological. Spoken's English Places pack is an
        // older tag, so component lookups may need a second page.
        if ([json count] == 100 && page < 5) {
            [self fetchGitHubReleases:repository component:component page:page + 1 completion:completion];
            return;
        }
        NSString *message = component.length
            ? [NSString stringWithFormat:@"This repository has no ZIP release for the \"%@\" component.", component]
            : @"This repository has no packaged ZIP release. Download it from its page and import the ZIP.";
        if (completion) completion(nil, TKSourcesError(message));
    }];
}

- (void)fetchGitHubReleases:(NSString *)repository component:(NSString *)component completion:(void (^)(NSDictionary * _Nullable assetInfo, NSError * _Nullable error))completion {
    [self fetchGitHubReleases:repository component:component page:1 completion:completion];
}

- (void)fetchGitHubReleases:(NSString *)repository completion:(void (^)(NSDictionary * _Nullable assetInfo, NSError * _Nullable error))completion {
    [self fetchGitHubReleases:repository component:nil completion:completion];
}

- (TKAddOnSearchResult *)githubRepositoryResult:(NSString *)fullName name:(NSString *)name {
    TKAddOnSearchResult *result = [TKAddOnSearchResult new];
    result.source = TKAddOnSourceGitHub;
    result.identifier = fullName;
    result.name = name ?: fullName;
    result.summary = @"GitHub repository";
    result.pageURL = [@"https://github.com/" stringByAppendingString:fullName];
    result.payload = @{@"repository": fullName};
    result.compatibilityNote = @"The package TOC is checked against this game version after download.";
    return result;
}

#pragma mark - Spoken multi-part package

- (void)spokenComponentsWithCompletion:(void (^)(NSArray<TKAddOnComponent *> *, NSError *))completion {
    NSArray<NSDictionary *> *definitions = @[
        @{@"component": @"spoken", @"name": @"Spoken",
          @"detail": @"Core add-on · includes Quests, Places and Readables", @"required": @YES},
        @{@"component": @"quests-audio", @"name": @"Quests voice pack",
          @"detail": @"English · all quest dialogue", @"required": @NO},
        @{@"component": @"zones-audio", @"name": @"Places voice pack",
          @"detail": @"English · zone and subarea lore", @"required": @NO},
        @{@"component": @"books-audio", @"name": @"Readables voice pack",
          @"detail": @"English · books, letters and notes", @"required": @NO},
    ];
    NSMutableArray *slots = [NSMutableArray arrayWithCapacity:definitions.count];
    for (NSUInteger i = 0; i < definitions.count; i++) [slots addObject:NSNull.null];
    __block NSError *coreError = nil;
    dispatch_group_t group = dispatch_group_create();
    for (NSUInteger index = 0; index < definitions.count; index++) {
        NSDictionary *definition = definitions[index];
        dispatch_group_enter(group);
        [self fetchGitHubReleases:@"rusty-key/spoken-wow" component:definition[@"component"]
            completion:^(NSDictionary *info, NSError *error) {
            TKAddOnComponent *component = [TKAddOnComponent new];
            component.componentID = definition[@"component"];
            component.name = definition[@"name"];
            component.detail = definition[@"detail"];
            component.repository = @"rusty-key/spoken-wow";
            component.required = [definition[@"required"] boolValue];
            component.selected = YES;
            NSDictionary *release = info[@"release"];
            NSDictionary *asset = info[@"asset"];
            if (release && asset) {
                NSString *tag = [release[@"tag_name"] isKindOfClass:NSString.class] ? release[@"tag_name"] : @"";
                NSString *version = [tag componentsSeparatedByString:@"/"].lastObject ?: tag;
                if ([version hasPrefix:@"v"]) version = [version substringFromIndex:1];
                component.version = version;
                component.assetName = asset[@"name"];
                component.assetURL = asset[@"browser_download_url"];
                component.pageURL = release[@"html_url"];
                component.size = [asset[@"size"] unsignedLongLongValue];
            } else {
                component.detail = [component.detail stringByAppendingString:@" · unavailable"];
                component.selected = NO;
                if (component.required && !coreError) coreError = error ?: TKSourcesError(@"Spoken has no downloadable core release.");
            }
            @synchronized (slots) { slots[index] = component; }
            dispatch_group_leave(group);
        }];
    }
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSMutableArray<TKAddOnComponent *> *components = [NSMutableArray new];
        for (id slot in slots) if ([slot isKindOfClass:TKAddOnComponent.class]) [components addObject:slot];
        if (completion) completion(components, coreError);
    });
}

- (void)downloadSpokenComponents:(NSArray<TKAddOnComponent *> *)components
    progress:(void (^)(NSString *))progress
    completion:(void (^)(TKAddOnDownload *, NSError *))completion {
    TKAddOnComponent *core = nil;
    NSMutableArray<TKAddOnComponent *> *ordered = [NSMutableArray new];
    for (TKAddOnComponent *component in components) {
        if (!component.selected || !component.assetURL.length) continue;
        if ([component.componentID isEqualToString:@"spoken"]) core = component;
        else [ordered addObject:component];
    }
    if (!core) { dispatch_async(self.spokenQueue, ^{ if (completion) completion(nil, TKSourcesError(@"Install Spoken itself before its voice packs.")); }); return; }
    [ordered insertObject:core atIndex:0];
    NSMutableArray<TKAddOnDownload *> *downloads = [NSMutableArray new];
    dispatch_async(self.spokenQueue, ^{
        NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:@"WolkaraAddOns"];
        [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
        __block NSUInteger index = 0;
        __block void (^next)(void) = nil;
        next = ^{
            if (index >= ordered.count) {
                TKAddOnDownload *root = nil;
                NSMutableArray<TKAddOnDownload *> *dependencies = [NSMutableArray new];
                for (TKAddOnDownload *download in downloads) {
                    if ([download.identifier hasSuffix:@"#spoken"]) root = download;
                    else [dependencies addObject:download];
                }
                root.dependencies = dependencies.copy;
                if (completion) completion(root, nil);
                next = nil;
                return;
            }
            TKAddOnComponent *component = ordered[index];
            // A previous attempt may have finished before the app was
            // interrupted. Reuse a complete archive with the exact asset size
            // instead of downloading the same multi-hundred-MB pack again.
            NSURL *cached = nil;
            NSArray *entries = [NSFileManager.defaultManager contentsOfDirectoryAtPath:directory error:NULL];
            for (NSString *name in entries) {
                if (![name.pathExtension.lowercaseString isEqualToString:@"zip"]) continue;
                NSString *path = [directory stringByAppendingPathComponent:name];
                NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:path error:NULL];
                if ([attributes[NSFileSize] unsignedLongLongValue] == component.size) { cached = [NSURL fileURLWithPath:path]; break; }
            }
            if (cached) {
                TKAddOnDownload *download = [TKAddOnDownload new];
                download.archiveURL = cached;
                download.name = component.name;
                download.version = component.version ?: @"";
                download.identifier = [NSString stringWithFormat:@"%@#%@", component.repository, component.componentID];
                download.pageURL = component.pageURL;
                download.source = TKAddOnSourceGitHub;
                [downloads addObject:download];
                index++;
                next();
                return;
            }
            NSString *size = [NSByteCountFormatter stringFromByteCount:(long long)component.size countStyle:NSByteCountFormatterCountStyleFile];
            if (progress) dispatch_async(dispatch_get_main_queue(), ^{ progress([NSString stringWithFormat:@"Downloading %@ (%@)…", component.name, size]); });
            [self downloadURL:[NSURL URLWithString:component.assetURL] queue:self.spokenQueue completion:^(NSURL *local, NSError *error) {
                if (!local) { if (completion) completion(nil, error); next = nil; return; }
                TKAddOnDownload *download = [TKAddOnDownload new];
                download.archiveURL = local;
                download.name = component.name;
                download.version = component.version ?: @"";
                download.identifier = [NSString stringWithFormat:@"%@#%@", component.repository, component.componentID];
                download.pageURL = component.pageURL;
                download.source = TKAddOnSourceGitHub;
                [downloads addObject:download];
                index++;
                next();
            }];
        };
        next();
    });
}


- (void)searchGitHub:(NSString *)term results:(NSMutableArray<TKAddOnSearchResult *> *)results messages:(NSMutableArray<NSString *> *)messages done:(void (^)(void))done {
    if (term.length < 2) { if (done) done(); return; }
    NSString *query = [NSString stringWithFormat:@"%@ world of warcraft addon in:name,description", term];
    NSString *encoded = [query stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.github.com/search/repositories?q=%@&per_page=20&sort=stars&order=desc", encoded]];
    [self getJSON:url headers:@{@"X-GitHub-Api-Version": @"2022-11-28"} completion:^(id json, NSError *error) {
        if (![json isKindOfClass:NSDictionary.class] || ![json[@"items"] isKindOfClass:NSArray.class]) {
            @synchronized (messages) { [messages addObject:[NSString stringWithFormat:@"GitHub: %@", error.localizedDescription ?: @"unexpected response"]]; }
            if (done) done();
            return;
        }
        for (NSDictionary *item in json[@"items"]) {
            if (![item isKindOfClass:NSDictionary.class]) continue;
            NSString *fullName = [item[@"full_name"] isKindOfClass:NSString.class] ? item[@"full_name"] : nil;
            if (!fullName.length) continue;
            TKAddOnSearchResult *result = [TKAddOnSearchResult new];
            result.source = TKAddOnSourceGitHub;
            result.identifier = fullName;
            result.name = [item[@"name"] isKindOfClass:NSString.class] ? item[@"name"] : fullName;
            NSDictionary *owner = item[@"owner"];
            result.author = [owner isKindOfClass:NSDictionary.class] && [owner[@"login"] isKindOfClass:NSString.class] ? owner[@"login"] : @"";
            result.summary = [item[@"description"] isKindOfClass:NSString.class] ? item[@"description"] : @"";
            result.pageURL = [item[@"html_url"] isKindOfClass:NSString.class] ? item[@"html_url"] : nil;
            result.payload = @{@"repository": fullName};
            result.compatibilityNote = @"The package TOC is checked against this game version after download.";
            @synchronized (results) { [results addObject:result]; }
        }
        if (done) done();
    }];
}

#pragma mark - CurseForge

- (void)searchCurseForge:(NSString *)term results:(NSMutableArray<TKAddOnSearchResult *> *)results messages:(NSMutableArray<NSString *> *)messages done:(void (^)(void))done {
    NSString *key = TKAddOnsSources.curseForgeKey;
    if (!key.length) {
        @synchronized (messages) { [messages addObject:@"CurseForge: add an API key in the add-ons menu to search and download from CurseForge."]; }
        if (done) done();
        return;
    }
    NSString *encoded = [term stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.curseforge.com/v1/mods/search?gameId=1&searchFilter=%@&pageSize=20&sortField=2&sortOrder=desc", encoded]];
    [self getJSON:url headers:@{@"x-api-key": key} completion:^(id json, NSError *error) {
        if (![json isKindOfClass:NSDictionary.class] || ![json[@"data"] isKindOfClass:NSArray.class]) {
            @synchronized (messages) { [messages addObject:[NSString stringWithFormat:@"CurseForge: %@", error.localizedDescription ?: @"unexpected response"]]; }
            if (done) done();
            return;
        }
        for (NSDictionary *mod in json[@"data"]) {
            if (![mod isKindOfClass:NSDictionary.class]) continue;
            NSNumber *modID = [mod[@"id"] isKindOfClass:NSNumber.class] ? mod[@"id"] : nil;
            if (!modID) continue;
            TKAddOnSearchResult *result = [TKAddOnSearchResult new];
            result.source = TKAddOnSourceCurseForge;
            result.identifier = modID.stringValue;
            result.name = [mod[@"name"] isKindOfClass:NSString.class] ? mod[@"name"] : modID.stringValue;
            NSString *author = @"";
            for (NSDictionary *a in mod[@"authors"]) if ([a isKindOfClass:NSDictionary.class] && [a[@"name"] isKindOfClass:NSString.class]) { author = a[@"name"]; break; }
            result.author = author;
            result.summary = [mod[@"summary"] isKindOfClass:NSString.class] ? mod[@"summary"] : @"";
            NSDictionary *links = mod[@"links"];
            result.pageURL = [links isKindOfClass:NSDictionary.class] && [links[@"websiteUrl"] isKindOfClass:NSString.class] ? links[@"websiteUrl"] : nil;
            result.payload = @{@"modId": modID, @"name": result.name};
            NSArray *indexes = [mod[@"latestFilesIndexes"] isKindOfClass:NSArray.class] ? mod[@"latestFilesIndexes"] : @[];
            if (indexes.count && self.gameVersion.length) {
                BOOL declared = NO, match = NO;
                for (NSDictionary *index in indexes) {
                    if (![index isKindOfClass:NSDictionary.class]) continue;
                    NSString *gameVersion = [index[@"gameVersion"] isKindOfClass:NSString.class] ? index[@"gameVersion"] : nil;
                    if (!gameVersion.length) continue;
                    declared = YES;
                    if ([gameVersion isEqualToString:self.gameVersion]) { match = YES; break; }
                }
                if (declared) {
                    result.compatible = match;
                    if (!match) result.compatibilityNote = [NSString stringWithFormat:@"CurseForge has no file listed for %@.", self.gameVersion];
                }
            }
            @synchronized (results) { [results addObject:result]; }
        }
        if (done) done();
    }];
}

- (NSDictionary *)bestCurseForgeFile:(NSArray<NSDictionary *> *)files {
    NSDictionary *best = nil;
    NSInteger bestScore = -1;
    for (NSDictionary *file in files) {
        if (![file isKindOfClass:NSDictionary.class]) continue;
        if ([file[@"isAvailable"] isKindOfClass:NSNumber.class] && ![file[@"isAvailable"] boolValue]) continue;
        NSArray *versions = [file[@"gameVersions"] isKindOfClass:NSArray.class] ? file[@"gameVersions"] : @[];
        BOOL forever = NO;
        for (NSString *version in versions) {
            if (![version isKindOfClass:NSString.class]) continue;
            if (self.gameVersion.length ? [version isEqualToString:self.gameVersion] : [version hasPrefix:@"1.60"]) { forever = YES; break; }
        }
        if (!forever) continue;
        NSInteger releaseType = [file[@"releaseType"] isKindOfClass:NSNumber.class] ? [file[@"releaseType"] integerValue] : 3;
        NSInteger score = releaseType == 1 ? 30 : (releaseType == 2 ? 20 : 10);
        NSNumber *fileID = [file[@"id"] isKindOfClass:NSNumber.class] ? file[@"id"] : nil;
        if (fileID) score += 0;
        if (score > bestScore) { best = file; bestScore = score; }
    }
    return best;
}

- (void)curseForgeDownloadURLForModID:(NSNumber *)modID file:(NSDictionary *)file completion:(void (^)(NSURL * _Nullable url, NSError * _Nullable error))completion {
    NSString *direct = [file[@"downloadUrl"] isKindOfClass:NSString.class] ? file[@"downloadUrl"] : nil;
    if (direct.length) { if (completion) completion([NSURL URLWithString:direct], nil); return; }
    NSString *key = TKAddOnsSources.curseForgeKey;
    if (!key.length) { if (completion) completion(nil, TKSourcesError(@"CurseForge needs an API key to download this file.")); return; }
    NSNumber *fileID = [file[@"id"] isKindOfClass:NSNumber.class] ? file[@"id"] : nil;
    if (!fileID) { if (completion) completion(nil, TKSourcesError(@"CurseForge did not return a file ID.")); return; }
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.curseforge.com/v1/mods/%@/files/%@/download-url", modID.stringValue, fileID.stringValue]];
    [self getJSON:url headers:@{@"x-api-key": key} completion:^(id json, NSError *error) {
        NSString *link = [json isKindOfClass:NSDictionary.class] && [json[@"data"] isKindOfClass:NSString.class] ? json[@"data"] : nil;
        if (!link.length) { if (completion) completion(nil, error ?: TKSourcesError(@"CurseForge did not provide a download URL.")); return; }
        if (completion) completion([NSURL URLWithString:link], nil);
    }];
}

- (void)resolveCurseForgeModID:(NSNumber *)modID name:(NSString *)name visited:(NSMutableSet<NSNumber *> *)visited depth:(NSInteger)depth completion:(void (^)(TKAddOnDownload * _Nullable download, NSError * _Nullable error))completion {
    if (depth > 4 || [visited containsObject:modID]) { if (completion) completion(nil, TKSourcesError(@"The CurseForge dependency graph is too deep.")); return; }
    [visited addObject:modID];
    NSString *key = TKAddOnsSources.curseForgeKey;
    if (!key.length) { if (completion) completion(nil, TKSourcesError(@"CurseForge needs an API key.")); return; }
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.curseforge.com/v1/mods/%@/files?pageSize=50", modID.stringValue]];
    [self getJSON:url headers:@{@"x-api-key": key} completion:^(id json, NSError *error) {
        NSArray *files = [json isKindOfClass:NSDictionary.class] && [json[@"data"] isKindOfClass:NSArray.class] ? json[@"data"] : nil;
        if (!files.count) { if (completion) completion(nil, error ?: TKSourcesError(self.gameVersion.length ? [NSString stringWithFormat:@"This CurseForge project has no file for %@.", self.gameVersion] : @"This CurseForge project has no Forever 1.60 file.")); return; }
        NSDictionary *file = [self bestCurseForgeFile:files];
        if (!file) { if (completion) completion(nil, TKSourcesError(self.gameVersion.length ? [NSString stringWithFormat:@"This CurseForge project has no file for %@.", self.gameVersion] : @"This CurseForge project has no Forever 1.60 file.")); return; }
        [self curseForgeDownloadURLForModID:modID file:file completion:^(NSURL *url, NSError *error) {
            if (!url) { if (completion) completion(nil, error); return; }
            NSString *display = [file[@"displayName"] isKindOfClass:NSString.class] ? file[@"displayName"] : ([file[@"fileName"] isKindOfClass:NSString.class] ? file[@"fileName"] : @"");
            NSMutableArray<NSNumber *> *requirements = [NSMutableArray new];
            for (NSDictionary *dependency in file[@"dependencies"]) {
                if (![dependency isKindOfClass:NSDictionary.class]) continue;
                NSInteger relation = [dependency[@"relationType"] isKindOfClass:NSNumber.class] ? [dependency[@"relationType"] integerValue] : 0;
                NSNumber *depID = [dependency[@"modId"] isKindOfClass:NSNumber.class] ? dependency[@"modId"] : nil;
                if (relation == 3 && depID && ![depID isEqualToNumber:modID]) [requirements addObject:depID];
            }
            if (!requirements.count) {
                [self downloadURL:url completion:^(NSURL *local, NSError *error) {
                    if (!local) { if (completion) completion(nil, error); return; }
                    TKAddOnDownload *download = [TKAddOnDownload new];
                    download.archiveURL = local; download.name = name; download.version = display;
                    download.identifier = modID.stringValue; download.source = TKAddOnSourceCurseForge;
                    if (completion) completion(download, nil);
                }];
                return;
            }
            NSMutableArray<TKAddOnDownload *> *dependencies = [NSMutableArray new];
            dispatch_group_t group = dispatch_group_create();
            NSMutableArray<NSError *> *failures = [NSMutableArray new];
            for (NSNumber *depID in requirements) {
                dispatch_group_enter(group);
                [self resolveCurseForgeModID:depID name:[@"CurseForge " stringByAppendingString:depID.stringValue] visited:visited depth:depth + 1 completion:^(TKAddOnDownload *dependency, NSError *failure) {
                    @synchronized (dependencies) {
                        if (dependency) [dependencies addObject:dependency];
                        else if (failure) [failures addObject:failure];
                    }
                    dispatch_group_leave(group);
                }];
            }
            dispatch_group_notify(group, dispatch_get_main_queue(), ^{
                if (failures.count) { if (completion) completion(nil, failures.firstObject); return; }
                [self downloadURL:url completion:^(NSURL *local, NSError *error) {
                    if (!local) { if (completion) completion(nil, error); return; }
                    TKAddOnDownload *download = [TKAddOnDownload new];
                    download.archiveURL = local; download.name = name; download.version = display;
                    download.identifier = modID.stringValue; download.source = TKAddOnSourceCurseForge;
                    download.dependencies = dependencies;
                    if (completion) completion(download, nil);
                }];
            });
        }];
    }];
}


#pragma mark - Wago (public add-on page)

static NSString *TKWagoUnescape(NSString *value) {
    NSMutableString *out = [value mutableCopy];
    [out replaceOccurrencesOfString:@"&quot;" withString:@"\"" options:0 range:NSMakeRange(0, out.length)];
    [out replaceOccurrencesOfString:@"&#039;" withString:@"'" options:0 range:NSMakeRange(0, out.length)];
    [out replaceOccurrencesOfString:@"&#39;" withString:@"'" options:0 range:NSMakeRange(0, out.length)];
    [out replaceOccurrencesOfString:@"&amp;" withString:@"&" options:0 range:NSMakeRange(0, out.length)];
    [out replaceOccurrencesOfString:@"&lt;" withString:@"<" options:0 range:NSMakeRange(0, out.length)];
    [out replaceOccurrencesOfString:@"&gt;" withString:@">" options:0 range:NSMakeRange(0, out.length)];
    return out;
}

- (void)getWagoPage:(NSString *)slug completion:(void (^)(NSString * _Nullable html, NSError * _Nullable error))completion {
    NSString *escaped = [slug stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://addons.wago.io/addons/%@", escaped]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 30;
    [request setValue:@"Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1" forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"text/html,application/xhtml+xml" forHTTPHeaderField:@"Accept"];
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) { if (completion) completion(nil, error); return; }
        NSInteger status = [(NSHTTPURLResponse *)response statusCode];
        if (status == 404) { if (completion) completion(nil, TKSourcesError(@"No Wago add-on page was found for that name.")); return; }
        if (status < 200 || status >= 300) { if (completion) completion(nil, TKSourcesError([NSString stringWithFormat:@"Wago returned HTTP %ld.", (long)status])); return; }
        NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (!html.length) { if (completion) completion(nil, TKSourcesError(@"Wago returned an empty page.")); return; }
        if (completion) completion(html, nil);
    }];
    [task resume];
}

- (NSArray<NSString *> *)wagoSlugsForQuery:(NSString *)term {
    NSString *value = [term stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!value.length) return @[];
    NSRange addons = [value rangeOfString:@"/addons/" options:NSCaseInsensitiveSearch];
    if (addons.location != NSNotFound) {
        value = [value substringFromIndex:addons.location + addons.length];
    } else if ([value.lowercaseString containsString:@"wago.io"]) {
        NSURL *url = [NSURL URLWithString:value];
        NSArray<NSString *> *parts = url.pathComponents;
        NSUInteger index = [parts indexOfObjectPassingTest:^BOOL(NSString *part, NSUInteger idx, BOOL *stop) {
            (void)idx; (void)stop; return [part caseInsensitiveCompare:@"addons"] == NSOrderedSame;
        }];
        if (index != NSNotFound && index + 1 < parts.count) value = parts[index + 1];
    }
    NSRange stop = [value rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"?#"]];
    if (stop.location != NSNotFound) value = [value substringToIndex:stop.location];
    while ([value hasSuffix:@"/"]) value = [value substringToIndex:value.length - 1];
    value = value.lowercaseString;
    NSMutableArray<NSString *> *candidates = [NSMutableArray new];
    for (NSString *candidate in @[value, [value stringByReplacingOccurrencesOfString:@" " withString:@""], [value stringByReplacingOccurrencesOfString:@" " withString:@"-"]])
        if (candidate.length && ![candidates containsObject:candidate]) [candidates addObject:candidate];
    return candidates;
}

- (TKAddOnSearchResult *)wagoResultFromHTML:(NSString *)html slug:(NSString *)slug error:(NSError **)error {
    NSRange marker = [html rangeOfString:@"data-page=\""];
    if (marker.location == NSNotFound) { if (error) *error = TKSourcesError(@"Wago returned an unexpected page."); return nil; }
    NSUInteger start = NSMaxRange(marker);
    NSRange end = [html rangeOfString:@"\"" options:0 range:NSMakeRange(start, html.length - start)];
    if (end.location == NSNotFound) { if (error) *error = TKSourcesError(@"Wago returned an unexpected page."); return nil; }
    NSString *encoded = [html substringWithRange:NSMakeRange(start, end.location - start)];
    NSData *jsonData = [TKWagoUnescape(encoded) dataUsingEncoding:NSUTF8StringEncoding];
    NSError *parse = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&parse];
    NSDictionary *props = [json isKindOfClass:NSDictionary.class] ? json[@"props"] : nil;
    NSDictionary *addon = [props isKindOfClass:NSDictionary.class] && [props[@"addon"] isKindOfClass:NSDictionary.class] ? props[@"addon"] : nil;
    NSDictionary *metadata = [props isKindOfClass:NSDictionary.class] && [props[@"metadata"] isKindOfClass:NSDictionary.class] ? props[@"metadata"] : nil;
    if (!addon || !metadata) { if (error) *error = parse ?: TKSourcesError(@"Wago's add-on data could not be read."); return nil; }
    NSDictionary *releases = [metadata[@"recent_releases"] isKindOfClass:NSDictionary.class] ? metadata[@"recent_releases"] : nil;
    if (!releases) releases = [addon[@"recent_releases"] isKindOfClass:NSDictionary.class] ? addon[@"recent_releases"] : ([addon[@"releases"] isKindOfClass:NSDictionary.class] ? addon[@"releases"] : @{});
    NSString *flavor = self.wagoFlavor ?: @"retail";
    NSDictionary *release = [releases[flavor] isKindOfClass:NSDictionary.class] ? releases[flavor] : nil;
    BOOL compatible = YES;
    NSString *note = nil;
    if (!release) {
        compatible = NO;
        note = [NSString stringWithFormat:@"Wago has no %@ release for this add-on.", flavor];
        for (NSString *fallback in @[@"retail", @"classic", @"forever"]) {
            if ([releases[fallback] isKindOfClass:NSDictionary.class]) { release = releases[fallback]; break; }
        }
        if (!release) release = [releases.allValues firstObject];
    }
    if (![release isKindOfClass:NSDictionary.class]) { if (error) *error = TKSourcesError(@"Wago has no downloadable release for this add-on."); return nil; }
    NSArray *patches = [release[[NSString stringWithFormat:@"supported_%@_patches", flavor]] isKindOfClass:NSArray.class] ? release[[NSString stringWithFormat:@"supported_%@_patches", flavor]] : nil;
    if (patches.count && self.gameVersion.length && ![patches containsObject:self.gameVersion]) {
        compatible = NO;
        note = [NSString stringWithFormat:@"Wago release supports %@, not %@.", [patches componentsJoinedByString:@", "], self.gameVersion];
    }
    NSString *download = [release[@"download_link"] isKindOfClass:NSString.class] ? release[@"download_link"] : nil;
    if (!download.length) { if (error) *error = TKSourcesError(@"Wago did not provide a download link for this release."); return nil; }
    NSString *author = @"";
    NSArray *developers = metadata[@"developers"];
    if ([developers isKindOfClass:NSArray.class] && [developers.firstObject isKindOfClass:NSDictionary.class] && [developers.firstObject[@"name"] isKindOfClass:NSString.class])
        author = developers.firstObject[@"name"];
    else if ([metadata[@"owner"] isKindOfClass:NSString.class]) author = metadata[@"owner"];
    NSString *actualSlug = [addon[@"slug"] isKindOfClass:NSString.class] ? addon[@"slug"] : slug;
    TKAddOnSearchResult *result = [TKAddOnSearchResult new];
    result.source = TKAddOnSourceWago;
    result.identifier = actualSlug;
    result.name = [addon[@"display_name"] isKindOfClass:NSString.class] ? addon[@"display_name"] : actualSlug;
    result.summary = [addon[@"summary"] isKindOfClass:NSString.class] ? addon[@"summary"] : @"";
    result.author = author;
    result.version = [release[@"label"] isKindOfClass:NSString.class] ? release[@"label"] : @"";
    result.pageURL = [NSString stringWithFormat:@"https://addons.wago.io/addons/%@", actualSlug];
    result.directURL = [NSURL URLWithString:download];
    result.payload = @{@"slug": actualSlug, @"flavor": flavor};
    result.compatible = compatible;
    result.compatibilityNote = note;
    return result;
}

- (void)fetchWagoResultForSlug:(NSString *)slug completion:(void (^)(TKAddOnSearchResult * _Nullable result, NSError * _Nullable error))completion {
    [self getWagoPage:slug completion:^(NSString *html, NSError *error) {
        if (!html) { if (completion) completion(nil, error); return; }
        NSError *parse = nil;
        TKAddOnSearchResult *result = [self wagoResultFromHTML:html slug:slug error:&parse];
        if (completion) completion(result, result ? nil : (parse ?: TKSourcesError(@"Wago's add-on data could not be read.")));
    }];
}
- (void)tryWagoSlugs:(NSArray<NSString *> *)slugs index:(NSUInteger)index results:(NSMutableArray<TKAddOnSearchResult *> *)results messages:(NSMutableArray<NSString *> *)messages lastError:(NSError *)lastError done:(void (^)(void))done {
    if (index >= slugs.count) {
        @synchronized (messages) {
            [messages addObject:lastError.localizedDescription ?: @"Wago: no add-on page for this name. Open wago.io to search, then paste the add-on URL."];
        }
        if (done) done();
        return;
    }
    __weak TKAddOnsSources *weakSelf = self;
    [self fetchWagoResultForSlug:slugs[index] completion:^(TKAddOnSearchResult *result, NSError *error) {
        if (result) {
            @synchronized (results) { [results addObject:result]; }
            if (done) done();
        } else {
            [weakSelf tryWagoSlugs:slugs index:index + 1 results:results messages:messages lastError:error done:done];
        }
    }];
}

- (void)searchWago:(NSString *)term results:(NSMutableArray<TKAddOnSearchResult *> *)results messages:(NSMutableArray<NSString *> *)messages done:(void (^)(void))done {
    NSArray<NSString *> *slugs = [self wagoSlugsForQuery:term];
    if (!slugs.count) { if (done) done(); return; }
    [self tryWagoSlugs:slugs index:0 results:results messages:messages lastError:nil done:done];
}

#pragma mark - Search

- (void)search:(NSString *)query completion:(TKAddOnSearchCompletion)completion {
    NSString *term = [query stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSMutableArray<TKAddOnSearchResult *> *results = [NSMutableArray new];
    NSMutableArray<NSString *> *messages = [NSMutableArray new];
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);
    [self searchTukui:term results:results messages:messages done:^{ dispatch_group_leave(group); }];
    if (term.length) {
        dispatch_group_enter(group);
        [self searchGitHub:term results:results messages:messages done:^{ dispatch_group_leave(group); }];
        dispatch_group_enter(group);
        [self searchCurseForge:term results:results messages:messages done:^{ dispatch_group_leave(group); }];
        dispatch_group_enter(group);
        [self searchWago:term results:results messages:messages done:^{ dispatch_group_leave(group); }];
    }
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSArray *sorted = [results sortedArrayUsingComparator:^NSComparisonResult(TKAddOnSearchResult *a, TKAddOnSearchResult *b) {
            if (a.source != b.source) return a.source < b.source ? NSOrderedAscending : NSOrderedDescending;
            return [a.name localizedCaseInsensitiveCompare:b.name];
        }];
        completion(sorted, messages.copy);
    });
}

#pragma mark - Resolve

- (void)resolveResult:(TKAddOnSearchResult *)result completion:(void (^)(TKAddOnDownload * _Nullable, NSError * _Nullable))completion {
    if (result.source == TKAddOnSourceTukui) {
        [self downloadURL:result.directURL completion:^(NSURL *local, NSError *error) {
            if (!local) { if (completion) completion(nil, error); return; }
            TKAddOnDownload *download = [TKAddOnDownload new];
            download.archiveURL = local; download.name = result.name; download.version = result.version;
            download.identifier = result.identifier; download.source = TKAddOnSourceTukui; download.pageURL = result.pageURL;
            if (completion) completion(download, nil);
        }];
        return;
    }
    if (result.source == TKAddOnSourceGitHub) {
        NSDictionary *parts = [self githubIdentifierParts:result.identifier];
        NSString *repository = [result.payload[@"repository"] isKindOfClass:NSString.class] ? result.payload[@"repository"] : parts[@"repository"];
        NSString *component = [result.payload[@"component"] isKindOfClass:NSString.class] ? result.payload[@"component"] : parts[@"component"];
        [self fetchGitHubReleases:repository component:component completion:^(NSDictionary *info, NSError *error) {
            if (!info) { if (completion) completion(nil, error); return; }
            NSDictionary *asset = info[@"asset"];
            NSString *link = [asset[@"browser_download_url"] isKindOfClass:NSString.class] ? asset[@"browser_download_url"] : nil;
            [self downloadURL:link.length ? [NSURL URLWithString:link] : nil completion:^(NSURL *local, NSError *error) {
                if (!local) { if (completion) completion(nil, error); return; }
                NSDictionary *release = info[@"release"];
                TKAddOnDownload *download = [TKAddOnDownload new];
                download.archiveURL = local; download.name = result.name;
                download.version = [release[@"tag_name"] isKindOfClass:NSString.class] ? release[@"tag_name"] : result.version;
                download.identifier = result.identifier.length ? result.identifier : repository;
                download.source = TKAddOnSourceGitHub;
                download.pageURL = result.pageURL ?: ([release[@"html_url"] isKindOfClass:NSString.class] ? release[@"html_url"] : nil);
                if (completion) completion(download, nil);
            }];
        }];
        return;
    }
    if (result.source == TKAddOnSourceWago) {
        // Wago download links are signed and expire. Re-read the page at
        // install time so a result left open for a while still gets a fresh
        // link, and so the current flavor is checked again.
        __weak TKAddOnsSources *weakSelf = self;
        [self fetchWagoResultForSlug:result.identifier completion:^(TKAddOnSearchResult *fresh, NSError *pageError) {
            (void)pageError;
            TKAddOnsSources *strongSelf = weakSelf;
            if (!strongSelf) return;
            if (fresh && !fresh.compatible) {
                if (completion) completion(nil, TKSourcesError(fresh.compatibilityNote ?: @"Wago has no release for this game version."));
                return;
            }
            TKAddOnSearchResult *target = fresh ?: result;
            [strongSelf downloadURL:target.directURL completion:^(NSURL *local, NSError *error) {
                if (!local) { if (completion) completion(nil, error); return; }
                TKAddOnDownload *download = [TKAddOnDownload new];
                download.archiveURL = local; download.name = target.name; download.version = target.version;
                download.identifier = target.identifier; download.source = TKAddOnSourceWago; download.pageURL = target.pageURL;
                if (completion) completion(download, nil);
            }];
        }];
        return;
    }
    if (result.source == TKAddOnSourceCurseForge) {
        NSNumber *modID = [result.payload[@"modId"] isKindOfClass:NSNumber.class] ? result.payload[@"modId"] : @(result.identifier.integerValue);
        [self resolveCurseForgeModID:modID name:result.name visited:[NSMutableSet new] depth:0 completion:^(TKAddOnDownload *download, NSError *error) {
            if (download) download.pageURL = result.pageURL;
            if (completion) completion(download, error);
        }];
        return;
    }
    if (completion) completion(nil, TKSourcesError(@"This provider cannot download packages."));
}

#pragma mark - Updates

- (void)latestForInstalled:(TKInstalledAddOn *)installed completion:(void (^)(TKAddOnSearchResult * _Nullable, NSError * _Nullable))completion {
    if (installed.source == TKAddOnSourceTukui) {
        [self fetchTukui:^(NSArray<NSDictionary *> *items, NSError *error) {
            if (!items) { dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, error); }); return; }
            for (NSDictionary *item in items) {
                NSString *slug = [item[@"slug"] isKindOfClass:NSString.class] ? item[@"slug"] : nil;
                NSNumber *itemID = [item[@"id"] isKindOfClass:NSNumber.class] ? item[@"id"] : nil;
                NSString *ident = itemID.stringValue;
                if (![installed.identifier isEqual:slug ?: @""] && ![installed.identifier isEqual:ident ?: @""]) continue;
                TKAddOnSearchResult *result = [TKAddOnSearchResult new];
                result.source = TKAddOnSourceTukui;
                result.identifier = slug ?: installed.identifier;
                result.name = [item[@"name"] isKindOfClass:NSString.class] ? item[@"name"] : installed.name;
                result.version = [item[@"version"] isKindOfClass:NSString.class] ? item[@"version"] : @"";
                NSString *download = [item[@"url"] isKindOfClass:NSString.class] ? item[@"url"] : nil;
                result.directURL = download.length ? [NSURL URLWithString:download] : nil;
                result.pageURL = [item[@"web_url"] isKindOfClass:NSString.class] ? item[@"web_url"] : nil;
                result.payload = item;
                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(result, nil); });
                return;
            }
            if (completion) completion(nil, TKSourcesError(@"This add-on is not in the Tukui catalog."));
        }];
        return;
    }
    if (installed.source == TKAddOnSourceGitHub) {
        NSDictionary *parts = [self githubIdentifierParts:installed.identifier];
        NSString *repository = parts[@"repository"];
        NSString *component = parts[@"component"];
        [self fetchGitHubReleases:repository component:component completion:^(NSDictionary *info, NSError *error) {
            if (!info) { dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, error); }); return; }
            NSDictionary *release = info[@"release"];
            TKAddOnSearchResult *result = [TKAddOnSearchResult new];
            result.source = TKAddOnSourceGitHub;
            result.identifier = installed.identifier;
            result.name = installed.name;
            result.version = [release[@"tag_name"] isKindOfClass:NSString.class] ? release[@"tag_name"] : @"";
            result.pageURL = [release[@"html_url"] isKindOfClass:NSString.class] ? release[@"html_url"] : nil;
            result.payload = component.length ? @{@"repository": repository, @"component": component} : @{@"repository": repository};
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(result, nil); });
        }];
        return;
    }
    if (installed.source == TKAddOnSourceWago) {
        [self fetchWagoResultForSlug:installed.identifier completion:^(TKAddOnSearchResult *result, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (result) result.pageURL = installed.pageURL ?: result.pageURL;
                if (completion) completion(result, error);
            });
        }];
        return;
    }
    if (installed.source == TKAddOnSourceCurseForge) {
        NSString *key = TKAddOnsSources.curseForgeKey;
        if (!key.length) { if (completion) completion(nil, TKSourcesError(@"CurseForge needs an API key.")); return; }
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.curseforge.com/v1/mods/%@/files?pageSize=50", installed.identifier]];
        [self getJSON:url headers:@{@"x-api-key": key} completion:^(id json, NSError *error) {
            NSArray *files = [json isKindOfClass:NSDictionary.class] && [json[@"data"] isKindOfClass:NSArray.class] ? json[@"data"] : nil;
            NSDictionary *file = files ? [self bestCurseForgeFile:files] : nil;
            if (!file) { if (completion) completion(nil, error ?: TKSourcesError(@"No Forever 1.60 file is available.")); return; }
            TKAddOnSearchResult *result = [TKAddOnSearchResult new];
            result.source = TKAddOnSourceCurseForge;
            result.identifier = installed.identifier;
            result.name = installed.name;
            result.version = [file[@"displayName"] isKindOfClass:NSString.class] ? file[@"displayName"] : ([file[@"fileName"] isKindOfClass:NSString.class] ? file[@"fileName"] : @"");
            result.payload = @{@"modId": @(installed.identifier.integerValue), @"name": installed.name};
            result.pageURL = installed.pageURL;
            result.compatibilityNote = [NSString stringWithFormat:@"CurseForge file for %@.", self.gameVersion ?: @"Forever 1.60"];
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(result, nil); });
        }];
        return;
    }
    if (completion) completion(nil, nil);
}

@end
