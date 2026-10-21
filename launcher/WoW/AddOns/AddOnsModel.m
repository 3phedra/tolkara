#import "AddOnsModel.h"

NSString *TKAddOnSourceName(TKAddOnSourceKind source) {
    switch (source) {
        case TKAddOnSourceTukui: return @"Tukui";
        case TKAddOnSourceCurseForge: return @"CurseForge";
        case TKAddOnSourceGitHub: return @"GitHub";
        case TKAddOnSourceImport: return @"Imported";
        case TKAddOnSourceWago: return @"Wago";
        case TKAddOnSourceLocal: return @"Local";
    }
    return @"Unknown";
}

NSString *TKAddOnSourceKey(TKAddOnSourceKind source) {
    switch (source) {
        case TKAddOnSourceTukui: return @"tukui";
        case TKAddOnSourceCurseForge: return @"curseforge";
        case TKAddOnSourceGitHub: return @"github";
        case TKAddOnSourceImport: return @"import";
        case TKAddOnSourceWago: return @"wago";
        case TKAddOnSourceLocal: return @"local";
    }
    return @"local";
}

TKAddOnSourceKind TKAddOnSourceFromKey(NSString *key) {
    if ([key isEqualToString:@"tukui"]) return TKAddOnSourceTukui;
    if ([key isEqualToString:@"curseforge"]) return TKAddOnSourceCurseForge;
    if ([key isEqualToString:@"github"]) return TKAddOnSourceGitHub;
    if ([key isEqualToString:@"import"]) return TKAddOnSourceImport;
    if ([key isEqualToString:@"wago"]) return TKAddOnSourceWago;
    return TKAddOnSourceLocal;
}

@implementation TKAddOnSearchResult
- (instancetype)init {
    if ((self = [super init])) { _dependencyNames = @[]; _compatible = YES; }
    return self;
}
@end

@implementation TKAddOnDownload
- (instancetype)init {
    if ((self = [super init])) _dependencies = @[];
    return self;
}
@end

@implementation TKAddOnComponent
@end

@implementation TKInstalledAddOn
- (instancetype)init {
    if ((self = [super init])) { _folders = @[]; _compatible = YES; }
    return self;
}
@end

@implementation TKAddOnBackup
@end
