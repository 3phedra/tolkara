#import "AddOnsTOC.h"

NSString *TKAddOnsRelativePath(NSString *fullPath, NSString *rootPath) {
    NSArray<NSString *> *root = rootPath.pathComponents;
    NSArray<NSString *> *full = fullPath.pathComponents;
    if (root.count && [root.firstObject isEqualToString:@"/"]) root = [root subarrayWithRange:NSMakeRange(1, root.count - 1)];
    if (full.count && [full.firstObject isEqualToString:@"/"]) full = [full subarrayWithRange:NSMakeRange(1, full.count - 1)];
    if (!root.count || full.count < root.count) return nil;
    for (NSInteger start = (NSInteger)full.count - (NSInteger)root.count; start >= 0; start--) {
        if ([[full subarrayWithRange:NSMakeRange((NSUInteger)start, root.count)] isEqualToArray:root]) {
            NSInteger tailStart = start + (NSInteger)root.count;
            NSRange tail = NSMakeRange((NSUInteger)tailStart, full.count - (NSUInteger)tailStart);
            return [[full subarrayWithRange:tail] componentsJoinedByString:@"/"];
        }
    }
    return nil;
}

@implementation TKAddOnTOC

+ (nullable instancetype)tocAtPath:(NSString *)path {
    if (!path.length) return nil;
    // QuestieDB and similar add-ons put a generated database after the TOC
    // headers; some TOCs are tens of megabytes. Only the header block is
    // needed for metadata, so read a bounded prefix instead of the whole file.
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!handle) return nil;
    NSData *head = [handle readDataOfLength:262144];
    [handle closeFile];
    if (!head.length) return nil;
    NSString *text = [[NSString alloc] initWithData:head encoding:NSUTF8StringEncoding];
    if (!text) text = [[NSString alloc] initWithData:head encoding:NSISOLatin1StringEncoding];
    if (!text) return nil;
    NSMutableDictionary<NSString *, NSString *> *fields = [NSMutableDictionary new];
    for (NSString *line in [text componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (![trimmed hasPrefix:@"##"]) continue;
        NSRange colon = [trimmed rangeOfString:@":"];
        if (colon.location == NSNotFound) continue;
        NSString *key = [[trimmed substringWithRange:NSMakeRange(2, colon.location - 2)] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].lowercaseString;
        NSString *value = [[trimmed substringFromIndex:colon.location + 1] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (key.length && value.length && !fields[key]) fields[key] = value;
    }
    TKAddOnTOC *toc = [TKAddOnTOC new];
    toc->_path = path;
    toc->_folder = path.stringByDeletingLastPathComponent.lastPathComponent;
    toc->_title = fields[@"title"].length ? fields[@"title"] : toc->_folder;
    toc->_version = fields[@"version"] ?: @"";
    NSString *interface = fields[@"interface"] ?: @"";
    NSMutableArray<NSString *> *interfaces = [NSMutableArray new];
    for (NSString *part in [interface componentsSeparatedByString:@","]) {
        NSString *trimmed = [part stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (trimmed.length) [interfaces addObject:trimmed];
    }
    toc->_interfaceVersions = interfaces.copy;
    toc->_interfaceVersion = interfaces.firstObject ?: @"";
    toc->_curseProjectID = fields[@"x-curse-project-id"];
    toc->_tukuiProjectID = fields[@"x-tukui-project-id"];
    toc->_wowiID = fields[@"x-wowi-id"];
    toc->_fields = fields.copy;
    return toc;
}

+ (NSArray<TKAddOnTOC *> *)tocsInDirectory:(NSString *)directory maxDepth:(NSInteger)depth {
    NSFileManager *fm = NSFileManager.defaultManager;
    BOOL isDirectory = NO;
    if (![fm fileExistsAtPath:directory isDirectory:&isDirectory] || !isDirectory) return @[];
    NSMutableArray<TKAddOnTOC *> *result = [NSMutableArray new];
    NSURL *root = [NSURL fileURLWithPath:directory isDirectory:YES];
    NSDirectoryEnumerator<NSURL *> *enumerator = [fm enumeratorAtURL:root
        includingPropertiesForKeys:@[NSURLIsDirectoryKey]
        options:NSDirectoryEnumerationSkipsHiddenFiles
        errorHandler:^BOOL(NSURL *url, NSError *error) { (void)url; (void)error; return YES; }];
    NSInteger limit = MAX(depth, 0);
    for (NSURL *url in enumerator) {
        NSNumber *isDir = nil;
        [url getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:NULL];
        NSString *relative = TKAddOnsRelativePath(url.path, directory);
        if (!relative) continue;
        NSInteger level = MAX(0, (NSInteger)relative.pathComponents.count - 1);
        if (level > limit) { if (isDir.boolValue) [enumerator skipDescendants]; continue; }
        if (isDir.boolValue) continue;
        if (![url.path.pathExtension.lowercaseString isEqualToString:@"toc"]) continue;
        TKAddOnTOC *toc = [self tocAtPath:url.path];
        if (toc) [result addObject:toc];
    }
    [result sortUsingComparator:^NSComparisonResult(TKAddOnTOC *a, TKAddOnTOC *b) { return [a.path compare:b.path]; }];
    return result;
}

@end
