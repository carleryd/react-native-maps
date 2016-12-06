#ifndef AIRMapUtilities_h
#define AIRMapUtilities_h

@interface AIRMapUtilities : NSObject
+ (void)highlightOnTap:(UIView *)element withDuration:(NSInteger)duration toAlpha:(double)alpha;
+ (void)setAndResetAlpha:(UIView *)element fromAlpha:(double)a1 toAlpha:(double)a2 afterDuration:(NSInteger)duration;
@end

#endif /* AIRMapUtilities_h */
