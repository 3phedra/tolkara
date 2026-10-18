#import "AddOnsManager.h"
#import "AddOnsTOC.h"
#import "AddOnsZip.h"
#include <stdio.h>
#include <stdlib.h>

#define CHECK(...) do { if (!(__VA_ARGS__)) { fprintf(stderr, "addons check failed: %s\n", #__VA_ARGS__); abort(); } } while (0)

static void WriteTOCWithInterface(NSString *directory, NSString *title, NSString *version, NSString *curseID, NSString *interface) {
    NSFileManager *fm = NSFileManager.defaultManager;
    CHECK([fm createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL]);
    NSString *toc = [NSString stringWithFormat:@"## Interface: %@\n## Title: %@\n## Version: %@\n## X-Curse-Project-ID: %@\n", interface, title, version, curseID];
    CHECK([toc writeToFile:[directory stringByAppendingPathComponent:@"TestAddon.toc"] atomically:YES encoding:NSUTF8StringEncoding error:NULL]);
}

static void WriteTOCFile(NSString *directory, NSString *file, NSString *title, NSString *version, NSString *curseID, NSString *interface) {
    NSFileManager *fm = NSFileManager.defaultManager;
    CHECK([fm createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL]);
    NSString *toc = [NSString stringWithFormat:@"## Interface: %@\n## Title: %@\n## Version: %@\n## X-Curse-Project-ID: %@\n", interface, title, version, curseID];
    CHECK([toc writeToFile:[directory stringByAppendingPathComponent:file] atomically:YES encoding:NSUTF8StringEncoding error:NULL]);
}

static void WriteTOC(NSString *directory, NSString *title, NSString *version, NSString *curseID) {
    WriteTOCWithInterface(directory, title, version, curseID, @"16001");
}

static TKInstalledAddOn *Find(NSArray<TKInstalledAddOn *> *addons, NSString *name) {
    for (TKInstalledAddOn *addon in addons) if ([addon.name isEqualToString:name]) return addon;
    return nil;
}

