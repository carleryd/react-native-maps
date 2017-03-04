package com.airbnb.android.react.maps;

import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.uimanager.ThemedReactContext;
import com.facebook.react.uimanager.ViewGroupManager;
import com.facebook.react.uimanager.annotations.ReactProp;

/**
 * Created by nils on 2017-03-03.
 */

public class AirMapAheadMarkerManager extends ViewGroupManager<AheadMapMarker> {

    @Override
    public String getName() {
        return "AIRMapAheadMarker";
    }

    @Override
    protected AheadMapMarker createViewInstance(ThemedReactContext reactContext) {
        return new AheadMapMarker(reactContext);
    }

    @ReactProp(name = "coordinate")
    public void setCoordinate(AheadMapMarker view, ReadableMap map) {
        view.setCoordinate(map);
    }
}
