#import <UIKit/UIKit.h>
#import "AddOnsSources.h"

NS_ASSUME_NONNULL_BEGIN
/// The curated Spoken package: the core add-on (Quests, Places, Readables)
/// plus the optional English voice packs. Sizes and release tags come from
/// the GitHub releases, so the user can see the 2.4 GB before committing.
@interface TKSpokenPackagesViewController : UITableViewController
- (instancetype)initWithSources:(TKAddOnsSources *)sources;
@property(nonatomic, copy, nullable) void (^onInstall)(NSArray<TKAddOnComponent *> *components);
@end
NS_ASSUME_NONNULL_END
