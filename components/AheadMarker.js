import React, { PropTypes } from "react";
import {
    View,
    StyleSheet,
    Platform,
    NativeModules,
    Animated,
    findNodeHandle,
} from "react-native";

import resolveAssetSource
    from "react-native/Libraries/Image/resolveAssetSource";
import decorateMapComponent, {
    SUPPORTED,
    USES_DEFAULT_IMPLEMENTATION,
} from "./decorateMapComponent";

const viewConfig = {
    uiViewClassName: "AIR<provider>AheadMarker",
    validAttributes: {
        coordinate: true,
    },
};

const propTypes = {
    ...View.propTypes,
    /**
   * The coordinate for the marker.
   */
    coordinate: PropTypes.shape({
        /**
     * Coordinates for the anchor point of the marker.
     */
        latitude: PropTypes.number.isRequired,
        longitude: PropTypes.number.isRequired,
    }).isRequired,

    weightedValue: PropTypes.number.isRequired,
};

class AheadMarker extends React.Component {
    constructor(props) {
        super(props);
    }

    _runCommand(name, args) {
        switch (Platform.OS) {
            case "android":
                NativeModules.UIManager.dispatchViewManagerCommand(
                    this._getHandle(),
                    this.getUIManagerCommand(name),
                    args,
                );
                break;

            case "ios":
                this.getMapManagerCommand(name)(this._getHandle(), ...args);
                break;

            default:
                break;
        }
    }

    render() {
        const AIRMapAheadMarker = this.getAirComponent();

        return (
            <AIRMapAheadMarker
                ref={ref => {
                    this.marker = ref;
                }}
                {...this.props}
                style={[styles.marker, this.props.style]}
            />
        );
    }
}

AheadMarker.propTypes = propTypes;
// MapMarker.defaultProps = defaultProps;
AheadMarker.viewConfig = viewConfig;

const styles = StyleSheet.create({
    marker: {
        position: "absolute",
        backgroundColor: "transparent",
    },
});

module.exports = decorateMapComponent(AheadMarker, {
    componentType: "AheadMarker",
    providers: {
        google: {
            ios: SUPPORTED,
            android: USES_DEFAULT_IMPLEMENTATION,
        },
    },
});
