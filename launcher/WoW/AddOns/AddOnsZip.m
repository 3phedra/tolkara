#import "AddOnsZip.h"
#import <zlib.h>
#import "AddOnsTOC.h"
#import <sys/stat.h>

NSErrorDomain const TKAddOnsZipErrorDomain = @"TKAddOnsZipErrorDomain";

// Spoken's "All" quest voice pack alone is about 1.5 GB (roughly 15k audio
// entries). These remain absolute bounds, not a free pass for arbitrary ZIPs.
static const NSUInteger TKZipMaxCompressed = 2ull * 1024u * 1024u * 1024u;
static const NSUInteger TKZipMaxExpanded = 4ull * 1024u * 1024u * 1024u;
static const NSUInteger TKZipMaxEntry = 256u * 1024u * 1024u;
static const NSUInteger TKZipMaxEntries = 30000;
static const NSUInteger TKZipBuffer = 256u * 1024u;

static NSError *TKZipError(NSString *message) {
    return [NSError errorWithDomain:TKAddOnsZipErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey:message}];
}

static uint16_t TKRead16(const uint8_t *bytes, NSUInteger length, NSUInteger offset) {
    if (offset + 2 > length) return 0;
    return (uint16_t)(bytes[offset] | ((uint16_t)bytes[offset + 1] << 8));
}

static uint32_t TKRead32(const uint8_t *bytes, NSUInteger length, NSUInteger offset) {
    if (offset + 4 > length) return 0;
    return (uint32_t)bytes[offset] | ((uint32_t)bytes[offset + 1] << 8) |
        ((uint32_t)bytes[offset + 2] << 16) | ((uint32_t)bytes[offset + 3] << 24);
}

static void TKAppend16(NSMutableData *data, uint16_t value) {
    uint8_t bytes[2] = {(uint8_t)value, (uint8_t)(value >> 8)};
    [data appendBytes:bytes length:sizeof bytes];
}

static void TKAppend32(NSMutableData *data, uint32_t value) {
    uint8_t bytes[4] = {(uint8_t)value, (uint8_t)(value >> 8), (uint8_t)(value >> 16), (uint8_t)(value >> 24)};
    [data appendBytes:bytes length:sizeof bytes];
}

static BOOL TKSafePath(NSString *name) {
    if (!name.length || [name hasPrefix:@"/"] || [name hasPrefix:@"~"]) return NO;
    if ([name rangeOfString:@"\\"].location != NSNotFound) return NO;
    for (NSString *component in [name componentsSeparatedByString:@"/"]) {
        if (!component.length || [component isEqualToString:@"."] || [component isEqualToString:@".."]) return NO;
        if ([component rangeOfString:@":"].location != NSNotFound) return NO;
    }
    return YES;
}

static NSData *TKInflateRaw(NSData *compressed, NSUInteger expected, NSError **error) {
    if (compressed.length > TKZipMaxCompressed || expected > TKZipMaxEntry) {
        if (error) *error = TKZipError(@"The package is too large.");
        return nil;
    }
    z_stream stream = {0};
    if (inflateInit2(&stream, -MAX_WBITS) != Z_OK) {
        if (error) *error = TKZipError(@"Could not start decompression.");
        return nil;
    }
    NSMutableData *output = [NSMutableData dataWithCapacity:MIN(expected, (NSUInteger)TKZipBuffer)];
    uint8_t *buffer = malloc(TKZipBuffer);
    if (!buffer) { inflateEnd(&stream); if (error) *error = TKZipError(@"Out of memory."); return nil; }
    stream.next_in = (Bytef *)compressed.bytes;
    stream.avail_in = (uInt)compressed.length;
    NSError *failure = nil;
    for (;;) {
        stream.next_out = buffer;
        stream.avail_out = (uInt)TKZipBuffer;
        int status = inflate(&stream, Z_NO_FLUSH);
        NSUInteger produced = TKZipBuffer - stream.avail_out;
        if (produced) [output appendBytes:buffer length:produced];
        if (output.length > TKZipMaxEntry || output.length > expected) {
            failure = TKZipError(@"The package expands beyond its declared size."); break;
        }
        if (status == Z_STREAM_END) break;
        if (status != Z_OK) { failure = TKZipError(@"The package has invalid compressed data."); break; }
    }
    free(buffer);
    inflateEnd(&stream);
    if (!failure && output.length != expected) failure = TKZipError(@"The package is truncated.");
    if (failure) { if (error) *error = failure; return nil; }
    return output;
}

