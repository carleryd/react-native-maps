#import "UIView+React.h"
#import <Foundation/Foundation.h>
#import "AIRMapUtilities.h"
#import "AIRMapMarker.h"

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

@end
