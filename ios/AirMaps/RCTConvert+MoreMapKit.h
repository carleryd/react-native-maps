//
// Created by Leland Richardson on 12/27/15.
// Copyright (c) 2015 Facebook. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
#import <React/RCTConvert.h>
#import "AIRMapAheadMarker.h"

@interface RCTConvert (MoreMapKit)

+ (ImportantStatus)ImportantStatus:(id)json;

@end
