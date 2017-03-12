/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "AIRMapAheadMarker.h"
#import "AIRMapAheadMarkerUtilities.h"

#import <React/RCTBridge.h>
#import <React/RCTEventDispatcher.h>
#import <React/RCTImageLoader.h>
#import <React/RCTUtils.h>
#import <React/UIView+React.h>
#import "NSString+Color.h"

#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0];


@implementation AIRMapAheadMarker {
    RCTImageLoaderCancellationBlock _reloadImageCancellationBlock;
    MKAnnotationView *_anView;
}

- (id)init {
    self = [super init];
    self.coveringMarkers = [[NSMutableArray alloc] init];
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
 * Note: Should maybe use a TouchRecognizer?
 */
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    CGPoint center = [[self map] convertCoordinate:[self coordinate] toPointToView:[self map]];
    CGRect bounds = CGRectMake(center.x - self.size.width/2,
                               center.y - self.size.height/2,
                               self.size.width,
                               self.size.height);
    BOOL existsInMap = [[[self map] annotations] containsObject:self];
    
    if (CGRectContainsPoint(bounds, point) && existsInMap == YES) {
        AIRMapAheadMarkerUtilities *utilities = [AIRMapAheadMarkerUtilities sharedInstance];
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

//- (void)fetchImageFromURL:(NSURL *)url andAddAsImageOn:(UIImageView *)imageView
//{
//    
//}
//
//- (void)downloadContentFromUrl:(NSURL *)url {
//    NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10.0];
//    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
//    if (connection) {
//        receivedData = [[NSMutableData data] retain];
//        self.downloadProgressLabel.text = @"Downloading...";
//    } else {
//        // oh noes!
//    }
//}
//
//- (void) connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
//    [receivedData setLength:0];
//}
//
//- (void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
//    [receivedData appendData:data];
//    int kb = [receivedData length] / 1024;
//    self.downloadProgressLabel.text = [NSString stringWithFormat:@"Downloaded\n%d kB", kb];
//}

/**
 * 1. Create circle with default image and add as subview.
 * 2. Start fetch of real image and when done, change default image to this image.
 */
- (void)setCircleSubviewOnAnnotationView:(MKAnnotationView *)anView
                            withImageSrc:(NSString *)imageSrc
                                withSize:(CGSize)size
                         withBorderColor:(UIColor *)borderColor
{
    NSURL *url = [NSURL URLWithString:[self imageSrc]];
    //        NSURLRequest *request = [NSURLRequest requestWithURL:[self imageSrc]];
    //        NSURLConnection *connection [[NSURLConnection alloc] initWithRequest:request delegate:<#(nullable id)#> startImmediately:YES];
//    UIImage *image = [UIImage imageWithData: [NSData dataWithContentsOfURL:url]];
    //        CGFloat width = self.bounds.size.width;
    //        CGFloat height = self.bounds.size.height;
    CGFloat width = size.width;
    CGFloat height = size.height;
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(-size.width/2,
                                                                           -size.height/2,
                                                                           size.width,
                                                                           size.height)];
    
//    imageView.image = image;
//    [fetchImageFromURL:url andAddAsImageOn:imageView];
    imageView.tag = 7777; // Use this tag to remove subview when URL image loaded.
    [imageView setBackgroundColor:borderColor];
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = YES;
    //        imageView.layer.cornerRadius = self.size.width / 2;
    imageView.layer.cornerRadius = size.width / 2;
    imageView.layer.borderWidth = imageView.layer.cornerRadius * 0.10;
    imageView.layer.borderColor = [borderColor CGColor];
    imageView.layer.masksToBounds = YES;
    [anView addSubview:imageView];
}

/**
 * The map will request a view to be shown for each annotation on the map.
 * This function returns that view.
 */
- (MKAnnotationView *)getAnnotationView
{
    if (_anView == nil) {
        _anView = [[MKAnnotationView alloc] initWithAnnotation:self reuseIdentifier: nil];
        _anView.annotation = self;
        _anView.draggable = self.draggable;
        _anView.layer.zPosition = self.zIndex;

        [self setCircleSubviewOnAnnotationView:(MKAnnotationView *)_anView
                                  withImageSrc:[self imageSrc]
                                      withSize:self.size
                               withBorderColor:[[self borderColor] representedColor]
         ];
    }
    [_anView setAlpha:[self alpha]];
        
    return _anView;
}

- (void)setZIndex:(NSInteger)zIndex
{
    _zIndex = zIndex;
    self.layer.zPosition = _zIndex;
}

- (void)setRadius:(float)radius
{
    [self setSize:CGSizeMake(radius * 2, radius * 2)];
    _radius = radius;
}

- (void)setImportantStatus:(ImportantStatus)importantStatus
{
    _importantStatus = importantStatus;
    
    CGFloat alpha = (importantStatus.isImportant == YES)
        ? 1.0
        : importantStatus.unimportantOpacity;
    [self setAlpha:alpha];
    
    if ([[self map] clusterMarkers] == YES) {
        [self.map.delegate mapView:[self map] regionDidChangeAnimated:NO];
    }
}

@end