static NSData *TKDeflateRaw(NSData *input, NSError **error) {
    z_stream stream = {0};
    if (deflateInit2(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, -MAX_WBITS, 8, Z_DEFAULT_STRATEGY) != Z_OK) {
        if (error) *error = TKZipError(@"Could not start compression.");
        return nil;
    }
    NSMutableData *output = [NSMutableData dataWithCapacity:MAX((NSUInteger)64, input.length / 2)];
    uint8_t *buffer = malloc(TKZipBuffer);
    if (!buffer) { deflateEnd(&stream); if (error) *error = TKZipError(@"Out of memory."); return nil; }
    stream.next_in = (Bytef *)input.bytes;
    stream.avail_in = (uInt)input.length;
    NSError *failure = nil;
    for (;;) {
        stream.next_out = buffer;
        stream.avail_out = (uInt)TKZipBuffer;
        int status = deflate(&stream, Z_FINISH);
        NSUInteger produced = TKZipBuffer - stream.avail_out;
        if (produced) [output appendBytes:buffer length:produced];
        if (status == Z_STREAM_END) break;
        if (status != Z_OK && status != Z_BUF_ERROR) { failure = TKZipError(@"Could not compress the backup."); break; }
        if (status == Z_BUF_ERROR && produced == 0) { failure = TKZipError(@"Could not compress the backup."); break; }
    }
    free(buffer);
    deflateEnd(&stream);
    if (failure) { if (error) *error = failure; return nil; }
    return output;
}

static void TKDOSTime(NSDate *date, uint16_t *timeValue, uint16_t *dateValue) {
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    calendar.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    NSDateComponents *parts = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay|NSCalendarUnitHour|NSCalendarUnitMinute|NSCalendarUnitSecond fromDate:date ?: [NSDate date]];
    NSInteger year = MAX(1980, MIN(2107, parts.year));
    *dateValue = (uint16_t)(((year - 1980) << 9) | (parts.month << 5) | parts.day);
    *timeValue = (uint16_t)((parts.hour << 11) | (parts.minute << 5) | (parts.second / 2));
}

@implementation TKAddOnsZip

