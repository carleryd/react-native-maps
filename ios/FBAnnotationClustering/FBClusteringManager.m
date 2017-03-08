//
//  FBClusterManager.m
//  AnnotationClustering
//
//  Created by Filip Bec on 05/01/14.
//  Copyright (c) 2014 Infinum Ltd. All rights reserved.
//

#import "FBQuadTree.h"
#import "FBClusteringManager.h"
#import "AIRMapMarker.h"
#import "AIRMapAheadMarker.h"
#import "AIRMapAheadMarkerUtilities.h"
#import "NSString+Color.h"


/**
 * Our marker radius is defined in pixels but our current map size is defined in MKMapRect dimensions.
 * What we need to do is convert the marker's coordinates to points in this MKMapRect and then obtain
 * a way to convert these points to pixels and vice versa.
 * When we have the distance between two markers in pixels we can determine whether two markers collide.
 */
MarkerCoveredState checkCollision(CLLocationCoordinate2D coordA,
                                  CLLocationCoordinate2D coordB,
                                  CGFloat radiusA,
                                  CGFloat radiusB,
                                  MKMapRect mapRect,
                                  CGRect screenRect)
{
    CGFloat screenWidth = screenRect.size.width;
    CGFloat screenHeight = screenRect.size.height;
    CGFloat rectWidth = mapRect.size.width;
    CGFloat rectHeight = mapRect.size.height;
    CGFloat pixelPerRectPointX = screenWidth / rectWidth;
    CGFloat pixelPerRectPointY = screenHeight / rectHeight;
    
    CGFloat latA = coordA.latitude;
    CGFloat lngA = coordA.longitude;
    MKMapPoint pointA = MKMapPointForCoordinate(CLLocationCoordinate2DMake(latA, lngA));
    
    CGFloat latB = coordB.latitude;
    CGFloat lngB = coordB.longitude;
    MKMapPoint pointB = MKMapPointForCoordinate(CLLocationCoordinate2DMake(latB, lngB));
    
    CGFloat distanceX = fabsf(pointA.x - pointB.x);
    CGFloat distanceY = fabsf(pointA.y - pointB.y);
    CGFloat pixelDistanceX = distanceX * pixelPerRectPointX;
    CGFloat pixelDistanceY = distanceY * pixelPerRectPointY;
    CGFloat pixelHypotenuse = sqrt(pow(pixelDistanceX, 2.0) + pow(pixelDistanceY, 2.0));
    CGFloat combinedRadius = radiusA + radiusB;
    
    MarkerCoveredState coveredState = ((pixelHypotenuse - radiusA) < 0)
        ? FULLY_COVERED
        : ((pixelHypotenuse - radiusA - radiusB) < 0)
            ? PARTIALLY_COVERED
            : NOT_COVERED;
    
    return coveredState;
}

FBAnnotationDot* createDotAnnotationFromMarker(AIRMapAheadMarker *marker)
{
    FBAnnotationDot *dotAnnotation = [[FBAnnotationDot alloc] init];
    [dotAnnotation setCoordinate:[marker coordinate]];
    [dotAnnotation setColor:[[marker borderColor] representedColor]];
    [dotAnnotation setAlpha:[marker alpha]];
    return dotAnnotation;
}

#pragma mark - FBClusteringManager

@interface FBClusteringManager ()

@property (nonatomic, strong) FBQuadTree *tree;
@property (nonatomic, strong) NSRecursiveLock *lock;

@end


@implementation FBClusteringManager
{
    NSArray *_topAheadMarkerIds;
}

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
- (NSArray *)clusteredAnnotationsWithinMapRect:(MKMapRect)rect
                                 withZoomScale:(double)zoomScale
                                   withMapView:(MKMapView *)mapView
{
    return [self largestFirstClusteringWithMapRect:rect
                              withAheadMarkerLimit:5
                                       withMapView:mapView
            ];
}

- (id)getTopAheadMarkerInMapRect:(MKMapRect)mapRect
{
    FBBoundingBox mapBox = FBBoundingBoxForMapRect(mapRect);
    
    NSMutableArray *aheadMarkers = [[NSMutableArray alloc] init];
    [self.tree enumerateAnnotationsInBox:mapBox usingBlock:^(id<MKAnnotation> obj) {
        if ([obj isKindOfClass:[AIRMapAheadMarker class]]) {
            [aheadMarkers addObject:obj];
        }
    }];
    
    NSArray *sortedAheadMarkers = [self sortMarkersBasedOnRadius:(NSArray *)aheadMarkers];
    return [sortedAheadMarkers firstObject];
}

- (void)sendTopPostIdsToJSUsingMapView:(AIRMap *)mapView usingSortedMarkers:(NSArray *)sortedMarkers
{
    NSMutableArray *topAheadMarkerIds = [NSMutableArray arrayWithCapacity:[sortedMarkers count]];
    [sortedMarkers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [topAheadMarkerIds addObject:[(AIRMapAheadMarker *)obj postId]];
    }];
    
    /**
     * If we have new top markers on our screen we want to inform JS of this,
     * if they are the same it's unnecessary overhead to send it over the bridge.
     */
    if ([_topAheadMarkerIds isEqualToArray:topAheadMarkerIds] == NO) {
        if (mapView.onTopAheadMarkerChange && [topAheadMarkerIds count] > 0) {
            mapView.onTopAheadMarkerChange(@{
                               @"topPostIds": topAheadMarkerIds,
                               });
        }
        _topAheadMarkerIds = topAheadMarkerIds;
    }
}

