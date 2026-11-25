pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Qt.labs.folderlistmodel
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "customImage"
    hoverEnabled: true

    // "path" aceita tanto uma imagem quanto uma pasta com imagens.
    property string imagePath: Config.options.background.widgets.customImage.path ?? ""
    property bool isFolderPath: imagePath !== "" && !/\.(png|jpe?g|webp|avif|bmp|gif|tiff?)(\?.*)?$/i.test(imagePath)
    property int slideIndex: 0
    property int intervalSeconds: Math.max(2, Config.options.background.widgets.customImage.intervalSeconds ?? 10)
    property string displayedImage: {
        if (!root.isFolderPath)
            return root.imagePath
        if (imageFolder.count === 0)
            return ""
        return String(imageFolder.get(root.slideIndex % imageFolder.count, "fileUrl") || "")
    }
    property bool dropHover: false
    property int shapeType: ShapeUtils.getShape(Config.options.background.widgets.customImage.shape ?? "Cookie4Sided")
    property real widgetSize: Config.options.background.widgets.customImage.size ?? 200

    onImagePathChanged: slideIndex = 0

    // Carrega as imagens de uma pasta. A lista muda quando arquivos são adicionados/removidos.
    FolderListModel {
        id: imageFolder
        folder: root.isFolderPath
            ? (root.imagePath.startsWith("file:") ? root.imagePath : "file://" + encodeURI(root.imagePath))
            : "file:///__customimage_no_folder__"
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.avif", "*.bmp", "*.gif", "*.tif", "*.tiff"]
        caseSensitive: false
        showDirs: false
        showFiles: true
        showDotAndDotDot: false
        sortField: FolderListModel.Name
        onCountChanged: root.slideIndex = 0
    }

    Timer {
        id: slideshowTimer
        interval: root.intervalSeconds * 1000
        repeat: true
        running: root.isFolderPath && imageFolder.count > 1
        onTriggered: root.slideIndex = (root.slideIndex + 1) % imageFolder.count
    }

    implicitWidth: contentItem.implicitWidth
    implicitHeight: contentItem.implicitHeight

    Item {
        id: contentItem
        implicitWidth: root.widgetSize
        implicitHeight: root.widgetSize

        Behavior on implicitWidth {
            animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
        }
        Behavior on implicitHeight {
            animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
        }

        MaterialShape {
            id: shadowShape
            anchors.fill: parent
            color: Appearance.colors.colPrimaryContainer
            shape: root.shapeType
            visible: false
        }

        StyledDropShadow {
            target: shadowShape
            z: -1
            visible: Config.options.background.widgets.shadow
        }

        MaterialShape {
            id: imageShape
            anchors.fill: parent
            z: 0
            color: Appearance.colors.colPrimaryContainer
            shape: root.shapeType

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: MaterialShape {
                    width: imageShape.width
                    height: imageShape.height
                    shape: root.shapeType
                }
            }

            StyledImage {
                anchors.fill: parent
                source: root.displayedImage
                fillMode: Image.PreserveAspectCrop
                cache: false
                antialiasing: true
                sourceSize.width: parent.width
                sourceSize.height: parent.height
                visible: root.displayedImage !== ""
            }

            MaterialSymbol {
                anchors.centerIn: parent
                iconSize: contentItem.implicitWidth / 3
                text: root.dropHover ? "download" : "image"
                fill: root.dropHover ? 1 : 0
                color: root.dropHover
                    ? Appearance.colors.colPrimary
                    : Appearance.colors.colOnPrimaryContainer
                visible: root.displayedImage === ""
                Behavior on color {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }
            }

            // Arraste uma foto OU a pasta inteira do gerenciador de arquivos.
            DropArea {
                anchors.fill: parent
                keys: ["text/uri-list"]
                onEntered: (drag) => {
                    drag.accept(Qt.CopyAction)
                    root.dropHover = true
                }
                onExited: root.dropHover = false
                onDropped: (drop) => {
                    if (drop.hasUrls && drop.urls.length > 0) {
                        const url = drop.urls[0].toString()
                        if (url.startsWith("file://")) {
                            const cleanPath = decodeURIComponent(url.replace(/^file:\/\//, ""))
                            const isSupportedImage = /\.(png|jpe?g|webp|avif|bmp|gif|tiff?)$/i.test(cleanPath)
                            // Pastas normalmente não possuem extensão de arquivo.
                            const looksLikeFolder = !/\.[^/.]+$/.test(cleanPath.replace(/\/$/, ""))
                            if (isSupportedImage || looksLikeFolder)
                                Config.options.background.widgets.customImage.path = cleanPath.replace(/\/$/, "")
                        }
                    }
                    root.dropHover = false
                }
            }
        }

        ResizeHandler {
            anchorItem: imageShape
            hoverActive: root.containsMouse
            locked: Config.options.background.widgetsLocked
            currentWidth: root.widgetSize
            resizeMode: "diagonal"
            z: 1
            onResized: (newValue) => {
                root.widgetSize = Math.max(80, newValue)
            }
            onResizeFinished: {
                Config.options.background.widgets.customImage.size = root.widgetSize
            }
        }
    }
}
