#ifndef AIRMapUtilities_h
#define AIRMapUtilities_h

#import "AIRMapAheadMarker.h"

@interface AIRMapUtilities : NSObject {
    NSString *someProperty;
    AIRMapAheadMarker *prevPressedMarker;
    CGPoint touchStartPos;
    BOOL hasMovedRegion;
}
@property (nonatomic, retain) NSString *someProperty;
@property (nonatomic, retain) AIRMapAheadMarker *prevPressedMarker;
@property (nonatomic, assign) BOOL hasMovedRegion;
@property (nonatomic, assign) CGPoint touchStartPos;

+ (instancetype)sharedInstance;
+ (void)highlightOnTap:(UIView *)element withDuration:(NSInteger)duration toAlpha:(double)alpha;
+ (void)setAndResetAlpha:(UIView *)element
               fromAlpha:(double)a1
                 toAlpha:(double)a2
           afterDuration:(NSInteger)duration;

+ (UIImage *)createCircleWithColor:(UIColor *)color
                      withImageURL:(UIImage *)imageURL
                        withRadius:(CGFloat)radius;

+ (UILabel *)createClusterIndicatorWithColor:(UIColor *)color
                         withAmountInCluster:(NSInteger)amount
                           usingMarkerRadius:(CGFloat)radius
                           usingMarkerCenter:(CGPoint)center
                     withClusterIndicatorTag:(NSInteger)clusterIndicatorTag;

@end

#endif /* AIRMapUtilities_h */
