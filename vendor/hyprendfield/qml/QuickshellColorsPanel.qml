import QtQuick
import QtQuick.Controls
import "Appearance.js" as Appearance

// HYPR_ENDFIELD_SETTINGS_HUB_20A
// Agora vive DENTRO da galeria de wallpapers. ColorSchemes continua sendo o backend.
Item {
    id: root
    width: 798; height: 527
    readonly property var bridge: quickshellBridge.state
    property bool creatorOpen: false
    onVisibleChanged: if (visible) quickshellBridge.refresh()
    Rectangle { anchors.fill:parent; color:Appearance.tone("#171719") }
    Text { x:22; y:14; text:"CORES & PALETAS"; font.family:harmonyBold.name; font.pixelSize:20; color:"#F5F5F0" }
    Text { x:22; y:43; width:570; text:"Personalização de cores do Quickshell — independente do wallpaper."; font.family:harmonyRegular.name; font.pixelSize:12; color:"#BBBBBB" }
    CalendarButton { x:612; y:13; width:156; height:30; title:"CRIAR PALETA"; kind:"secondary"; onClicked:root.creatorOpen=!root.creatorOpen }
    Rectangle { x:20; y:78; width:758; height:1; color:"#424341" }
    Text { x:22; y:89; text:"PALETA ATIVA: " +(root.bridge.scheme||"MATERIAL (AUTOMÁTICO)"); color:Appearance.accent("#FFFA00"); font.pixelSize:12; font.family:harmonyBold.name }
    Flickable {
        x:20; y:116; width:758; height:238; clip:true; contentHeight:colorRows.implicitHeight+10; boundsBehavior:Flickable.StopAtBounds
        Column {
            id:colorRows; spacing:6; width:758
            Repeater {
                model:root.bridge.schemes || []
                Rectangle {
                    id:row; required property var modelData
                    readonly property bool active:root.bridge.scheme===modelData.id
                    width:758; height:44; color:active?"#333333":"#252527"; border.color:active?Appearance.accent("#FFFA00"):"#4C4C4C"
                    Rectangle { x:9;y:11;width:4;height:22;color:active?Appearance.accent("#FFFA00"):"#707070" }
                    Text { x:23; y:12; width:520; font.family:harmonyMedium.name; font.pixelSize:14; color:"#F2F2F2"; text:modelData.name; elide:Text.ElideRight }
                    Text { x:626; y:14; width:118; horizontalAlignment:Text.AlignRight; font.family:harmonyBold.name; font.pixelSize:11; color:Appearance.accent("#FFFA00"); text:active?"ATIVA":"APLICAR" }
                    MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; enabled:root.bridge.available&&!root.bridge.busy; onClicked:if(!row.active) quickshellBridge.setScheme(row.modelData.id) }
                }
            }
        }
    }
    Text { x:22; y:363; text:"PRIMÁRIA"; font.pixelSize:10; color:"#B5B5B5" }
    Row { x:98; y:358; spacing:5
        Repeater {
            model:root.bridge.accents || []
            Rectangle {
                required property var modelData
                readonly property bool chosen:root.bridge.primaryAccent===modelData.id
                width:25; height:25; radius:4; color:modelData.color
                border.width:chosen?3:1; border.color:chosen?"white":"#444444"
                MouseArea { anchors.fill:parent; enabled:!!root.bridge.scheme; cursorShape:Qt.PointingHandCursor; onClicked:quickshellBridge.setAccent("primary",parent.modelData.id) }
            }
        }
    }
    Text { x:22; y:396; text:"SECUNDÁRIA"; font.pixelSize:10; color:"#B5B5B5" }
    Row { x:98; y:391; spacing:5
        Repeater {
            model:root.bridge.accents || []
            Rectangle {
                required property var modelData
                readonly property bool chosen:root.bridge.secondaryAccent===modelData.id
                width:25; height:25; radius:4; color:modelData.color
                border.width:chosen?3:1; border.color:chosen?"white":"#444444"
                MouseArea { anchors.fill:parent; enabled:!!root.bridge.scheme; cursorShape:Qt.PointingHandCursor; onClicked:quickshellBridge.setAccent("secondary",parent.modelData.id) }
            }
        }
    }
    Rectangle { x:20; y:425; width:758; height:1; color:"#424341" }
    CalendarButton { x:22; y:437; width:174; height:32; title:"IMPORTAR JSON"; kind:"secondary"; onClicked:quickshellBridge.importScheme() }
    CalendarButton { x:207; y:437; width:171; height:32; title:"ABRIR PASTA"; kind:"secondary"; onClicked:quickshellBridge.openSchemeFolder() }
    CalendarButton { x:389; y:437; width:140; height:32; title:"RECARREGAR"; kind:"secondary"; onClicked:quickshellBridge.reloadSchemes() }
    Text { x:24; y:485; width:744; text:root.bridge.notice||"A escolha de cores não troca o wallpaper por conta própria."; elide:Text.ElideRight; color:"#BBBBBB"; font.pixelSize:11 }

    // Mini-editor, com criação a partir do template OFICIAL do end4-pC.
    Rectangle {
        visible:root.creatorOpen; z:20; anchors.fill:parent; color:"#191A1A"; border.color:Appearance.accent("#FFFA00")
        Text { x:20; y:19; text:"CRIAR NOVA PALETA"; color:"white"; font.pixelSize:20; font.family:harmonyBold.name }
        Text { x:20; y:52; width:743; wrapMode:Text.WordWrap; text:"O esquema será criado no diretório nativo ~/.config/illogical-impulse/schemes. Use letras, números, _ ou - no identificador."; color:"#B0B0B0"; font.pixelSize:12 }
        Text { x:22; y:105; text:"IDENTIFICADOR (3 A 40 CARACTERES)"; color:Appearance.accent("#FFFA00"); font.pixelSize:12 }
        Rectangle { x:20;y:126;width:748;height:43;color:"#303030";border.color:"#656565"
            TextField { id:paletteName;anchors.fill:parent;placeholderText:"Ex.: hiyuki-personalizado";font.pixelSize:15;color:"white";background:null;leftPadding:11;rightPadding:11 }
        }
        Text { x:22; y:199; text:"COR PRINCIPAL (HEX)";color:Appearance.accent("#FFFA00");font.pixelSize:12 }
        Rectangle { x:20;y:220;width:355;height:44;color:"#303030";border.color:"#656565"
            TextField { id:palettePrimary;anchors.fill:parent;text:"#88C0D0";font.pixelSize:15;color:"white";background:null;leftPadding:11 }
        }
        Text { x:410; y:199; text:"COR SECUNDÁRIA (HEX)";color:Appearance.accent("#FFFA00");font.pixelSize:12 }
        Rectangle { x:398;y:220;width:370;height:44;color:"#303030";border.color:"#656565"
            TextField { id:paletteSecondary;anchors.fill:parent;text:"#B48EAD";font.pixelSize:15;color:"white";background:null;leftPadding:11 }
        }
        Text { x:22; y:289; width:730; wrapMode:Text.WordWrap; text:"As demais cores de superfícies e terminais vêm do template oficial; poderão ser ajustadas editando o JSON. Nada será sobrescrito.";color:"#B0B0B0";font.pixelSize:12 }
        CalendarButton { x:20;y:404;width:232;height:46;title:"CRIAR";onClicked:{if(quickshellBridge.createScheme(paletteName.text,palettePrimary.text,paletteSecondary.text))root.creatorOpen=false;} }
        CalendarButton { x:270;y:404;width:232;height:46;title:"CANCELAR";kind:"secondary";onClicked:root.creatorOpen=false }
        Text { x:22; y:475; width:735; text:root.bridge.notice||"Digite um nome e duas cores em #RRGGBB.";color:"#CCCCCC";font.pixelSize:12 }
    }
}