/**
 * Our own clustering function.
 * It checks markers against each other and creates clusters based on the largest markers.
 * Time complexity is O(n^2) where n is the amount of markers.
 */
- (NSArray *)largestFirstClusteringWithMapRect:(MKMapRect)mapRect
                          withAheadMarkerLimit:(NSInteger)aheadMarkerLimit
                                   withMapView:(AIRMap *)mapView
{
    [self.lock lock];
    
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    /**
     * annotationsToBeShown - Keeps track of the annotations which will later be added to the mapView.
     */
    NSMutableArray *annotationsToBeShown = [[NSMutableArray alloc] init];
    

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
            AIRMapAheadMarker *marker = obj;
            /**
             * Since we are going to re-calculate clustering on all markers, we need to make
             * sure these values are all reset beforehand.
             */
            [marker setCoveredState:NOT_COVERED];
            [[marker coveringMarkers] removeAllObjects];
            [aheadMarkers addObject:obj];
        } else {
            [annotationsToBeShown addObject:obj];
        }
    }];
    
    NSArray *sortedAheadMarkers = [self sortMarkersBasedOnRadius:(NSArray *)aheadMarkers];
    
    [self sendTopPostIdsToJSUsingMapView:mapView usingSortedMarkers:sortedAheadMarkers];
    
    /**
     * Beginning at head, look through list and check collision between each annotation.
     */
    NSInteger aheadMarkerCount = 0;
    for (int a = 0; a < [sortedAheadMarkers count]; ++a) {
        AIRMapAheadMarker *ma = [sortedAheadMarkers objectAtIndex:a];
        // Ignore ma if it is already clustered.
        if ([ma coveredState] != NOT_COVERED) {
            continue;
        }
        
        /**
         * Check marker ma against each marker mb to determine if mb should be covered by ma.
         * If so, this will result in mb being removed and ma will become a larger cluster.
         */
        for (int b = 0; b < [sortedAheadMarkers count]; ++b) {
            // Unnecessary to check all cases. In list [A, B, C] we wanna check A-B, A-C, B-C, done.
            if (a >= b) continue;
            AIRMapAheadMarker *mb = [sortedAheadMarkers objectAtIndex:b];
            // Ignore mb if it is already clustered.
            if ([mb coveredState] != NOT_COVERED) {
                continue;
            }
            
            MarkerCoveredState mbCoveredState = checkCollision([ma coordinate],
                                                               [mb coordinate],
                                                               [ma radius],
                                                               [mb radius],
                                                               mapRect,
                                                               screenRect);
            
            switch (mbCoveredState) {
                case NOT_COVERED:
                    break;
                case PARTIALLY_COVERED:
                    break;
                case FULLY_COVERED:
                {
                    [[ma coveringMarkers] addObject:mb];
                    [annotationsToBeShown removeObject:mb];
                }
                    break;
                default:
                    break;
            }
            
            if ([mb coveredState] == NOT_COVERED) {
                [mb setCoveredState:mbCoveredState];
            }
        }
    }
    
    for (AIRMapAheadMarker *marker in sortedAheadMarkers) {
        /**
         * We only want to create as many AIRMapAheadMarkers as the method input aheadMarkerLimit
         * specifies. We use a counter to keep track of how many has been created and then, if
         * we reach the limit, the rest of the markers should be dots.
         */
        if (aheadMarkerCount < aheadMarkerLimit) {
            /**
             * Here we start adding the markers which will end up on the map.
             * Four outcomes: Cluster marker, standard marker, dot marker, no marker.
             */
            if ([[marker coveringMarkers] count] > 0) {
                aheadMarkerCount++;
                [annotationsToBeShown addObject:marker];
            } else {
                switch ([marker coveredState]) {
                    case NOT_COVERED:
                    {
                        aheadMarkerCount++;
                        [[marker coveringMarkers] removeAllObjects];
                        [annotationsToBeShown addObject:marker];
                    }
                        break;
                    case PARTIALLY_COVERED:
                    {
                        FBAnnotationDot *dotAnnotation = createDotAnnotationFromMarker(marker);
                        [annotationsToBeShown addObject:dotAnnotation];
                    }
                        break;
                    case FULLY_COVERED:
                        break;
                    default:
                        break;
                }
            }
        } else {
            /**
             * At this point we have created the amount of markers we wanted.
             * The rest shall be dots, if visible, i.e. not FULLY_COVERED.
             */
            switch ([marker coveredState]) {
                case NOT_COVERED:
                case PARTIALLY_COVERED:
                {
                    FBAnnotationDot *dotAnnotation = createDotAnnotationFromMarker(marker);
                    [annotationsToBeShown addObject:dotAnnotation];
                }
                    break;
                case FULLY_COVERED:
                    break;
                default:
                    break;
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
        // Remove any existing cluster indicators.
        for (UIView *subview in [anView subviews]) {
            if ([subview tag] == clusterIndicatorTag) {
                [subview removeFromSuperview];
            }
        }
        // Add cluster indicator if marker is a cluster.
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
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
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
    
        [mapView addAnnotations:[toAdd allObjects]];
        [mapView removeAnnotations:[toRemove allObjects]];
        [self updateCoverAmountIndicatorForAnnotations:annotations];
    }];
}

@end
