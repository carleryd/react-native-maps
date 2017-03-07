/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "AIRMap.h"

#import "RCTImageView.h"
#import "RCTEventDispatcher.h"
#import "AIRMapMarker.h"
#import "AIRMapAheadMarker.h"
#import "AIRMapPolyline.h"
#import "AIRMapPolygon.h"
#import "AIRMapCircle.h"
#import <QuartzCore/QuartzCore.h>
#import "AIRMapUrlTile.h"
#import "AIRMapAheadMarkerUtilities.h"

const CLLocationDegrees AIRMapDefaultSpan = 0.005;
const NSTimeInterval AIRMapRegionChangeObserveInterval = 0.1;
const CGFloat AIRMapZoomBoundBuffer = 0.01;


@interface MKMapView (UIGestureRecognizer)

// this tells the compiler that MKMapView actually implements this method
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch;

@end

@interface AIRMap ()

@property (nonatomic, strong) UIActivityIndicatorView *activityIndicatorView;
@property (nonatomic, assign) NSNumber *shouldZoomEnabled;
@property (nonatomic, assign) NSNumber *shouldScrollEnabled;

- (void)updateScrollEnabled;
- (void)updateZoomEnabled;

@end

@implementation AIRMap
{
    UIView *_legalLabel;
    CLLocationManager *_locationManager;
    BOOL _initialRegionSet;

    // Array to manually track RN subviews
    //
    // AIRMap implicitly creates subviews that aren't regular RN children
    // (SMCalloutView injects an overlay subview), which otherwise confuses RN
    // during component re-renders:
    // https://github.com/facebook/react-native/blob/v0.16.0/React/Modules/RCTUIManager.m#L657
    //
    // Implementation based on RCTTextField, another component with indirect children
    // https://github.com/facebook/react-native/blob/v0.16.0/Libraries/Text/RCTTextField.m#L20
    NSMutableArray<UIView *> *_reactSubviews;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _hasStartedRendering = NO;
        _reactSubviews = [NSMutableArray new];
        _nsOperationQueue = [[NSOperationQueue alloc] init];

        // Find Apple link label
        for (UIView *subview in self.subviews) {
            if ([NSStringFromClass(subview.class) isEqualToString:@"MKAttributionLabel"]) {
                // This check is super hacky, but the whole premise of moving around
                // Apple's internal subviews is super hacky
                _legalLabel = subview;
                break;
            }
        }

        // 3rd-party callout view for MapKit that has more options than the built-in. It's painstakingly built to
        // be identical to the built-in callout view (which has a private API)
        self.calloutView = [SMCalloutView platformCalloutView];
        self.calloutView.delegate = self;
        
        // clusteringManager handles the clustering of markers.
        // We init it here so that we can add markers to it, at the same time as we add them to the map
        self.clusteringManager = [[FBClusteringManager alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_regionChangeObserveTimer invalidate];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-missing-super-calls"
- (void)insertReactSubview:(id<RCTComponent>)subview atIndex:(NSInteger)atIndex {
    // Our desired API is to pass up markers/overlays as children to the mapview component.
    // This is where we intercept them and do the appropriate underlying mapview action.
    if ([subview isKindOfClass:[AIRMapMarker class]]) {
        /**
         * Add the annotation both to the map, and to the clustering manager.
         * The clustering manager determines if the annotation should be clustered.
         */
        [self.clusteringManager addAnnotations:@[(id<MKAnnotation>)subview]];
    } else if ([subview isKindOfClass:[AIRMapAheadMarker class]]) {
        [self addAnnotation:(id<MKAnnotation>)subview];
        // Only add the annotation to the clusteringManager, it will then add it to the MapView.
        if (self.clusterMarkers) {
            [self.clusteringManager addAnnotations:@[(id<MKAnnotation>)subview]];
        }
    } else if ([subview isKindOfClass:[AIRMapPolyline class]]) {
        ((AIRMapPolyline *)subview).map = self;
        [self addOverlay:(id<MKOverlay>)subview];
    } else if ([subview isKindOfClass:[AIRMapPolygon class]]) {
        ((AIRMapPolygon *)subview).map = self;
        [self addOverlay:(id<MKOverlay>)subview];
    } else if ([subview isKindOfClass:[AIRMapCircle class]]) {
        [self addOverlay:(id<MKOverlay>)subview];
    } else if ([subview isKindOfClass:[AIRMapUrlTile class]]) {
        ((AIRMapUrlTile *)subview).map = self;
        [self addOverlay:(id<MKOverlay>)subview];
    } else {
        NSArray<id<RCTComponent>> *childSubviews = [subview reactSubviews];
        for (int i = 0; i < childSubviews.count; i++) {
          [self insertReactSubview:(UIView *)childSubviews[i] atIndex:atIndex];
        }
    }
    [_reactSubviews insertObject:(UIView *)subview atIndex:(NSUInteger) atIndex];
}
#pragma clang diagnostic pop

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-missing-super-calls"
- (void)removeReactSubview:(id<RCTComponent>)subview {
    // similarly, when the children are being removed we have to do the appropriate
    // underlying mapview action here.
    if ([subview isKindOfClass:[AIRMapMarker class]]) {
        [self.clusteringManager removeAnnotations:@[(id <MKAnnotation>) subview]];
    } else if ([subview isKindOfClass:[AIRMapAheadMarker class]]) {
        [self removeAnnotation:(id<MKAnnotation>) subview];
        if (self.clusterMarkers) {
            [self.clusteringManager removeAnnotations:@[(id <MKAnnotation>) subview]];
        }
    } else if ([subview isKindOfClass:[AIRMapPolyline class]]) {
        [self removeOverlay:(id <MKOverlay>) subview];
    } else if ([subview isKindOfClass:[AIRMapPolygon class]]) {
        [self removeOverlay:(id <MKOverlay>) subview];
    } else if ([subview isKindOfClass:[AIRMapCircle class]]) {
        [self removeOverlay:(id <MKOverlay>) subview];
    } else if ([subview isKindOfClass:[AIRMapUrlTile class]]) {
        [self removeOverlay:(id <MKOverlay>) subview];
    } else {
        NSArray<id<RCTComponent>> *childSubviews = [subview reactSubviews];
        for (int i = 0; i < childSubviews.count; i++) {
          [self removeReactSubview:(UIView *)childSubviews[i]];
        }
    }
    [_reactSubviews removeObject:(UIView *)subview];
}
#pragma clang diagnostic pop

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-missing-super-calls"
- (NSArray<id<RCTComponent>> *)reactSubviews {
  return _reactSubviews;
}
#pragma clang diagnostic pop

#pragma mark Overrides for Callout behavior

// override UIGestureRecognizer's delegate method so we can prevent MKMapView's recognizer from firing
// when we interact with UIControl subclasses inside our callout view.
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if ([touch.view isDescendantOfView:self.calloutView])
        return NO;
    else
        return [super gestureRecognizer:gestureRecognizer shouldReceiveTouch:touch];
}

/**
 * Run when the react subviews has changed. Using this function we can remove several markers
 * at once on the RN side and only trigger this function once, compared to removeReactSubview.
 */
- (void)didUpdateReactSubviews {
    for (UIView *subview in _reactSubviews) {
        [self addSubview:subview];
    }

    [[self delegate] mapView:self regionDidChangeAnimated:NO];
}

/**
 * If we have an active marker pressed and we begin a touch on the map:
 * 1. Set that marker to a lower opacity.
 * 2. Record at what point on the screen we started the press,
 *    this is useful for touchesMoved.
 */
- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    AIRMapAheadMarkerUtilities *utilities = [AIRMapAheadMarkerUtilities sharedInstance];
    AIRMapAheadMarker* marker = [utilities prevPressedMarker];
    if (marker != nil) {
        CGFloat newAlpha = marker.importantStatus.unimportantOpacity/2;
        [[marker getAnnotationView] setAlpha:newAlpha];

        UITouch *touch = [[event allTouches] anyObject];
        [utilities setTouchStartPos:[touch locationInView:touch.view]];
        CGPoint point = [touch locationInView:touch.view];
    }
}

