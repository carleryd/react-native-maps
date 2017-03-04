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
    private float weightedValue;
    private DataSource<CloseableReference<CloseableImage>> dataSource;

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
        if (uri == null) {
//            iconBitmapDescriptor = null;
//            update();
        } else if (uri.startsWith("http://") || uri.startsWith("https://") ||
                uri.startsWith("file://")) {
            ImageRequest imageRequest = ImageRequestBuilder
                    .newBuilderWithSource(Uri.parse(uri))
                    .build();

            ImagePipeline imagePipeline = Fresco.getImagePipeline();
            dataSource = imagePipeline.fetchDecodedImage(imageRequest, this);
//            DraweeController controller = Fresco.newDraweeControllerBuilder()
//                    .setImageRequest(imageRequest)
//                    .setControllerListener(mLogoControllerListener)
//                    .setOldController(logoHolder.getController())
//                    .build();
//            logoHolder.setController(controller);
        } else {
//            iconBitmapDescriptor = getBitmapDescriptorByName(uri);
//            update();
        }
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


}
