#import "TouchGamepadLayout.h"
#include <math.h>

static NSString *const LayoutKey = @"WolkaraTouchLayoutV1";
NSNotificationName const AKGamepadLayoutDidChangeNotification = @"AKGamepadLayoutDidChange";
static CGFloat Clamp(CGFloat value, CGFloat minimum, CGFloat maximum, CGFloat fallback) {
    return isfinite(value) ? MAX(minimum,MIN(maximum,value)) : fallback;
}
static CGFloat Number(id value, CGFloat fallback) {
    return [value isKindOfClass:NSNumber.class] ? [value doubleValue] : fallback;
}
@implementation AKGamepadLayout {
    NSUserDefaults *_defaults;
    NSMutableDictionary *_positions;
    NSMutableDictionary<NSString *, NSNumber *> *_scales;
}
- (instancetype)initWithDefaults:(NSUserDefaults *)defaults {
    if ((self = [super init])) {
        _defaults = defaults;
        id saved = [defaults objectForKey:LayoutKey];
        // Import the former app's preferences once; current settings take priority.
        if (!saved) {
            id legacy = [defaults objectForKey:@"WowkaraTouchLayoutV1"];
            if ([legacy isKindOfClass:NSDictionary.class]) {
                saved = legacy;
                [defaults setObject:legacy forKey:LayoutKey];
            }
        }
        NSDictionary *values = [saved isKindOfClass:NSDictionary.class] ? saved : @{};
        self.opacity = Number(values[@"opacity"],0.8);
        self.rearScale = Number(values[@"rearScale"],1);
        self.frontScale = Number(values[@"frontScale"],1);
        self.hapticsEnabled = Number(values[@"hapticsEnabled"],1) != 0;
        self.performanceOverlayEnabled = Number(values[@"performanceOverlayEnabled"],0) != 0;
        _positions = [NSMutableDictionary new];
        id positions = values[@"positions"];
        if ([positions isKindOfClass:NSDictionary.class]) for (NSString *key in positions) {
            id point = positions[key];
            if (![key isKindOfClass:NSString.class] || ![point isKindOfClass:NSArray.class] || [point count] != 2) continue;
            CGFloat x = Number(point[0],NAN), y = Number(point[1],NAN);
            if (isfinite(x) && isfinite(y)) _positions[key] = @[@(Clamp(x,0,1,0)),@(Clamp(y,0,1,0))];
        }
        _scales = [NSMutableDictionary new];
        id scales = values[@"scales"];
        if ([scales isKindOfClass:NSDictionary.class]) for (NSString *key in scales) {
            if (![key isKindOfClass:NSString.class]) continue;
            CGFloat value = Number(scales[key],1);
            if (isfinite(value) && value != 1) _scales[key] = @(Clamp(value,0.75,2.5,1));
        }
    }
    return self;
}
- (void)setOpacity:(CGFloat)value { _opacity = Clamp(value,0.2,1,0.8); }
- (void)setRearScale:(CGFloat)value { _rearScale = Clamp(value,0.8,1.5,1); }
- (void)setFrontScale:(CGFloat)value { _frontScale = Clamp(value,0.65,1.4,1); }
- (CGFloat)scaleForItem:(NSString *)item {
    return _scales[item] ? _scales[item].doubleValue : 1;
}
- (void)setScale:(CGFloat)scale forItem:(NSString *)item {
    if (![item isKindOfClass:NSString.class] || !item.length) return;
    CGFloat value = Clamp(scale,0.75,2.5,1);
    if (fabs(value-1) < 0.0001) [_scales removeObjectForKey:item];
    else _scales[item] = @(value);
}
- (CGRect)frameForItem:(NSString *)item defaultFrame:(CGRect)frame inBounds:(CGRect)bounds {
    CGFloat baseWidth = MAX(0,MIN(frame.size.width,bounds.size.width));
    CGFloat baseHeight = MAX(0,MIN(frame.size.height,bounds.size.height));
    CGFloat scale = [self scaleForItem:item];
    CGFloat width = MAX(0,MIN(baseWidth*scale,bounds.size.width));
    CGFloat height = MAX(0,MIN(baseHeight*scale,bounds.size.height));
    CGFloat dx = MAX(0,bounds.size.width-baseWidth), dy = MAX(0,bounds.size.height-baseHeight);
    NSArray *point = _positions[item];
    CGFloat x = point ? [point[0] doubleValue]*dx : frame.origin.x-bounds.origin.x;
    CGFloat y = point ? [point[1] doubleValue]*dy : frame.origin.y-bounds.origin.y;
    CGFloat maxX = MAX(0,bounds.size.width-width), maxY = MAX(0,bounds.size.height-height);
    x = MIN(Clamp(x,0,dx,0),maxX); y = MIN(Clamp(y,0,dy,0),maxY);
    return CGRectMake(bounds.origin.x+x,bounds.origin.y+y,width,height);
}
- (void)moveItem:(NSString *)item toFrame:(CGRect)frame inBounds:(CGRect)bounds {
    CGFloat dx = MAX(0,bounds.size.width-frame.size.width), dy = MAX(0,bounds.size.height-frame.size.height);
    CGFloat x = dx > 0 ? (frame.origin.x-bounds.origin.x)/dx : 0;
    CGFloat y = dy > 0 ? (frame.origin.y-bounds.origin.y)/dy : 0;
    _positions[item] = @[@(Clamp(x,0,1,0)),@(Clamp(y,0,1,0))];
}
- (void)save {
    [_defaults setObject:@{@"opacity":@(_opacity),@"rearScale":@(_rearScale),
        @"frontScale":@(_frontScale),@"hapticsEnabled":@(_hapticsEnabled),
        @"performanceOverlayEnabled":@(_performanceOverlayEnabled),@"positions":_positions,
        @"scales":_scales} forKey:LayoutKey];
    [NSNotificationCenter.defaultCenter postNotificationName:AKGamepadLayoutDidChangeNotification object:_defaults];
}
- (void)reset {
    self.opacity = 0.8; self.rearScale = 1; self.frontScale = 1;
    self.hapticsEnabled = YES;
    self.performanceOverlayEnabled = NO;
    [_positions removeAllObjects]; [_scales removeAllObjects]; [self save];
}
@end
