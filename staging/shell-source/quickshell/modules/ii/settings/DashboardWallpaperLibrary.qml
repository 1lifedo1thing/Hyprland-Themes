// Biblioteca de wallpapers do dashboard end4-pC
// Mantém o wallpaperSelector original; usa Wallpapers.apply para estáticos e vídeos.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root
    property bool animated: false
    property bool scanning: false
    property var videos: []
    property string statusMessage: ""
    property string pickKind: "static"
    property string pendingPath: ""
    property string pendingDestination: ""
    property bool pendingRenamed: false
    property bool processing: false

    readonly property string home: Quickshell.env("HOME")
    readonly property string staticFolder: home + "/Pictures/Wallpapers"
    readonly property string animatedFolder: staticFolder + "/Animated"
    readonly property string helper: FileUtils.trimFileProtocol(Quickshell.shellPath("scripts/wallpaper-library.py"))
    implicitHeight: 70 + (root.pendingPath !== "" ? 128 : 0) + (root.statusMessage !== "" ? 36 : 0)

    function clearPending() {
        pendingPath = ""
        pendingDestination = ""
        pendingRenamed = false
    }
    function openPicker() {
        if (chooser.running || root.processing) return
        root.pickKind = root.animated ? "animated" : "static"
        chooser.command = ["kdialog", "--getopenfilename",
            root.pickKind === "static" ? root.staticFolder : root.animatedFolder,
            root.pickKind === "static"
                ? "Imagens (*.png *.jpg *.jpeg *.webp *.avif *.bmp *.svg)"
                : "Vídeos (*.mp4 *.mkv *.webm *.mov *.m4v *.gif)"]
        root.statusMessage = ""
        chooser.running = true
    }
    function inspectSelected(path) {
        if (inspector.running) return
        inspector.command = ["python3", root.helper, "inspect", "--kind", root.pickKind, "--source", path]
        inspector.running = true
    }
    function confirmImport(action) {
        if (!root.pendingPath || root.processing) return
        root.processing = true
        importer.command = ["python3", root.helper, "import", "--kind", root.pickKind,
                            "--source", root.pendingPath, "--action", action]
        importer.running = true
    }
    function refreshAnimated() {
        if (scanProc.running) return
        root.scanning = true
        scanProc.command = ["python3", root.helper, "scan-animated"]
        scanProc.running = true
    }
    function showStatic() {
        root.animated = false
        Wallpapers.setDirectory(root.staticFolder)
    }
    function showAnimated() {
        root.animated = true
        root.refreshAnimated()
    }
    Component.onCompleted: Wallpapers.setDirectory(root.staticFolder)

    component ActionButton: Rectangle {
        id: btn
        property string label: ""
        property string symbol: ""
        property bool primary: false
        property bool selected: false
        signal clicked()
        implicitWidth: contents.implicitWidth + 26
        implicitHeight: 39
        radius: 20
        color: selected || primary ? Appearance.colors.colPrimary : Appearance.colors.colSecondaryContainer
        border.width: selected ? 2 : 0
        border.color: Appearance.colors.colOnPrimary
        RowLayout {
            id: contents
            anchors.centerIn: parent
            spacing: 7
            MaterialSymbol {
                text: btn.symbol
                iconSize: 18
                color: btn.primary || btn.selected ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
            }
            StyledText {
                text: btn.label
                color: btn.primary || btn.selected ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    Process {
        id: chooser
        stdout: StdioCollector {
            onStreamFinished: {
                const picked = this.text.trim()
                if (picked.length > 0) root.inspectSelected(picked)
            }
        }
        onExited: (code) => {
            if (code !== 0 && code !== 1)
                root.statusMessage = "Não foi possível abrir o seletor. Instale kdialog."
        }
    }
    Process {
        id: inspector
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(this.text.trim())
                    if (!result.ok) { root.statusMessage = result.error; return }
                    root.pendingPath = result.source
                    root.pendingDestination = result.destination
                    root.pendingRenamed = result.will_rename
                    if (result.inside) {
                        root.statusMessage = "Arquivo já organizado em " + result.folder
                        root.clearPending()
                        if (root.pickKind === "animated") root.showAnimated()
                        else root.showStatic()
                    }
                } catch(e) { root.statusMessage = "Falha ao conferir o arquivo: " + e }
            }
        }
    }
    Process {
        id: importer
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(this.text.trim())
                    if (!result.ok) { root.statusMessage = result.error; return }
                    root.statusMessage = result.message + (result.warning ? " • " + result.warning : "")
                    root.clearPending()
                    if (root.pickKind === "animated") root.showAnimated()
                    else root.showStatic()
                } catch(e) { root.statusMessage = "Falha na importação: " + e }
            }
        }
        onExited: (code) => root.processing = false
    }
    Process {
        id: scanProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(this.text.trim())
                    if (!result.ok) { root.statusMessage = result.error; return }
                    root.videos = result.items || []
                    if (!result.ffmpeg)
                        root.statusMessage = "Instale ffmpeg para gerar miniaturas dos vídeos."
                } catch(e) { root.statusMessage = "Falha ao ler vídeos: " + e }
            }
        }
        onExited: (code) => root.scanning = false
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            spacing: 9
            ActionButton {
                label: "Estáticos"
                symbol: "image"
                selected: !root.animated
                onClicked: root.showStatic()
            }
            ActionButton {
                label: "Animados"
                symbol: "movie"
                selected: root.animated
                onClicked: root.showAnimated()
            }
            Item { Layout.fillWidth: true }
            ActionButton {
                visible: root.animated
                label: "Atualizar"
                symbol: "refresh"
                onClicked: root.refreshAnimated()
            }
            ActionButton {
                label: "Abrir pasta"
                symbol: "folder_open"
                onClicked: Quickshell.execDetached(["xdg-open", root.animated ? root.animatedFolder : root.staticFolder])
            }
            ActionButton {
                label: "Adicionar wallpaper"
                symbol: "add_photo_alternate"
                primary: true
                onClicked: root.openPicker()
            }
        }
        Rectangle {
            visible: root.pendingPath !== ""
            Layout.fillWidth: true
            Layout.preferredHeight: 128
            radius: 16
            color: Appearance.colors.colTertiaryContainer
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 5
                StyledText {
                    Layout.fillWidth: true
                    text: "Arquivo fora da galeria. Mover pode afetar outros caminhos; copie se estiver em uso."
                    color: Appearance.colors.colOnTertiaryContainer
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: "Origem: " + root.pendingPath
                    color: Appearance.colors.colOnTertiaryContainer
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    elide: Text.ElideMiddle
                }
                StyledText {
                    Layout.fillWidth: true
                    text: "Destino: " + root.pendingDestination + (root.pendingRenamed ? " (nome ajustado para evitar sobrescrever)" : "")
                    color: Appearance.colors.colOnTertiaryContainer
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    elide: Text.ElideMiddle
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    ActionButton { label: "Mover e adicionar"; symbol: "drive_file_move"; primary: true; onClicked: root.confirmImport("move") }
                    ActionButton { label: "Copiar"; symbol: "content_copy"; onClicked: root.confirmImport("copy") }
                    ActionButton { label: "Cancelar"; symbol: "close"; onClicked: root.clearPending() }
                }
            }
        }
        Rectangle {
            visible: root.statusMessage !== ""
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            radius: 12
            color: Appearance.colors.colSecondaryContainer
            StyledText {
                anchors.fill: parent
                anchors.margins: 7
                text: root.statusMessage
                color: Appearance.colors.colOnSecondaryContainer
                font.pixelSize: Appearance.font.pixelSize.small
                elide: Text.ElideMiddle
            }
        }
        GridView {
            id: animatedGrid
            visible: root.animated
            Layout.fillHeight: root.animated
            Layout.fillWidth: true
            clip: true
            model: root.videos
            cellWidth: Math.max(170, Math.floor(width / Math.max(1, Math.floor(width / 255))))
            cellHeight: 190
            boundsBehavior: Flickable.StopAtBounds
            delegate: Item {
                id: tile
                required property var modelData
                required property int index
                width: animatedGrid.cellWidth
                height: animatedGrid.cellHeight
                readonly property bool activeVideo: String(Config.options.background.wallpaperPath) === modelData.path
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 6
                    radius: 18
                    clip: true
                    color: Appearance.colors.colLayer1
                    border.width: tile.activeVideo ? 3 : 1
                    border.color: tile.activeVideo ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
                    Image {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: labelArea.top
                        source: tile.modelData.thumbnail ? "file://" + tile.modelData.thumbnail : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 43; height: 43; radius: 22
                        color: Appearance.colors.colPrimary
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: tile.activeVideo ? "check" : "play_arrow"
                            iconSize: 25
                            color: Appearance.colors.colOnPrimary
                        }
                    }
                    Rectangle {
                        id: labelArea
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 42
                        color: Appearance.colors.colLayer1
                        StyledText {
                            anchors.fill: parent
                            anchors.margins: 8
                            text: tile.modelData.name
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer1
                            elide: Text.ElideMiddle
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!WallpaperLayouts.prepareSwitch(tile.modelData.path)) {
                                root.statusMessage = "Não foi possível preparar a troca do wallpaper."
                                return
                            }
                            Wallpapers.stopPreview()
                            Wallpapers.apply(tile.modelData.path)
                            root.statusMessage = "Aplicando animado: " + tile.modelData.name
                        }
                    }
                }
            }
        }
        StyledText {
            visible: root.animated && root.videos.length === 0
            Layout.fillWidth: true
            text: root.scanning ? "Carregando wallpapers animados..." : "Sem vídeos. Use Adicionar wallpaper para importar um."
            font.pixelSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colSubtext
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
