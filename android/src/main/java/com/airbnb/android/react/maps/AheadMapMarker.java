package com.airbnb.android.react.maps;

import android.content.Context;

import com.facebook.drawee.view.DraweeHolder;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.uimanager.SimpleViewManager;
import com.facebook.react.views.view.ReactViewGroup;
import com.google.android.gms.maps.GoogleMap;
import com.google.android.gms.maps.model.LatLng;
import com.google.maps.android.clustering.Cluster;
import com.google.maps.android.clustering.ClusterItem;
import com.google.maps.android.clustering.ClusterManager;

/**
 * Created by nils on 2017-03-03.
 */
public class AheadMapMarker extends AirMapFeature implements ClusterItem {
    public final int profilePhoto = R.drawable.walter; /* TODO REMOVE */
    public final String name = "Nils";
    private final Context context;
    private LatLng position;
    private String title;

    public AheadMapMarker(Context context) {
        super(context);
        this.context = context;
    }

    @Override
    public void addToMap(GoogleMap map) {

    }

    @Override
    public void removeFromMap(GoogleMap map) {

    }

    @Override
    public Object getFeature() {
        return null;
    }

    public void addToCluster(ClusterManager mClusterManager) {
        mClusterManager.addItem(this);
    }

    public void removeFromCluster(ClusterManager mClusterManager) {
        mClusterManager.removeItem(this);
    }

    public void setCoordinate(ReadableMap coordinate) {
        position = new LatLng(coordinate.getDouble("latitude"), coordinate.getDouble("longitude"));
    }

    @Override
    public LatLng getPosition() {
        return position;
    }

    @Override
    public String getTitle() {
        return this.title;
    }

    @Override
    public String getSnippet() {
        return null;
    }

}
