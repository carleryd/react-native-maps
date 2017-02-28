/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>

#import <React/RCTConvert+MapKit.h>
#import <React/RCTComponent.h>
#import "AIRMap.h"

@class RCTBridge;

@interface AIRMapAheadMarker : MKAnnotationView <MKAnnotation>

struct ImportantStatus {
    BOOL isImportant;
    float unimportantOpacity;
};
typedef struct ImportantStatus ImportantStatus;

@property (nonatomic, weak) AIRMap *map;
@property (nonatomic, weak) RCTBridge *bridge;

@property (nonatomic, strong) NSString *identifier;
@property (nonatomic, copy) NSString *imageSrc;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, assign) CLLocationCoordinate2D coordinate;
@property (nonatomic, strong) UIColor *pinColor;
@property (nonatomic, assign) NSInteger zIndex;

@property (nonatomic, assign) ImportantStatus importantStatus;
@property (nonatomic, assign) float radius;
/**
 * TODO: Is it possible to set this as UIColor directly using representedColor func?
 */
@property (nonatomic, copy) NSString *borderColor;

/**
 * These properties are part of the clustering logic.
 * hiddenByCluster - Describes whether this marker is covered by a cluster.
 * coveringMarkers - An array of markers that this marker is covering.
 */
@property (nonatomic, assign) BOOL hiddenByCluster;
@property (nonatomic, strong) NSMutableArray *coveringMarkers;


@property (nonatomic, copy) RCTBubblingEventBlock onPress;
@property (nonatomic, copy) RCTDirectEventBlock onSelect;
@property (nonatomic, copy) RCTDirectEventBlock onDeselect;
@property (nonatomic, copy) RCTDirectEventBlock onDragStart;
@property (nonatomic, copy) RCTDirectEventBlock onDrag;
@property (nonatomic, copy) RCTDirectEventBlock onDragEnd;


- (MKAnnotationView *)getAnnotationView;
- (BOOL)shouldUsePinView;
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event;

@end
