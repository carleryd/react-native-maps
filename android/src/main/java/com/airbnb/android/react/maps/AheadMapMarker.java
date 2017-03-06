package com.airbnb.android.react.maps;

import android.content.Context;
import android.net.Uri;

import com.facebook.common.references.CloseableReference;
import com.facebook.datasource.DataSource;
import com.facebook.drawee.backends.pipeline.Fresco;
import com.facebook.drawee.interfaces.DraweeController;
import com.facebook.drawee.view.DraweeHolder;
import com.facebook.imagepipeline.core.ImagePipeline;
import com.facebook.imagepipeline.image.CloseableImage;
import com.facebook.imagepipeline.request.ImageRequest;
import com.facebook.imagepipeline.request.ImageRequestBuilder;
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
    private String identifier;
    private float weightedValue;
    private DataSource<CloseableReference<CloseableImage>> dataSource;
    private Uri uri;

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

    public void setImage(String uri) {
        if(uri == null) {
            this.uri = Uri.parse("https://3.bp.blogspot.com/-W__wiaHUjwI/Vt3Grd8df0I/AAAAAAAAA78/7xqUNj8ujtY/s1600/image02.png");
        }else{
            this.uri = Uri.parse(uri);
        }
    }

    public Uri getImage(){
        return uri;
    }

    public void setWeightedValue(float value) {
        weightedValue = value;
    }

    public float getWeightedValue(){
        return weightedValue;
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


    public void setIdentifier(String identifier) {
        this.identifier = identifier;
    }

    public String getIdentifier() {
        return this.identifier;
    }



}