/**
 * If we move too far while having an active marker pressed,
 * revert marker settings and set to no active marker pressed.
 */
- (void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    AIRMapAheadMarkerUtilities *utilities = [AIRMapAheadMarkerUtilities sharedInstance];
    AIRMapAheadMarker* marker = [utilities prevPressedMarker];

    UITouch *touch = [[event allTouches] anyObject];
    CGPoint touchLocation = [touch locationInView:self];
    CGPoint startTouch = [utilities touchStartPos];
    double diffX = fabs(startTouch.x - touchLocation.x);
    double diffY = fabs(startTouch.y - touchLocation.y);

    double threshold = 30;
    if (diffX > threshold || diffY > threshold) {
        CGFloat newAlpha = marker.importantStatus.unimportantOpacity;
        [[marker getAnnotationView] setAlpha:newAlpha];
        [utilities setPrevPressedMarker:nil];
    }
}

/**
 * When we stop touching map, and we have an active marker pressed,
 * send markerPress to JS land and set to no active marker pressed.
 */
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    AIRMapAheadMarker *marker = [[AIRMapAheadMarkerUtilities sharedInstance] prevPressedMarker];
    if (marker != nil) {
        [[AIRMapAheadMarkerUtilities sharedInstance] setPrevPressedMarker:nil];
        [self triggerMarkerPressWithMarker:marker];
        
        if (self.clusterMarkers) {
            [[self delegate] mapView:self regionDidChangeAnimated:NO];
        }
    }
}

