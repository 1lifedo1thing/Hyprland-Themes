import QtQuick
import qs.modules.common
import qs.services

Rectangle {
    id: root
    required property var widget
    property bool blurred: Config.options.background.widgets.blurWidgets
    property bool shadowed: Config.options.background.widgets.shadow
    property color tint: Appearance.colors.colLayer1
    readonly property real _contrastOriginalTintOpacity: 0.55
    property real tintOpacity: ThemeContrast.activeForScheme ? ThemeContrast.widgetOpacity : _contrastOriginalTintOpacity // END4_CONTRAST_V1

    radius: Appearance.rounding?.verylarge ?? 30
    color: Appearance.colors.colPrimaryContainer

    StyledRectangularShadow {
        target: root
        z: -2
        visible: root.shadowed
    }

    FastBlurred {
        anchors.fill: parent
        anchors.margins: root.blurred ? -1 : 0
        blurSource: root.widget.wallpaperItem
        cardRadius: root.radius + (root.blurred ? 1 : 0)
        tint: root.tint
        tintOpacity: root.tintOpacity
        trackX: root.widget.x + root.x
        trackY: root.widget.y + root.y
        visible: root.blurred
    }
}
