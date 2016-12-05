#import "UIView+React.h"
#import <Foundation/Foundation.h>
#import "AIRMapUtilities.h"

@implementation AIRMapUtilities

+ (void)highlightOnTap:(UIView *)element withDuration:(NSInteger)duration toAlpha:(double)alpha {
    element.alpha = alpha;
    
    dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_MSEC * duration);
    dispatch_after(delay, dispatch_get_main_queue(), ^(void){
        // do work in the UI thread here
        element.alpha = 1.0;
    });
}

@end