- (void)triggerMarkerPressWithMarker:(id)marker {
    AIRMapAheadMarker *aheadMarker = marker;
    [[aheadMarker getAnnotationView] setAlpha:aheadMarker.importantStatus.unimportantOpacity];
    ImportantStatus newImportantStatus = [aheadMarker importantStatus];
    newImportantStatus.isImportant = NO;
    [aheadMarker setImportantStatus:newImportantStatus];
    
    id markerPressEvent = @{
                            @"action": @"marker-press",
                            @"id": aheadMarker.identifier ?: @"unknown",
                            @"coordinate": @{
                                    @"latitude": @(aheadMarker.coordinate.latitude),
                                    @"longitude": @(aheadMarker.coordinate.longitude)
                                    }
                            };

    if (aheadMarker.onPress) aheadMarker.onPress(markerPressEvent);
}

// Allow touches to be sent to our calloutview.
// See this for some discussion of why we need to override this: https://github.com/nfarina/calloutview/pull/9
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *calloutMaybe = [self.calloutView hitTest:[self.calloutView convertPoint:point fromView:self] withEvent:event];
    if (calloutMaybe) return calloutMaybe;

    // We need to trigger hitTest on AIRMapMarker so we can highlight and select it on click
    RCTView *view = (UIView *)[super hitTest:point withEvent:event];

    // If it's not a callout, then always return the MKNewAnnotationContainerView which will handle pinch & zoom properly
    // - MKMapView
    // - - UIView
    // - - - MKBasicMapView
    // - - - - _MKMapLayerHostingView
    // - - - MKScrollContainerView
    // - - - - MKOverlayContainerView
    // - - - MKNewAnnotationContainerView
    // - - MKAttributionLabel
    UIView *container = ((UIView *)[((UIView *)[self.subviews objectAtIndex:0]).subviews objectAtIndex:2]);
    return container;
}

#pragma mark SMCalloutViewDelegate

- (NSTimeInterval)calloutView:(SMCalloutView *)calloutView delayForRepositionWithSize:(CGSize)offset {

    // When the callout is being asked to present in a way where it or its target will be partially offscreen, it asks us
    // if we'd like to reposition our surface first so the callout is completely visible. Here we scroll the map into view,
    // but it takes some math because we have to deal in lon/lat instead of the given offset in pixels.

    CLLocationCoordinate2D coordinate = self.region.center;

    // where's the center coordinate in terms of our view?
    CGPoint center = [self convertCoordinate:coordinate toPointToView:self];

    // move it by the requested offset
    center.x -= offset.width;
    center.y -= offset.height;

    // and translate it back into map coordinates
    coordinate = [self convertPoint:center toCoordinateFromView:self];

    // move the map!
    [self setCenterCoordinate:coordinate animated:YES];

    // tell the callout to wait for a while while we scroll (we assume the scroll delay for MKMapView matches UIScrollView)
    return kSMCalloutViewRepositionDelayForUIScrollView;
}

#pragma mark Accessors

