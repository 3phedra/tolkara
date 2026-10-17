#import <Foundation/Foundation.h>
#import "../App/AppLibrary.h"

NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, TKWoWInstallationState) {
    TKWoWInstallationMissing, TKWoWInstallationOutdated,
    TKWoWInstallationNeedsRepair, TKWoWInstallationReady
};
@interface TKWoWInstallation : NSObject
@property(nonatomic) TKWoWInstallationState state;
@property(nonatomic, copy, nullable) NSString *installedVersion;
@property(nonatomic, strong, nullable) TKApp *app;
@property(nonatomic, strong, nullable) NSError *error;
@end
// Read-only check of an imported installation against a verified current plan.
// Run on a worker queue. Ready verifies metadata and executable, not every data block.
TKWoWInstallation *TKWoWInspectInstallation(TKAppLibrary *library, NSDictionary *product, NSDictionary *plan);
// Cheap, offline check: is an edition registered and are its files present?
// Ready here means "an executable exists", not "verified against the CDN".
TKWoWInstallation *TKWoWLocalInspection(TKAppLibrary *library, NSDictionary *product);
NS_ASSUME_NONNULL_END
