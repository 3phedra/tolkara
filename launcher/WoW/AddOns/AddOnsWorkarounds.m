#import "AddOnsWorkarounds.h"
#import "AddOnsTOC.h"

static NSError *TKWorkaroundError(NSString *message) {
    return [NSError errorWithDomain:@"TKAddOnWorkaroundErrorDomain" code:1 userInfo:@{NSLocalizedDescriptionKey: message}];
}

@implementation TKAddOnWorkaroundPatch

+ (instancetype)patchPath:(NSString *)path find:(NSString *)find replace:(NSString *)replace marker:(NSString *)marker {
    return [self patchPath:path find:find replace:replace marker:marker optional:NO];
}

+ (instancetype)patchPath:(NSString *)path find:(NSString *)find replace:(NSString *)replace marker:(NSString *)marker optional:(BOOL)optional {
    TKAddOnWorkaroundPatch *patch = [self new];
    patch.path = path;
    patch.find = find;
    patch.replace = replace;
    patch.marker = marker;
    patch.optional = optional;
    return patch;
}

@end

@implementation TKAddOnWorkaround

+ (NSArray<TKAddOnWorkaround *> *)builtInWorkarounds {
    NSString *welcomeFind = @"    for _, template in ipairs({ \"SettingsFrameTemplate\", \"BasicFrameTemplateWithInset\" }) do";
    NSString *welcomeReplace = @"    local templates = (Version and Version.IsCamelot) and { \"BasicFrameTemplateWithInset\" } or { \"SettingsFrameTemplate\", \"BasicFrameTemplateWithInset\" }\n"
        @"    for _, template in ipairs(templates) do";

    NSString *optionsAnchor = @"local pendingLinks = {}\n";
    NSString *optionsHelper = @"local function CanNestSettingsPages()\n"
        @"    if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then return false end\n"
        @"    return not (Version and Version.IsCamelot)\n"
        @"end\n\n";
    NSString *registerFind = @"function Options:RegisterPage(page)\n"
        @"    page.category = Settings.RegisterCanvasLayoutSubcategory(self.category, page.frame, page.name)\n"
        @"end";
    NSString *registerReplace = @"function Options:RegisterPage(page)\n"
        @"    if CanNestSettingsPages() then\n"
        @"        page.category = Settings.RegisterCanvasLayoutSubcategory(self.category, page.frame, page.name)\n"
        @"        return\n"
        @"    end\n"
        @"    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then\n"
        @"        page.category = Settings.RegisterCanvasLayoutCategory(page.frame, page.name)\n"
        @"        Settings.RegisterAddOnCategory(page.category)\n"
        @"    end\n"
        @"end";
    NSString *linkFind = @"    if Settings and Settings.RegisterCanvasLayoutSubcategory then return end";
    NSString *linkReplace = @"    if Settings and Settings.RegisterCanvasLayoutSubcategory and CanNestSettingsPages() then return end";

    NSString *environmentAnchor = @"}, { __index = _G })\n";
    NSString *environmentBlock = @"local _, _, _, environmentInterface = GetBuildInfo()\n"
        @"if environmentInterface and environmentInterface >= 16000 and environmentInterface < 20000 then\n"
        @"    local allowedCVars = {\n"
        @"        Sound_EnableSFX = true, Sound_EnableMusic = true,\n"
        @"        Sound_EnableAmbience = true, Sound_EnableDialog = true,\n"
        @"    }\n"
        @"    function SpokenEnv.SetCVar(name, value)\n"
        @"        if allowedCVars[name] then _G.SetCVar(name, value) end\n"
        @"    end\n"
        @"end\n";
    NSString *environmentReplace = [environmentAnchor stringByAppendingFormat:@"\n%@", environmentBlock];

    NSString *muteFind = @"function SoundUtils:MuteChannel(channel, muted, fadeOut)\n"
        @"    local cvar = CHANNEL_CVARS[channel]";
    NSString *muteReplace = @"function SoundUtils:MuteChannel(channel, muted, fadeOut)\n"
        @"    if Version and Version.IsCamelot and channel == \"Dialog\" then fadeOut = false end\n"
        @"    local cvar = CHANNEL_CVARS[channel]";

    NSString *greetingFind = @"function GreetingFirst:SetDialogApart()\n"
        @"    local dialog = Number(\"Sound_DialogVolume\")";
    NSString *greetingReplace = @"function GreetingFirst:SetDialogApart()\n"
        @"    if Version and Version.IsCamelot then return false end\n"
        @"    local dialog = Number(\"Sound_DialogVolume\")";

    NSString *enableFind = @"local function EnableOutOfDate(addon)\n"
        @"    if not changed_checkAddonVersion then";
    NSString *enableReplace = @"local function EnableOutOfDate(addon)\n"
        @"    if Version and Version.IsCamelot then return end\n"
        @"    if not changed_checkAddonVersion then";
    NSString *restoreFind = @"local function RestoreOutOfDate(addon)\n"
        @"    if changed_checkAddonVersion then";
    NSString *restoreReplace = @"local function RestoreOutOfDate(addon)\n"
        @"    if Version and Version.IsCamelot then return end\n"
        @"    if changed_checkAddonVersion then";

    TKAddOnWorkaround *settings = [TKAddOnWorkaround new];
    settings.identifier = @"spoken-camelot-settings";
    settings.name = @"Spoken settings on Forever";
    settings.summary = @"Uses Spoken's basic welcome frame and top-level settings pages on the Forever client instead of the Blizzard-only Settings UI.";
    settings.targetFolders = @[@"Spoken", @"Spoken_Quests"];
    settings.targetVersionPrefix = @"3.5";
    settings.defaultEnabled = YES;
    settings.patches = @[
        [TKAddOnWorkaroundPatch patchPath:@"Spoken/UI/Welcome.lua" find:welcomeFind replace:welcomeReplace
                                   marker:@"local templates = (Version and Version.IsCamelot)"],
        [TKAddOnWorkaroundPatch patchPath:@"Spoken/UI/Options.lua" find:optionsAnchor
                                  replace:[optionsAnchor stringByAppendingString:optionsHelper]
                                   marker:@"local function CanNestSettingsPages()"],
        [TKAddOnWorkaroundPatch patchPath:@"Spoken/UI/Options.lua" find:registerFind replace:registerReplace
                                   marker:@"if CanNestSettingsPages() then"],
        [TKAddOnWorkaroundPatch patchPath:@"Spoken/UI/Options.lua" find:linkFind replace:linkReplace
                                   marker:@"and CanNestSettingsPages() then return end"],
    ];

    TKAddOnWorkaround *sound = [TKAddOnWorkaround new];
    sound.identifier = @"spoken-camelot-sound";
    sound.name = @"Spoken sound on Forever";
    sound.summary = @"Keeps the Dialog channel mute for Silence NPC Voices and skips the protected volume and out-of-date CVar writes.";
    sound.targetFolders = @[@"Spoken", @"Spoken_Quests"];
    sound.targetVersionPrefix = @"3.5";
    sound.defaultEnabled = YES;
    sound.patches = @[
        [TKAddOnWorkaroundPatch patchPath:@"Spoken/Environment.lua" find:environmentAnchor
                                  replace:environmentReplace marker:@"local allowedCVars"],
        [TKAddOnWorkaroundPatch patchPath:@"Spoken/SoundUtils.lua" find:muteFind replace:muteReplace
                                   marker:@"if Version and Version.IsCamelot and channel == \"Dialog\" then fadeOut = false end"],
        [TKAddOnWorkaroundPatch patchPath:@"Spoken_Quests/GreetingFirst.lua" find:greetingFind replace:greetingReplace
                                   marker:@"if Version and Version.IsCamelot then return false end"],
        [TKAddOnWorkaroundPatch patchPath:@"Spoken_Quests/DataModules.lua" find:enableFind replace:enableReplace
                                   marker:@"local function EnableOutOfDate(addon)\n    if Version and Version.IsCamelot then return end"],
        [TKAddOnWorkaroundPatch patchPath:@"Spoken_Quests/DataModules.lua" find:restoreFind replace:restoreReplace
                                   marker:@"local function RestoreOutOfDate(addon)\n    if Version and Version.IsCamelot then return end"],
    ];
    return @[settings, sound];
}

