import QtQuick
import QtQuick.Controls
import "Appearance.js" as Appearance

// HYPR_ENDFIELD_SETTINGS_HUB_20A — mantém a ponte original.
// HYPR_ENDFIELD_SETTINGS_COMPACT_20C — controles adequados e navegação Endfield.
// Fonte única: DashboardSettingsCatalog -> IPC hyprendfieldConfig -> Quickshell.
Item {
    id: root
    width: 590
    height: 429
    clip: true

    readonly property var snapshot: quickshellBridge.configState
    readonly property color accent: Appearance.accent("#FFFA00")
    property string activeGroup: ""
    property string searchText: ""
    property bool pickerOpen: false
    property string pickerKey: ""
    property string pickerTitle: ""
    property var pickerOptions: []
    property var pickerValue: null

    function groupName(group) {
        const key = String(group).toLowerCase().trim();
        const mapping = {"general":"GERAL", "interface":"INTERFACE", "bar":"BARRA",
            "desktop":"DESKTOP", "hyprland":"HYPRLAND", "services":"SERVIÇOS"};
        return mapping[key] ?? String(group).toUpperCase();
    }
    function openPicker(option) {
        if (snapshot.busy || !option.options || !option.options.length) return;
        pickerKey = option.key;
        pickerTitle = option.title;
        pickerValue = option.value;
        pickerOptions = option.options;
        pickerOpen = true;
    }
    function applyOption(key, value) {
        if (snapshot.busy) return;
        quickshellBridge.configSetOption(key, value);
    }
    function refresh() {
        if (!snapshot.busy) quickshellBridge.configRefresh();
    }

    readonly property var groups: {
        const result = [];
        for (const section of (snapshot.sections || [])) {
            if (section.group && !result.includes(section.group)) result.push(section.group);
        }
        return result;
    }
    readonly property var entries: {
        const result = [];
        const needle = searchText.toLocaleLowerCase().trim();
        for (const section of (snapshot.sections || [])) {
            if (activeGroup && section.group !== activeGroup) continue;
            const controls = (section.controls || []).filter(c =>
                !needle || (String(c.title) + " " + String(section.title) + " " + String(c.key))
                    .toLocaleLowerCase().includes(needle));
            if (!controls.length) continue;
            result.push({heading:true, title:section.title, key:"section:"+section.group+":"+section.title});
            for (const c of controls) result.push(Object.assign({heading:false}, c));
        }
        return result;
    }
    readonly property int resultCount: entries.filter(e => !e.heading).length

    Component.onCompleted: refresh()
    onVisibleChanged: if (visible) refresh()
    onActiveGroupChanged: { settingsList.positionViewAtBeginning(); pickerOpen = false; }
    onSearchTextChanged: { settingsList.positionViewAtBeginning(); pickerOpen = false; }

    // Plano de fundo discreto: mantém as texturas existentes do EndfieldHUD visíveis.
    Rectangle { anchors.fill: parent; color: "#1817191A" }
    Rectangle { x:0; y:0; width:4; height:33; color:root.accent }
    Text {
        x:13; y:1; width:360; height:22
        text:"QUICKSHELL  /  CONFIGURAÇÕES"
        font.family:harmonyBold.name; font.pixelSize:15; font.letterSpacing:0.5
        color:Appearance.tone("#F3F2EE"); elide:Text.ElideRight
    }
    Text {
        x:13; y:23; width:450; height:15
        text:"CONTROLES DO END4-PC  •  CONFIGURAÇÕES ORIGINAIS"
        font.family:harmonyRegular.name; font.pixelSize:9; font.letterSpacing:0.7
        color:Appearance.tone("#9B9B9B")
    }
    Rectangle {
        x:493; y:1; width:96; height:29; radius:2
        color:refreshMouse.pressed ? "#363636" : "#272729"
        border.color:Appearance.tone("#646464")
        Text { anchors.centerIn:parent; text:root.snapshot.busy ? "LENDO..." : "↻  ATUALIZAR"; color:"#F4F4F4"; font.pixelSize:10; font.family:harmonyBold.name }
        MouseArea { id:refreshMouse; anchors.fill:parent; cursorShape:Qt.PointingHandCursor; enabled:!root.snapshot.busy; onClicked:root.refresh() }
    }
    Rectangle { x:0; y:40; width:590; height:1; color:Appearance.tone("#4A4A4A") }

    // Categorias reais, construídas do snapshot do Quickshell.
    Flickable {
        x:0; y:49; width:590; height:34; clip:true
        contentWidth: tabs.width; contentHeight:height
        boundsBehavior:Flickable.StopAtBounds
        Row {
            id:tabs; spacing:4
            Repeater {
                model:[""].concat(root.groups)
                Rectangle {
                    id:tab
                    required property string modelData
                    readonly property bool current:root.activeGroup===modelData
                    height:29; width:Math.max(68,tabCaption.implicitWidth+19)
                    radius:2
                    color:current?root.accent:"#272729"
                    border.color:current?root.accent:"#555555"
                    Text {
                        id:tabCaption; anchors.centerIn:parent
                        text:tab.modelData?root.groupName(tab.modelData):"TODOS"
                        color:tab.current?"#171717":"#DADADA"; font.pixelSize:10
                        font.family:harmonyBold.name
                    }
                    MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked:root.activeGroup=tab.modelData }
                }
            }
        }
    }

    Rectangle {
        x:0; y:89; width:590; height:36; radius:2
        color:"#252526"; border.color:Appearance.tone("#575757")
        Text { x:11; y:9; text:"⌕"; color:root.accent; font.pixelSize:17 }
        TextField {
            id:searchInput; x:39; y:3; width:535; height:30
            placeholderText:"Pesquisar por nome, seção ou opção..."
            text:root.searchText
            onTextEdited:root.searchText=text
            color:"#F4F4F4"; placeholderTextColor:"#8E8E8E"
            font.pixelSize:12
            background:Item {}
            selectByMouse:true
        }
    }
    Text {
        x:3; y:132; width:420; height:17
        text:(root.activeGroup?root.groupName(root.activeGroup):"TODAS AS CATEGORIAS")+"  /  "+root.resultCount+" CONTROLES"
        color:Appearance.tone("#B9B9B9"); font.pixelSize:10; font.letterSpacing:0.5
        font.family:harmonyMedium.name; elide:Text.ElideRight
    }
    Text {
        x:480; y:132; width:108; height:17; horizontalAlignment:Text.AlignRight
        text:root.snapshot.available?"IPC CONECTADO":"IPC OFFLINE"
        color:root.snapshot.available?root.accent:"#D98D76"; font.pixelSize:9
        font.family:harmonyMedium.name
    }

    ListView {
        id:settingsList
        x:0; y:154; width:590; height:238
        clip:true; spacing:5
        boundsBehavior:Flickable.StopAtBounds
        model:root.entries
        delegate:Item {
            id:entry
            required property var modelData
            width:settingsList.width-5
            readonly property bool heading:!!modelData.heading
            readonly property string kind:heading?"heading":String(modelData.type)
            height:heading?30:(kind==="text"?76:(kind==="slider"?75:55))

            Rectangle {
                anchors.fill:parent; radius:2
                color:entry.heading?"#2A292B":"#1D1C1F"
                border.color:entry.heading?"#4A484B":"#39383B"
            }
            Rectangle { x:0; y:0; width:entry.heading?4:2; height:parent.height; color:entry.heading?root.accent:"#757575" }
            Text {
                x:12; y:entry.heading?8:7; width:entry.heading?540:(entry.kind==="text"||entry.kind==="slider"?550:325)
                height:20
                text:entry.modelData.title
                elide:Text.ElideRight
                color:entry.heading?root.accent:"#EFEFEF"
                font.family:entry.heading?harmonyBold.name:harmonyMedium.name
                font.pixelSize:entry.heading?11:12
            }
            Text {
                visible:!entry.heading && entry.kind!=="text" && entry.kind!=="slider"
                x:12; y:30; width:315; height:15
                text:String(entry.modelData.key||""); elide:Text.ElideMiddle
                color:"#777777"; font.pixelSize:9
            }

            // Toggle: ação única, nunca altera arquivo local de configuração.
            Rectangle {
                visible:entry.kind==="toggle"
                x:473; y:11; width:99; height:32; radius:2
                color:entry.modelData.value?root.accent:"#343235"
                border.color:entry.modelData.value?root.accent:"#555555"
                Rectangle { x:entry.modelData.value?76:3; y:5; width:19; height:20; color:entry.modelData.value?"#191919":"#B3B3B3"; radius:2 }
                Text { x:9; y:9; width:65; horizontalAlignment:Text.AlignHCenter; text:entry.modelData.value?"LIGADO":"DESLIGADO"; color:entry.modelData.value?"#111111":"#F5F5F5"; font.pixelSize:9; font.family:harmonyBold.name }
                MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; enabled:!root.snapshot.busy; onClicked:root.applyOption(entry.modelData.key,!entry.modelData.value) }
            }

            // Numérico discreto: respeita limites e intervalo do próprio catálogo.
            Row {
                visible:entry.kind==="spin"
                x:413; y:10; spacing:4
                readonly property real stepSize:Number(entry.modelData.step??1)
                Repeater {
                    model:[-1,0,1]
                    Rectangle {
                        id:spinButton
                        required property int modelData
                        width:modelData===0?84:35; height:32; radius:2
                        color:modelData===0?"#29282A":"#353336"
                        border.color:"#5B595C"
                        Text { anchors.centerIn:parent; text:spinButton.modelData===0?String(entry.modelData.value):(spinButton.modelData<0?"−":"+"); color:spinButton.modelData===0?root.accent:"#F6F6F6"; font.pixelSize:12; font.family:harmonyBold.name }
                        MouseArea {
                            anchors.fill:parent; cursorShape:Qt.PointingHandCursor
                            enabled:spinButton.modelData!==0&&!root.snapshot.busy
                            onClicked:{
                                const c=entry.modelData;
                                const min=c.from??-1e9, max=c.to??1e9, step=c.step??1;
                                const value=Math.max(min,Math.min(max,Number(c.value)+spinButton.modelData*Number(step)));
                                if(value!==Number(c.value))root.applyOption(c.key,Number(value.toFixed(5)));
                            }
                        }
                    }
                }
            }

            // Slider de verdade: envia o valor ao soltar, não a cada pixel movido.
            Slider {
                id:valueSlider
                visible:entry.kind==="slider"
                x:312; y:30; width:235; height:37
                enabled:!root.snapshot.busy
                from:Number(entry.modelData.from??0)
                to:Number(entry.modelData.to??100)
                stepSize:Math.max(0.001,Number(entry.modelData.step??1))
                value:Number(entry.modelData.value??0)
                onPressedChanged: {
                    if(!pressed && entry.kind==="slider" && enabled && Math.abs(value-Number(entry.modelData.value))>0.00001)
                        root.applyOption(entry.modelData.key,Number(value.toFixed(5)));
                }
            }
            Text {
                visible:entry.kind==="slider"
                x:445; y:7; width:105; horizontalAlignment:Text.AlignRight
                text:Number(entry.modelData.value??0).toLocaleString(Qt.locale("pt_BR"))
                font.pixelSize:11; font.family:harmonyBold.name; color:root.accent
            }
            Text {
                visible:entry.kind==="slider"
                x:12; y:36; width:260; height:21; elide:Text.ElideMiddle
                text:String(entry.modelData.key||"")
                font.pixelSize:9; color:"#777777"
            }

            // Seleção com lista real, não o antigo clique que alternava opções.
            Rectangle {
                visible:entry.kind==="select"||entry.kind==="combo"
                x:352; y:10; width:220; height:33; radius:2
                color:"#29282A"; border.color:"#686568"
                readonly property var opts:entry.modelData.options||[]
                readonly property int selected:opts.findIndex(o=>o.value===entry.modelData.value)
                Text {
                    x:10; y:9; width:185; height:21; elide:Text.ElideRight
                    text:parent.selected<0?String(entry.modelData.value??"—"):String(parent.opts[parent.selected].label)
                    color:"#EEEEEE"; font.pixelSize:11
                }
                Text { x:199; y:6; text:"⌄"; color:root.accent; font.pixelSize:17 }
                MouseArea { anchors.fill:parent; enabled:!root.snapshot.busy&&parent.opts.length>0; cursorShape:Qt.PointingHandCursor; onClicked:root.openPicker(entry.modelData) }
            }

            // Campo editável: só altera a configuração ao pressionar Enter/APLICAR.
            Rectangle {
                visible:entry.kind==="text"
                x:12; y:32; width:560; height:36; radius:2
                color:"#29282A"; border.color:"#666366"
                TextField {
                    id:field
                    x:4; y:3; width:462; height:30; clip:true
                    text:entry.kind==="text"?String(entry.modelData.value??""):""
                    color:"#F6F6F6"; font.pixelSize:11; selectByMouse:true
                    background:Item {}
                    onAccepted:if(entry.kind==="text")root.applyOption(entry.modelData.key,text)
                }
                Rectangle {
                    x:468; y:3; width:89; height:30; radius:2
                    color:root.snapshot.busy?"#555555":root.accent
                    Text { anchors.centerIn:parent; text:"APLICAR"; color:"#191919"; font.pixelSize:10; font.family:harmonyBold.name }
                    MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; enabled:!root.snapshot.busy; onClicked:root.applyOption(entry.modelData.key,field.text) }
                }
            }
        }
        ScrollBar.vertical: ScrollBar { policy:ScrollBar.AsNeeded }
    }

    Text {
        x:0; y:218; width:590; horizontalAlignment:Text.AlignHCenter
        visible:root.entries.length===0
        text:root.snapshot.busy?"LENDO CONFIGURAÇÕES...":(root.snapshot.available?"NENHUMA OPÇÃO ENCONTRADA":"PONTE IPC INDISPONÍVEL")
        color:"#BBBBBB"; font.pixelSize:12; font.family:harmonyMedium.name
    }
    Rectangle { x:0; y:400; width:590; height:1; color:Appearance.tone("#4E4E4E") }
    Rectangle { x:1; y:408; width:4; height:13; color:root.accent }
    Text {
        x:13; y:406; width:572; height:20; elide:Text.ElideRight
        text:root.snapshot.notice||"ALTERAÇÕES ENVIADAS AO QUICKSHELL  •  EDITORES ESPECIAIS NA 20E"
        color:root.snapshot.notice?"#ECD082":"#B3B3B3"; font.pixelSize:10
    }

    // Lista de seleção sobre a página: não é cortada pelo ListView.
    Item {
        anchors.fill:parent; z:20; visible:root.pickerOpen
        Rectangle { anchors.fill:parent; color:"#BC000000" }
        MouseArea { anchors.fill:parent; onClicked:root.pickerOpen=false }
        Rectangle {
            x:37; y:49; width:516; height:328; radius:3
            color:"#202023"; border.color:root.accent; border.width:1
            Rectangle { x:0; width:4; height:40; color:root.accent }
            Text {
                x:14; y:10; width:450; height:21
                text:root.pickerTitle; color:"#F6F6F6"; font.family:harmonyBold.name
                font.pixelSize:14; elide:Text.ElideRight
            }
            Rectangle {
                x:480; y:7; width:27; height:27; color:"#3A383B"; border.color:"#666666"
                Text { anchors.centerIn:parent; text:"×"; font.pixelSize:20; color:"white" }
                MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked:root.pickerOpen=false }
            }
            Rectangle { x:12; y:40; width:492; height:1; color:"#555555" }
            ListView {
                x:12; y:49; width:492; height:266; clip:true; spacing:3
                model:root.pickerOptions
                delegate:Rectangle {
                    id:pickerOption
                    required property var modelData
                    width:480; height:35; radius:2
                    readonly property bool selected:modelData.value===root.pickerValue
                    color:selected?"#45412C":"#2C2B2E"
                    border.color:selected?root.accent:"#494949"
                    Text { x:10; y:8; width:436; height:23; elide:Text.ElideRight; text:String(pickerOption.modelData.label); color:pickerOption.selected?root.accent:"#F0F0F0"; font.pixelSize:12 }
                    Text { x:455; y:8; text:pickerOption.selected?"✓":"›"; color:pickerOption.selected?root.accent:"#8A8A8A"; font.pixelSize:14 }
                    MouseArea {
                        anchors.fill:parent; enabled:!root.snapshot.busy; cursorShape:Qt.PointingHandCursor
                        onClicked:{
                            const key=root.pickerKey;
                            const value=pickerOption.modelData.value;
                            root.pickerOpen=false;
                            if(value!==root.pickerValue)root.applyOption(key,value);
                        }
                    }
                }
                ScrollBar.vertical: ScrollBar { policy:ScrollBar.AsNeeded }
            }
        }
    }
}
