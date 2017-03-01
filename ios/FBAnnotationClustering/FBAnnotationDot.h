//
//  FBAnnotationDot.h
//  AirMaps
//
//  Created by roflmao on 2017-03-01.
//  Copyright © 2017 Christopher. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>


/**
 Class that is used to display annotation clusters.
 */
@interface FBAnnotationDot : NSObject <MKAnnotation>

/// Coordinate of the annotation. It will always be set.
@property (nonatomic, assign) CLLocationCoordinate2D coordinate;

@property (nonatomic, strong) UIColor *color;

@property (nonatomic, assign) CGFloat alpha;

@end
