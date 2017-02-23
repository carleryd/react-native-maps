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
    MKAnnotationView *_anView;
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
    
    if (CGRectContainsPoint(bounds, point)) {
        AIRMapUtilities *utilities = [AIRMapUtilities sharedInstance];
        
        if ([utilities prevPressedMarker] != nil) {
            utilities.prevPressedMarker.alpha = 1.0; // TODO: Reset somehow(maybe user_has_popped is true/false)
        }
        
        [utilities setPrevPressedMarker:self];
    }
    return [super hitTest:point withEvent:event];
}

- (MKAnnotationView *)getAnnotationView
{
    if (_anView == nil) {
        _anView = [[MKAnnotationView alloc] initWithAnnotation:self reuseIdentifier: nil];
        _anView.annotation = self;
        _anView.draggable = self.draggable;
        
        NSURL *url = [NSURL URLWithString: [self imageSrc]];
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
        imageView.layer.borderColor = [[@"#039be5" representedColor] CGColor];
        imageView.layer.masksToBounds = YES;
        [_anView addSubview:imageView];
    }
    return _anView;
}

- (void)setZIndex:(NSInteger)zIndex
{
    _zIndex = zIndex;
    self.layer.zPosition = _zIndex;
}

@end
