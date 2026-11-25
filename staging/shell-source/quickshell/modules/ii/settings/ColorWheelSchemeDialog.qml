import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    signal closed()
    // END4_SCHEME_SAVE_COLORS_V1
    property string editSchemeId: ""

    function populateForm() {
        root.activeSlot = 0
        root.statusMessage = ""
        if (root.editSchemeId === "") {
            schemeName.text = ""
            root.chosenColors = ["#e87559", "#80a8e7", "#b585dc"]
            return
        }
        const data = ColorSchemes.schemes[root.editSchemeId]
        if (!data) {
            root.statusMessage = "Tema não encontrado."
            return
        }
        schemeName.text = data.name
        const mode = Appearance.m3colors.darkmode ? "dark" : "light"
        const accents = data.accents[mode]
        root.chosenColors = [
            accents[ColorSchemes.currentAccent("primary")] ?? "#e87559",
            accents[ColorSchemes.currentAccent("secondary")] ?? "#80a8e7",
            accents[data.defaults.tertiary] ?? "#b585dc"
        ]
    }
    onVisibleChanged: { if (visible) Qt.callLater(root.populateForm) }

    anchors.fill: parent
    z: 999
    property int activeSlot: 0
    property var chosenColors: ["#e87559", "#80a8e7", "#b585dc"]
    property string statusMessage: ""
    property bool saving: false
    readonly property var slotLabels: ["Primária", "Secundária", "Terciária"]
    readonly property real wheelRadius: wheel.width / 2 - 4

    function clamp(n) { return Math.max(0, Math.min(1, n)) }
    function toHex(n) { return Math.round(clamp(n) * 255).toString(16).padStart(2, "0") }
    function hsvToHex(h, s, v) {
        h = (h % 1 + 1) % 1
        const i = Math.floor(h * 6)
        const f = h * 6 - i
        const p = v * (1 - s), q = v * (1 - f * s), t = v * (1 - (1 - f) * s)
        const parts = [[v,t,p],[q,v,p],[p,v,t],[p,q,v],[t,p,v],[v,p,q]][i % 6]
        return "#" + root.toHex(parts[0]) + root.toHex(parts[1]) + root.toHex(parts[2])
    }
    function hexToHsv(value) {
        const raw = String(value).replace("#", "")
        if (!/^[a-fA-F0-9]{6}$/.test(raw)) return {h:0,s:0,v:1}
        const r = parseInt(raw.slice(0,2),16)/255
        const g = parseInt(raw.slice(2,4),16)/255
        const b = parseInt(raw.slice(4,6),16)/255
        const hi = Math.max(r,g,b), lo = Math.min(r,g,b), d = hi - lo
        let h = 0
        if (d) {
            if (hi === r) h = ((g-b)/d) % 6
            else if (hi === g) h = (b-r)/d + 2
            else h = (r-g)/d + 4
            h = (h / 6 + 1) % 1
        }
        return {h:h, s:hi === 0 ? 0 : d / hi, v:hi}
    }
    function setColor(slot, color) {
        const update = root.chosenColors.slice()
        update[slot] = color
        root.chosenColors = update
    }
    function chooseAt(x,y) {
        const dx = x - wheel.width/2, dy = y - wheel.height/2
        const dist = Math.sqrt(dx*dx+dy*dy)
        const sat = root.clamp(dist / root.wheelRadius)
        const hue = ((Math.atan2(dy,dx) / (Math.PI * 2)) + 1) % 1
        const old = root.hexToHsv(root.chosenColors[root.activeSlot])
        root.setColor(root.activeSlot, root.hsvToHex(hue,sat,old.v))
    }
    function markerX(color) {
        const hsv = root.hexToHsv(color)
        return wheel.width/2 + Math.cos(hsv.h*Math.PI*2)*hsv.s*root.wheelRadius-9
    }
    function markerY(color) {
        const hsv = root.hexToHsv(color)
        return wheel.height/2 + Math.sin(hsv.h*Math.PI*2)*hsv.s*root.wheelRadius-9
    }
    function save() {
        if (root.saving) return
        const name = schemeName.text.trim()
        if (!name) { root.statusMessage = "Digite um nome para o tema."; return }
        root.statusMessage = "Criando tema..."
        root.saving = true
        if (root.editSchemeId !== "") {
            saveProcess.command = ["python3", Quickshell.shellPath("scripts/colors/save_theme_colors.py"),
                "--edit-colors", "--scheme", root.editSchemeId,
                "--primary", root.chosenColors[0], "--secondary", root.chosenColors[1],
                "--tertiary", root.chosenColors[2],
                "--source-mode", Appearance.m3colors.darkmode ? "dark" : "light"]
        } else {
            saveProcess.command = ["python3", Quickshell.shellPath("scripts/colors/create_custom_scheme.py"),
                "--name", name, "--primary", root.chosenColors[0],
                "--secondary", root.chosenColors[1], "--tertiary", root.chosenColors[2]]
        }
        saveProcess.running = true
    }

    Process {
        id: saveProcess
        stdout: StdioCollector { id: saveOutput }
        stderr: StdioCollector { id: saveError }
        onExited: code => {
            root.saving = false
            if (code === 0) {
                const schemeId = saveOutput.text.trim()
                if (schemeId.length > 0) {
                    ColorSchemes.reload()
                    if (root.editSchemeId !== "") {
                        ColorSchemes.run(["--scheme-name", schemeId,
                            "--scheme-primary", "custom_primary",
                            "--scheme-secondary", "custom_secondary"], false)
                    } else {
                        ColorSchemes.setScheme(schemeId, false)
                    }
                    root.statusMessage = root.editSchemeId !== "" ? "Cores salvas no tema." : "Tema " + schemeId + " criado e selecionado."
                    // END4_AUTO_BIND_SCHEME_V1: ao criar/editar, vincula o wallpaper atual.
                    Quickshell.execDetached(["python3", Quickshell.shellPath("scripts/colors/bind_scheme_wallpaper.py"), "--bind", schemeId])
                    root.closed()
                } else root.statusMessage = "Não foi possível identificar o novo tema."
            } else {
                root.statusMessage = saveError.text.trim() || "Falha ao criar o tema."
            }
        }
    }

    Rectangle { anchors.fill: parent; color: "#db000000" }
    MouseArea { anchors.fill: parent; onClicked: root.closed() }

    Rectangle {
        id: modal
        anchors.centerIn: parent
        width: Math.min(760, parent.width-28)
        height: Math.min(570, parent.height-24)
        radius: 24
        // Sempre opaco, mesmo com UI glass/transparência ativa.
        color: Qt.rgba(Appearance.colors.colLayer1.r,
                       Appearance.colors.colLayer1.g,
                       Appearance.colors.colLayer1.b, 1.0)
        border.width: 1
        border.color: Appearance.colors.colOutlineVariant
        clip: true

        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    text: root.editSchemeId === "" ? "Criar tema · roda de cores" : "Editar cores do tema · " + root.editSchemeId
                    color: Appearance.colors.colOnLayer1
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.DemiBold
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    implicitWidth: 33; implicitHeight: 33; radius: 16
                    color: Appearance.colors.colSecondaryContainer
                    MaterialSymbol { anchors.centerIn: parent; text: "close"; iconSize: 19 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.closed() }
                }
            }

            TextField {
                id: schemeName
                Layout.fillWidth: true
                placeholderText: "Nome do novo tema (ex.: Sakura)"
                readOnly: root.editSchemeId !== ""
                font.pixelSize: 15
                color: Appearance.colors.colOnLayer1
                selectByMouse: true
                background: Rectangle { radius: 10; color: Appearance.colors.colSecondaryContainer }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 20

                // END4_COLOR_WHEEL_LAYOUT_FIX_V1 — textura nítida e responsiva.
                Item {
                    id: wheelArea
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 280
                    Layout.minimumWidth: 155
                    Layout.minimumHeight: 155

                    Item {
                        id: wheel
                        anchors.centerIn: parent
                        width: Math.max(0, Math.min(parent.width - 8, parent.height - 8, 304))
                        height: width

                        Image {
                            anchors.fill: parent
                            source: Qt.resolvedUrl("ColorWheelSpectrum.png")
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                            cache: true
                        }

                        Repeater {
                            model: 3
                            delegate: Rectangle {
                                required property int index
                                x: root.markerX(root.chosenColors[index])
                                y: root.markerY(root.chosenColors[index])
                                width: 18
                                height: 18
                                radius: 9
                                color: root.chosenColors[index]
                                border.color: index === root.activeSlot ? "#ffffff" : "#252525"
                                border.width: index === root.activeSlot ? 3 : 2
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.CrossCursor
                            onPressed: mouse => root.chooseAt(mouse.x, mouse.y)
                            onPositionChanged: mouse => {
                                if (pressed) root.chooseAt(mouse.x, mouse.y)
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10
                    StyledText {
                        text: "Selecione qual cor deseja editar"
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                        wrapMode: Text.WordWrap
                    }
                    Repeater {
                        model: 3
                        delegate: Rectangle {
                            required property int index
                            Layout.fillWidth: true
                            implicitHeight: 44
                            radius: 12
                            color: root.activeSlot === index ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer0
                            border.width: root.activeSlot === index ? 2 : 0
                            border.color: Appearance.colors.colPrimary
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                Rectangle { implicitWidth: 25; implicitHeight: 25; radius: 13; color: root.chosenColors[index] }
                                StyledText { text: root.slotLabels[index]; color: Appearance.colors.colOnLayer1; font.pixelSize: Appearance.font.pixelSize.small }
                                Item { Layout.fillWidth: true }
                                StyledText { text: root.chosenColors[index].toUpperCase(); color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smaller }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.activeSlot = index }
                        }
                    }
                    // END4_COLOR_WHEEL_HEX_V14 - Digitar HEX edita a cor do slot ativo.
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        spacing: 10

                        StyledText {
                            text: "HEX"
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnLayer1
                        }

                        TextField {
                            id: hexInput
                            Layout.fillWidth: true
                            Layout.minimumWidth: 90
                            Layout.preferredHeight: 40
                            leftPadding: 12
                            rightPadding: 12
                            selectByMouse: true
                            maximumLength: 7
                            inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                            font.family: Appearance.font.family.monospace
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer1
                            selectionColor: Appearance.colors.colPrimary
                            selectedTextColor: Appearance.colors.colOnPrimary
                            placeholderText: "#BB3024"
                            text: String(root.chosenColors[root.activeSlot]).toUpperCase()
                            property bool updatingFromInput: false
                            readonly property bool validHex: /^#?[0-9a-fA-F]{6}$/.test(text.trim())

                            onTextEdited: {
                                if (!validHex) return
                                const chosen = "#" + text.trim().replace(/^#/, "").toUpperCase()
                                updatingFromInput = true
                                root.setColor(root.activeSlot, chosen)
                                updatingFromInput = false
                                root.statusMessage = ""
                            }
                            onEditingFinished: {
                                if (!validHex) {
                                    root.statusMessage = "HEX inválido. Digite 6 dígitos, por exemplo #BB3024."
                                }
                                text = String(root.chosenColors[root.activeSlot]).toUpperCase()
                            }

                            background: Rectangle {
                                radius: 10
                                color: Appearance.colors.colSecondaryContainer
                                border.width: 1
                                border.color: hexInput.validHex ? Appearance.colors.colOutlineVariant : Appearance.colors.colError
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 9
                            color: root.chosenColors[root.activeSlot]
                            border.width: 1
                            border.color: Appearance.colors.colOutlineVariant
                        }

                        Connections {
                            target: root
                            function onActiveSlotChanged() {
                                hexInput.text = String(root.chosenColors[root.activeSlot]).toUpperCase()
                            }
                            function onChosenColorsChanged() {
                                if (!hexInput.updatingFromInput)
                                    hexInput.text = String(root.chosenColors[root.activeSlot]).toUpperCase()
                            }
                        }
                    }

                    StyledText { text: "Brilho da cor selecionada"; color: Appearance.colors.colOnLayer1; font.pixelSize: Appearance.font.pixelSize.small }
                    Slider {
                        Layout.fillWidth: true
                        from: 0.08; to: 1.0
                        value: root.hexToHsv(root.chosenColors[root.activeSlot]).v
                        onMoved: {
                            const hsv=root.hexToHsv(root.chosenColors[root.activeSlot])
                            root.setColor(root.activeSlot,root.hsvToHex(hsv.h,hsv.s,value))
                        }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: "Arraste na roda para escolher o tom; o centro reduz a saturação. Cores claras e escuras do sistema serão geradas automaticamente."
                        wrapMode: Text.WordWrap
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                    Item { Layout.fillHeight: true }
                }
            }

            StyledText {
                text: root.statusMessage
                visible: root.statusMessage.length > 0
                color: Appearance.colors.colPrimary
                font.pixelSize: Appearance.font.pixelSize.small
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Rectangle {
                    Layout.preferredWidth: 130; implicitHeight: 38; radius: 18
                    color: Appearance.colors.colSecondaryContainer
                    StyledText { anchors.centerIn: parent; text: "Importar JSON"; color: Appearance.colors.colOnSecondaryContainer; font.pixelSize: Appearance.font.pixelSize.small }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { root.closed(); ColorSchemes.addScheme() }
                    }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    Layout.preferredWidth: 105; implicitHeight: 38; radius: 18
                    color: Appearance.colors.colSecondaryContainer
                    StyledText { anchors.centerIn: parent; text: "Cancelar"; color: Appearance.colors.colOnSecondaryContainer }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.closed() }
                }
                Rectangle {
                    Layout.preferredWidth: 155; implicitHeight: 38; radius: 18
                    color: root.saving ? Appearance.colors.colSecondaryContainer : Appearance.colors.colPrimary
                    StyledText { anchors.centerIn: parent; text: root.saving ? "Salvando..." : (root.editSchemeId === "" ? "Criar e aplicar" : "Salvar cores no tema"); color: root.saving ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnPrimary }
                    MouseArea { anchors.fill: parent; enabled: !root.saving; cursorShape: Qt.PointingHandCursor; onClicked: root.save() }
                }
            }
        }
    }
}
