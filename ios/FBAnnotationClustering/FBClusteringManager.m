//
//  FBClusterManager.m
//  AnnotationClustering
//
//  Created by Filip Bec on 05/01/14.
//  Copyright (c) 2014 Infinum Ltd. All rights reserved.
//

#import "FBClusteringManager.h"
#import "FBQuadTree.h"
#import "AIRMapMarker.h"
#import "AIRMapAheadMarker.h"

static NSString * const kFBClusteringManagerLockName = @"co.infinum.clusteringLock";

#pragma mark - Utility functions

NSInteger FBZoomScaleToZoomLevel(MKZoomScale scale)
{
    double totalTilesAtMaxZoom = MKMapSizeWorld.width / 256.0;
    NSInteger zoomLevelAtMaxZoom = log2(totalTilesAtMaxZoom);
    NSInteger zoomLevel = MAX(0, zoomLevelAtMaxZoom + floor(log2f(scale) + 0.5));
    
    return zoomLevel;
}

CGFloat FBCellSizeForZoomScale(MKZoomScale zoomScale)
{
    NSInteger zoomLevel = FBZoomScaleToZoomLevel(zoomScale);
    
    switch (zoomLevel) {
        case 13:
        case 14:
        case 15:
            return 64;
        case 16:
        case 17:
        case 18:
            return 32;
        case 19:
            return 16;
            
        default:
            return 88;
    }
}

#pragma mark - FBClusteringManager

@interface FBClusteringManager ()

@property (nonatomic, strong) FBQuadTree *tree;
@property (nonatomic, strong) NSRecursiveLock *lock;

@end


@implementation FBClusteringManager

- (id)init
{
    return [self initWithAnnotations:nil];
}

- (id)initWithAnnotations:(NSArray *)annotations
{
    self = [super init];
    if (self) {
        _lock = [NSRecursiveLock new];
        [self addAnnotations:annotations];
    }
    return self;
}

- (void)setAnnotations:(NSArray *)annotations
{
    self.tree = nil;
    [self addAnnotations:annotations];
}

- (void)addAnnotations:(NSArray *)annotations
{
    if (!self.tree) {
        self.tree = [[FBQuadTree alloc] init];
    }

    [self.lock lock];
    for (id<MKAnnotation> annotation in annotations) {
        [self.tree insertAnnotation:annotation];
    }
    [self.lock unlock];
}

- (void)removeAnnotations:(NSArray *)annotations
{
    if (!self.tree) {
        return;
    }

    [self.lock lock];
    for (id<MKAnnotation> annotation in annotations) {
        [self.tree removeAnnotation:annotation];
    }
    [self.lock unlock];
}

- (NSArray *)clusteredAnnotationsWithinMapRect:(MKMapRect)rect withZoomScale:(double)zoomScale
{
    return [self myClusteringFunc:rect];
//    return [self myClusteringFunc:rect withZoomScale:zoomScale withFilter:nil];
}

