import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// END4_CONTRAST_UI_V11_ROUNDED
// END4_CONTRAST_CARD_EDGE_V12
// Base estável V8. Retém o limite de largura de 374px:
// V9 removia o limite e fazia controles ultrapassarem o viewport.
// Apenas pequenos ajustes visuais; não modifica o serviço ThemeContrast.
Rectangle {
    id: root

    radius: 14
    clip: true
    // O card do dashboard pode ultrapassar a parte visivel do viewport.
    // Fundo fica limitado aos controles e usa uma moldura arredondada propria.
    color: "transparent"
    border.width: 0
    implicitHeight: controls.implicitHeight + 18

    // Não use root.width-24 puro: a área do dashboard pode ter uma parte fora da tela.
    // A V8 provou que o teto de 374px mantém todos os controles visíveis.
    readonly property real usableWidth: Math.max(0, Math.min(root.width - 24, 374))
    readonly property color surface: Appearance.m3colors.m3surfaceContainerHigh
    readonly property color accent: Appearance.m3colors.m3primary

    function brightness(c) {
        const v = Qt.color(c)
        function linear(x) { return x <= 0.04045 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(v.r) + 0.7152 * linear(v.g) + 0.0722 * linear(v.b)
    }
    readonly property color foreground: brightness(surface) > 0.179 ? "#211b26" : "#faf6ff"
    readonly property color secondaryText: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.82)
    readonly property color subtleSurface: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.10)
    readonly property color stroke: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.22)
    readonly property color accentText: brightness(accent) > 0.179 ? "#211b26" : "#ffffff"

    Rectangle {
        id: roundedCardSurface
        x: 0
        y: 0
        width: Math.max(0, Math.min(root.width, root.usableWidth + 24))
        height: root.height
        radius: root.radius
        antialiasing: true
        color: root.surface
        border.width: 1
        border.color: root.stroke
    }

    Column {
        id: controls
        x: 12
        y: 9
        width: root.usableWidth
        spacing: 4

        Item {
            width: parent.width
            height: 21
            MaterialSymbol {
                x: 0
                anchors.verticalCenter: parent.verticalCenter
                text: "contrast"
                iconSize: 18
                color: root.accent
            }
            StyledText {
                x: 24
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, parent.width - 24)
                text: "Contraste do tema"
                color: root.foreground
                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }

        Rectangle {
            id: autoControl
            width: parent.width
            height: 37
            radius: 10
            color: root.subtleSurface

            MaterialSymbol {
                x: 9
                anchors.verticalCenter: parent.verticalCenter
                text: "auto_awesome"
                iconSize: 18
                color: root.accent
            }
            StyledText {
                x: 35
                y: 3
                width: Math.max(0, parent.width - 103)
                height: 17
                text: "Automático"
                color: root.foreground
                font.pixelSize: 12
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
            StyledText {
                x: 35
                y: 21
                width: Math.max(0, parent.width - 103)
                height: 14
                text: "Contraste conforme o wallpaper"
                color: root.secondaryText
                font.pixelSize: 10
                elide: Text.ElideRight
            }
            Rectangle {
                width: 39
                height: 22
                radius: 11
                anchors.right: parent.right
                anchors.rightMargin: 9
                anchors.verticalCenter: parent.verticalCenter
                color: ThemeContrast.automatic ? root.accent : root.stroke
                Rectangle {
                    x: ThemeContrast.automatic ? parent.width - width - 3 : 3
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    radius: 8
                    color: ThemeContrast.automatic ? root.accentText : root.foreground
                    Behavior on x { NumberAnimation { duration: 140 } }
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: ThemeContrast.setValue("automatic", !ThemeContrast.automatic)
            }
        }

        Item {
            width: parent.width
            height: 16
            StyledText {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Ajuste manual"
                font.pixelSize: 11
                color: root.secondaryText
            }
            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, parent.width - 102)
                height: 1
                color: root.stroke
            }
        }

        Item {
            id: presets
            width: parent.width
            height: 28
            readonly property real gap: 5
            readonly property real tileWidth: Math.max(0, (width - 2 * gap) / 3)

            Repeater {
                model: [
                    { label: "Suave", value: "suave" },
                    { label: "Médio", value: "medio" },
                    { label: "Forte", value: "forte" }
                ]
                delegate: Rectangle {
                    id: tile
                    required property int index
                    required property var modelData
                    readonly property bool selected: !ThemeContrast.automatic && ThemeContrast.preset === modelData.value
                    x: index * (presets.tileWidth + presets.gap)
                    y: 0
                    width: presets.tileWidth
                    height: presets.height
                    radius: 14
                    color: selected ? root.accent : root.subtleSurface
                    border.width: selected ? 0 : 1
                    border.color: root.stroke
                    StyledText {
                        anchors.fill: parent
                        text: tile.modelData.label
                        color: tile.selected ? root.accentText : root.foreground
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ThemeContrast.setValue("preset", tile.modelData.value)
                    }
                }
            }
        }

        // Dois sliders compactos, com rótulo e porcentagem na mesma linha.
        // Um Repeater direto dentro da Column evita tipos QML locais não resolvidos.
        Repeater {
            model: [
                { caption: "Opacidade dos cards", glyph: "layers", field: "opacity", minimum: 35 },
                { caption: "Texto / ícones", glyph: "format_color_text", field: "text", minimum: 0 }
            ]
            delegate: Item {
                id: control
                required property var modelData
                readonly property real minimum: modelData.minimum
                readonly property real amount: modelData.field === "opacity"
                    ? (ThemeContrast.automatic ? ThemeContrast.effectiveOpacity : ThemeContrast.manualOpacity)
                    : (ThemeContrast.automatic ? Math.round(ThemeContrast.textStrength * 100) : ThemeContrast.manualText)
                readonly property real fraction: Math.max(0, Math.min(1, (amount - minimum) / (100 - minimum)))
                width: parent.width
                height: 31

                function updateAt(xInRow) {
                    if (track.width <= 0) return
                    const progress = Math.max(0, Math.min(1, (xInRow - track.x) / track.width))
                    ThemeContrast.setValue(modelData.field, Math.round(minimum + progress * (100 - minimum)))
                }

                MaterialSymbol {
                    x: 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: control.modelData.glyph
                    iconSize: 15
                    color: root.accent
                }
                StyledText {
                    x: 20
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, track.x - x - 7)
                    color: root.foreground
                    font.pixelSize: 10
                    text: control.modelData.caption
                    elide: Text.ElideRight
                }
                Rectangle {
                    id: track
                    x: Math.max(104, Math.min(152, control.width * 0.44))
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, control.width - x - 40)
                    // Trilha inteira em formato de cápsula: ambas as pontas arredondadas.
                    height: 6
                    radius: height / 2
                    antialiasing: true
                    clip: true
                    color: root.stroke
                    Rectangle {
                        // Mantém a extremidade preenchida oculta sob o marcador circular.
                        // Evita a pontinha reta/intervalo visual ao lado do marcador.
                        width: control.fraction <= 0 ? 0 : Math.min(parent.width, parent.width * control.fraction + 3)
                        height: parent.height
                        radius: Math.min(height / 2, width / 2)
                        antialiasing: true
                        visible: control.fraction > 0
                        color: root.accent
                    }
                }
                Rectangle {
                    x: track.x + track.width * control.fraction - width / 2
                    anchors.verticalCenter: track.verticalCenter
                    width: 14
                    height: 14
                    radius: 7
                    color: root.accent
                    border.width: 2
                    border.color: root.surface
                }
                StyledText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(control.amount) + "%"
                    font.pixelSize: 10
                    color: root.foreground
                }
                MouseArea {
                    id: touch
                    x: Math.max(0, track.x - 8)
                    y: 0
                    width: Math.max(0, Math.min(control.width - x, track.width + 16))
                    height: parent.height
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => control.updateAt(mouse.x + touch.x)
                    onPositionChanged: mouse => {
                        if (pressed) control.updateAt(mouse.x + touch.x)
                    }
                }
            }
        }
    }
}
