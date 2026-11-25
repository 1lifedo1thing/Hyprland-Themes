import QtQuick
import "Appearance.js" as Appearance

// HYPR_ENDFIELD_HARDWARE_STAGE15 — painel somente leitura.
// HYPR_ENDFIELD_BRIDGE_STAGE18A — mantém o sinal da ponte Quickshell.
// HYPR_ENDFIELD_SETTINGS_HUB_20A — mantém o atalho da página de configurações.
// HYPR_ENDFIELD_HARDWARE_COMPACT_20B — redesenho compacto, sem alterar controladores.
Item {
    id: overview
    signal openSettings()
    signal openThemes()

    readonly property var snapshot: hardwareController.state
    readonly property real outerPad: 3
    readonly property real gap: 9
    readonly property real cardWidth: (width - 2 * outerPad - gap) / 2
    readonly property color accentColor: Appearance.accent("#FFFA00")

    onVisibleChanged: if (visible) hardwareController.refresh()
    Component.onCompleted: if (visible) hardwareController.refresh()

    // Os dados continuam vindo do hardwareController original: nenhum valor é inventado.
    readonly property var entries: [
        { label: "CPU", number: "01", value: snapshot.cpu || "—", detail: snapshot.cpuDetails || "" },
        { label: "GPU", number: "02", value: snapshot.gpu || "—", detail: snapshot.gpuDetails || "" },
        { label: qsTr("PLACA-MÃE"), number: "03", value: snapshot.board || "—", detail: snapshot.boardDetails || "" },
        { label: "RAM", number: "04", value: snapshot.memory || "—", detail: snapshot.memoryDetails || "" },
        { label: qsTr("ARMAZENAMENTO"), number: "05", value: snapshot.storage || "—", detail: snapshot.storageDetails || "" },
        { label: qsTr("SISTEMA"), number: "06", value: snapshot.system || "—", detail: snapshot.systemDetails || "" }
    ]

    // Cabeçalho contido: não disputa espaço com o SettingsHeader do HUD.
    Rectangle {
        x: overview.outerPad; y: 6; width: 3; height: 23
        color: overview.accentColor
    }
    Text {
        x: 15; y: 2; width: 275; height: 21
        text: qsTr("HARDWARE  /  INVENTÁRIO")
        color: Appearance.tone("#EEEEEE")
        font.family: harmonyBold.name; font.pixelSize: 13; font.letterSpacing: 1.05
        renderType: Text.CurveRendering
    }
    Text {
        x: 15; y: 21; width: 290; height: 14
        text: qsTr("SISTEMA LOCAL  ·  SOMENTE LEITURA")
        color: Appearance.tone("#8E8E8E")
        font.family: harmonyRegular.name; font.pixelSize: 9; font.letterSpacing: 0.5
        renderType: Text.CurveRendering
    }
    CalendarButton {
        x: overview.width - 180; y: 2; width: 142; height: 30
        title: qsTr("CONFIGURAÇÕES"); kind: "secondary"
        onClicked: overview.openSettings()
    }
    CalendarButton {
        x: overview.width - 33; y: 2; width: 30; height: 30
        glyph: "↻"; kind: "icon"
        enabled: !overview.snapshot.loading
        onClicked: hardwareController.refresh()
    }
    Rectangle {
        x: overview.outerPad; y: 38; width: overview.width - overview.outerPad * 2; height: 1
        color: Appearance.tone("#454545")
    }

    Repeater {
        model: overview.entries
        Rectangle {
            id: card
            required property int index
            required property var modelData
            readonly property bool hero: index < 2
            x: overview.outerPad + (index % 2) * (overview.cardWidth + overview.gap)
            y: hero ? 48 : 166 + Math.floor((index - 2) / 2) * 94
            width: overview.cardWidth
            height: hero ? 108 : 84
            radius: 3
            clip: true
            color: Appearance.tone("#1B1C1E")
            border.color: Appearance.tone("#48494B")
            border.width: 1

            // Traço angular Endfield: detalhe visual sem degradar legibilidade.
            Rectangle { x: 0; y: 0; width: card.hero ? 57 : 38; height: 2; color: overview.accentColor }
            Rectangle { x: 0; y: 0; width: 2; height: card.hero ? 29 : 19; color: overview.accentColor }
            Rectangle { x: card.width - 20; y: 0; width: 20; height: 1; color: overview.accentColor; opacity: 0.5 }

            Text {
                x: 13; y: 11; width: card.width - 68; height: 17
                text: card.modelData.label
                color: overview.accentColor
                font.family: harmonyBold.name; font.pixelSize: card.hero ? 11 : 10
                font.letterSpacing: 1.35; renderType: Text.CurveRendering
            }
            Text {
                x: card.width - 36; y: 11; width: 23; height: 17
                text: card.modelData.number
                color: Appearance.tone("#68696D")
                font.family: harmonyMedium.name; font.pixelSize: 10
                horizontalAlignment: Text.AlignRight
                renderType: Text.CurveRendering
            }
            Rectangle {
                x: 13; y: 30; width: card.width - 26; height: 1
                color: Appearance.tone("#3A3B3E")
            }
            Text {
                id: primaryValue
                x: 13; y: card.hero ? 38 : 38
                width: card.width - 26
                height: card.hero ? 43 : 24
                text: card.modelData.value
                color: Appearance.tone("#F1F2F3")
                font.family: harmonyBold.name
                font.pixelSize: card.hero ? 15 : 16
                font.letterSpacing: card.hero ? 0.08 : 0
                wrapMode: card.hero ? Text.Wrap : Text.NoWrap
                maximumLineCount: card.hero ? 2 : 1
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                renderType: Text.CurveRendering
            }
            Text {
                x: 13; y: card.hero ? 85 : 63
                width: card.width - 27; height: 15
                text: card.modelData.detail
                color: Appearance.tone("#949599")
                elide: Text.ElideRight
                font.family: harmonyRegular.name; font.pixelSize: 10
                renderType: Text.CurveRendering
            }
            Rectangle {
                x: card.width - 40; y: card.height - 4
                width: 27; height: 1; color: overview.accentColor; opacity: 0.68
            }
        }
    }

    // Um rodapé simples, em vez de mais um bloco grande de configurações.
    Rectangle {
        x: overview.outerPad; y: 357; width: overview.width - overview.outerPad * 2; height: 1
        color: Appearance.tone("#454545")
    }
    Rectangle {
        x: overview.outerPad; y: 379; width: 27; height: 3
        color: overview.accentColor
    }
    Text {
        x: 38; y: 372; width: overview.width - 252; height: 24
        text: overview.snapshot.loading
            ? qsTr("ATUALIZANDO DADOS DO HARDWARE…")
            : qsTr("ARCH LINUX  /  INVENTÁRIO SEM ROOT")
        color: Appearance.tone("#9C9DA0")
        font.family: harmonyMedium.name; font.pixelSize: 10
        font.letterSpacing: 0.35; elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
        renderType: Text.CurveRendering
    }
    Rectangle {
        id: quickshellButton
        x: overview.width - 206; y: 367; width: 203; height: 32
        color: overview.accentColor
        radius: 2
        Rectangle { x: 0; y: 0; width: 4; height: parent.height; color: Appearance.tone("#F1F1F1"); opacity: 0.65 }
        Text {
            anchors.centerIn: parent
            text: qsTr("CONFIG. QUICKSHELL") + "  ›"
            color: "#171719"
            font.family: harmonyBold.name; font.pixelSize: 11
            font.letterSpacing: 0.45
            renderType: Text.CurveRendering
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: overview.openThemes()
        }
    }
}
