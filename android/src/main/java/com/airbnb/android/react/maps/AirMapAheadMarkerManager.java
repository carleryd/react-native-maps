package com.airbnb.android.react.maps;

import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.uimanager.ThemedReactContext;
import com.facebook.react.uimanager.ViewGroupManager;
import com.facebook.react.uimanager.annotations.ReactProp;

import javax.annotation.Nullable;

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

    @ReactProp(name = "weightedValue", defaultFloat = 0f)
    public void setWeightedValue(AheadMapMarker view, float value) {
        view.setWeightedValue(value);
    }



//    @ReactProp(name = "image")
//    public void setImage(AirMapMarker view, @Nullable String source) {
//        view.setImage(source);
//    }

}
