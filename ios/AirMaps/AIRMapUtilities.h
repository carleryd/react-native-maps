#ifndef AIRMapUtilities_h
#define AIRMapUtilities_h

#import "AIRMapMarker.h"

@interface AIRMapUtilities : NSObject {
    NSString *someProperty;
    AIRMapMarker *currentSelectedMarker;
    AIRMapMarker *touchBeginMarker;
    AIRMapMarker *touchEndMarker;
}
@property (nonatomic, retain) NSString *someProperty;
@property (nonatomic, retain) AIRMapMarker *currentSelectedMarker;
@property (nonatomic, retain) AIRMapMarker *touchBeginMarker;
@property (nonatomic, retain) AIRMapMarker *touchEndMarker;

+ (instancetype)sharedInstance;
//+ (void)setTouchBeginOnMarker:(AIRMapMarker *)marker withTouchBegin:(BOOL)touchBegin withTouchEnd:(BOOL)touchEnd;
+ (void)highlightOnTap:(UIView *)element withDuration:(NSInteger)duration toAlpha:(double)alpha;
+ (void)setAndResetAlpha:(UIView *)element fromAlpha:(double)a1 toAlpha:(double)a2 afterDuration:(NSInteger)duration;
@end

#endif /* AIRMapUtilities_h */