- (NSArray *)clusteredAnnotationsWithinMapRect:(MKMapRect)rect
                                 withZoomScale:(double)zoomScale
                                    withFilter:(BOOL (^)(id<MKAnnotation>)) filter
{
    double cellSize = FBCellSizeForZoomScale(zoomScale);
    if ([self.delegate respondsToSelector:@selector(cellSizeFactorForCoordinator:)]) {
        cellSize *= [self.delegate cellSizeFactorForCoordinator:self];
    }
    double scaleFactor = zoomScale / cellSize;
    
    NSInteger minX = floor(MKMapRectGetMinX(rect) * scaleFactor);
    NSInteger maxX = floor(MKMapRectGetMaxX(rect) * scaleFactor);
    NSInteger minY = floor(MKMapRectGetMinY(rect) * scaleFactor);
    NSInteger maxY = floor(MKMapRectGetMaxY(rect) * scaleFactor);
    
    NSMutableArray *clusteredAnnotations = [[NSMutableArray alloc] init];
    
    [self.lock lock];
    /**
     * Iterate through current region and check static rect sizes at all positions in this region
     * to check if two or more annotations exist in one of these rects and if so, cluster them.
     */
    for (NSInteger x = minX; x <= maxX; x++) {
        for (NSInteger y = minY; y <= maxY; y++) {
            MKMapRect mapRect = MKMapRectMake(x/scaleFactor, y/scaleFactor, 1.0/scaleFactor, 1.0/scaleFactor);
            FBBoundingBox mapBox = FBBoundingBoxForMapRect(mapRect);
            
            __block double totalLatitude = 0;
            __block double totalLongitude = 0;
            
            NSMutableArray *annotations = [[NSMutableArray alloc] init];

            /**
             * Iterate through found annotations in current rect and, if any found,
             * add them to 'annotations'.
             */
            [self.tree enumerateAnnotationsInBox:mapBox usingBlock:^(id<MKAnnotation> obj) {
                if(!filter || (filter(obj) == TRUE))
                {
                    totalLatitude += [obj coordinate].latitude;
                    totalLongitude += [obj coordinate].longitude;
                    [annotations addObject:obj];
                }
            }];
            
            /**
             * Three cases:
             * 1. No annotations found in 'annotations' => Skip to next rect.
             * 2. Only 1 annotation found in 'annotations' => Add to 'clusteredAnnotations'.
             * 3. Several annotations found in 'annotations' => Create cluster and add to
             *      'clusteredAnnotations'.
             */
            NSInteger count = [annotations count];
            if (count == 1) {
                [clusteredAnnotations addObjectsFromArray:annotations];
            } else if (count > 1) {
                CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(totalLatitude/count, totalLongitude/count);
                FBAnnotationCluster *cluster = [[FBAnnotationCluster alloc] init];
                cluster.coordinate = coordinate;
                cluster.annotations = annotations;
                // TODO REMOVE
                cluster.topAnnotation = [annotations objectAtIndex:0];
                [clusteredAnnotations addObject:cluster];
            }
        }
    }
    [self.lock unlock];
    
    return [NSArray arrayWithArray:clusteredAnnotations];
}

