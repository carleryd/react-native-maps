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


@implementation AIRMapAheadMarker {
    RCTImageLoaderCancellationBlock _reloadImageCancellationBlock;
    MKPinAnnotationView *_pinView;
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
    if (CGRectContainsPoint(self.bounds, point)) {
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
    if ([self shouldUsePinView]) {
        // In this case, we want to render a platform "default" marker.
        if (_pinView == nil) {
            _pinView = [[MKPinAnnotationView alloc] initWithAnnotation:self reuseIdentifier: nil];
            _pinView.annotation = self;
        }
        
        _pinView.enabled = false;
        _pinView.draggable = self.draggable;
        _pinView.layer.zPosition = self.zIndex;
        
        // TODO(lmr): Looks like this API was introduces in iOS 8. We may want to handle differently for earlier
        // versions. Right now it's just leaving it with the default color. People needing the colors are free to
        // use their own custom markers.
        if ([_pinView respondsToSelector:@selector(setPinTintColor:)]) {
            _pinView.pinTintColor = self.pinColor;
        }
        
        return _pinView;
    } else {
        // If it has subviews, it means we are wanting to render a custom marker with arbitrary react views.
        // if it has a non-null image, it means we want to render a custom marker with the image.
        // In either case, we want to return the AIRMapAheadMarker since it is both an MKAnnotation and an
        // MKAnnotationView all at the same time.
        self.layer.zPosition = self.zIndex;
        return self;
    }
}

- (BOOL)shouldUsePinView
{
    return self.reactSubviews.count == 0 && !self.imageSrc;
}

- (void)setImageSrc:(NSString *)imageSrc
{
    _imageSrc = imageSrc;
    
    if (_reloadImageCancellationBlock) {
        _reloadImageCancellationBlock();
        _reloadImageCancellationBlock = nil;
    }
    _reloadImageCancellationBlock = [_bridge.imageLoader loadImageWithURLRequest:[RCTConvert NSURLRequest:_imageSrc]
                                                                            size:self.bounds.size
                                                                           scale:RCTScreenScale()
                                                                         clipped:YES
                                                                      resizeMode:RCTResizeModeCenter
                                                                   progressBlock:nil
                                                                partialLoadBlock:nil
                                                                 completionBlock:^(NSError *error, UIImage *image) {
                                                                     if (error) {
                                                                         // TODO(lmr): do something with the error?
                                                                         NSLog(@"%@", error);
                                                                     }
                                                                     dispatch_async(dispatch_get_main_queue(), ^{
                                                                         self.image = image;
                                                                     });
                                                                 }];
}

- (void)setPinColor:(UIColor *)pinColor
{
    _pinColor = pinColor;
    
    if ([_pinView respondsToSelector:@selector(setPinTintColor:)]) {
        _pinView.pinTintColor = _pinColor;
    }
}

- (void)setZIndex:(NSInteger)zIndex
{
    _zIndex = zIndex;
    self.layer.zPosition = _zIndex;
}

@end
