#ifndef AIRMapUtilities_h
#define AIRMapUtilities_h

#import "AIRMapMarker.h"

@interface AIRMapUtilities : NSObject {
    NSString *someProperty;
    AIRMapMarker *prevPressedMarker;
}
@property (nonatomic, retain) NSString *someProperty;
@property (nonatomic, retain) AIRMapMarker *prevPressedMarker;

+ (instancetype)sharedInstance;
+ (void)highlightOnTap:(UIView *)element withDuration:(NSInteger)duration toAlpha:(double)alpha;
+ (void)setAndResetAlpha:(UIView *)element fromAlpha:(double)a1 toAlpha:(double)a2 afterDuration:(NSInteger)duration;
@end

#endif /* AIRMapUtilities_h */
