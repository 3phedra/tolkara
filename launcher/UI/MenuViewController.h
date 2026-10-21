#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@interface TKMenuItem : NSObject
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy, nullable) NSString *subtitle;
@property(nonatomic, copy, nullable) NSString *symbolName;
@property(nonatomic) BOOL selected;
@property(nonatomic) BOOL destructive;
@property(nonatomic, copy, nullable) void (^handler)(void);
+ (instancetype)itemWithTitle:(NSString *)title subtitle:(nullable NSString *)subtitle
    symbol:(nullable NSString *)symbol selected:(BOOL)selected destructive:(BOOL)destructive
    handler:(nullable void (^)(void))handler;
@end

/// A theme-native replacement for action sheets. Popover on iPad, a medium
/// sheet on iPhone; dark surface, serif heading and gold selection marks.
@interface TKMenuViewController : UIViewController
+ (void)presentFrom:(UIViewController *)presenter sourceView:(nullable UIView *)sourceView
    sourceRect:(CGRect)sourceRect title:(nullable NSString *)title message:(nullable NSString *)message
    items:(NSArray<TKMenuItem *> *)items;
@end
NS_ASSUME_NONNULL_END