+ (BOOL)extractArchiveAtURL:(NSURL *)archiveURL toDirectory:(NSString *)destination error:(NSError **)error {
    NSData *archive = [NSData dataWithContentsOfURL:archiveURL options:NSDataReadingMappedIfSafe error:error];
    if (!archive) return NO;
    const uint8_t *bytes = archive.bytes;
    NSUInteger length = archive.length;
    if (length < 22) { if (error) *error = TKZipError(@"The package is not a ZIP archive."); return NO; }
    NSInteger searchStart = (NSInteger)length - 22 - 65535;
    if (searchStart < 0) searchStart = 0;
    NSInteger eocd = -1;
    for (NSInteger i = (NSInteger)length - 22; i >= searchStart; i--) {
        if (TKRead32(bytes, length, (NSUInteger)i) == 0x06054b50) { eocd = i; break; }
    }
    if (eocd < 0) { if (error) *error = TKZipError(@"The package is not a ZIP archive."); return NO; }
    uint16_t disk = TKRead16(bytes, length, eocd + 4);
    uint16_t centralDisk = TKRead16(bytes, length, eocd + 6);
    uint16_t diskEntries = TKRead16(bytes, length, eocd + 8);
    uint16_t entries = TKRead16(bytes, length, eocd + 10);
    uint32_t centralSize = TKRead32(bytes, length, eocd + 12);
    uint32_t centralOffset = TKRead32(bytes, length, eocd + 16);
    if (disk || centralDisk || diskEntries != entries) { if (error) *error = TKZipError(@"Multi-disk ZIP archives are not supported."); return NO; }
    if (entries == 0xFFFF || centralSize == 0xFFFFFFFF || centralOffset == 0xFFFFFFFF) { if (error) *error = TKZipError(@"ZIP64 packages are not supported."); return NO; }
    if (entries == 0 || entries > TKZipMaxEntries) { if (error) *error = TKZipError(@"The package has an unsupported number of files."); return NO; }
    if ((NSUInteger)centralOffset + centralSize > length) { if (error) *error = TKZipError(@"The package directory is truncated."); return NO; }
    NSFileManager *fm = NSFileManager.defaultManager;
    if (![fm createDirectoryAtPath:destination withIntermediateDirectories:YES attributes:nil error:error]) return NO;
    NSMutableSet<NSString *> *seen = [NSMutableSet new];
    NSUInteger totalExpanded = 0;
    NSUInteger position = centralOffset;
    for (uint16_t index = 0; index < entries; index++) {
        if (position + 46 > length || TKRead32(bytes, length, position) != 0x02014b50) {
            if (error) *error = TKZipError(@"The package directory is invalid."); return NO;
        }
        uint16_t flags = TKRead16(bytes, length, position + 8);
        uint16_t method = TKRead16(bytes, length, position + 10);
        uint32_t crc = TKRead32(bytes, length, position + 16);
        uint32_t compressedSize = TKRead32(bytes, length, position + 20);
        uint32_t expandedSize = TKRead32(bytes, length, position + 24);
        uint16_t nameLength = TKRead16(bytes, length, position + 28);
        uint16_t extraLength = TKRead16(bytes, length, position + 30);
        uint16_t commentLength = TKRead16(bytes, length, position + 32);
        uint32_t external = TKRead32(bytes, length, position + 38);
        uint32_t localOffset = TKRead32(bytes, length, position + 42);
        NSUInteger next = position + 46 + nameLength + extraLength + commentLength;
        if (next > length || position + 46 + nameLength > length) { if (error) *error = TKZipError(@"The package directory is truncated."); return NO; }
        NSString *name = [[NSString alloc] initWithBytes:bytes + position + 46 length:nameLength encoding:NSUTF8StringEncoding];
        if (!name) name = [[NSString alloc] initWithBytes:bytes + position + 46 length:nameLength encoding:NSISOLatin1StringEncoding];
        position = next;
        if (!name.length) { if (error) *error = TKZipError(@"The package contains a nameless file."); return NO; }
        if (flags & 0x41) { if (error) *error = TKZipError(@"Encrypted packages are not supported."); return NO; }
        if (method != 0 && method != 8) { if (error) *error = TKZipError(@"The package uses an unsupported compression method."); return NO; }
        BOOL isDirectory = [name hasSuffix:@"/"];
        NSString *clean = isDirectory ? [name substringToIndex:name.length - 1] : name;
        if (!TKSafePath(clean)) { if (error) *error = TKZipError([NSString stringWithFormat:@"The package contains an unsafe path: %@", name]); return NO; }
        NSString *normalized = [clean.precomposedStringWithCanonicalMapping lowercaseString];
        if ([seen containsObject:normalized]) { if (error) *error = TKZipError(@"The package contains duplicate paths."); return NO; }
        [seen addObject:normalized];
        uint32_t mode = (external >> 16) & 0xF000;
        if (mode == S_IFLNK || mode == S_IFIFO || mode == S_IFCHR || mode == S_IFBLK || mode == S_IFSOCK) {
            if (error) *error = TKZipError(@"The package contains a link or special file."); return NO;
        }
        if (isDirectory) {
            NSError *dirError = nil;
            if (![fm createDirectoryAtPath:[destination stringByAppendingPathComponent:clean] withIntermediateDirectories:YES attributes:nil error:&dirError]) {
                if (error) *error = dirError; return NO;
            }
            continue;
        }
        if (expandedSize > TKZipMaxEntry || totalExpanded + expandedSize > TKZipMaxExpanded || compressedSize > TKZipMaxCompressed) {
            if (error) *error = TKZipError(@"The package expands beyond the allowed size."); return NO;
        }
        totalExpanded += expandedSize;
        if (localOffset + 30 > length || TKRead32(bytes, length, localOffset) != 0x04034b50) {
            if (error) *error = TKZipError(@"A package file entry is invalid."); return NO;
        }
        uint16_t localName = TKRead16(bytes, length, localOffset + 26);
        uint16_t localExtra = TKRead16(bytes, length, localOffset + 28);
        NSUInteger dataOffset = (NSUInteger)localOffset + 30 + localName + localExtra;
        if (dataOffset + compressedSize > length) { if (error) *error = TKZipError(@"A package file is truncated."); return NO; }
        NSData *payload = nil;
        if (method == 0) {
            if (compressedSize != expandedSize) { if (error) *error = TKZipError(@"A stored package file has inconsistent sizes."); return NO; }
            payload = [archive subdataWithRange:NSMakeRange(dataOffset, compressedSize)];
        } else {
            NSData *compressed = [archive subdataWithRange:NSMakeRange(dataOffset, compressedSize)];
            payload = TKInflateRaw(compressed, expandedSize, error);
            if (!payload) return NO;
        }
        uLong actual = crc32(0, payload.bytes, (uInt)payload.length);
        if ((uint32_t)actual != crc) { if (error) *error = TKZipError(@"A package file failed its checksum."); return NO; }
        NSString *path = [destination stringByAppendingPathComponent:clean];
        NSString *parent = path.stringByDeletingLastPathComponent;
        if (![fm createDirectoryAtPath:parent withIntermediateDirectories:YES attributes:nil error:error]) return NO;
        if (![payload writeToFile:path options:NSDataWritingAtomic error:error]) return NO;
    }
    return YES;
}