- (NSString *)versionInDirectory:(NSString *)directory {
    NSString *folder = self.targetFolders.firstObject;
    if (!folder.length) return nil;
    NSArray<TKAddOnTOC *> *tocs = [TKAddOnTOC tocsInDirectory:[directory stringByAppendingPathComponent:folder] maxDepth:1];
    return tocs.firstObject.version;
}

- (TKAddOnWorkaroundState)stateInDirectory:(NSString *)directory detail:(NSString * _Nullable * _Nullable)detail {
    if (detail) *detail = nil;
    NSString *target = self.targetFolders.firstObject;
    if (!target.length) return TKAddOnWorkaroundStateNotInstalled;
    BOOL isDirectory = NO;
    if (![NSFileManager.defaultManager fileExistsAtPath:[directory stringByAppendingPathComponent:target] isDirectory:&isDirectory] || !isDirectory) {
        if (detail) *detail = @"The target add-on is not installed.";
        return TKAddOnWorkaroundStateNotInstalled;
    }
    NSString *version = [self versionInDirectory:directory];
    if (self.targetVersionPrefix.length && version.length && ![version hasPrefix:self.targetVersionPrefix]) {
        if (detail) *detail = [NSString stringWithFormat:@"Installed version %@; this workaround targets %@.x.", version, self.targetVersionPrefix];
        return TKAddOnWorkaroundStateIncompatible;
    }
    NSUInteger applied = 0, pending = 0;
    for (TKAddOnWorkaroundPatch *patch in self.patches) {
        NSString *path = [directory stringByAppendingPathComponent:patch.path];
        NSString *text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
        if (!text) {
            if (patch.optional) continue;
            if (detail) *detail = [NSString stringWithFormat:@"Missing %@.", patch.path];
            return TKAddOnWorkaroundStateIncompatible;
        }
        if ([text containsString:patch.marker] || [text containsString:patch.replace]) applied++;
        else if ([text containsString:patch.find]) pending++;
        else {
            if (detail) *detail = [NSString stringWithFormat:@"A patch no longer matches %@.", patch.path];
            return TKAddOnWorkaroundStateIncompatible;
        }
    }
    if (applied == self.patches.count) {
        if (detail) *detail = @"All patches are applied.";
        return TKAddOnWorkaroundStateApplied;
    }
    if (applied == 0 && pending > 0) {
        if (detail) *detail = @"No patches are applied.";
        return TKAddOnWorkaroundStateDisabled;
    }
    if (detail) *detail = [NSString stringWithFormat:@"%lu of %lu patches are applied.", (unsigned long)applied, (unsigned long)self.patches.count];
    return TKAddOnWorkaroundStatePartial;
}

