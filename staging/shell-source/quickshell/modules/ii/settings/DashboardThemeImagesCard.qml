import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Theme image importer. Uses the same file naming scheme as the user's
// customized SidebarRightContent and UserCardWidget. Never changes palettes.
DashboardCard {
    id: root
    tint: Appearance.colors.colLayer1

    readonly property string normalizedScheme: String(Config.options.appearance.palette.namedScheme || "")
        .toLowerCase().replace(/[^a-z0-9]/g, "")
    readonly property string currentTheme: normalizedScheme === "hotlinemiami" ? "hotline-miami" : normalizedScheme
    readonly property string imageDir: Quickshell.env("HOME") + "/Pictures/SidebarThemes"
    readonly property string iconUrl: "file://" + imageDir + "/" + currentTheme + ".webp"
    readonly property string cardUrl: "file://" + imageDir + "/" + currentTheme + "-card.webp"
    readonly property string helper: Quickshell.shellPath("scripts/theme-images-manager.py")
    property string pendingKind: "icon"
    property string pendingTheme: ""
    property string pendingPath: ""
    property string pendingDestination: ""
    property bool pendingReplaces: false
    property string feedback: "Selecione imagens. Arquivos externos só serão movidos após sua confirmação."

    function importImage(kind, path) {
        if (currentTheme === "") {
            feedback = "Selecione um esquema de cores nomeado primeiro."
            return
        }
        const input = String(path ?? "").trim()
        if (input.length === 0) {
            feedback = "Escolha uma imagem ou cole o caminho do arquivo."
            return
        }
        if (importProc.running || inspectProc.running) {
            feedback = "Uma imagem já está sendo processada."
            return
        }
        pendingKind = kind
        pendingTheme = currentTheme
        pendingPath = input
        feedback = "Conferindo o local da imagem..."
        inspectProc.command = ["python3", helper, "inspect", pendingTheme, pendingKind, pendingPath]
        inspectProc.running = true
    }

    function performImport(moveOriginal) {
        if (importProc.running) return
        importProc.command = ["python3", helper, moveOriginal ? "move" : "install",
                              pendingTheme, pendingKind, pendingPath]
        importProc.running = true
        feedback = moveOriginal ? "Movendo e convertendo imagem..." : "Salvando imagem..."
    }

    function browse(kind) {
        if (filePicker.running) return
        pendingKind = kind
        filePicker.command = ["kdialog", "--getopenfilename", Quickshell.env("HOME") + "/Pictures", "Imagens (*.webp *.png *.jpg *.jpeg)"]
        filePicker.running = true
    }

    function refreshPreview() {
        iconPreview.source = ""
        cardPreview.source = ""
        Qt.callLater(() => {
            iconPreview.source = Qt.binding(() => root.iconUrl)
            cardPreview.source = Qt.binding(() => root.cardUrl)
        })
    }

    Process {
        id: inspectProc
        stdout: StdioCollector { id: inspectOutput }
        stderr: StdioCollector { id: inspectError }
        onExited: (code) => {
            try {
                const data = JSON.parse(inspectOutput.text.trim())
                if (code !== 0 || !data.ok) {
                    root.feedback = data.error || "Imagem inválida ou inacessível."
                    return
                }
                root.pendingPath = data.source
                root.pendingDestination = data.destination
                root.pendingReplaces = data.replace
                if (data.outside) {
                    root.feedback = "Arquivo fora da pasta SidebarThemes. Confirme a movimentação."
                    moveDialog.open()
                } else {
                    root.performImport(false)
                }
            } catch (e) {
                root.feedback = "Erro ao verificar o arquivo: " + (inspectError.text.trim() || e)
            }
        }
    }

    Process {
        id: filePicker
        stdout: StdioCollector { id: filePickerOutput }
        stderr: StdioCollector { id: filePickerError }
        onExited: (code) => {
            const selected = filePickerOutput.text.trim()
            if (code === 0 && selected.length > 0) root.importImage(root.pendingKind, selected)
            else if (code !== 0 && code !== 1) root.feedback = "Não foi possível abrir kdialog. Cole o caminho no campo."
        }
    }
    Process {
        id: importProc
        stdout: StdioCollector { id: importOutput }
        stderr: StdioCollector { id: importError }
        onExited: (code) => {
            try {
                const data = JSON.parse(importOutput.text.trim())
                if (code !== 0 || !data.ok) {
                    root.feedback = data.error || "Falha ao salvar a imagem."
                    return
                }
                const name = root.pendingKind === "icon" ? "Ícone" : "Card"
                if (data.moved)
                    root.feedback = name + " movido para: " + data.path + ". Atualize os cards para aplicar."
                else if (data.already)
                    root.feedback = "A imagem já está na pasta correta: " + data.path
                else
                    root.feedback = name + " salvo em: " + data.path + ". Atualize os cards para aplicar."
                if (data.backup) root.feedback += " Imagem anterior preservada em .backups."
                if (data.warning) root.feedback += " AVISO: " + data.warning
                root.refreshPreview()
            } catch (e) {
                root.feedback = "Falha ao importar: " + (importError.text.trim() || e)
            }
        }
    }
    Process {
        id: prepareDir
        command: ["python3", root.helper, "prepare"]
        onExited: (code) => {
            if (code === 0) Quickshell.execDetached(["xdg-open", root.imageDir])
            else root.feedback = "Não consegui preparar a pasta de imagens."
        }
    }

    // Confirmação antes de modificar o local de um arquivo externo.
    Popup {
        id: moveDialog
        modal: true
        focus: true
        anchors.centerIn: Overlay.overlay
        width: Math.min(570, root.width - 32)
        padding: 20
        closePolicy: Popup.CloseOnEscape
        background: Rectangle {
            color: Appearance.colors.colLayer1
            border.width: 1
            border.color: Appearance.colors.colOutlineVariant
            radius: 20
        }
        contentItem: ColumnLayout {
            spacing: 14
            RowLayout {
                spacing: 10
                MaterialSymbol {
                    text: "drive_file_move"
                    iconSize: 28
                    color: Appearance.colors.colPrimary
                }
                StyledText {
                    Layout.fillWidth: true
                    text: "Organizar imagem do tema"
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                }
            }
            StyledText {
                Layout.fillWidth: true
                text: "Esta imagem está fora de ~/Pictures/SidebarThemes/. Deseja movê-la para a pasta correta?"
                wrapMode: Text.Wrap
                color: Appearance.colors.colOnLayer1
            }
            StyledText {
                Layout.fillWidth: true
                text: "Origem: " + root.pendingPath
                wrapMode: Text.WrapAnywhere
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
            }
            StyledText {
                Layout.fillWidth: true
                text: "Destino: " + root.pendingDestination
                wrapMode: Text.WrapAnywhere
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
            }
            StyledText {
                Layout.fillWidth: true
                visible: root.pendingReplaces
                text: "Já existe uma imagem para este tema. Ela será guardada em SidebarThemes/.backups antes da substituição."
                wrapMode: Text.Wrap
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colPrimary
            }
            StyledText {
                Layout.fillWidth: true
                text: "PNG e JPG serão convertidos para WebP. A imagem original só será removida depois que a nova for salva com sucesso."
                wrapMode: Text.Wrap
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Item { Layout.fillWidth: true }
                ThemeButton {
                    labelText: "Cancelar"
                    downAction: () => {
                        moveDialog.close()
                        root.feedback = "Movimentação cancelada. O arquivo original foi mantido."
                    }
                }
                ThemeButton {
                    labelText: "Mover e adicionar"
                    colBackground: Appearance.colors.colPrimary
                    colBackgroundHover: Appearance.colors.colPrimaryHover
                    contentItem: StyledText {
                        text: "Mover e adicionar"
                        color: Appearance.colors.colOnPrimary
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                    downAction: () => {
                        moveDialog.close()
                        root.performImport(true)
                    }
                }
            }
        }
    }

    component ThemeButton: RippleButton {
        id: button
        property string labelText: "Escolher"
        implicitHeight: 36
        horizontalPadding: 12
        buttonRadius: 12
        colBackground: Appearance.colors.colSecondaryContainer
        colBackgroundHover: Appearance.colors.colSecondaryContainerHover
        colRipple: Appearance.colors.colSecondaryContainerActive
        contentItem: StyledText {
            text: button.labelText
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: Appearance.colors.colOnSecondaryContainer
            font.pixelSize: Appearance.font.pixelSize.small
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            MaterialShapeWrappedMaterialSymbol {
                shape: MaterialShape.Shape.Gem
                text: "imagesmode"
                iconSize: 25
                fill: 1
                padding: 11
                color: Appearance.colors.colPrimary
                colSymbol: Appearance.colors.colOnPrimary
            }
            ColumnLayout {
                spacing: 2
                StyledText {
                    text: "Imagens do tema"
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    text: "Tema atual: " + (root.currentTheme || "nenhum tema nomeado")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }
            }
            Item { Layout.fillWidth: true }
            ThemeButton {
                labelText: "Abrir pasta"
                downAction: () => { prepareDir.running = true }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            // Icon editor
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                spacing: 7
                StyledText {
                    text: "Ícone / avatar"
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer1
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 95
                    radius: 16
                    color: Appearance.colors.colSecondaryContainer
                    Item {
                        anchors.centerIn: parent
                        width: Math.min(parent.height - 12, 104)
                        height: width
                        Image {
                            id: iconPreview
                            anchors.fill: parent
                            source: root.currentTheme !== "" ? root.iconUrl : ""
                            fillMode: Image.PreserveAspectCrop
                            cache: false
                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle {
                                    width: iconPreview.width
                                    height: iconPreview.height
                                    radius: width / 2
                                }
                            }
                        }
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "account_circle"
                            iconSize: 48
                            color: Appearance.colors.colOnSecondaryContainer
                            visible: iconPreview.status !== Image.Ready
                        }
                    }
                }
                StyledText {
                    text: root.currentTheme ? root.currentTheme + ".webp" : "Selecione um tema"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    TextField {
                        id: iconInput
                        Layout.fillWidth: true
                        implicitHeight: 36
                        placeholderText: "Caminho do ícone (.webp/.png/.jpg)"
                        selectByMouse: true
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.small
                        onAccepted: root.importImage("icon", text)
                        background: Rectangle {
                            color: Appearance.colors.colSecondaryContainer
                            radius: 10
                        }
                    }
                    ThemeButton {
                        labelText: "Escolher"
                        downAction: () => root.browse("icon")
                    }
                    ThemeButton {
                        labelText: "Salvar"
                        downAction: () => root.importImage("icon", iconInput.text)
                    }
                }
            }

            // Card editor
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                spacing: 7
                StyledText {
                    text: "Imagem do card"
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer1
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 95
                    radius: 16
                    color: Appearance.colors.colSecondaryContainer
                    clip: true
                    Image {
                        id: cardPreview
                        anchors.fill: parent
                        source: root.currentTheme !== "" ? root.cardUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                    }
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "image"
                        iconSize: 48
                        color: Appearance.colors.colOnSecondaryContainer
                        visible: cardPreview.status !== Image.Ready
                    }
                }
                StyledText {
                    text: root.currentTheme ? root.currentTheme + "-card.webp" : "Selecione um tema"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    TextField {
                        id: cardInput
                        Layout.fillWidth: true
                        implicitHeight: 36
                        placeholderText: "Caminho do fundo (.webp/.png/.jpg)"
                        selectByMouse: true
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.small
                        onAccepted: root.importImage("card", text)
                        background: Rectangle {
                            color: Appearance.colors.colSecondaryContainer
                            radius: 10
                        }
                    }
                    ThemeButton {
                        labelText: "Escolher"
                        downAction: () => root.browse("card")
                    }
                    ThemeButton {
                        labelText: "Salvar"
                        downAction: () => root.importImage("card", cardInput.text)
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            StyledText {
                Layout.fillWidth: true
                text: root.feedback
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                wrapMode: Text.Wrap
            }
            ThemeButton {
                labelText: "Atualizar cards"
                downAction: () => Quickshell.reload(true)
            }
        }
    }
}