int main(void) {
    @autoreleasepool {
        NSFileManager *fm = NSFileManager.defaultManager;
        NSString *root = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        NSString *game = [root stringByAppendingPathComponent:@"World of Warcraft/_classic_beta_"];
        NSString *build = [root stringByAppendingPathComponent:@"build"];
        NSString *support = [root stringByAppendingPathComponent:@"support"];
        NSString *backups = [root stringByAppendingPathComponent:@"backups"];
        CHECK([fm createDirectoryAtPath:game withIntermediateDirectories:YES attributes:nil error:NULL]);
        NSString *rootBuildInfo = [[game stringByDeletingLastPathComponent] stringByAppendingPathComponent:@".build.info"];
        CHECK([@"Version!STRING:1.60.1.70450\n" writeToFile:rootBuildInfo atomically:YES encoding:NSUTF8StringEncoding error:NULL]);
        TKAddOnsManager *manager = [[TKAddOnsManager alloc] initWithGameDirectory:game supportDirectory:support backupDirectory:backups];
        CHECK([manager.gameVersion isEqualToString:@"1.60.1"]);
        CHECK([manager.buildVersion isEqualToString:@"70450"]);
        CHECK([manager.interfaceVersion isEqualToString:@"16001"]);
        CHECK([manager.productName isEqualToString:@"Forever Beta"]);
        NSError *error = nil;

        NSString *source = [build stringByAppendingPathComponent:@"TestAddon"];
        WriteTOC(source, @"Test Addon", @"1.0", @"12345");
        TKAddOnTOC *toc = [TKAddOnTOC tocAtPath:[source stringByAppendingPathComponent:@"TestAddon.toc"]];
        CHECK(toc && [toc.title isEqualToString:@"Test Addon"]);
        CHECK([toc.version isEqualToString:@"1.0"]);
        CHECK([toc.interfaceVersion isEqualToString:@"16001"]);
        CHECK([toc.interfaceVersions containsObject:@"16001"]);
        CHECK([toc.curseProjectID isEqualToString:@"12345"]);

        NSURL *archive = [NSURL fileURLWithPath:[root stringByAppendingPathComponent:@"TestAddon-1.0.zip"]];
        CHECK([TKAddOnsZip createArchiveAtURL:archive fromDirectory:source rootName:@"TestAddon" error:&error]);
        NSString *extracted = [root stringByAppendingPathComponent:@"extracted"];
        CHECK([TKAddOnsZip extractArchiveAtURL:archive toDirectory:extracted error:&error]);
        CHECK([fm fileExistsAtPath:[extracted stringByAppendingPathComponent:@"TestAddon/TestAddon.toc"]]);

        CHECK([manager installArchive:archive source:TKAddOnSourceCurseForge identifier:@"12345" name:@"Test Addon" version:@"1.0" pageURL:@"https://example.com" error:&error]);
        NSArray<TKInstalledAddOn *> *installed = [manager installedAddOns:&error];
        CHECK(installed && installed.count == 1);
        TKInstalledAddOn *addon = installed.firstObject;
        CHECK([addon.name isEqualToString:@"Test Addon"]);
        CHECK([addon.version isEqualToString:@"1.0"]);
        CHECK(addon.source == TKAddOnSourceCurseForge);
        CHECK([addon.identifier isEqualToString:@"12345"]);
        CHECK(addon.managed && addon.enabled);
        CHECK(addon.compatible);
        CHECK([addon.folders isEqualToArray:@[@"TestAddon"]]);

        NSString *badSource = [build stringByAppendingPathComponent:@"WrongAddon"];
        WriteTOCWithInterface(badSource, @"Wrong Addon", @"1.0", @"999", @"11507");
        NSURL *badArchive = [NSURL fileURLWithPath:[root stringByAppendingPathComponent:@"WrongAddon.zip"]];
        CHECK([TKAddOnsZip createArchiveAtURL:badArchive fromDirectory:badSource rootName:@"WrongAddon" error:&error]);
        CHECK(![manager installArchive:badArchive source:TKAddOnSourceImport identifier:@"wrong" name:@"Wrong Addon" version:@"1.0" pageURL:nil error:&error]);
        CHECK(error != nil);
        CHECK(![fm fileExistsAtPath:[game stringByAppendingPathComponent:@"Interface/AddOns/WrongAddon"]]);
        error = nil;

        NSString *retailSource = [build stringByAppendingPathComponent:@"RetailOnly"];
        WriteTOCWithInterface(retailSource, @"Retail Only", @"1.0", @"998", @"110005");
        NSURL *retailArchive = [NSURL fileURLWithPath:[root stringByAppendingPathComponent:@"RetailOnly.zip"]];
        CHECK([TKAddOnsZip createArchiveAtURL:retailArchive fromDirectory:retailSource rootName:@"RetailOnly" error:&error]);
        CHECK(![manager installArchive:retailArchive source:TKAddOnSourceImport identifier:@"retail" name:@"Retail Only" version:@"1.0" pageURL:nil error:&error]);
        CHECK(error != nil);
        error = nil;

        NSString *multiSource = [build stringByAppendingPathComponent:@"MultiAddon"];
        WriteTOCFile(multiSource, @"MultiAddon.toc", @"Multi Retail", @"1.0", @"997", @"110005");
        WriteTOCFile(multiSource, @"MultiAddon_Classic.toc", @"Multi Forever", @"2.0", @"997", @"16001");
        NSURL *multiArchive = [NSURL fileURLWithPath:[root stringByAppendingPathComponent:@"MultiAddon.zip"]];
        CHECK([TKAddOnsZip createArchiveAtURL:multiArchive fromDirectory:multiSource rootName:@"MultiAddon" error:&error]);
        CHECK([manager installArchive:multiArchive source:TKAddOnSourceImport identifier:@"" name:@"" version:@"" pageURL:nil error:&error]);
        installed = [manager installedAddOns:&error];
        TKInstalledAddOn *multi = Find(installed, @"Multi Forever");
        CHECK(multi && [multi.version isEqualToString:@"2.0"]);
        CHECK([multi.interfaceVersion isEqualToString:@"16001"]);
        CHECK(multi.compatible);
        CHECK([multi.folders isEqualToArray:@[@"MultiAddon"]]);

        NSString *multiInterfaceSource = [build stringByAppendingPathComponent:@"MultiInterface"];
        WriteTOCWithInterface(multiInterfaceSource, @"Multi Interface", @"4.0", @"", @"11509, 16001");
        NSURL *multiInterfaceArchive = [NSURL fileURLWithPath:[root stringByAppendingPathComponent:@"MultiInterface.zip"]];
        CHECK([TKAddOnsZip createArchiveAtURL:multiInterfaceArchive fromDirectory:multiInterfaceSource rootName:@"MultiInterface" error:&error]);
        CHECK([manager installArchive:multiInterfaceArchive source:TKAddOnSourceImport identifier:@"multi-interface" name:@"" version:@"" pageURL:nil error:&error]);
        installed = [manager installedAddOns:&error];
        TKInstalledAddOn *multiInterface = Find(installed, @"Multi Interface");
        CHECK(multiInterface != nil);
        CHECK([multiInterface.interfaceVersion isEqualToString:@"16001"]);
        CHECK(multiInterface.compatible);

        NSString *questieSource = [build stringByAppendingPathComponent:@"QuestieLike"];
        WriteTOCFile([questieSource stringByAppendingPathComponent:@"Questie"], @"Questie.toc", @"Questie", @"12.1.0", @"", @"16001");
        WriteTOCFile([questieSource stringByAppendingPathComponent:@"QuestieDB"], @"QuestieDB.toc", @"QuestieDB", @"1.0.6", @"", @"16001");
        WriteTOCFile([questieSource stringByAppendingPathComponent:@"Questie/Libs/A"], @"LibStub.toc", @"LibStub A", @"1.0", @"", @"16001");
        WriteTOCFile([questieSource stringByAppendingPathComponent:@"Questie/Libs/B"], @"LibStub.toc", @"LibStub B", @"1.0", @"", @"16001");
        NSURL *questieArchive = [NSURL fileURLWithPath:[root stringByAppendingPathComponent:@"QuestieLike.zip"]];
        CHECK([TKAddOnsZip createArchiveAtURL:questieArchive fromDirectory:questieSource rootName:@"QuestieLike" error:&error]);
        CHECK([manager installArchive:questieArchive source:TKAddOnSourceImport identifier:@"questie-like" name:@"Questie" version:@"12.1.0" pageURL:nil error:&error]);
        installed = [manager installedAddOns:&error];
        TKInstalledAddOn *questie = Find(installed, @"Questie");
        CHECK(questie != nil);
        CHECK([questie.folders containsObject:@"Questie"]);
        CHECK([questie.folders containsObject:@"QuestieDB"]);
        CHECK(![questie.folders containsObject:@"LibStub"]);
        CHECK([fm fileExistsAtPath:[game stringByAppendingPathComponent:@"Interface/AddOns/Questie/Libs/A/LibStub.toc"]]);
        CHECK([fm fileExistsAtPath:[game stringByAppendingPathComponent:@"Interface/AddOns/QuestieDB/QuestieDB.toc"]]);

        NSString *staleRoot = [build stringByAppendingPathComponent:@"StalePackage"];
        WriteTOCFile([staleRoot stringByAppendingPathComponent:@"Main"], @"Main.toc", @"Main Addon", @"1.0", @"", @"16001");
        WriteTOCFile([staleRoot stringByAppendingPathComponent:@"ExtraLib"], @"ExtraLib.toc", @"Extra Lib", @"1.0", @"", @"16001");
        NSURL *staleArchive = [NSURL fileURLWithPath:[root stringByAppendingPathComponent:@"StalePackage.zip"]];
        CHECK([TKAddOnsZip createArchiveAtURL:staleArchive fromDirectory:staleRoot rootName:@"StalePackage" error:&error]);
        CHECK([manager installArchive:staleArchive source:TKAddOnSourceImport identifier:@"stale-package" name:@"Stale Package" version:@"1.0" pageURL:nil error:&error]);
        installed = [manager installedAddOns:&error];
        TKInstalledAddOn *stale = Find(installed, @"Stale Package");
        CHECK(stale != nil);
        CHECK([stale.folders containsObject:@"Main"] && [stale.folders containsObject:@"ExtraLib"]);

        NSString *staleUpdateRoot = [build stringByAppendingPathComponent:@"StalePackage-2"];
        WriteTOCFile([staleUpdateRoot stringByAppendingPathComponent:@"Main"], @"Main.toc", @"Main Addon", @"2.0", @"", @"16001");
        NSURL *staleUpdateArchive = [NSURL fileURLWithPath:[root stringByAppendingPathComponent:@"StalePackage-2.zip"]];
        CHECK([TKAddOnsZip createArchiveAtURL:staleUpdateArchive fromDirectory:staleUpdateRoot rootName:@"StalePackage" error:&error]);
        CHECK([manager installArchive:staleUpdateArchive source:TKAddOnSourceImport identifier:@"stale-package" name:@"Stale Package" version:@"2.0" pageURL:nil error:&error]);
        installed = [manager installedAddOns:&error];
        stale = Find(installed, @"Stale Package");
        CHECK(stale != nil && [stale.version isEqualToString:@"2.0"]);
        CHECK([stale.folders isEqualToArray:@[@"Main"]]);
        CHECK(![fm fileExistsAtPath:[game stringByAppendingPathComponent:@"Interface/AddOns/ExtraLib"]]);
        CHECK([fm fileExistsAtPath:[support stringByAppendingPathComponent:[NSString stringWithFormat:@"Previous/%@/ExtraLib", stale.packageID]]]);

        NSString *spokenRoot = [build stringByAppendingPathComponent:@"SpokenPatch"];
        NSString *spokenDir = [spokenRoot stringByAppendingPathComponent:@"Spoken"];
        WriteTOCFile(spokenDir, @"Spoken.toc", @"Spoken", @"3.5.0", @"", @"16001");
        NSString *environment = @"SpokenEnv = setmetatable({}, { __index = _G })\n";
        CHECK([environment writeToFile:[spokenDir stringByAppendingPathComponent:@"Environment.lua"] atomically:YES encoding:NSUTF8StringEncoding error:NULL]);
        NSString *soundUtils = @"function SoundUtils:MuteChannel(channel, muted, fadeOut)\n    local cvar = CHANNEL_CVARS[channel]\nend\n";
        CHECK([soundUtils writeToFile:[spokenDir stringByAppendingPathComponent:@"SoundUtils.lua"] atomically:YES encoding:NSUTF8StringEncoding error:NULL]);
        NSString *spokenUI = [spokenDir stringByAppendingPathComponent:@"UI"];
        CHECK([fm createDirectoryAtPath:spokenUI withIntermediateDirectories:YES attributes:nil error:NULL]);
        NSString *welcome = @"local function Window()\n    for _, template in ipairs({ \"SettingsFrameTemplate\", \"BasicFrameTemplateWithInset\" }) do\n    end\nend\n";
        CHECK([welcome writeToFile:[spokenUI stringByAppendingPathComponent:@"Welcome.lua"] atomically:YES encoding:NSUTF8StringEncoding error:NULL]);
        NSString *options = @"local pendingLinks = {}\nfunction Options:RegisterPage(page)\n    page.category = Settings.RegisterCanvasLayoutSubcategory(self.category, page.frame, page.name)\nend\nfunction Options:AddLink(text, onClick)\n    if Settings and Settings.RegisterCanvasLayoutSubcategory then return end\nend\n";
        CHECK([options writeToFile:[spokenUI stringByAppendingPathComponent:@"Options.lua"] atomically:YES encoding:NSUTF8StringEncoding error:NULL]);
        NSString *questsDir = [spokenRoot stringByAppendingPathComponent:@"Spoken_Quests"];
        WriteTOCFile(questsDir, @"Spoken_Quests.toc", @"Spoken Quests", @"3.5.0", @"", @"16001");
        NSString *greeting = @"function GreetingFirst:SetDialogApart()\n    local dialog = Number(\"Sound_DialogVolume\")\nend\n";
        CHECK([greeting writeToFile:[questsDir stringByAppendingPathComponent:@"GreetingFirst.lua"] atomically:YES encoding:NSUTF8StringEncoding error:NULL]);
        NSString *dataModules = @"local function EnableOutOfDate(addon)\n    if not changed_checkAddonVersion then\n    end\nend\nlocal function RestoreOutOfDate(addon)\n    if changed_checkAddonVersion then\n    end\nend\n";
        CHECK([dataModules writeToFile:[questsDir stringByAppendingPathComponent:@"DataModules.lua"] atomically:YES encoding:NSUTF8StringEncoding error:NULL]);
        NSURL *spokenArchive = [NSURL fileURLWithPath:[root stringByAppendingPathComponent:@"SpokenPatch.zip"]];
        CHECK([TKAddOnsZip createArchiveAtURL:spokenArchive fromDirectory:spokenRoot rootName:@"SpokenPatch" error:&error]);
        CHECK([manager installArchive:spokenArchive source:TKAddOnSourceImport identifier:@"spoken-patch" name:@"Spoken" version:@"3.5.0" pageURL:nil error:&error]);
        NSString *installedWelcome = [NSString stringWithContentsOfFile:[game stringByAppendingPathComponent:@"Interface/AddOns/Spoken/UI/Welcome.lua"] encoding:NSUTF8StringEncoding error:NULL];
        CHECK([installedWelcome containsString:@"local templates = (Version and Version.IsCamelot)"]);
        CHECK([installedWelcome containsString:@"for _, template in ipairs(templates) do"]);
        NSString *installedOptions = [NSString stringWithContentsOfFile:[game stringByAppendingPathComponent:@"Interface/AddOns/Spoken/UI/Options.lua"] encoding:NSUTF8StringEncoding error:NULL];
        CHECK([installedOptions containsString:@"CanNestSettingsPages"]);
        CHECK([installedOptions containsString:@"Settings.RegisterCanvasLayoutCategory(page.frame, page.name)"]);
        CHECK([installedOptions containsString:@"and CanNestSettingsPages() then return end"]);
        NSString *installedEnvironment = [NSString stringWithContentsOfFile:[game stringByAppendingPathComponent:@"Interface/AddOns/Spoken/Environment.lua"] encoding:NSUTF8StringEncoding error:NULL];
        CHECK([installedEnvironment containsString:@"allowedCVars"]);
        CHECK([installedEnvironment containsString:@"Sound_EnableDialog"]);
        CHECK(![installedEnvironment containsString:@"function SpokenEnv.SetCVar() end"]);
        NSString *installedSoundUtils = [NSString stringWithContentsOfFile:[game stringByAppendingPathComponent:@"Interface/AddOns/Spoken/SoundUtils.lua"] encoding:NSUTF8StringEncoding error:NULL];
        CHECK([installedSoundUtils containsString:@"if Version and Version.IsCamelot and channel == \"Dialog\" then fadeOut = false end"]);
        NSString *installedGreeting = [NSString stringWithContentsOfFile:[game stringByAppendingPathComponent:@"Interface/AddOns/Spoken_Quests/GreetingFirst.lua"] encoding:NSUTF8StringEncoding error:NULL];
        CHECK([installedGreeting containsString:@"if Version and Version.IsCamelot then return false end"]);
        NSString *installedDataModules = [NSString stringWithContentsOfFile:[game stringByAppendingPathComponent:@"Interface/AddOns/Spoken_Quests/DataModules.lua"] encoding:NSUTF8StringEncoding error:NULL];
        CHECK([installedDataModules componentsSeparatedByString:@"if Version and Version.IsCamelot then return end"].count - 1 == 2);

        NSArray<TKAddOnWorkaround *> *workarounds = [manager workarounds:&error];
        CHECK(workarounds.count == 2);
        TKAddOnWorkaround *settingsWorkaround = nil, *soundWorkaround = nil;
        for (TKAddOnWorkaround *workaround in workarounds) {
            if ([workaround.identifier isEqualToString:@"spoken-camelot-settings"]) settingsWorkaround = workaround;
            if ([workaround.identifier isEqualToString:@"spoken-camelot-sound"]) soundWorkaround = workaround;
        }
        CHECK(settingsWorkaround != nil && settingsWorkaround.enabled && settingsWorkaround.state == TKAddOnWorkaroundStateApplied);
        CHECK(soundWorkaround != nil && soundWorkaround.enabled && soundWorkaround.state == TKAddOnWorkaroundStateApplied);

        CHECK([manager setWorkaround:settingsWorkaround enabled:NO error:&error]);
        workarounds = [manager workarounds:&error];
        for (TKAddOnWorkaround *workaround in workarounds)
            if ([workaround.identifier isEqualToString:@"spoken-camelot-settings"]) settingsWorkaround = workaround;
        CHECK(!settingsWorkaround.enabled && settingsWorkaround.state == TKAddOnWorkaroundStateDisabled);
        installedWelcome = [NSString stringWithContentsOfFile:[game stringByAppendingPathComponent:@"Interface/AddOns/Spoken/UI/Welcome.lua"] encoding:NSUTF8StringEncoding error:NULL];
        CHECK(![installedWelcome containsString:@"local templates = (Version and Version.IsCamelot)"]);
        CHECK([manager setWorkaround:settingsWorkaround enabled:YES error:&error]);
        workarounds = [manager workarounds:&error];
        for (TKAddOnWorkaround *workaround in workarounds)
            if ([workaround.identifier isEqualToString:@"spoken-camelot-settings"]) settingsWorkaround = workaround;
        CHECK(settingsWorkaround.enabled && settingsWorkaround.state == TKAddOnWorkaroundStateApplied);
        installedWelcome = [NSString stringWithContentsOfFile:[game stringByAppendingPathComponent:@"Interface/AddOns/Spoken/UI/Welcome.lua"] encoding:NSUTF8StringEncoding error:NULL];
        CHECK([installedWelcome containsString:@"local templates = (Version and Version.IsCamelot)"]);

        NSURL *spokenUpdate = [NSURL fileURLWithPath:[root stringByAppendingPathComponent:@"SpokenPatch-2.zip"]];
        CHECK([TKAddOnsZip createArchiveAtURL:spokenUpdate fromDirectory:spokenRoot rootName:@"SpokenPatch" error:&error]);
        CHECK([manager installArchive:spokenUpdate source:TKAddOnSourceImport identifier:@"spoken-patch" name:@"Spoken" version:@"3.5.1" pageURL:nil error:&error]);
        installed = [manager installedAddOns:&error];
        TKInstalledAddOn *spoken = Find(installed, @"Spoken");
        CHECK(spoken != nil && [spoken.version isEqualToString:@"3.5.1"]);
        installedOptions = [NSString stringWithContentsOfFile:[game stringByAppendingPathComponent:@"Interface/AddOns/Spoken/UI/Options.lua"] encoding:NSUTF8StringEncoding error:NULL];
        CHECK([installedOptions componentsSeparatedByString:@"CanNestSettingsPages"].count - 1 == 3);
        installedDataModules = [NSString stringWithContentsOfFile:[game stringByAppendingPathComponent:@"Interface/AddOns/Spoken_Quests/DataModules.lua"] encoding:NSUTF8StringEncoding error:NULL];
        CHECK([installedDataModules componentsSeparatedByString:@"if Version and Version.IsCamelot then return end"].count - 1 == 2);
        installedEnvironment = [NSString stringWithContentsOfFile:[game stringByAppendingPathComponent:@"Interface/AddOns/Spoken/Environment.lua"] encoding:NSUTF8StringEncoding error:NULL];
        CHECK([installedEnvironment componentsSeparatedByString:@"allowedCVars"].count - 1 == 2);
        installedSoundUtils = [NSString stringWithContentsOfFile:[game stringByAppendingPathComponent:@"Interface/AddOns/Spoken/SoundUtils.lua"] encoding:NSUTF8StringEncoding error:NULL];
        CHECK([installedSoundUtils componentsSeparatedByString:@"if Version and Version.IsCamelot and channel == \"Dialog\" then fadeOut = false end"].count - 1 == 1);

        NSString *updatedSource = [build stringByAppendingPathComponent:@"TestAddon-2"];
        WriteTOC(updatedSource, @"Test Addon", @"2.0", @"12345");
        NSURL *updatedArchive = [NSURL fileURLWithPath:[root stringByAppendingPathComponent:@"TestAddon-2.0.zip"]];
        CHECK([TKAddOnsZip createArchiveAtURL:updatedArchive fromDirectory:updatedSource rootName:@"TestAddon" error:&error]);
        CHECK([manager installArchive:updatedArchive source:TKAddOnSourceCurseForge identifier:@"12345" name:@"Test Addon" version:@"2.0" pageURL:@"https://example.com" error:&error]);
        installed = [manager installedAddOns:&error];
        addon = Find(installed, @"Test Addon");
        CHECK(addon && [addon.version isEqualToString:@"2.0"]);
        NSString *previous = [support stringByAppendingPathComponent:[NSString stringWithFormat:@"Previous/%@/TestAddon", addon.packageID]];
        CHECK([fm fileExistsAtPath:previous]);
        NSString *previousTOC = [NSString stringWithContentsOfFile:[previous stringByAppendingPathComponent:@"TestAddon.toc"] encoding:NSUTF8StringEncoding error:NULL];
        CHECK([previousTOC containsString:@"## Version: 1.0"]);

        CHECK([manager setEnabled:NO forAddOn:addon error:&error]);
        installed = [manager installedAddOns:&error];
        addon = Find(installed, @"Test Addon");
        CHECK(addon && !addon.enabled);
        CHECK(![fm fileExistsAtPath:[game stringByAppendingPathComponent:@"Interface/AddOns/TestAddon"]]);
        CHECK([fm fileExistsAtPath:[support stringByAppendingPathComponent:[NSString stringWithFormat:@"Disabled/%@/TestAddon", addon.packageID]]]);
        CHECK([manager setEnabled:YES forAddOn:addon error:&error]);
        installed = [manager installedAddOns:&error];
        addon = Find(installed, @"Test Addon");
        CHECK(addon && addon.enabled);
        CHECK([fm fileExistsAtPath:[game stringByAppendingPathComponent:@"Interface/AddOns/TestAddon/TestAddon.toc"]]);

        NSString *importSource = [build stringByAppendingPathComponent:@"ImportedAddon"];
        WriteTOC(importSource, @"Imported Addon", @"3.0", @"");
        NSURL *importArchive = [NSURL fileURLWithPath:[root stringByAppendingPathComponent:@"Imported.zip"]];
        CHECK([TKAddOnsZip createArchiveAtURL:importArchive fromDirectory:importSource rootName:@"ImportedAddon" error:&error]);
        CHECK([manager installArchive:importArchive source:TKAddOnSourceImport identifier:@"" name:@"" version:@"" pageURL:nil error:&error]);
        installed = [manager installedAddOns:&error];
        TKInstalledAddOn *imported = Find(installed, @"Imported Addon");
        CHECK(imported && [imported.version isEqualToString:@"3.0"]);
        CHECK(imported.source == TKAddOnSourceImport);

        NSString *wtf = [game stringByAppendingPathComponent:@"WTF"];
        NSString *savedVariables = [wtf stringByAppendingPathComponent:@"Account/123/SavedVariables"];
        CHECK([fm createDirectoryAtPath:savedVariables withIntermediateDirectories:YES attributes:nil error:NULL]);
        NSString *settings = [savedVariables stringByAppendingPathComponent:@"TestAddon.lua"];
        CHECK([@"TestAddonDB = { value = 42 }" writeToFile:settings atomically:YES encoding:NSUTF8StringEncoding error:NULL]);
        TKAddOnBackup *backup = [manager createBackup:&error];
        CHECK(backup && [fm fileExistsAtPath:backup.url.path]);
        CHECK([@"TestAddonDB = { value = 0 }" writeToFile:settings atomically:YES encoding:NSUTF8StringEncoding error:NULL]);
        CHECK([manager restoreBackup:backup error:&error]);
        NSString *restored = [NSString stringWithContentsOfFile:settings encoding:NSUTF8StringEncoding error:NULL];
        CHECK([restored isEqualToString:@"TestAddonDB = { value = 42 }"]);
        CHECK([manager backups].count >= 1);
        CHECK([manager deleteBackup:backup error:&error]);

        CHECK([manager removeAddOn:imported error:&error]);
        installed = [manager installedAddOns:&error];
        CHECK(Find(installed, @"Imported Addon") == nil);
        addon = Find(installed, @"Test Addon");
        CHECK(addon);
        TKInstalledAddOn *multiAddon = Find(installed, @"Multi Forever");
        if (multiAddon) CHECK([manager removeAddOn:multiAddon error:&error]);
        TKInstalledAddOn *multiInterfaceAddon = Find(installed, @"Multi Interface");
        if (multiInterfaceAddon) CHECK([manager removeAddOn:multiInterfaceAddon error:&error]);
        TKInstalledAddOn *questieAddon = Find(installed, @"Questie");
        if (questieAddon) CHECK([manager removeAddOn:questieAddon error:&error]);
        TKInstalledAddOn *staleAddon = Find(installed, @"Stale Package");
        if (staleAddon) CHECK([manager removeAddOn:staleAddon error:&error]);
        TKInstalledAddOn *spokenAddon = Find(installed, @"Spoken");
        if (spokenAddon) CHECK([manager removeAddOn:spokenAddon error:&error]);
        CHECK([manager removeAddOn:addon error:&error]);
        CHECK([manager installedAddOns:&error].count == 0);
        CHECK(![fm fileExistsAtPath:[game stringByAppendingPathComponent:@"Interface/AddOns/TestAddon"]]);
        CHECK([fm fileExistsAtPath:settings]);

        [fm removeItemAtPath:root error:NULL];
        printf("addons: ok\n");
    }
    return 0;
}