+ (BOOL)createArchiveAtURL:(NSURL *)archiveURL fromDirectory:(NSString *)sourceDirectory rootName:(NSString *)rootName error:(NSError **)error {
    NSFileManager *fm = NSFileManager.defaultManager;
    BOOL isDirectory = NO;
    if (![fm fileExistsAtPath:sourceDirectory isDirectory:&isDirectory] || !isDirectory) {
        if (error) *error = TKZipError(@"There is nothing to back up yet.");
        return NO;
    }
    NSString *root = [rootName stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
    if (!root.length) { if (error) *error = TKZipError(@"The archive root is empty."); return NO; }
    if (![fm createDirectoryAtPath:archiveURL.URLByDeletingLastPathComponent.path withIntermediateDirectories:YES attributes:nil error:error]) return NO;
    NSMutableData *archive = [NSMutableData new];
    NSMutableData *central = [NSMutableData new];
    uint16_t count = 0;
    NSURL *sourceRoot = [NSURL fileURLWithPath:sourceDirectory isDirectory:YES];
    NSDirectoryEnumerator<NSURL *> *enumerator = [fm enumeratorAtURL:sourceRoot
        includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLIsSymbolicLinkKey, NSURLContentModificationDateKey]
        options:NSDirectoryEnumerationSkipsHiddenFiles
        errorHandler:^BOOL(NSURL *url, NSError *failure) { (void)url; (void)failure; return YES; }];
    for (NSURL *url in enumerator) {
        NSNumber *isDir = nil, *isLink = nil; NSDate *modified = nil;
        [url getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:NULL];
        [url getResourceValue:&isLink forKey:NSURLIsSymbolicLinkKey error:NULL];
        [url getResourceValue:&modified forKey:NSURLContentModificationDateKey error:NULL];
        if (isLink.boolValue) continue;
        if (isDir.boolValue) continue;
        NSString *relative = TKAddOnsRelativePath(url.path, sourceDirectory);
        if (!relative.length) continue;
        NSData *contents = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:error];
        if (!contents) return NO;
        if (contents.length > TKZipMaxEntry) { if (error) *error = TKZipError(@"A settings file is too large to back up."); return NO; }
        NSString *name = [root stringByAppendingPathComponent:relative];
        BOOL ascii = [name canBeConvertedToEncoding:NSASCIIStringEncoding];
        uint16_t flags = ascii ? 0 : 0x0800;
        uint16_t timeValue = 0, dateValue = 0;
        TKDOSTime(modified, &timeValue, &dateValue);
        uint32_t crc = (uint32_t)crc32(0, contents.bytes, (uInt)contents.length);
        NSError *compressionError = nil;
        NSData *compressed = TKDeflateRaw(contents, &compressionError);
        uint16_t method = 8;
        if (!compressed || compressed.length >= contents.length) { compressed = contents; method = 0; compressionError = nil; }
        if (!compressed) { if (error) *error = compressionError; return NO; }
        if (count == UINT16_MAX) { if (error) *error = TKZipError(@"The backup has too many files."); return NO; }
        uint32_t localOffset = (uint32_t)archive.length;
        TKAppend32(archive, 0x04034b50);
        TKAppend16(archive, 20);
        TKAppend16(archive, flags);
        TKAppend16(archive, method);
        TKAppend16(archive, timeValue);
        TKAppend16(archive, dateValue);
        TKAppend32(archive, crc);
        TKAppend32(archive, (uint32_t)compressed.length);
        TKAppend32(archive, (uint32_t)contents.length);
        NSData *nameData = [name dataUsingEncoding:NSUTF8StringEncoding];
        TKAppend16(archive, (uint16_t)nameData.length);
        TKAppend16(archive, 0);
        [archive appendData:nameData];
        [archive appendData:compressed];
        TKAppend32(central, 0x02014b50);
        TKAppend16(central, 20);
        TKAppend16(central, 20);
        TKAppend16(central, flags);
        TKAppend16(central, method);
        TKAppend16(central, timeValue);
        TKAppend16(central, dateValue);
        TKAppend32(central, crc);
        TKAppend32(central, (uint32_t)compressed.length);
        TKAppend32(central, (uint32_t)contents.length);
        TKAppend16(central, (uint16_t)nameData.length);
        TKAppend16(central, 0);
        TKAppend16(central, 0);
        TKAppend16(central, 0);
        TKAppend16(central, 0);
        TKAppend32(central, ((uint32_t)(S_IFREG | 0644) << 16));
        TKAppend32(central, localOffset);
        [central appendData:nameData];
        count++;
    }
    if (!count) { if (error) *error = TKZipError(@"There is nothing to back up yet."); return NO; }
    uint32_t centralOffset = (uint32_t)archive.length;
    [archive appendData:central];
    TKAppend32(archive, 0x06054b50);
    TKAppend16(archive, 0);
    TKAppend16(archive, 0);
    TKAppend16(archive, count);
    TKAppend16(archive, count);
    TKAppend32(archive, (uint32_t)central.length);
    TKAppend32(archive, centralOffset);
    TKAppend16(archive, 0);
    return [archive writeToURL:archiveURL options:NSDataWritingAtomic error:error];
}

@end