- (NSArray *)myClusteringFunc:(MKMapRect)rect
{
    NSMutableArray *clusteredAnnotations = [[NSMutableArray alloc] init];
    NSMutableSet *clusteredMarkers = [[NSMutableSet alloc] init];
    
    [self.lock lock];
    
    /**
     * Get all annotations in current region.
     */
    FBBoundingBox mapBox = FBBoundingBoxForMapRect(rect);
    NSMutableArray *annotations = [[NSMutableArray alloc] init];

    /**
     * Iterate through found annotations in current region and add them to 'annotations'.
     */
    [self.tree enumerateAnnotationsInBox:mapBox usingBlock:^(id<MKAnnotation> obj) {
        [annotations addObject:obj];
    }];
    
    /**
     * Sort annotations based on radius.
     */
    NSArray *sortedAnnotations;
    sortedAnnotations = [annotations sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        AIRMapAheadMarker *markerA = a;
        AIRMapAheadMarker *markerB = b;
        NSInteger largerThanMaxRadius = 1000;
        NSInteger penaltyA = (markerA.importantStatus.isImportant == YES) ? 0 : largerThanMaxRadius;
        NSInteger penaltyB = (markerB.importantStatus.isImportant == YES) ? 0 : largerThanMaxRadius;
        CGFloat importanceA = [markerA radius] - penaltyA;
        CGFloat importanceB = [markerB radius] - penaltyB;
        if (importanceA > importanceB) return (NSComparisonResult)NSOrderedAscending;
        else if (importanceB > importanceA) return (NSComparisonResult)NSOrderedDescending;
        return (NSComparisonResult)NSOrderedSame;
    }];
    NSLog(@"fdsa #####################");
    for (id annotation in sortedAnnotations) {
        if ([annotation isKindOfClass:[AIRMapAheadMarker class]]) {
            AIRMapAheadMarker *marker = annotation;
            NSLog(@"fdsa radius %f important? %f", [marker radius], marker.importantStatus.isImportant);
            [marker setHiddenByCluster:NO];
        } else {
            NSLog(@"fdsa something wrong");
        }
    }
    NSLog(@"fdsa #####################");
    
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat screenWidth = screenRect.size.width;
    CGFloat screenHeight = screenRect.size.height;
    CGFloat rectWidth = rect.size.width;
    CGFloat rectHeight = rect.size.height;
    /**
     * These are later used to determine whether two markers intersect because our area is
     * a MKMapRect and we will convert our coordinates to such a point.
     */
    CGFloat pixelPerRectPointX = screenWidth / rectWidth;
    CGFloat pixelPerRectPointY = screenHeight / rectHeight;
    
    /**
     * Beginning at head, look through list and check each annotation against the rest
     */
    for (int a = 0; a < [sortedAnnotations count]; ++a) {
        // If this marker is already clustered it is of no interest to us.
        AIRMapAheadMarker *ma = [sortedAnnotations objectAtIndex:a];
        if ([clusteredMarkers containsObject:ma]) {
            continue;
        }
        NSMutableArray *coveredByA = [[NSMutableArray alloc] init];
        
        CGFloat latA = ma.coordinate.latitude;
        CGFloat lngA = ma.coordinate.longitude;
        MKMapPoint pointA = MKMapPointForCoordinate(CLLocationCoordinate2DMake(latA, lngA));
        
        /**
         * MKMapPoint point is inside of MKMapRect rect.
         * Using rectsPointsPerPixelX we should be able to determine how far one marker is to another.
         */
        for (int b = 0; b < [sortedAnnotations count]; ++b) {
            // If this marker is already clustered it is of no interest to us.
            AIRMapAheadMarker *mb = [sortedAnnotations objectAtIndex:b];
            if ([clusteredMarkers containsObject:mb]) continue;
            if (a != b) {
                CGFloat latB = mb.coordinate.latitude;
                CGFloat lngB = mb.coordinate.longitude;
                MKMapPoint pointB = MKMapPointForCoordinate(CLLocationCoordinate2DMake(latB, lngB));
                
                CGFloat distanceX = fabsf(pointA.x - pointB.x);
                CGFloat distanceY = fabsf(pointA.y - pointB.y);
                CGFloat pixelDistanceX = distanceX * pixelPerRectPointX;
                CGFloat pixelDistanceY = distanceY * pixelPerRectPointY;
                CGFloat pixelHypotenuse = sqrt(pow(pixelDistanceX, 2.0) + pow(pixelDistanceY, 2.0));
                CGFloat combinedRadius = [ma radius] + [mb radius];
                
                if (combinedRadius > pixelHypotenuse) {
                    [coveredByA addObject:mb];
                    [mb setHiddenByCluster:YES];
                }
            }
        }
        /**
         * If it covers some markers, create a cluster.
         * If it has not been a part of any clustering, simply add it.
         * If it has been covered by another marker, ignore it.
         */
        if ([coveredByA count] > 0) {
            FBAnnotationCluster *cluster = [[FBAnnotationCluster alloc] init];
            cluster.coordinate = [ma coordinate];
            cluster.annotations = coveredByA;
            cluster.topAnnotation = ma;
            [clusteredAnnotations addObject:cluster];
            [clusteredMarkers addObjectsFromArray:coveredByA];
        } else if ([clusteredMarkers member:ma] == false) {
            [clusteredAnnotations addObject:ma];
        }
    }
    [self.lock unlock];
    
    return [NSArray arrayWithArray:clusteredAnnotations];
}

- (NSArray *)allAnnotations
{
    NSMutableArray *annotations = [[NSMutableArray alloc] init];
    
    [self.lock lock];
    [self.tree enumerateAnnotationsUsingBlock:^(id<MKAnnotation> obj) {
        [annotations addObject:obj];
    }];
    [self.lock unlock];
    
    return annotations;
}

- (void)displayAnnotations:(NSArray *)annotations onMapView:(MKMapView *)mapView
{
    NSMutableSet *before = [NSMutableSet setWithArray:mapView.annotations];
    MKUserLocation *userLocation = [mapView userLocation];
    if (userLocation) {
        [before removeObject:userLocation];
    }
    NSSet *after = [NSSet setWithArray:annotations];
    
    NSMutableSet *toKeep = [NSMutableSet setWithSet:before];
    [toKeep intersectSet:after];
    
    NSMutableSet *toAdd = [NSMutableSet setWithSet:after];
    [toAdd minusSet:toKeep];
    
    NSMutableSet *toRemove = [NSMutableSet setWithSet:before];
    [toRemove minusSet:after];
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [mapView addAnnotations:[toAdd allObjects]];
        [mapView removeAnnotations:[toRemove allObjects]];
    }];
}

@end
