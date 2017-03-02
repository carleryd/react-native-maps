//
//  FBAnnotationDot.m
//  AirMaps
//
//  Created by roflmao on 2017-03-01.
//  Copyright © 2017 Christopher. All rights reserved.
//

#import "FBAnnotationDot.h"
#import "AIRMapAheadMarkerUtilities.h"

@implementation FBAnnotationDot {
    MKAnnotationView *_anView;
}

- (MKAnnotationView *)getAnnotationView
{
    if (_anView == nil) {
        static NSString* identifier = @"dotAnnotationView";
        _anView = [[MKAnnotationView alloc] initWithAnnotation:self
                                               reuseIdentifier:identifier
                     ];
        _anView.enabled = false;
        
        /* Use NSString-Color library to intelligently convert string colors to hex.
         * See https://github.com/nicolasgoutaland/NSString-Color
         */
        _anView.image = [AIRMapAheadMarkerUtilities createCircleWithColor:[self color]
                                                               withRadius:5.0
                         ];
        [_anView setAlpha:[self alpha]];
    }
    
    return _anView;
}

@end
