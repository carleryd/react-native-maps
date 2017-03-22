/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "AIRMapAheadMarkerManager.h"

#import <React/RCTConvert+CoreLocation.h>
#import "RCTConvert+MoreMapKit.h"
#import <React/UIView+React.h>
#import "AIRMapAheadMarker.h"

@interface AIRMapAheadMarkerManager () <MKMapViewDelegate>

@end

@implementation AIRMapAheadMarkerManager

RCT_EXPORT_MODULE()

- (UIView *)view
{
    AIRMapAheadMarker *marker = [AIRMapAheadMarker new];
    marker.bridge = self.bridge;
    return marker;
}

RCT_EXPORT_VIEW_PROPERTY(identifier, NSString)
//RCT_EXPORT_VIEW_PROPERTY(reuseIdentifier, NSString)
RCT_EXPORT_VIEW_PROPERTY(title, NSString)
RCT_REMAP_VIEW_PROPERTY(description, subtitle, NSString)
RCT_EXPORT_VIEW_PROPERTY(coordinate, CLLocationCoordinate2D)
RCT_EXPORT_VIEW_PROPERTY(centerOffset, CGPoint)
RCT_EXPORT_VIEW_PROPERTY(imageSrc, NSString)
RCT_EXPORT_VIEW_PROPERTY(pinColor, UIColor)
RCT_EXPORT_VIEW_PROPERTY(draggable, BOOL)
RCT_EXPORT_VIEW_PROPERTY(zIndex, NSInteger)
RCT_EXPORT_VIEW_PROPERTY(importantStatus, ImportantStatus)
RCT_EXPORT_VIEW_PROPERTY(radius, float)
RCT_EXPORT_VIEW_PROPERTY(postId, NSString)
RCT_EXPORT_VIEW_PROPERTY(borderColor, NSString)


RCT_EXPORT_VIEW_PROPERTY(onPress, RCTBubblingEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onSelect, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onDeselect, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onDragStart, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onDrag, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onDragEnd, RCTDirectEventBlock)

#pragma mark - Events

@end