- (void)setShowsUserLocation:(BOOL)showsUserLocation
{
    if (self.showsUserLocation != showsUserLocation) {
        if (showsUserLocation && !_locationManager) {
            _locationManager = [CLLocationManager new];
            if ([_locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
                [_locationManager requestWhenInUseAuthorization];
            }
        }
        super.showsUserLocation = showsUserLocation;
    }
}

- (void)setFollowsUserLocation:(BOOL)followsUserLocation
{
    _followUserLocation = followsUserLocation;
}

- (void)setHandlePanDrag:(BOOL)handleMapDrag {
    for (UIGestureRecognizer *recognizer in [self gestureRecognizers]) {
        if ([recognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
            recognizer.enabled = handleMapDrag;
            break;
        }
    }
}

- (void)setRegion:(MKCoordinateRegion)region animated:(BOOL)animated
{
    // If location is invalid, abort
    if (!CLLocationCoordinate2DIsValid(region.center)) {
        return;
    }

    // If new span values are nil, use old values instead
    if (!region.span.latitudeDelta) {
        region.span.latitudeDelta = self.region.span.latitudeDelta;
    }
    if (!region.span.longitudeDelta) {
        region.span.longitudeDelta = self.region.span.longitudeDelta;
    }

    // Animate/move to new position
    [super setRegion:region animated:animated];
}

- (void)setInitialRegion:(MKCoordinateRegion)initialRegion {
    if (!_initialRegionSet) {
        _initialRegionSet = YES;
        [self setRegion:initialRegion animated:NO];
    }
}

- (void)setCacheEnabled:(BOOL)cacheEnabled {
    _cacheEnabled = cacheEnabled;
    if (self.cacheEnabled && self.cacheImageView.image == nil) {
        self.loadingView.hidden = NO;
        [self.activityIndicatorView startAnimating];
    }
    else {
        if (_loadingView != nil) {
            self.loadingView.hidden = YES;
        }
    }
}

- (void)setLoadingEnabled:(BOOL)loadingEnabled {
    _loadingEnabled = loadingEnabled;
    if (!self.hasShownInitialLoading) {
        self.loadingView.hidden = !self.loadingEnabled;
    }
    else {
        if (_loadingView != nil) {
            self.loadingView.hidden = YES;
        }
    }
}

- (UIColor *)loadingBackgroundColor {
    return self.loadingView.backgroundColor;
}

- (void)setLoadingBackgroundColor:(UIColor *)loadingBackgroundColor {
    self.loadingView.backgroundColor = loadingBackgroundColor;
}

- (UIColor *)loadingIndicatorColor {
    return self.activityIndicatorView.color;
}

- (void)setLoadingIndicatorColor:(UIColor *)loadingIndicatorColor {
    self.activityIndicatorView.color = loadingIndicatorColor;
}

// Include properties of MKMapView which are only available on iOS 9+
// and check if their selector is available before calling super method.

- (void)setShowsCompass:(BOOL)showsCompass {
    if ([MKMapView instancesRespondToSelector:@selector(setShowsCompass:)]) {
        [super setShowsCompass:showsCompass];
    }
}

- (BOOL)showsCompass {
    if ([MKMapView instancesRespondToSelector:@selector(showsCompass)]) {
        return [super showsCompass];
    } else {
        return NO;
    }
}

- (void)setShowsScale:(BOOL)showsScale {
    if ([MKMapView instancesRespondToSelector:@selector(setShowsScale:)]) {
        [super setShowsScale:showsScale];
    }
}

- (BOOL)showsScale {
    if ([MKMapView instancesRespondToSelector:@selector(showsScale)]) {
        return [super showsScale];
    } else {
        return NO;
    }
}

- (void)setShowsTraffic:(BOOL)showsTraffic {
    if ([MKMapView instancesRespondToSelector:@selector(setShowsTraffic:)]) {
        [super setShowsTraffic:showsTraffic];
    }
}

- (BOOL)showsTraffic {
    if ([MKMapView instancesRespondToSelector:@selector(showsTraffic)]) {
        return [super showsTraffic];
    } else {
        return NO;
    }
}

- (void)setScrollEnabled:(BOOL)scrollEnabled {
    self.shouldScrollEnabled = [NSNumber numberWithBool:scrollEnabled];
    [self updateScrollEnabled];
}

- (void)updateScrollEnabled {
    if (self.cacheEnabled) {
        [super setScrollEnabled:NO];
    }
    else if (self.shouldScrollEnabled != nil) {
        [super setScrollEnabled:[self.shouldScrollEnabled boolValue]];
    }
}

- (void)setZoomEnabled:(BOOL)zoomEnabled {
    self.shouldZoomEnabled = [NSNumber numberWithBool:zoomEnabled];
    [self updateZoomEnabled];
}

- (void)updateZoomEnabled {
    if (self.cacheEnabled) {
        [super setZoomEnabled: NO];
    }
    else if (self.shouldZoomEnabled != nil) {
        [super setZoomEnabled:[self.shouldZoomEnabled boolValue]];
    }
}

- (void)cacheViewIfNeeded {
    if (self.hasShownInitialLoading) {
        if (!self.cacheEnabled) {
            if (_cacheImageView != nil) {
                self.cacheImageView.hidden = YES;
                self.cacheImageView.image = nil;
            }
        }
        else {
            self.cacheImageView.image = nil;
            self.cacheImageView.hidden = YES;

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self.cacheImageView.image = nil;
                self.cacheImageView.hidden = YES;
                UIGraphicsBeginImageContextWithOptions(self.bounds.size, self.opaque, 0.0);
                [self.layer renderInContext:UIGraphicsGetCurrentContext()];
                UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
                UIGraphicsEndImageContext();

                self.cacheImageView.image = image;
                self.cacheImageView.hidden = NO;
            });
        }

        [self updateScrollEnabled];
        [self updateZoomEnabled];
        [self updateLegalLabelInsets];
    }
}

