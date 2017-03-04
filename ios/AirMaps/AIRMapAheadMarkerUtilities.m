#import "UIView+React.h"
#import <Foundation/Foundation.h>
#import "AIRMapAheadMarkerUtilities.h"
#import "AIRMapAheadMarker.h"
#import "NSString+Color.h"

@implementation AIRMapAheadMarkerUtilities

/**
 * This creates a singleton of the AIRMapAheadMarkerUtilities object.
 * This object is used to keep track of touch events on AIRMapAheadMarker's.
 */
+ (instancetype)sharedInstance {
    static AIRMapAheadMarkerUtilities *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
        // Do any other initialisation stuff here
    });
    return sharedInstance;
}

+ (UIImage *)createMarkerCircleWithColor:(UIColor *)color
                      withImageURL:(UIImage *)imageURL
                        withRadius:(CGFloat)radius
{
    UIImage* circle = [self createCircleWithColor:color withRadius:radius];
    
    NSURL *url = [NSURL URLWithString: imageURL];
    UIImage *image = [UIImage imageWithData: [NSData dataWithContentsOfURL:url]];

    return circle;
}

+ (UIImage *)createCircleWithColor:(UIColor *)color
                        withRadius:(CGFloat)radius
{
    UIImage *circle = nil;
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(radius*2, radius*2), NO, 0.0f);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSaveGState(ctx);
    
    CGRect rect = CGRectMake(0, 0, radius*2, radius*2);
    CGContextSetFillColorWithColor(ctx, color.CGColor);
    CGContextFillEllipseInRect(ctx, rect);
    
    CGContextRestoreGState(ctx);
    circle = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return circle;
}

+ (UILabel *)createClusterIndicatorWithColor:(UIColor *)color
                         withAmountInCluster:(NSInteger)amount
                           usingMarkerRadius:(CGFloat)radius
                     withClusterIndicatorTag:(NSInteger)tag
{
    NSString *amountString = [NSString stringWithFormat:@"%lu", (unsigned long)amount];
    NSString *limitedAmountString = (amount > 99) ? @"99+" : amountString;
    CGRect labelRect = CGRectMake(radius * 0.20, -radius * 1.20, radius, radius);
    UILabel *labelView = [[UILabel alloc] initWithFrame:labelRect];
    labelView.tag = tag;
    [labelView setBackgroundColor:color];

    labelView.layer.cornerRadius = labelView.frame.size.width / 2;
    labelView.clipsToBounds = YES;
    [labelView setText:limitedAmountString];
    [labelView setAdjustsFontSizeToFitWidth:YES];
    [labelView setTextColor:[@"white" representedColor]];
    [labelView setTextAlignment:NSTextAlignmentCenter];
    return labelView;
}

@end
