#import <Foundation/Foundation.h>
#import "AddOnsSources.h"
#include <stdio.h>
#include <stdlib.h>

#define CHECK(...) do { if (!(__VA_ARGS__)) { fprintf(stderr, "github check failed: %s\n", #__VA_ARGS__); abort(); } } while (0)

@interface TKAddOnsSources (GitHubTest)
- (NSDictionary *)bestGitHubReleaseInReleases:(NSArray *)releases repository:(NSString *)repository;
- (NSDictionary *)bestGitHubReleaseInReleases:(NSArray *)releases repository:(NSString *)repository component:(NSString *)component;
@end

static NSDictionary *Release(NSString *tag, BOOL prerelease, NSString *assetName) {
    NSMutableDictionary *release = [@{@"tag_name": tag, @"prerelease": @(prerelease), @"draft": @NO} mutableCopy];
    if (assetName.length) {
        release[@"assets"] = @[@{@"name": assetName,
            @"browser_download_url": [@"https://example.com/" stringByAppendingString:assetName]}];
    } else {
        release[@"assets"] = @[];
    }
    return release;
}

static NSString *SelectedTag(NSDictionary *info) {
    NSDictionary *release = info[@"release"];
    return [release isKindOfClass:NSDictionary.class] ? release[@"tag_name"] : nil;
}

int main(void) {
    @autoreleasepool {
        TKAddOnsSources *sources = [[TKAddOnsSources alloc] initWithGameVersion:@"1.60.1"];
        NSDictionary *info = [sources bestGitHubReleaseInReleases:@[
            Release(@"quests-audio/v2.4.0", NO, @"SpokenQuestsAudioAll-2.4.0.zip"),
            Release(@"spoken/v3.5.0", NO, @"Spoken-3.5.0.zip")
        ] repository:@"rusty-key/spoken-wow"];
        CHECK([SelectedTag(info) isEqualToString:@"spoken/v3.5.0"]);

        info = [sources bestGitHubReleaseInReleases:@[
            Release(@"spoken/v3.5.0", NO, @"Spoken-3.5.0.zip"),
            Release(@"spoken/v3.5.0-alpha.1", YES, @"Spoken-3.5.0-alpha.1.zip")
        ] repository:@"rusty-key/spoken-wow"];
        CHECK([SelectedTag(info) isEqualToString:@"spoken/v3.5.0"]);

        info = [sources bestGitHubReleaseInReleases:@[
            Release(@"quests-audio/v2.5.0", NO, @"SpokenQuestsAudioAll-2.5.0.zip"),
            Release(@"spoken/v3.6.0", NO, @"Spoken-3.6.0.zip"),
            Release(@"spoken/v3.5.0", NO, @"Spoken-3.5.0.zip")
        ] repository:@"rusty-key/spoken-wow"];
        CHECK([SelectedTag(info) isEqualToString:@"spoken/v3.6.0"]);

        info = [sources bestGitHubReleaseInReleases:@[
            Release(@"spoken/v3.5.0-alpha.1", YES, @"Spoken-3.5.0-alpha.1.zip"),
            Release(@"quests-audio/v2.4.0", NO, @"SpokenQuestsAudioAll-2.4.0.zip")
        ] repository:@"rusty-key/spoken-wow"];
        CHECK([SelectedTag(info) isEqualToString:@"spoken/v3.5.0-alpha.1"]);

        info = [sources bestGitHubReleaseInReleases:@[
            Release(@"v2.0.0", NO, @"Addon-2.0.0.zip"),
            Release(@"v1.0.0", NO, @"Addon-1.0.0.zip")
        ] repository:@"owner/addon"];
        CHECK([SelectedTag(info) isEqualToString:@"v2.0.0"]);

        info = [sources bestGitHubReleaseInReleases:@[
            Release(@"spoken/v9.9.9", NO, nil),
            Release(@"spoken/v3.5.0", NO, @"Spoken-3.5.0.zip")
        ] repository:@"rusty-key/spoken-wow"];
        CHECK([SelectedTag(info) isEqualToString:@"spoken/v3.5.0"]);

        info = [sources bestGitHubReleaseInReleases:@[
            Release(@"zones-audio-deDE/v2.1.1", NO, @"SpokenZonesAudio_deDE-2.1.1.zip"),
            Release(@"spoken/v3.5.0", NO, @"Spoken-3.5.0.zip")
        ] repository:@"rusty-key/spoken-wow"];
        CHECK([SelectedTag(info) isEqualToString:@"spoken/v3.5.0"]);

        info = [sources bestGitHubReleaseInReleases:@[] repository:@"owner/addon"];
        CHECK(info == nil);

        info = [sources bestGitHubReleaseInReleases:@[
            Release(@"spoken/v3.5.0", NO, @"Spoken-3.5.0.zip"),
            Release(@"quests-audio/v2.4.0", NO, @"SpokenQuestsAudioAll-2.4.0.zip"),
            Release(@"zones-audio/v2.0.1", NO, @"SpokenZonesAudio-2.0.1.zip")
        ] repository:@"rusty-key/spoken-wow" component:@"quests-audio"];
        CHECK([SelectedTag(info) isEqualToString:@"quests-audio/v2.4.0"]);

        info = [sources bestGitHubReleaseInReleases:@[
            Release(@"quests-audio/v2.5.0", NO, @"SpokenQuestsAudioAll-2.5.0.zip"),
            Release(@"quests-audio/v2.4.0", NO, @"SpokenQuestsAudioAll-2.4.0.zip")
        ] repository:@"rusty-key/spoken-wow" component:@"quests-audio"];
        CHECK([SelectedTag(info) isEqualToString:@"quests-audio/v2.5.0"]);

        info = [sources bestGitHubReleaseInReleases:@[
            Release(@"quests-audio/v2.5.0-beta.1", YES, @"SpokenQuestsAudioAll-2.5.0-beta.1.zip"),
            Release(@"quests-audio/v2.4.0", NO, @"SpokenQuestsAudioAll-2.4.0.zip")
        ] repository:@"rusty-key/spoken-wow" component:@"quests-audio"];
        CHECK([SelectedTag(info) isEqualToString:@"quests-audio/v2.4.0"]);

        info = [sources bestGitHubReleaseInReleases:@[
            Release(@"spoken/v3.5.0", NO, @"Spoken-3.5.0.zip"),
            Release(@"zones-audio/v2.0.1", NO, @"SpokenZonesAudio-2.0.1.zip")
        ] repository:@"rusty-key/spoken-wow" component:@"books-audio"];
        CHECK(info == nil);

        printf("github source: ok\n");
    }
    return 0;
}
