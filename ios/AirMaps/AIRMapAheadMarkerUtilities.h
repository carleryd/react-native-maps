#ifndef AIRMapAheadMarkerUtilities_h
#define AIRMapAheadMarkerUtilities_h

#import "AIRMapAheadMarker.h"

@interface AIRMapAheadMarkerUtilities : NSObject {
    AIRMapAheadMarker *prevPressedMarker;
    CGPoint touchStartPos;
    
    dispatch_queue_t concurrentQueue;
    NSOperationQueue *operationQueue;
}
@property (nonatomic, retain) AIRMapAheadMarker *prevPressedMarker;
@property (nonatomic, assign) CGPoint touchStartPos;
@property (nonatomic, retain) NSOperationQueue *operationQueue;

+ (instancetype)sharedInstance;

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

#endif /* AIRMapAheadMarkerUtilities_h */
