#import <UIKit/UIKit.h>
#import "AddOnsViewController.h"
#import "AddOnsManager.h"
#import "AddOnsSources.h"
#include <stdio.h>
#include <stdlib.h>

@interface TKAddOnsViewController (Fixture)
- (void)loadInstalled;
- (void)modeChanged;
@end

@interface TKAddOnsFixtureSources : TKAddOnsSources
@end

@implementation TKAddOnsFixtureSources
- (void)search:(NSString *)query completion:(TKAddOnSearchCompletion)completion {
    (void)query;
    if (completion) completion(@[], @[]);
}
@end

@interface TKAddOnsFixtureDelegate : UIResponder <UIWindowSceneDelegate>
@property(nonatomic) UIWindow *window;
@property(nonatomic) TKAddOnsViewController *controller;
@property(nonatomic) UIView *loading;
@property(nonatomic) UITableView *table;
@property(nonatomic) UISegmentedControl *modes;
@end

@implementation TKAddOnsFixtureDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    (void)session; (void)options;
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *root = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    NSString *game = [root stringByAppendingPathComponent:@"World of Warcraft/_classic_beta_"];
    NSString *addon = [game stringByAppendingPathComponent:@"Interface/AddOns/TestAddon"];
    assert([fm createDirectoryAtPath:addon withIntermediateDirectories:YES attributes:nil error:NULL]);
    NSString *toc = @"## Interface: 16001\n## Title: Test Addon\n## Version: 1.0\n";
    assert([toc writeToFile:[addon stringByAppendingPathComponent:@"TestAddon.toc"] atomically:YES encoding:NSUTF8StringEncoding error:NULL]);
    NSString *build = [[game stringByDeletingLastPathComponent] stringByAppendingPathComponent:@".build.info"];
    assert([@"Version!STRING:1.60.1.70450\n" writeToFile:build atomically:YES encoding:NSUTF8StringEncoding error:NULL]);

    TKAddOnsManager *manager = [[TKAddOnsManager alloc] initWithGameDirectory:game
        supportDirectory:[root stringByAppendingPathComponent:@"support"]
        backupDirectory:[root stringByAppendingPathComponent:@"backups"]];
    TKAddOnsFixtureSources *sources = [[TKAddOnsFixtureSources alloc] initWithGameVersion:manager.gameVersion wagoFlavor:manager.wagoFlavor];
    self.controller = [[TKAddOnsViewController alloc] initWithManager:manager sources:sources];
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:self.controller];
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        fprintf(stderr, "AddOns UIKit TIMEOUT\n");
        _Exit(1);
    });
    [self performSelector:@selector(start) withObject:nil afterDelay:0.2];
}

- (void)start {
    [self.controller loadViewIfNeeded];
    self.loading = [self.controller valueForKey:@"loadingView"];
    self.table = [self.controller valueForKey:@"table"];
    self.modes = [self.controller valueForKey:@"modes"];
    assert(self.loading && self.table && self.modes);
    [self.controller loadInstalled];
    [self performSelector:@selector(checkSilentLoad) withObject:nil afterDelay:0.5];
}

- (void)checkSilentLoad {
    assert(self.loading.hidden);
    assert(self.table.userInteractionEnabled);
    self.modes.selectedSegmentIndex = 1;
    [self.controller modeChanged];
    [self performSelector:@selector(checkInstalled) withObject:nil afterDelay:0.5];
}

- (void)checkInstalled {
    assert(self.loading.hidden);
    assert(self.table.userInteractionEnabled);
    NSArray *installed = [self.controller valueForKey:@"installed"];
    assert(installed.count == 1);
    self.modes.selectedSegmentIndex = 2;
    [self.controller modeChanged];
    [self performSelector:@selector(checkWorkarounds) withObject:nil afterDelay:0.5];
}

- (void)checkWorkarounds {
    assert(self.loading.hidden);
    assert(self.table.userInteractionEnabled);
    NSArray<TKAddOnWorkaround *> *workarounds = [self.controller valueForKey:@"workarounds"];
    assert(workarounds.count == 2);
    for (TKAddOnWorkaround *workaround in workarounds)
        assert(workaround.state == TKAddOnWorkaroundStateNotInstalled);
    self.modes.selectedSegmentIndex = 0;
    [self.controller modeChanged];
    assert(self.loading.hidden);
    assert(self.table.userInteractionEnabled);
    printf("AddOns UIKit PASS: installed refresh, workarounds tab and tab switches keep loading state correct.\n");
    fflush(stdout);
    exit(0);
}

@end

@interface TKAddOnsFixtureApp : UIResponder <UIApplicationDelegate>
@end

@implementation TKAddOnsFixtureApp
- (UISceneConfiguration *)application:(UIApplication *)app configurationForConnectingSceneSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    (void)app; (void)options;
    UISceneConfiguration *config = [[UISceneConfiguration alloc] initWithName:@"AddOns fixture" sessionRole:session.role];
    config.delegateClass = TKAddOnsFixtureDelegate.class;
    return config;
}
@end

int main(int argc, char **argv) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(TKAddOnsFixtureApp.class)); }
}
