import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root

    required property var collage

    readonly property var result: root.collage.result
    readonly property bool canSplit: Collage.leafCount < Collage.maxTiles
    readonly property bool canRemove: Collage.leafCount > 1

    Repeater {
        model: ScriptModel {
            values: root.result.leaves
            objectProp: "id"
        }

        delegate: Item {
            id: tileControls
            required property var modelData
            x: modelData.x
            y: modelData.y
            width: modelData.w
            height: modelData.h

            Behavior on x { enabled: !Collage.dragging; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on y { enabled: !Collage.dragging; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on width { enabled: !Collage.dragging; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on height { enabled: !Collage.dragging; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            // END4_CROP_OVERLAY_V4: editor é carregado sobre widgets e drop areas.
            // Assim o MouseArea recebe o gesto sem depender da camada do fundo.
            // Os botões abaixo permanecem ACIMA desta área e continuam clicáveis.
            MouseArea {
                id: cropDragArea
                anchors.fill: parent
                enabled: Collage.cropEditTileId === tileControls.modelData.id
                    && !Config.options.background.widgetsLocked && !GlobalStates.screenLocked
                acceptedButtons: Qt.LeftButton
                hoverEnabled: enabled
                preventStealing: true
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                property real pressX: 0
                property real pressY: 0
                property real startPanX: 0
                property real startPanY: 0

                onPressed: mouse => {
                    cropDragArea.pressX = mouse.x
                    cropDragArea.pressY = mouse.y
                    cropDragArea.startPanX = Number(tileControls.modelData.cropPanX) || 0
                    cropDragArea.startPanY = Number(tileControls.modelData.cropPanY) || 0
                    Collage.liveCropPanX = cropDragArea.startPanX
                    Collage.liveCropPanY = cropDragArea.startPanY
                    Collage.cropDragTileId = tileControls.modelData.id
                }
                onPositionChanged: mouse => {
                    if (!cropDragArea.pressed || Collage.cropDragTileId !== tileControls.modelData.id) return
                    // 1 pixel do mouse move 1 pixel da imagem, nas duas direções.
                    Collage.liveCropPanX = cropDragArea.startPanX
                        + (mouse.x - cropDragArea.pressX) / Math.max(1, tileControls.width)
                    Collage.liveCropPanY = cropDragArea.startPanY
                        + (mouse.y - cropDragArea.pressY) / Math.max(1, tileControls.height)
                }
                onReleased: {
                    if (Collage.cropDragTileId !== tileControls.modelData.id) return
                    const px = Collage.liveCropPanX
                    const py = Collage.liveCropPanY
                    Collage.cropDragTileId = -1
                    Collage.setCrop(tileControls.modelData.id,
                        tileControls.modelData.cropX, tileControls.modelData.cropY,
                        tileControls.modelData.cropZoom, px, py)
                }
                onCanceled: { Collage.cropDragTileId = -1 }
                onWheel: wheel => {
                    if (wheel.angleDelta.y === 0) return
                    const zoom = Math.max(0.15, Math.min(6,
                        tileControls.modelData.cropZoom * Math.pow(1.20, wheel.angleDelta.y / 120)))
                    Collage.setCrop(tileControls.modelData.id,
                        tileControls.modelData.cropX, tileControls.modelData.cropY, zoom,
                        tileControls.modelData.cropPanX, tileControls.modelData.cropPanY)
                    wheel.accepted = true
                }
            }

            Rectangle {
                visible: Collage.cropEditTileId === tileControls.modelData.id
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 12
                width: cropHint.implicitWidth + 20
                height: 32
                radius: 16
                color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.15)

                StyledText {
                    id: cropHint
                    anchors.centerIn: parent
                    text: "Arraste para mover  •  Scroll para zoom"
                    color: Appearance.colors.colOnLayer0
                }
            }

            Rectangle {
                id: actionPill
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                implicitWidth: actionRow.implicitWidth + 12
                implicitHeight: 44
                radius: Appearance.rounding.full
                color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.15)

                RowLayout {
                    id: actionRow
                    anchors.centerIn: parent
                    spacing: 2

                    component TileAction: RippleButton {
                        id: action
                        property string symbol
                        property string tip
                        implicitWidth: 36
                        implicitHeight: 36
                        buttonRadius: Appearance.rounding.full
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: action.symbol
                            iconSize: 20
                            color: action.enabled ? Appearance.colors.colOnLayer0 : ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.6)
                        }
                        StyledToolTip {
                            text: action.tip
                        }
                    }

                    TileAction {
                        symbol: "wallpaper"
                        tip: Translation.tr("Change image (or drop a file on the tile)")
                        onClicked: Collage.pickImage(tileControls.modelData.id)
                    }
                    // END4_CROP_PER_TILE_V2: não altera os controles originais.
                    TileAction {
                        symbol: "crop"
                        tip: "Ajustar enquadramento: arraste a imagem / scroll para zoom"
                        toggled: Collage.cropEditTileId === tileControls.modelData.id
                        onClicked: Collage.toggleCropEdit(tileControls.modelData.id)
                    }
                    TileAction {
                        symbol: "center_focus_strong"
                        tip: "Centralizar e remover zoom"
                        visible: Collage.cropEditTileId === tileControls.modelData.id
                        onClicked: Collage.resetCrop(tileControls.modelData.id)
                    }
                    TileAction {
                        symbol: "splitscreen_vertical_add"
                        tip: Translation.tr("Split side by side")
                        enabled: root.canSplit
                        onClicked: Collage.splitLeaf(tileControls.modelData.id, "v")
                    }
                    TileAction {
                        symbol: "splitscreen_add"
                        tip: Translation.tr("Split top and bottom")
                        enabled: root.canSplit
                        onClicked: Collage.splitLeaf(tileControls.modelData.id, "h")
                    }
                    TileAction {
                        symbol: "delete"
                        tip: Translation.tr("Remove")
                        enabled: root.canRemove
                        onClicked: Collage.removeLeaf(tileControls.modelData.id)
                    }
                }
            }
        }
    }

    Repeater {
        model: ScriptModel {
            values: root.result.splits
            objectProp: "path"
        }

        delegate: MouseArea {
            id: gutter
            required property var modelData
            readonly property bool vertical: modelData.d === "v"
            readonly property real hitSize: Math.max(Collage.gap, 20)

            x: vertical ? modelData.line - hitSize / 2 : modelData.from
            y: vertical ? modelData.from : modelData.line - hitSize / 2
            width: vertical ? hitSize : modelData.to - modelData.from
            height: vertical ? modelData.to - modelData.from : hitSize
            enabled: Collage.cropEditTileId < 0
            hoverEnabled: true
            preventStealing: true
            cursorShape: vertical ? Qt.SplitHCursor : Qt.SplitVCursor

            function ratioAt(mouse) {
                const point = gutter.mapToItem(root, mouse.x, mouse.y)
                const area = root.result.area
                return vertical
                    ? ((point.x - area.x) / area.w - modelData.fx) / modelData.fw
                    : ((point.y - area.y) / area.h - modelData.fy) / modelData.fh
            }

            property bool moved: false

            onPressed: {
                gutter.moved = false
                Collage.dragging = true
            }
            onPositionChanged: mouse => {
                if (!pressed) return
                gutter.moved = true
                const ratio = Math.max(0.15, Math.min(0.85, gutter.ratioAt(mouse)))
                const next = Object.assign({}, Collage.liveRatios)
                next[modelData.path] = ratio
                Collage.liveRatios = next
            }
            onReleased: mouse => {
                if (gutter.moved) Collage.setRatio(modelData.path, gutter.ratioAt(mouse))
                Collage.liveRatios = ({})
                Collage.dragging = false
            }
            onCanceled: {
                Collage.liveRatios = ({})
                Collage.dragging = false
            }
            onDoubleClicked: Collage.setRatio(modelData.path, 0.5)

            Rectangle {
                anchors.centerIn: parent
                width: gutter.vertical ? 4 : Math.min(parent.width, 80)
                height: gutter.vertical ? Math.min(parent.height, 80) : 4
                radius: 2
                color: Appearance.colors.colPrimary
                opacity: gutter.containsMouse || gutter.pressed ? 1 : 0.55
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }
        }
    }
}
