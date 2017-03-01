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

- (id)init {
    self = [super init];
    self.coveringMarkers = [[NSMutableArray alloc] init];
    self.bounds = CGRectMake(0, 0, [self radius] * 2, [self radius] * 2);
    return self;
}

- (void)insertReactSubview:(id<RCTComponent>)subview atIndex:(NSInteger)atIndex {
    [super insertReactSubview:(UIView *)subview atIndex:atIndex];
}

- (void)removeReactSubview:(id<RCTComponent>)subview {
    [super removeReactSubview:(UIView *)subview];
}

/**
 * We need to determine where on the map our annotation is and then determine how large it is.
 * Using this information, we can determine if the click event on the screen hit our annotation.
 * Note: existsInMap is for some reason necessary because even though we remove annotations which
 *       are no longer visible(i.e. clustered) from the map, the hitTest is still performed on them.
 */
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    CGPoint center = [[self map] convertCoordinate:[self coordinate] toPointToView:[self map]];
    CGRect bounds = CGRectMake(center.x - self.bounds.size.width/2 ,
                               center.y - self.bounds.size.height/2,
                               self.bounds.size.width,
                               self.bounds.size.height);
    BOOL existsInMap = [[[self map] annotations] containsObject:self];
    
    if (CGRectContainsPoint(bounds, point) && existsInMap) {
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

- (MKAnnotationView *)getAnnotationView
{
    if (_anView == nil) {
        _anView = [[MKAnnotationView alloc] initWithAnnotation:self reuseIdentifier: nil];
        _anView.annotation = self;
        _anView.draggable = self.draggable;
        _anView.layer.zPosition = self.zIndex;

        
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
        imageView.layer.borderColor = [[[self borderColor] representedColor] CGColor];
        imageView.layer.masksToBounds = YES;
        
        [_anView addSubview:imageView];
    }
    CGFloat alpha = (self.importantStatus.isImportant == YES)
        ? 1.0
        : self.importantStatus.unimportantOpacity;
    [_anView setAlpha:alpha];
        
    return _anView;
}

- (void)setZIndex:(NSInteger)zIndex
{
    _zIndex = zIndex;
    self.layer.zPosition = _zIndex;
}

@end
