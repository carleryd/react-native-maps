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
#import "AIRMapAheadMarkerUtilities.h"
#import "NSString+Color.h"

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

/**
 * This function is called by the MapView to cluster created markers.
 * Currently we only cluster AIRMapAheadMarkers.
 */
- (NSArray *)clusteredAnnotationsWithinMapRect:(MKMapRect)rect withZoomScale:(double)zoomScale
{
    return [self largestFirstClusteringWithMapRect:rect];
}

/**
 * Original function used by FBAnnotationClustering.
 * It uses a grid-based algorithm which is suitable for clustering huge amounts of markers(1000+).
 * Time complexity is O(n^2) where n^2 is the amount of cells in the grid.
 */
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
    
    NSMutableArray *annotationsToBeShown = [[NSMutableArray alloc] init];
    
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
             * 2. Only 1 annotation found in 'annotations' => Add to 'annotationsToBeShown'.
             * 3. Several annotations found in 'annotations' => Create cluster and add to
             *      'annotationsToBeShown'.
             */
            NSInteger count = [annotations count];
            if (count == 1) {
                [annotationsToBeShown addObjectsFromArray:annotations];
            } else if (count > 1) {
                CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(totalLatitude/count, totalLongitude/count);
                FBAnnotationCluster *cluster = [[FBAnnotationCluster alloc] init];
                cluster.coordinate = coordinate;
                cluster.annotations = annotations;
                [annotationsToBeShown addObject:cluster];
            }
        }
    }
    [self.lock unlock];
    
    return [NSArray arrayWithArray:annotationsToBeShown];
}

/**
 * Sort annotations based on radius and importance of marker.
 */
- (NSArray *)sortMarkersBasedOnRadius:(NSArray *)aheadMarkers {
    NSArray *sortedAheadMarkers;
    sortedAheadMarkers = [aheadMarkers sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        AIRMapAheadMarker *markerA = a;
        AIRMapAheadMarker *markerB = b;
        NSInteger largerThanMaxRadius = 1000;
        NSInteger penaltyA = (markerA.importantStatus.isImportant == YES) ? 0 : largerThanMaxRadius;
        NSInteger penaltyB = (markerB.importantStatus.isImportant == YES) ? 0 : largerThanMaxRadius;
        CGFloat importanceA = [markerA radius] - penaltyA;
        CGFloat importanceB = [markerB radius] - penaltyB;
        if (importanceA > importanceB) return (NSComparisonResult)NSOrderedAscending;
        else if (importanceB > importanceA) return (NSComparisonResult)NSOrderedDescending;
        /**
         * We want to avoid NSOrderedSame to be returned because it can cause re-clustering to
         * give different results with the same initial list of annotations which cause clusters
         * to change places with only a slight move of the map.
         */
        else {
            BOOL greaterLatitude = markerA.coordinate.latitude > markerB.coordinate.latitude;
            BOOL greaterLongitude = markerA.coordinate.longitude > markerB.coordinate.longitude;
            if (greaterLatitude == YES || greaterLongitude == YES) {
                return (NSComparisonResult)NSOrderedAscending;
            } else {
                return (NSComparisonResult)NSOrderedSame;
            }
        }
    }];
    return sortedAheadMarkers;
}

/**
 * Our marker radius is defined in pixels but our current map size is defined in MKMapRect dimensions.
 * What we need to do is convert the marker's coordinates to points in this MKMapRect and then obtain
 * a way to convert these points to pixels and vice versa.
 * When we have the distance between two markers in pixels we can determine whether two markers collide.
 */
- (BOOL)checkCollisionWithMarkerA:(AIRMapAheadMarker *)ma
                   againstMarkerB:(AIRMapAheadMarker *)mb
                     usingMapRect:(MKMapRect)mapRect
                  usingScreenRect:(CGRect)screenRect
{
    CGFloat screenWidth = screenRect.size.width;
    CGFloat screenHeight = screenRect.size.height;
    CGFloat rectWidth = mapRect.size.width;
    CGFloat rectHeight = mapRect.size.height;
    CGFloat pixelPerRectPointX = screenWidth / rectWidth;
    CGFloat pixelPerRectPointY = screenHeight / rectHeight;
    
    CGFloat latA = ma.coordinate.latitude;
    CGFloat lngA = ma.coordinate.longitude;
    MKMapPoint pointA = MKMapPointForCoordinate(CLLocationCoordinate2DMake(latA, lngA));
    
    CGFloat latB = mb.coordinate.latitude;
    CGFloat lngB = mb.coordinate.longitude;
    MKMapPoint pointB = MKMapPointForCoordinate(CLLocationCoordinate2DMake(latB, lngB));
    
    CGFloat distanceX = fabsf(pointA.x - pointB.x);
    CGFloat distanceY = fabsf(pointA.y - pointB.y);
    CGFloat pixelDistanceX = distanceX * pixelPerRectPointX;
    CGFloat pixelDistanceY = distanceY * pixelPerRectPointY;
    CGFloat pixelHypotenuse = sqrt(pow(pixelDistanceX, 2.0) + pow(pixelDistanceY, 2.0));
    CGFloat combinedRadius = [ma radius] + [mb radius];
    
    return combinedRadius > pixelHypotenuse;
}