- (void)updateLegalLabelInsets {
    if (_legalLabel) {
        dispatch_async(dispatch_get_main_queue(), ^{
            CGRect frame = _legalLabel.frame;
            if (_legalLabelInsets.left) {
                frame.origin.x = _legalLabelInsets.left;
            } else if (_legalLabelInsets.right) {
                frame.origin.x = self.frame.size.width - _legalLabelInsets.right - frame.size.width;
            }
            if (_legalLabelInsets.top) {
                frame.origin.y = _legalLabelInsets.top;
            } else if (_legalLabelInsets.bottom) {
                frame.origin.y = self.frame.size.height - _legalLabelInsets.bottom - frame.size.height;
            }
            _legalLabel.frame = frame;
        });
    }
}


- (void)setLegalLabelInsets:(UIEdgeInsets)legalLabelInsets {
  _legalLabelInsets = legalLabelInsets;
  [self updateLegalLabelInsets];
}

- (void)beginLoading {
    if ((!self.hasShownInitialLoading && self.loadingEnabled) || (self.cacheEnabled && self.cacheImageView.image == nil)) {
        self.loadingView.hidden = NO;
        [self.activityIndicatorView startAnimating];
    }
    else {
        if (_loadingView != nil) {
            self.loadingView.hidden = YES;
        }
    }
}

- (void)finishLoading {
    self.hasShownInitialLoading = YES;
    if (_loadingView != nil) {
        self.loadingView.hidden = YES;
    }
    [self cacheViewIfNeeded];
}

- (UIActivityIndicatorView *)activityIndicatorView {
    if (_activityIndicatorView == nil) {
        _activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        _activityIndicatorView.center = self.loadingView.center;
        _activityIndicatorView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        _activityIndicatorView.color = [UIColor colorWithRed:96.f/255.f green:96.f/255.f blue:96.f/255.f alpha:1.f]; // defaults to #606060
    }
    [self.loadingView addSubview:_activityIndicatorView];
    return _activityIndicatorView;
}

- (UIView *)loadingView {
    if (_loadingView == nil) {
        _loadingView = [[UIView alloc] initWithFrame:self.bounds];
        _loadingView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        _loadingView.backgroundColor = [UIColor whiteColor]; // defaults to #FFFFFF
        [self addSubview:_loadingView];
        _loadingView.hidden = NO;
    }
    return _loadingView;
}

- (UIImageView *)cacheImageView {
    if (_cacheImageView == nil) {
        _cacheImageView = [[UIImageView alloc] initWithFrame:self.bounds];
        _cacheImageView.contentMode = UIViewContentModeCenter;
        _cacheImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        [self addSubview:self.cacheImageView];
        _cacheImageView.hidden = YES;
    }
    return _cacheImageView;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self cacheViewIfNeeded];
}

@end
