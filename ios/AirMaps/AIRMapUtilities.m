#import "UIView+React.h"
#import <Foundation/Foundation.h>
#import "AIRMapUtilities.h"
#import "AIRMapAheadMarker.h"
#import "NSString+Color.h"

@implementation AIRMapUtilities

+ (instancetype)sharedInstance {
    static AIRMapUtilities *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
        // Do any other initialisation stuff here
    });
    return sharedInstance;
}

+ (void)highlightOnTap:(UIView *)element withDuration:(NSInteger)duration toAlpha:(double)alpha {
    [self setAndResetAlpha:element fromAlpha:alpha toAlpha:1.0 afterDuration:duration];
    UIView *parent = element.superview;
    UIView *parent1 = parent.superview;
    UIView *parent2 = parent1.superview;
    if (parent) {
        [self setAndResetAlpha:parent fromAlpha:alpha toAlpha:1.0 afterDuration:duration];
        if (parent1) {
            [self setAndResetAlpha:parent1 fromAlpha:alpha toAlpha:1.0 afterDuration:duration];
            if (parent2) {
                [self setAndResetAlpha:parent2 fromAlpha:alpha toAlpha:1.0 afterDuration:duration];
            }
        }
    }
}

+ (void)setAndResetAlpha:(UIView *)element fromAlpha:(double)a1 toAlpha:(double)a2 afterDuration:(NSInteger)duration {
    element.alpha = a1;
    dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_MSEC * duration);
    dispatch_after(delay, dispatch_get_main_queue(), ^(void){
        // do work in the UI thread here
        element.alpha = a2;
    });
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
    
    // TODO: second argument is opaque, set it depending on isImportant
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
    CGRect labelRect = CGRectMake(radius * 0.20, -radius * 1.20, radius, radius);
    UILabel *labelView = [[UILabel alloc] initWithFrame:labelRect];
    labelView.tag = tag;
    [labelView setBackgroundColor:color];

    labelView.layer.cornerRadius = labelView.frame.size.width / 2;
    labelView.clipsToBounds = YES;
    [labelView setText:[NSString stringWithFormat:@"%lu", (unsigned long)amount]];
    [labelView setTextColor:[@"white" representedColor]];
    [labelView setTextAlignment:NSTextAlignmentCenter];
    return labelView;
}


@end