/**
 * Since we don't remove and re-add AIRMapAheadMarker's when they change the amount of markers the
 * MapView won't call getAnnotationView() on the markers so we need to update the MKAnnotationView 
 * of the markers that have changed.
 */
- (void)updateCoverAmountIndicatorForAnnotations:(NSArray *)annotations
{
    NSInteger clusterIndicatorTag = 1234;
    for (AIRMapAheadMarker *aheadMarker in annotations) {
        if ([aheadMarker isKindOfClass:[AIRMapAheadMarker class]] == NO) continue;
        MKAnnotationView *anView = [aheadMarker getAnnotationView];
        for (UIView *subview in [anView subviews]) {
            if ([subview tag] == clusterIndicatorTag) {
                [subview removeFromSuperview];
            }
        }
        if (aheadMarker.coveringMarkers.count > 0) {
            UIColor *color = [[aheadMarker borderColor] representedColor];
            NSInteger amountInCluster = aheadMarker.coveringMarkers.count+1;
            UILabel *labelView = [AIRMapAheadMarkerUtilities createClusterIndicatorWithColor:color
                                                                         withAmountInCluster:amountInCluster
                                                                           usingMarkerRadius:[aheadMarker radius]
                                                                     withClusterIndicatorTag:clusterIndicatorTag
                                  ];
            
            [anView addSubview:labelView];
        }
    }
}

/**
 * Our own clustering function.
 * It checks markers against each other and creates clusters based on the largest markers.
 * Time complexity is O(n^2) where n is the amount of markers.
 */
- (NSArray *)largestFirstClusteringWithMapRect:(MKMapRect)mapRect
{
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    /**
     * annotationsToBeShown - Keeps track of the annotations which will later be added to the mapView.
     * coveredAnnotations - Keeps track of annotations which are covered by other annotations.
     */
    NSMutableArray *annotationsToBeShown = [[NSMutableArray alloc] init];
    NSMutableSet *coveredAnnotations = [[NSMutableSet alloc] init];
    
    [self.lock lock];
    

    /**
     * Iterate through found annotations in current region and add them to 'aheadMarkers'.
     */
    FBBoundingBox mapBox = FBBoundingBoxForMapRect(mapRect);
    NSMutableArray *aheadMarkers = [[NSMutableArray alloc] init];
    [self.tree enumerateAnnotationsInBox:mapBox usingBlock:^(id<MKAnnotation> obj) {
        /**
         * In case we have any other markers than AIRMapAheadMarkers we want to dismiss these
         * when calculating clustering and instead just add them directly.
         */
        if ([obj isKindOfClass:[AIRMapAheadMarker class]]) {
            [aheadMarkers addObject:obj];
        } else {
            [annotationsToBeShown addObject:obj];
        }
    }];
    
    NSArray *sortedAheadMarkers = [self sortMarkersBasedOnRadius:(NSArray *)aheadMarkers];
    
    /**
     * Beginning at head, look through list and check each annotation against the rest
     */
    for (int a = 0; a < [sortedAheadMarkers count]; ++a) {
        AIRMapAheadMarker *ma = [sortedAheadMarkers objectAtIndex:a];
        [[ma coveringMarkers] removeAllObjects];
        // Ignore ma if it is already clustered.
        if ([coveredAnnotations containsObject:ma]) continue;
        
        /**
         * Check marker ma against each marker mb to determine if mb should be covered by ma.
         * If so, this will result in mb being removed and ma will become a larger cluster.
         */
        for (int b = 0; b < [sortedAheadMarkers count]; ++b) {
            // Unnecessary to check all cases. In list [A, B, C] we wanna check A-B, A-C, B-C, done.
            if (a >= b) continue;
            AIRMapAheadMarker *mb = [sortedAheadMarkers objectAtIndex:b];
            // Ignore mb if it is already clustered.
            if ([coveredAnnotations containsObject:mb]) continue;
            
            if ([self checkCollisionWithMarkerA:ma
                                 againstMarkerB:mb
                                   usingMapRect:mapRect
                                usingScreenRect:screenRect
                 ] == YES)
            {
                [[ma coveringMarkers] addObject:mb];
                [annotationsToBeShown removeObject:mb];
                [coveredAnnotations addObject:mb];
            }
        }
        /**
         * If it covers some markers, create a cluster.
         * If it has not been a part of any clustering, simply add it.
         * If it has been covered by another marker, ignore it.
         */
        if ([[ma coveringMarkers] count] > 0) {
            [annotationsToBeShown addObject:ma];
        } else if ([coveredAnnotations member:ma] == false) {
            /**
             * A marker is not covered and will be shown as a non-cluster.
             */
            [[ma coveringMarkers] removeAllObjects];
            [annotationsToBeShown addObject:ma];
        }
    }
    [self.lock unlock];
    
    return [NSArray arrayWithArray:annotationsToBeShown];
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
        [self updateCoverAmountIndicatorForAnnotations:annotations];
    }];
}

@end
