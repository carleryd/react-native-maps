#ifndef AIRMapUtilities_h
#define AIRMapUtilities_h

#import "AIRMapAheadMarker.h"

@interface AIRMapUtilities : NSObject {
    NSString *someProperty;
    AIRMapAheadMarker *prevPressedMarker;
    CGPoint touchStartPos;
    BOOL hasMovedRegion;
    
    dispatch_queue_t concurrentQueue;
    NSOperationQueue *operationQueue;
}
@property (nonatomic, retain) NSString *someProperty;
@property (nonatomic, retain) AIRMapAheadMarker *prevPressedMarker;
@property (nonatomic, assign) BOOL hasMovedRegion;
@property (nonatomic, assign) CGPoint touchStartPos;
@property (nonatomic, retain) dispatch_queue_t concurrentQueue;
@property (nonatomic, retain) NSOperationQueue *operationQueue;

+ (instancetype)sharedInstance;
+ (void)highlightOnTap:(UIView *)element withDuration:(NSInteger)duration toAlpha:(double)alpha;
+ (void)setAndResetAlpha:(UIView *)element
               fromAlpha:(double)a1
                 toAlpha:(double)a2
           afterDuration:(NSInteger)duration;

+ (UIImage *)createMarkerCircleWithColor:(UIColor *)color
                            withImageURL:(UIImage *)imageURL
                              withRadius:(CGFloat)radius;

+ (UIImage *)createCircleWithColor:(UIColor *)color
                        withRadius:(CGFloat)radius;

+ (UILabel *)createClusterIndicatorWithColor:(UIColor *)color
                         withAmountInCluster:(NSInteger)amount
                           usingMarkerRadius:(CGFloat)radius
                     withClusterIndicatorTag:(NSInteger)clusterIndicatorTag;

@end

#endif /* AIRMapUtilities_h */
