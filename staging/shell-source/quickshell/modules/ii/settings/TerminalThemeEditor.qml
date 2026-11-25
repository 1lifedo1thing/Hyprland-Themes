import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell.Io
import Quickshell
import qs.modules.common

// Insira este componente logo abaixo da seção "Imagens do tema".
// Não depende da paleta do desktop: cada perfil possui sua própria capa e cores.
ColumnLayout {
    id: root
    spacing: 14

    property string helperPath: Quickshell.env("HOME") + "/.config/illogical-impulse/terminal_theme_manager.py"
    property var records: []
    property int chosenIndex: -1
    property var colorDraft: ({})
    property string coverDraft: ""
    // KITTY_AUTO_PALETA_V1: a geração é uma prévia, nunca salva automaticamente.
    property bool gerandoPaleta: false
    property string geradorDePaleta: Quickshell.env("HOME") + "/.config/illogical-impulse/kitty_paleta_auto.py"
    property string nameDraft: ""
    property bool busy: false
    property string info: ""
    property color ink: Appearance.colors.colOnSurface
    property color accent: Appearance.colors.colPrimary
    property color surface: Appearance.m3colors.m3surfaceContainerHigh
    property var fields: [
        ["background", "Fundo"], ["foreground", "Texto"],
        ["cursor", "Cursor"], ["selection_background", "Seleção"],
        ["selection_foreground", "Texto selecionado"],
        ["color0", "ANSI 0"], ["color1", "ANSI 1"],
        ["color2", "ANSI 2"], ["color3", "ANSI 3"],
        ["color4", "ANSI 4"], ["color5", "ANSI 5"],
        ["color6", "ANSI 6"], ["color7", "ANSI 7"],
        ["color8", "ANSI 8"], ["color9", "ANSI 9"],
        ["color10", "ANSI 10"], ["color11", "ANSI 11"],
        ["color12", "ANSI 12"], ["color13", "ANSI 13"],
        ["color14", "ANSI 14"], ["color15", "ANSI 15"]
    ]

    // Explicações mostradas ao passar o mouse pelas opções do Kitty.
    function colorHint(key) {
        const hints = {
            "background": "FUNDO\nCor de fundo da janela do terminal.\nNão é a cor do tema do desktop.",
            "foreground": "TEXTO\nCor padrão das letras e saídas de comandos.\nApps podem usar suas próprias cores ANSI.",
            "cursor": "CURSOR\nCor do bloco ou traço que indica onde você digita.",
            "selection_background": "SELEÇÃO\nFundo do texto selecionado com o mouse no terminal.",
            "selection_foreground": "TEXTO SELECIONADO\nCor das letras dentro da seleção do mouse.",
            "color0": "ANSI 0 · PRETO\nCor escura normal usada por aplicativos;\nnão é o fundo do terminal.",
            "color1": "ANSI 1 · VERMELHO\nUsado frequentemente para erros e alertas.\nO aplicativo decide quando usar.",
            "color2": "ANSI 2 · VERDE\nUsado frequentemente para sucessos e confirmações.\nO aplicativo decide quando usar.",
            "color3": "ANSI 3 · AMARELO\nUsado frequentemente para avisos.\nO aplicativo decide quando usar.",
            "color4": "ANSI 4 · AZUL\nUsado frequentemente em informações e links.\nO aplicativo decide quando usar.",
            "color5": "ANSI 5 · MAGENTA\nUsado para destaques, símbolos e sintaxe.\nO aplicativo decide quando usar.",
            "color6": "ANSI 6 · CIANO\nUsado para dados, valores e destaques.\nO aplicativo decide quando usar.",
            "color7": "ANSI 7 · BRANCO\nTom claro normal, muitas vezes usado em texto.\nNão é a cor padrão do texto.",
            "color8": "ANSI 8 · PRETO CLARO / CINZA\nVersão brilhante da cor ANSI 0.\nMuito usada para comentários e texto discreto.",
            "color9": "ANSI 9 · VERMELHO CLARO\nVersão brilhante do vermelho (ANSI 1).",
            "color10": "ANSI 10 · VERDE CLARO\nVersão brilhante do verde (ANSI 2).",
            "color11": "ANSI 11 · AMARELO CLARO\nVersão brilhante do amarelo (ANSI 3).",
            "color12": "ANSI 12 · AZUL CLARO\nVersão brilhante do azul (ANSI 4).",
            "color13": "ANSI 13 · MAGENTA CLARO\nVersão brilhante do magenta (ANSI 5).",
            "color14": "ANSI 14 · CIANO CLARO\nVersão brilhante do ciano (ANSI 6).",
            "color15": "ANSI 15 · BRANCO BRILHANTE\nVersão brilhante do branco (ANSI 7)."
        }
        return hints[key] || "Cor personalizada do terminal."
    }

    function callBackend(args, callback) {
        if (root.busy) return
        root.busy = true
        root.info = ""
        processTask.callback = callback
        processTask.resultText = ""
        processTask.command = ["python3", root.helperPath].concat(args)
        processTask.running = true
    }

    function refresh(preferId) {
        callBackend(["list"], function(out) {
            if (!out || !out.ok) { root.info = out && out.error ? out.error : "Não foi possível carregar os perfis"; return }
            root.records = out.profiles || []
            var wanted = preferId || out.active
            var index = root.records.findIndex(function(r) { return r.id === wanted })
            selectProfile(index < 0 ? 0 : index)
        })
    }

    function selectProfile(index) {
        if (index < 0 || index >= root.records.length) return
        root.chosenIndex = index
        const item = root.records[index]
        root.nameDraft = item.name
        root.coverDraft = item.cover || ""
        root.colorDraft = Object.assign({}, item.colors)
    }

    function selectedId() {
        return root.chosenIndex >= 0 && root.chosenIndex < root.records.length ? root.records[root.chosenIndex].id : ""
    }

    function saveProfile() {
        const id = root.selectedId()
        if (!id) return
        const body = JSON.stringify({name: root.nameDraft, cover: root.coverDraft, colors: root.colorDraft})
        callBackend(["save", id, body], function(out) {
            if (!out || !out.ok) { root.info = out && out.error ? out.error : "Erro ao salvar"; return }
            root.info = out.warning || "Tema salvo e aplicado!"
            Qt.callLater(function() { root.refresh(id) })
        })
    }

    Process {
        id: processTask
        property var callback: null
        property string resultText: ""
        running: false
        stdout: StdioCollector {
            onStreamFinished: processTask.resultText = text
        }
        onExited: (exitCode, exitStatus) => {
            root.busy = false
            const callback = processTask.callback
            processTask.callback = null
            Qt.callLater(function() {
                var result
                try { result = JSON.parse(processTask.resultText) }
                catch (e) { result = {ok: false, error: "Resposta inválida do gerenciador: " + processTask.resultText} }
                if (callback) callback(result)
            })
        }
    }

    FileDialog {
        id: coverDialog
        title: "Escolher capa do Fastfetch"
        nameFilters: ["Imagens (*.png *.webp *.jpg *.jpeg)"]
        onAccepted: {
            root.coverDraft = decodeURIComponent(selectedFile.toString().replace(/^file:\/\//, ""))
        }
    }

    ColorDialog {
        id: colorPicker
        property string targetKey: ""
        title: "Escolher cor do terminal"
        onAccepted: {
            function toByte(n) {
                return Math.round(n * 255).toString(16).padStart(2, "0")
            }
            var hex = ("#" + toByte(selectedColor.r) + toByte(selectedColor.g) + toByte(selectedColor.b)).toUpperCase()
            var next = Object.assign({}, root.colorDraft)
            next[targetKey] = hex
            root.colorDraft = next
        }
    }

    // KITTY_AUTO_PALETA_V1: gera cores SOMENTE para o perfil selecionado.
    function gerarCoresAutomaticamente() {
        if (root.busy || root.gerandoPaleta) return
        if (!root.coverDraft || !root.coverDraft.trim()) {
            root.info = "Escolha uma capa do Fastfetch antes de gerar as cores."
            return
        }
        root.gerandoPaleta = true
        root.info = "Analisando as cores da capa..."
        geradorPaletaProcess.resultText = ""
        geradorPaletaProcess.command = ["python3", root.geradorDePaleta, root.coverDraft.trim()]
        geradorPaletaProcess.running = true
    }

    Process {
        id: geradorPaletaProcess
        property string resultText: ""
        running: false
        stdout: StdioCollector {
            onStreamFinished: geradorPaletaProcess.resultText = text
        }
        onExited: (exitCode, exitStatus) => {
            root.gerandoPaleta = false
            Qt.callLater(function() {
                var response = null
                try { response = JSON.parse(geradorPaletaProcess.resultText) }
                catch (e) {
                    root.info = "Não foi possível ler as cores geradas. Confira o ffmpeg."
                    return
                }
                if (exitCode !== 0 || !response.ok || !response.colors) {
                    root.info = response && response.error ? response.error : "Erro ao gerar cores."
                    return
                }
                var colors = Object.assign({}, root.colorDraft)
                var keys = root.fields.map(function(field) { return field[0] })
                for (var key in response.colors) {
                    if (keys.indexOf(key) !== -1) colors[key] = response.colors[key]
                }
                root.colorDraft = colors
                root.info = "Cores geradas! Confira a prévia e clique em 'Salvar e aplicar tema' para confirmar."
            })
        }
    }

    Component.onCompleted: root.refresh()

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 66
        radius: 14
        color: Appearance.m3colors.m3surfaceContainer
        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12
            Rectangle {
                implicitWidth: 43; implicitHeight: 43; radius: 12; color: root.accent
                Text { anchors.centerIn: parent; text: "⌘"; color: "white"; font.pixelSize: 23 }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label { text: "Temas e capas do terminal"; color: root.ink; font.pixelSize: 17 }
                Label { text: "Perfis independentes do tema do desktop · Kitty + Fastfetch"; color: Appearance.colors.colOnSurfaceVariant; font.pixelSize: 12 }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        ComboBox {
            id: profileCombo
            Layout.fillWidth: true
            enabled: !root.busy
            model: root.records.map(function(p) { return p.name })
            currentIndex: root.chosenIndex
            onActivated: (index) => root.selectProfile(index)
        }
        Button {
            text: "Novo tema"
            enabled: !root.busy
            onClicked: createDialog.open()
        }
        Button {
            text: "Excluir"
            enabled: !root.busy && root.records.length > 1
            onClicked: deleteDialog.open()
        }
    }

    Dialog {
        id: createDialog
        title: "Criar tema de terminal"
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        anchors.centerIn: Overlay.overlay
        contentItem: TextField { id: newName; placeholderText: "Nome do novo tema"; implicitWidth: 280 }
        onAccepted: {
            if (!newName.text.trim()) return
            root.callBackend(["new", newName.text.trim()], function(result) {
                if (!result || !result.ok) { root.info = result && result.error ? result.error : "Erro ao criar"; return }
                Qt.callLater(function() { root.refresh(result.id) })
            })
        }
    }
    Dialog {
        id: deleteDialog
        title: "Excluir este tema?"
        modal: true
        standardButtons: Dialog.Yes | Dialog.No
        anchors.centerIn: Overlay.overlay
        Label { text: "O tema selecionado será removido da lista." }
        onAccepted: root.callBackend(["delete", root.selectedId()], function(out) {
            if (!out || !out.ok) { root.info = out && out.error ? out.error : "Erro ao excluir"; return }
            Qt.callLater(function() { root.refresh(out.active) })
        })
    }

    GridLayout {
        Layout.fillWidth: true
        columns: root.width > 770 ? 2 : 1
        columnSpacing: 14
        rowSpacing: 14

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 290
            radius: 15
            color: root.surface
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 9
                Label { text: "Capa do Fastfetch"; color: root.ink; font.pixelSize: 15 }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Appearance.m3colors.m3surfaceContainerLow
                    radius: 12
                    clip: true
                    Image {
                        anchors.fill: parent
                        source: root.coverDraft ? "file://" + root.coverDraft : ""
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: false
                        visible: status === Image.Ready
                    }
                    Label {
                        anchors.centerIn: parent
                        text: "Nenhuma capa selecionada"
                        color: Appearance.colors.colOnSurfaceVariant
                        visible: root.coverDraft.length === 0
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    TextField { id: coverField; Layout.fillWidth: true; text: root.coverDraft; placeholderText: "Caminho da capa (.png/.webp/.jpg)"; onTextEdited: root.coverDraft = text }
                    Button { text: "Escolher"; onClicked: coverDialog.open() }
                    Button { text: "Limpar"; onClicked: root.coverDraft = "" }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 290
            radius: 15
            color: root.surface
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10
                Label { text: "Prévia do Kitty"; color: root.ink; font.pixelSize: 15 }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 10
                    color: root.colorDraft.background || "#160E12"
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 6
                        Label { text: "pedro@Archlinux ~> fastfetch"; color: root.colorDraft.foreground || "white"; font.family: "monospace"; font.pixelSize: 14 }
                        Label { text: "󰣇  Arch Linux  ·  Hyprland"; color: root.colorDraft.color1 || root.accent; font.family: "monospace"; font.pixelSize: 15 }
                        Label { text: "CPU Ryzen 5 5600   GPU RX 7600"; color: root.colorDraft.foreground || "white"; font.family: "monospace"; font.pixelSize: 12 }
                        Label { text: "█ █ █ █ █ █ █ █"; color: root.colorDraft.color5 || "#D94F69"; font.family: "monospace"; font.pixelSize: 14 }
                    }
                }
                TextField { id: themeName; Layout.fillWidth: true; text: root.nameDraft; placeholderText: "Nome de exibição do tema"; onTextEdited: root.nameDraft = text }
            }
        }
    }

    Label { text: "Cores personalizadas"; color: root.ink; font.pixelSize: 16; font.bold: true }
    Label { text: "Passe o mouse sobre uma cor para ver sua função. As cores ANSI dependem do aplicativo; use #RRGGBB."; color: Appearance.colors.colOnSurfaceVariant; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }

    GridLayout {
        Layout.fillWidth: true
        columns: root.width > 860 ? 3 : (root.width > 560 ? 2 : 1)
        columnSpacing: 10
        rowSpacing: 9
        Repeater {
            model: root.fields
            delegate: RowLayout {
                Layout.fillWidth: true
                spacing: 8
                // END4_TERMINAL_COLOR_TOOLTIPS_V1
                ToolTip.text: root.colorHint(modelData[0])
                ToolTip.delay: 450
                ToolTip.timeout: 10000
                ToolTip.visible: colorHintHover.hovered && !colorHexField.activeFocus
                HoverHandler {
                    id: colorHintHover
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                }
                Rectangle {
                    Layout.preferredWidth: 23; Layout.preferredHeight: 23; radius: 6
                    color: root.colorDraft[modelData[0]] || "#FFFFFF"
                    border.width: 1; border.color: Appearance.colors.colOutlineVariant
                }
                Label { Layout.preferredWidth: 102; text: modelData[1]; color: root.ink; font.pixelSize: 12 }
                ToolButton {
                    text: "◉"
                    onClicked: {
                        colorPicker.targetKey = modelData[0]
                        colorPicker.selectedColor = root.colorDraft[modelData[0]] || "#FFFFFF"
                        colorPicker.open()
                    }
                }
                TextField {
                    id: colorHexField
                    Layout.fillWidth: true
                    text: root.colorDraft[modelData[0]] || ""
                    maximumLength: 7
                    placeholderText: "#RRGGBB"
                    onTextEdited: {
                        var copy = Object.assign({}, root.colorDraft)
                        copy[modelData[0]] = text
                        root.colorDraft = copy
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Button {
            text: root.gerandoPaleta ? "Gerando..." : "Gerar automaticamente"
            enabled: !root.busy && !root.gerandoPaleta && root.chosenIndex >= 0
            onClicked: root.gerarCoresAutomaticamente()
            ToolTip.visible: hovered
            ToolTip.text: "Gera as 21 cores do Kitty a partir da capa do Fastfetch. Não salva automaticamente."
        }
        Button {
            text: root.busy ? "Processando..." : "Salvar e aplicar tema"
            enabled: !root.busy && root.chosenIndex >= 0
            onClicked: root.saveProfile()
        }
        Button {
            text: "Aplicar cores salvas"
            enabled: !root.busy && root.chosenIndex >= 0
            onClicked: root.callBackend(["apply", root.selectedId()], function(out) {
                if (!out || !out.ok) { root.info = out && out.error ? out.error : "Erro ao aplicar"; return }
                root.info = out.warning || "Tema aplicado!"
                Qt.callLater(function() { root.refresh(out.active) })
            })
        }
        Item { Layout.fillWidth: true }
    }
    Label {
        text: root.info || "A seleção não altera o tema do desktop. Seu kitty.conf, Fish e Fastfetch originais serão preservados."
        color: root.info ? "#F2A5B8" : "#BDADB4"
        font.pixelSize: 12
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
}