- (BOOL)applyPatch:(TKAddOnWorkaroundPatch *)patch inDirectory:(NSString *)directory error:(NSError **)error {
    NSString *path = [directory stringByAppendingPathComponent:patch.path];
    NSError *readError = nil;
    NSString *text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&readError];
    if (!text) {
        if (patch.optional) return YES;
        if (error) *error = TKWorkaroundError([NSString stringWithFormat:@"Could not read %@.", patch.path]);
        return NO;
    }
    if ([text containsString:patch.marker] || [text containsString:patch.replace]) return YES;
    if (![text containsString:patch.find]) {
        if (patch.optional) return YES;
        if (error) *error = TKWorkaroundError([NSString stringWithFormat:@"This workaround no longer matches %@.", patch.path]);
        return NO;
    }
    text = [text stringByReplacingOccurrencesOfString:patch.find withString:patch.replace];
    if (![text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:error]) return NO;
    return YES;
}

- (BOOL)revertPatch:(TKAddOnWorkaroundPatch *)patch inDirectory:(NSString *)directory error:(NSError **)error {
    NSString *path = [directory stringByAppendingPathComponent:patch.path];
    NSString *text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
    if (!text) return YES;
    if (![text containsString:patch.marker] && ![text containsString:patch.replace]) return YES;
    if (![text containsString:patch.replace]) return YES;
    text = [text stringByReplacingOccurrencesOfString:patch.replace withString:patch.find];
    return [text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:error];
}

- (BOOL)applyInDirectory:(NSString *)directory error:(NSError **)error {
    NSString *version = [self versionInDirectory:directory];
    if (self.targetVersionPrefix.length && version.length && ![version hasPrefix:self.targetVersionPrefix]) {
        if (error) *error = TKWorkaroundError([NSString stringWithFormat:@"This workaround targets %@.x; the installed version is %@.", self.targetVersionPrefix, version]);
        return NO;
    }
    NSMutableArray<TKAddOnWorkaroundPatch *> *applied = [NSMutableArray new];
    for (TKAddOnWorkaroundPatch *patch in self.patches) {
        if (![self applyPatch:patch inDirectory:directory error:error]) {
            for (TKAddOnWorkaroundPatch *previous in applied.reverseObjectEnumerator)
                [self revertPatch:previous inDirectory:directory error:NULL];
            return NO;
        }
        [applied addObject:patch];
    }
    return YES;
}

- (BOOL)revertInDirectory:(NSString *)directory error:(NSError **)error {
    for (TKAddOnWorkaroundPatch *patch in self.patches.reverseObjectEnumerator) {
        if (![self revertPatch:patch inDirectory:directory error:error]) return NO;
    }
    return YES;
}

@end
