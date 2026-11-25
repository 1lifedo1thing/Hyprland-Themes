import QtQuick
import Quickshell.Widgets
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

// Image Card do end4-pC: ate 6 instancias independentes, com
// redimensionamento livre e substituicao da imagem por drag-and-drop.
// A instancia usa configEntryName para escolher imageCard, imageCard2, etc.
AbstractBackgroundWidget {
    id: root
    configEntryName: "imageCard"
    hoverEnabled: true

    readonly property real minCardSize: 90

    property string imagePath: root.configEntry.path ?? ""
    property bool dropHover: false

    // Converte caminhos locais para URLs com escapes seguros.
    readonly property string imageSource: {
        const p = String(root.imagePath || "")
        if (p === "") return ""
        if (/^[a-z][a-z0-9+.-]*:\/\//i.test(p)) return p
        return "file://" + encodeURI(p).replace(/#/g, "%23").replace(/\?/g, "%3F")
    }

    readonly property real cardSpacing: 12
    readonly property real singleWidth: 132
    readonly property real defaultHeight: 120
    readonly property string sizeMode: root.configEntry.sizeMode ?? "1x2"
    readonly property real defaultWidth: {
        if (sizeMode === "1x1") return singleWidth
        if (sizeMode === "1x2" || sizeMode === "2x2") return singleWidth * 2 + cardSpacing
        return singleWidth * 3 + cardSpacing * 2
    }
    readonly property real defaultCardHeight: (sizeMode === "2x2" || sizeMode === "2x3")
        ? defaultHeight * 2 + cardSpacing : defaultHeight

    // A configuracao e a fonte persistida; a previa e usada durante o arraste.
    readonly property real savedWidth: Number(root.configEntry.cardWidth) > 0
        ? Number(root.configEntry.cardWidth) : root.defaultWidth
    readonly property real savedHeight: Number(root.configEntry.cardHeight) > 0
        ? Number(root.configEntry.cardHeight) : root.defaultCardHeight

    property bool resizingCard: false
    property real previewWidth: 0
    property real previewHeight: 0
    property real resizeStartHeight: 0

    readonly property real widgetWidth: root.resizingCard ? root.previewWidth : root.savedWidth
    readonly property real widgetHeight: root.resizingCard ? root.previewHeight : root.savedHeight

    // Alem das dimensoes implicitas, define as dimensoes REAIS do MouseArea.
    // Isso evita que a geometria do canvas e a do cartao se desencontrem.
    width: root.widgetWidth
    height: root.widgetHeight
    implicitWidth: root.widgetWidth
    implicitHeight: root.widgetHeight

    function beginResize() {
        const vx = Math.round(root.x)
        const vy = Math.round(root.y)

        // Se a posicao visivel sofreu clamp pela tela, fixa-a para nao saltar.
        if (Math.abs(vx - Number(root.configEntry.x)) > 0.5)
            root.configEntry.x = vx
        if (Math.abs(vy - Number(root.configEntry.y)) > 0.5)
            root.configEntry.y = vy

        root.resizeStartHeight = root.savedHeight
        root.previewWidth = root.savedWidth
        root.previewHeight = root.savedHeight
        root.resizingCard = true
    }

    function finishResize() {
        if (!root.resizingCard) return

        const w = Math.max(root.minCardSize, Math.round(root.previewWidth))
        const h = Math.max(root.minCardSize, Math.round(root.previewHeight))

        // Atualiza a configuracao antes de retirar o modo de previa.
        root.configEntry.cardWidth = w
        root.configEntry.cardHeight = h
        root.previewWidth = w
        root.previewHeight = h
        root.resizingCard = false

        // Diagnostico enxuto: confirma o valor visivel imediatamente apos o commit.
        console.log("[ImageCard-SAVE]", root.configEntryName,
            "solicitado", w, h,
            "em-memoria", root.savedWidth, root.savedHeight)
    }

    // Se outro componente recarregar dimensoes antigas do JSON, este aviso
    // ajuda a separar problema de layout de problema de persistencia.
    property real lastResizeWidth: 0
    property real lastResizeHeight: 0
    property bool hasResizedLocally: false

    onSavedWidthChanged: {
        if (root.hasResizedLocally && !root.resizingCard
                && Math.round(root.savedWidth) !== Math.round(root.lastResizeWidth)) {
            console.warn("[ImageCard-RESET]", root.configEntryName,
                "largura voltou para", root.savedWidth,
                "apos salvar", root.lastResizeWidth)
        }
    }
    onSavedHeightChanged: {
        if (root.hasResizedLocally && !root.resizingCard
                && Math.round(root.savedHeight) !== Math.round(root.lastResizeHeight)) {
            console.warn("[ImageCard-RESET]", root.configEntryName,
                "altura voltou para", root.savedHeight,
                "apos salvar", root.lastResizeHeight)
        }
    }

    function localImagePath(value) {
        let path = String(value || "").trim()
        if (path.startsWith("file://")) {
            path = path.slice(7)
            if (path.startsWith("localhost/")) path = path.slice(9)
            try { path = decodeURIComponent(path) } catch (e) { return "" }
        }
        if (!path.startsWith("/")) return ""
        if (!/\.(png|jpe?g|webp|avif|bmp|gif|tiff?|svg)$/i.test(path)) return ""
        return path
    }

    function acceptDroppedImage(drop) {
        let newPath = ""
        if (drop.urls && drop.urls.length > 0) {
            for (let i = 0; i < drop.urls.length; ++i) {
                newPath = root.localImagePath(drop.urls[i].toString())
                if (newPath !== "") break
            }
        }
        if (newPath === "" && drop.hasText)
            newPath = root.localImagePath(String(drop.text).split(/\r?\n/)[0])

        if (newPath !== "") {
            root.configEntry.path = newPath
            drop.accept(Qt.CopyAction)
        }
        root.dropHover = false
    }

    Image {
        id: probe
        source: root.imageSource
        visible: false
        asynchronous: true
        cache: false
        sourceSize.width: 64
        sourceSize.height: 64
    }

    readonly property real imageAspect: probe.implicitHeight > 0
        ? probe.implicitWidth / probe.implicitHeight : 1
    readonly property bool imageWiderThanCard: root.imageAspect >=
        root.savedWidth / Math.max(1, root.savedHeight)

    WidgetCard {
        id: card
        anchors.fill: parent
        implicitWidth: root.widgetWidth
        implicitHeight: root.widgetHeight
        widget: root

        ClippingRectangle {
            anchors.fill: parent
            radius: card.radius
            color: "transparent"

            StyledImage {
                anchors.fill: parent
                source: root.imageSource
                visible: root.imagePath !== ""
                fillMode: Image.PreserveAspectCrop
                cache: false
                antialiasing: true
                smooth: true
                mipmap: true
                // Usa tamanho salvo para evitar decodificacao continua no resize.
                sourceSize.width: root.imageWiderThanCard ? 0 : Math.ceil(root.savedWidth * 2)
                sourceSize.height: root.imageWiderThanCard ? Math.ceil(root.savedHeight * 2) : 0
            }

            MaterialSymbol {
                anchors.centerIn: parent
                iconSize: Math.min(card.width, card.height) / 3
                text: root.dropHover ? "download" : "image"
                fill: root.dropHover ? 1 : 0
                color: root.dropHover
                    ? Appearance.colors.colPrimary
                    : Appearance.colors.colOnPrimaryContainer
                visible: root.imagePath === ""
            }

            Rectangle {
                anchors.fill: parent
                color: Appearance.colors.colPrimary
                opacity: root.dropHover ? 0.22 : 0
                visible: root.dropHover
                radius: card.radius
            }

            DropArea {
                anchors.fill: parent
                keys: ["text/uri-list", "text/plain"]
                onEntered: (drag) => {
                    drag.accept(Qt.CopyAction)
                    root.dropHover = true
                }
                onExited: root.dropHover = false
                onDropped: (drop) => root.acceptDroppedImage(drop)
            }
        }

        ResizeHandler {
            anchorItem: card
            hoverActive: root.containsMouse
            locked: Config.options.background.widgetsLocked
            currentWidth: root.widgetWidth
            resizeMode: "diagonal"
            z: 2

            onResizedXY: (dx, dy, startWidth) => {
                if (!root.resizingCard)
                    root.beginResize()

                root.previewWidth = Math.max(root.minCardSize, Math.round(startWidth + dx))
                root.previewHeight = Math.max(root.minCardSize,
                    Math.round(root.resizeStartHeight + dy))
            }

            onResizeFinished: {
                if (!root.resizingCard) return
                root.lastResizeWidth = Math.round(root.previewWidth)
                root.lastResizeHeight = Math.round(root.previewHeight)
                root.hasResizedLocally = true
                root.finishResize()
            }
        }
    }
}
