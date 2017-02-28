/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "AIRMapAheadMarker.h"
#import "AIRMapUtilities.h"

#import <React/RCTBridge.h>
#import <React/RCTEventDispatcher.h>
#import <React/RCTImageLoader.h>
#import <React/RCTUtils.h>
#import <React/UIView+React.h>
#import "NSString+Color.h"

#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0];


@implementation AIRMapAheadMarker { RCTImageLoaderCancellationBlock _reloadImageCancellationBlock;
    MKPinAnnotationView *_pinView;
    MKAnnotationView *_circleAnView;
    MKAnnotationView *_dotAnView;
    MKAnnotationView *_anView;
}

- (id)init {
    self = [super init];
    [self setCoveringMarkers:[[NSMutableArray alloc] init]];
    [self setCoveredState:NOT_COVERED];
    [self setScale:1.00];
    return self;
}

- (void)reactSetFrame:(CGRect)frame
{
    // Make sure we use the image size when available
    CGSize size = self.image ? self.image.size : frame.size;
    CGRect bounds = {CGPointZero, size};
    
    // The MapView is basically in charge of figuring out the center position of the marker view. If the view changed in
    // height though, we need to compensate in such a way that the bottom of the marker stays at the same spot on the
    // map.
    CGFloat dy = (bounds.size.height - self.bounds.size.height) / 2;
    CGPoint center = (CGPoint){ self.center.x, self.center.y - dy };
    
    // Avoid crashes due to nan coords
    if (isnan(center.x) || isnan(center.y) ||
        isnan(bounds.origin.x) || isnan(bounds.origin.y) ||
        isnan(bounds.size.width) || isnan(bounds.size.height)) {
        RCTLogError(@"Invalid layout for (%@)%@. position: %@. bounds: %@",
                    self.reactTag, self, NSStringFromCGPoint(center), NSStringFromCGRect(bounds));
        return;
    }
    
    self.center = center;
    self.bounds = bounds;
}

- (void)insertReactSubview:(id<RCTComponent>)subview atIndex:(NSInteger)atIndex {
    [super insertReactSubview:(UIView *)subview atIndex:atIndex];
}

- (void)removeReactSubview:(id<RCTComponent>)subview {
    [super removeReactSubview:(UIView *)subview];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    CGPoint center = [[self map] convertCoordinate:[self coordinate] toPointToView:[self map]];
    CGRect bounds = CGRectMake(center.x - [self radius],
                               center.y - [self radius],
                               [self radius] * 2,
                               [self radius] * 2);
    
    if (CGRectContainsPoint(bounds, point) && [self coveredState] == NOT_COVERED) {
        AIRMapUtilities *utilities = [AIRMapUtilities sharedInstance];
        AIRMapAheadMarker *marker = [utilities prevPressedMarker];
        
        if ([utilities prevPressedMarker] != nil) {
            CGFloat newAlpha = marker.importantStatus.isImportant == YES
                ? 1.0
                : marker.importantStatus.unimportantOpacity;
            [[marker getAnnotationView] setAlpha:newAlpha];
        }
        
        [utilities setPrevPressedMarker:self];
    }
    return [super hitTest:point withEvent:event];
}

- (UIImageView *)getImageViewFromUrl:(NSURL *)url
                          withRadius:(CGFloat)radius
                     withBorderColor:(UIColor *)borderColor
{
    UIImage *image = [UIImage imageWithData: [NSData dataWithContentsOfURL:url]];
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(-[self radius],
                                                                           -[self radius],
                                                                           [self radius]*2,
                                                                           [self radius]*2)];
    imageView.image = image;
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = YES;
    imageView.layer.cornerRadius = [self radius];
    imageView.layer.borderWidth = [self radius] * 0.1;
    imageView.layer.borderColor = [borderColor CGColor];
    imageView.layer.masksToBounds = YES;
    return imageView;
}

- (UIImage *)createCircle:(UIColor *)color {
    UIImage *circle = nil;
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(12.f, 12.f), NO, 0.0f);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSaveGState(ctx);
        
    CGRect rect = CGRectMake(0, 0, 12, 12);
    CGContextSetFillColorWithColor(ctx, color.CGColor);
    CGContextFillEllipseInRect(ctx, rect);
        
    CGContextRestoreGState(ctx);
    circle = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
        
    return circle;
}

- (void)updateAnnotationView
{
    NSLog(@"tttt updating annotationView");
    [self setAnView:_circleAnView];
    switch ([self coveredState]) {
        case FULLY_COVERED:
        {
            NSLog(@"tttt update FULLY_COVERED");
//            [self setAnView:_dotAnView];
        }
            break;
        case PARTIALLY_COVERED:
        {
            NSLog(@"tttt update PARTIALLY_COVERED");
//            if ([self scale] != 0.25) {
//                [UIView animateWithDuration:0.25 animations:^{
                    self.anView.transform = CGAffineTransformMakeScale(0.25, 0.25);
//                } completion:^(BOOL finished) {
//                }];
//                [self setScale:0.25];
//            }
//            [self setAnView:_dotAnView];
        }
            break;
        case NOT_COVERED:
        {
            NSLog(@"tttt update NOT_COVERED");
//            if ([self scale] != 1.00) {
//                [UIView animateWithDuration:0.25 animations:^{
                    self.anView.transform = CGAffineTransformMakeScale(1.00, 1.00);
//                } completion:^(BOOL finished) {
//                }];
//                [self setScale:1.00];
//            }
        }
            break;
        default:
        {
            NSLog(@"tttt update DEFAULT COVERED STATE");
        }
            break;
    }
    CGFloat alpha = (self.importantStatus.isImportant == YES)
        ? 1.0
        : self.importantStatus.unimportantOpacity;
    [[self anView] setAlpha:alpha];
}

- (MKAnnotationView *)getAnnotationView
{
    if (_anView == nil) {
        _anView = [[MKAnnotationView alloc] initWithAnnotation:self reuseIdentifier: nil];
        _anView.annotation = self;
        _anView.draggable = self.draggable;
    }
    if (_circleAnView == nil) {
        _circleAnView = [[MKAnnotationView alloc] initWithAnnotation:self reuseIdentifier: nil];
        _circleAnView.annotation = self;
        _circleAnView.draggable = self.draggable;
        
        UIImageView *imageView = [[UIImageView alloc] init];

        NSURL *url = [NSURL URLWithString: [self imageSrc]];
        imageView = [self getImageViewFromUrl:url
                                                withRadius:[self radius]
                                           withBorderColor:[[self borderColor] representedColor]
                                  ];
        [_circleAnView addSubview:imageView];
    }
    if (_dotAnView == nil) {
        _dotAnView = [[MKAnnotationView alloc] initWithAnnotation:self reuseIdentifier: nil];
        _dotAnView.annotation = self;
        _dotAnView.draggable = self.draggable;
        
        /* Use NSString-Color library to intelligently convert string colors to hex.
         * See https://github.com/nicolasgoutaland/NSString-Color
         */
        UIColor *color = [[self borderColor] representedColor];
        UIImage *image = [AIRMapUtilities createCircleWithColor:color withRadius:5];
        _dotAnView.image = image;
    }
    
    [self updateAnnotationView];
//    [self setAnView:_circleAnView];
    
    return [self anView];
}

- (void)setZIndex:(NSInteger)zIndex
{
    _zIndex = zIndex;
    self.layer.zPosition = _zIndex;
}

@end
