import QtQuick
import "Appearance.js" as Appearance

// EndfieldHUD TelemetryCanvases.swift: StorageCanvas (81/189/233/304px).
Item {
    id: page
    width: 590; height: 510
    property bool presented: false
    property bool details: false
    readonly property var inspection: storageController.analysis
    function byteLabel(bytes) {
        const n = Number(bytes || 0);
        if (n >= 1e12) return (n / 1e12).toFixed(2) + " TB";
        if (n >= 1e9) return (n / 1e9).toFixed(2) + " GB";
        if (n >= 1e6) return (n / 1e6).toFixed(1) + " MB";
        if (n >= 1e3) return (n / 1e3).toFixed(0) + " KB";
        return n + " B";
    }
    readonly property var reading: storageController.state
    readonly property var volume: reading.volume
    readonly property bool ready: volume.total > 0
    function amount(bytes) { return bytes >= 1e12 ? (bytes / 1e12).toFixed(2) : (bytes / 1e9).toFixed(1) }
    function unit(bytes) { return bytes >= 1e12 ? "TB" : "GB" }
    onPresentedChanged: storageController.active = presented
    Component.onDestruction: storageController.active = false
    SettingsHeader { title: qsTr("存储空间"); english: "STORAGE"; code: "SYS-10"; count: page.ready ? Math.round(page.volume.fraction * 100) + "%" : "—" }
    CalendarButton { x: 556; y: 22; width: 30; height: 30; kind: "icon"; glyph: "↻"; onClicked: storageController.refresh() }
    CalendarButton { x: 406; y: 24; width: 140; height: 26; kind: "secondary"; title: (page.volume.name || qsTr("启动磁盘")) + " ▾"; onClicked: volumes.visible = !volumes.visible }
    Text { y: 81; text: qsTr("可用"); color: Appearance.tone("#8A8A8A"); font.family: harmonyRegular.name; font.pixelSize: 10; renderType: Text.CurveRendering }
    Row { y: 97; spacing: 8
        Text { text: page.ready ? page.amount(page.volume.available) : "—"; color: Appearance.tone("#F4F4F4"); font.family: harmonyBold.name; font.pixelSize: 84; renderType: Text.CurveRendering }
        Text { y: 58; text: page.ready ? page.unit(page.volume.available) : ""; color: Appearance.tone("#8A8A8A"); font.family: harmonyMedium.name; font.pixelSize: 20; renderType: Text.CurveRendering }
    }
    Text { x: 290; y: 130; width: 300; horizontalAlignment: Text.AlignRight; text: qsTr("已用"); color: Appearance.tone("#8A8A8A"); font.family: harmonyRegular.name; font.pixelSize: 10; renderType: Text.CurveRendering }
    Text { x: 390; y: 146; width: 200; horizontalAlignment: Text.AlignRight; text: page.ready ? Math.round(page.volume.fraction * 100) + "%" : "—"; color: Appearance.tone("#F4F4F4"); font.family: harmonyBold.name; font.pixelSize: 30; renderType: Text.CurveRendering }
    Row { y: 189; spacing: 3
        Repeater { model: 40
            Rectangle { required property int index; width: (590 - 39 * 3) / 40; height: 30
                color: page.ready && index < Math.round(page.volume.fraction * 40) ? (page.volume.fraction > .9 ? "#B8262A" : Appearance.accent("#D9D300")) : Appearance.tone("#2B2B2B")
                Rectangle { width: parent.width; height: 2; color: page.ready && index < Math.round(page.volume.fraction * 40) ? (page.volume.fraction > .9 ? "#FF6B6D" : Appearance.accent("#FFFC6B")) : Appearance.tone("#3B3B3B") }
            }
        }
    }
    Row { y: 233; spacing: 6
        Repeater { model: [qsTr("总计"), qsTr("已用"), qsTr("可用")]
            Rectangle { required property string modelData; required property int index; width: (590 - 12) / 3; height: 55; color: Appearance.tone("#1E1E1E"); border.color: Appearance.tone("#343434")
                Text { x: 12; y: 10; text: modelData; color: Appearance.tone("#8A8A8A"); font.family: harmonyRegular.name; font.pixelSize: 10; renderType: Text.CurveRendering }
                Text { x: 12; y: 27; text: { const n = [page.volume.total, page.volume.used, page.volume.available][index]; return page.ready ? page.amount(n) + " " + page.unit(n) : "—" } color: index === 1 ? Appearance.accent("#FFFA00") : Appearance.tone("#EEEEEE"); font.family: harmonyBold.name; font.pixelSize: 16; renderType: Text.CurveRendering }
            }
        }
    }
    CalendarButton { x: (590 - width) / 2; y: 304; width: 136; height: 34; title: qsTr("存储设置"); onClicked: { if (storageController.openDolphin()) appController.hideHud(); } }
    Text { y: 352; width: 590; horizontalAlignment: Text.AlignHCenter; visible: !page.ready; text: page.reading.loading ? qsTr("正在刷新") : qsTr("无法读取存储容量。"); color: Appearance.tone("#8A8A8A"); font.family: harmonyRegular.name; font.pixelSize: 11; renderType: Text.CurveRendering }
    Rectangle { id: volumes; x: 370; y: 58; width: 220; height: choices.height + 8; visible: false; z: 100; color: Appearance.tone("#202020"); border.color: Appearance.tone("#555555")
        Column { id: choices; x: 4; y: 4; width: 212
            Repeater { model: page.reading.volumes
                Rectangle { required property var modelData; width: 212; height: 30; color: mouse.containsMouse ? Appearance.tone("#383838") : "transparent"
                    Text { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 192; elide: Text.ElideRight; text: modelData.name; color: Appearance.tone("#EEEEEE"); font.family: harmonyRegular.name; font.pixelSize: 12; renderType: Text.CurveRendering }
                    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; onClicked: { storageController.selectVolume(modelData.id); volumes.visible = false; } }
                }
            }
        }
    }

    // Etapa 11: a tela original permanece intacta; painel de leitura sob demanda.
    CalendarButton {
        x: (590 - width) / 2; y: 358; width: 180; height: 32
        title: qsTr("Analisar arquivos"); enabled: page.ready
        onClicked: { page.details = true; storageController.analyze(); }
    }
    Item {
        x: 0; y: 0; width: 590; height: 510; z: 150; visible: page.details
        Rectangle { anchors.fill: parent; color: Appearance.tone("#151515") }
        SettingsHeader {
            title: qsTr("Analise de arquivos"); english: "FILE ANALYSIS"
            code: "SYS-11"; count: page.inspection.loading ? "SCAN" : "LOCAL"
            back: true; onBackRequested: page.details = false
        }
        CalendarButton {
            x: 476; y: 84; width: 114; height: 26; kind: "secondary"
            title: page.inspection.loading ? qsTr("Analisando...") : qsTr("Analisar novamente")
            enabled: !page.inspection.loading
            onClicked: storageController.analyze()
        }
        Text {
            x: 2; y: 90; width: 462; elide: Text.ElideMiddle
            text: (page.inspection.root || page.volume.path || "")
            color: Appearance.tone("#AAAAAA"); font.family: harmonyRegular.name; font.pixelSize: 12
        }
        Text {
            x: 2; y: 122; width: 580; elide: Text.ElideRight
            text: page.inspection.loading ? qsTr("Varrendo arquivos sem bloquear o HUD...")
                  : page.inspection.error ? page.inspection.error
                  : page.inspection.files !== undefined ? (page.inspection.files + qsTr(" arquivos encontrados  |  ") + page.byteLabel(page.inspection.bytes))
                  : qsTr("Escolha Analisar novamente para iniciar")
            color: page.inspection.error ? "#FF7474" : Appearance.tone("#EEEEEE")
            font.family: harmonyMedium.name; font.pixelSize: 12
        }
        Rectangle { x: 0; y: 155; width: 285; height: 245; color: Appearance.tone("#1E1E1E"); border.color: Appearance.tone("#393939") }
        Rectangle { x: 295; y: 155; width: 295; height: 245; color: Appearance.tone("#1E1E1E"); border.color: Appearance.tone("#393939") }
        Text { x: 12; y: 166; text: qsTr("CATEGORIAS"); color: Appearance.accent("#FFFA00"); font.family: harmonyBold.name; font.pixelSize: 12 }
        Text { x: 307; y: 166; text: qsTr("MAIORES ARQUIVOS"); color: Appearance.accent("#FFFA00"); font.family: harmonyBold.name; font.pixelSize: 12 }
        Column {
            x: 12; y: 190; width: 261; spacing: 2
            Repeater {
                model: page.inspection.categories || []
                Item {
                    required property var modelData; width: 261; height: 27
                    Text { x: 0; y: 0; text: modelData.name; color: Appearance.tone("#D0D0D0"); font.family: harmonyRegular.name; font.pixelSize: 10 }
                    Text { x: 160; y: 0; width: 100; horizontalAlignment: Text.AlignRight; text: page.byteLabel(modelData.bytes); color: Appearance.tone("#F4F4F4"); font.family: harmonyMedium.name; font.pixelSize: 10 }
                    Rectangle { x: 0; y: 18; width: 261; height: 3; color: Appearance.tone("#333333") }
                    Rectangle { x: 0; y: 18; width: 261 * Math.max(0, Math.min(1, modelData.fraction)); height: 3; color: Appearance.accent("#FFFA00") }
                }
            }
        }
        Column {
            x: 307; y: 190; width: 271; spacing: 3
            Repeater {
                model: page.inspection.largest || []
                Rectangle {
                    required property var modelData; width: 271; height: 23
                    color: folderMouse.containsMouse ? Appearance.tone("#393939") : "transparent"
                    Text { x: 4; y: 5; width: 187; elide: Text.ElideMiddle; text: modelData.name; color: Appearance.tone("#EEEEEE"); font.family: harmonyRegular.name; font.pixelSize: 10 }
                    Text { x: 194; y: 5; width: 73; horizontalAlignment: Text.AlignRight; text: page.byteLabel(modelData.bytes); color: Appearance.accent("#FFFA00"); font.family: harmonyMedium.name; font.pixelSize: 10 }
                    MouseArea { id: folderMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (storageController.revealAnalyzedFile(modelData.path)) appController.hideHud(); } }
                }
            }
        }
        Text {
            x: 0; y: 420; width: 590; wrapMode: Text.Wrap; maximumLineCount: 2
            text: page.inspection.loading ? qsTr("Varredura limitada a 12 segundos, 15 mil arquivos e 10 niveis de pastas.")
                  : page.inspection.truncated ? qsTr("Resultado PARCIAL: limite de tempo, itens ou profundidade atingido. Os valores nao representam o disco inteiro.")
                  : qsTr("Resumo apenas da pasta analisada, nao de todo o disco. Clique num arquivo para abrir sua pasta no Dolphin.")
            color: page.inspection.truncated ? "#F0BD64" : Appearance.tone("#AAAAAA")
            font.family: harmonyRegular.name; font.pixelSize: 11
        }
        Text {
            x: 0; y: 472; width: 590
            text: qsTr("Somente leitura | Nada e apagado ou enviado pela rede")
            color: Appearance.tone("#777777"); font.family: harmonyRegular.name; font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
