import QtQuick
import "Appearance.js" as Appearance

// HYPR_ENDFIELD_BRIDGE_STAGE18A — primeira página do bridge; respeita a paleta do HUD.
Item {
    id: root
    readonly property var bridge: quickshellBridge.state
    onVisibleChanged: if (visible) quickshellBridge.refresh()
    Component.onCompleted: if (visible) quickshellBridge.refresh()

    Text {
        x: 4; y: 4; width: 430; height: 22
        text: qsTr("TEMAS DO QUICKSHELL")
        color: Appearance.tone("#F4F4F4")
        font.family: harmonyBold.name
        font.pixelSize: 16; font.letterSpacing: 1
        renderType: Text.CurveRendering
    }
    CalendarButton {
        x: 480; y: 0; width: 106; height: 29
        title: qsTr("ATUALIZAR"); kind: "secondary"
        onClicked: quickshellBridge.refresh()
    }
    Text {
        x: 4; y: 34; width: 574; height: 18
        text: root.bridge.available ? qsTr("TEMA ATIVO: ") + (root.bridge.scheme || "Material")
                                    : qsTr("CONFIGURAÇÃO DO QUICKSHELL INDISPONÍVEL")
        color: Appearance.accent("#FFFA00")
        font.family: harmonyMedium.name; font.pixelSize: 12
        renderType: Text.CurveRendering
    }
    Text {
        x: 4; y: 55; width: 574; height: 18
        text: qsTr("FUNDO: ") + (root.bridge.wallpaper || "—")
        elide: Text.ElideMiddle
        color: Appearance.tone("#8A8A8A")
        font.family: harmonyRegular.name; font.pixelSize: 11
        renderType: Text.CurveRendering
    }
    Rectangle { x: 0; y: 81; width: 590; height: 1; color: Appearance.tone("#4A4A4A") }
    Flickable {
        x: 0; y: 90; width: 590; height: 294
        clip: true
        contentHeight: choices.implicitHeight + 8
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: choices
            width: 578; spacing: 6
            Repeater {
                model: root.bridge.schemes || []
                Rectangle {
                    id: entry
                    required property var modelData
                    readonly property bool current: root.bridge.scheme === modelData.id
                    width: 578; height: 42
                    color: current ? Appearance.tone("#353535") : Appearance.tone("#1D1D1D")
                    border.color: current ? Appearance.accent("#FFFA00") : Appearance.tone("#3E3E3E")
                    Rectangle {
                        x: 8; y: 13; width: 3; height: 16
                        color: current ? Appearance.accent("#FFFA00") : Appearance.tone("#737373")
                    }
                    Text {
                        x: 20; y: 0; height: parent.height; width: 440
                        verticalAlignment: Text.AlignVCenter
                        text: modelData.name
                        color: Appearance.tone("#F4F4F4")
                        elide: Text.ElideRight
                        font.family: harmonyMedium.name; font.pixelSize: 14
                        renderType: Text.CurveRendering
                    }
                    Text {
                        x: 473; y: 0; height: parent.height; width: 88
                        verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignRight
                        text: current ? qsTr("ATIVO") : qsTr("APLICAR")
                        color: Appearance.accent("#FFFA00")
                        font.family: harmonyBold.name; font.pixelSize: 11
                        renderType: Text.CurveRendering
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !root.bridge.busy && root.bridge.available
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (!entry.current) quickshellBridge.setScheme(entry.modelData.id)
                    }
                }
            }
        }
    }
    Text {
        x: 3; y: 392; width: 578; height: 27
        text: root.bridge.notice || qsTr("A alteração é feita pelo serviço ColorSchemes do Quickshell.")
        color: Appearance.tone("#8A8A8A")
        font.family: harmonyRegular.name; font.pixelSize: 11
        wrapMode: Text.WordWrap; renderType: Text.CurveRendering
    }
}
