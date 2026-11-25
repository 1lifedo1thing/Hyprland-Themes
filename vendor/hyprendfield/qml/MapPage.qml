import QtQuick
import QtCore
import HyprEndfield.Map 1.0
import "Appearance.js" as Appearance

// World Map — geometry adapted from EndfieldHUD's WorldMapSurface / Canvas:
// central disc: 860×860, centre (295,304), radius 430, active radius 369.86.
// Original NOAA + Natural Earth/WGII files rendered as native Qt vector paths.
// Persistent world camera and max. 128 private local pins; no location access.
Item {
    id: root
    width: 590
    height: 510
    focus: presented
    property bool presented: false
    // Native vector resources are loaded only once when the component is built.
    property real cx: 0.8168275
    property real cy: 0.3747605
    property real zoom: 3.0
    property string selectedPin: ""
    readonly property real unitScale: 1.14 * 1920 * 1.15 / 1470
    readonly property real worldWidth: 440 * zoom * unitScale
    readonly property real worldHeight: 220 * zoom * unitScale
    readonly property real activeRadius: 216 * unitScale
    readonly property color accent: Appearance.accent("#FAD41F")
    readonly property color labelWhite: Appearance.tone("#EEEEEE")
    readonly property int pinLimit: 128

    function clamp(x,lo,hi) { return Math.max(lo,Math.min(hi,x)); }
    function wrap(x) { return ((x % 1) + 1) % 1; }
    function nearestDelta(x) { let dx = x - cx; return dx - Math.round(dx); }
    function inside(x,y) { return Math.hypot(x - 430, y - 430) <= activeRadius; }
    function screenAt(x,y) { return Qt.point(430 + nearestDelta(x)*worldWidth, 430+(y-cy)*worldHeight); }
    function worldAt(x,y) { return {x: wrap(cx+(x-430)/worldWidth),y:clamp(cy+(y-430)/worldHeight,0,1)}; }
    function constrainY(y, factor) {
        const half = 1/factor;
        return half >= .5 ? .5 : clamp(y,half,1-half);
    }
    function navigate(x,y,newZoom) {
        cx = wrap(x); zoom = clamp(newZoom,1,128); cy = constrainY(y,zoom);
        saveCamera.restart();
    }
    function panFrom(x0,y0,oldX,oldY,newX,newY) {
        cx = wrap(oldX-(newX-x0)/worldWidth);
        cy = constrainY(oldY-(newY-y0)/worldHeight,zoom);
    }
    function zoomAt(factor,x,y) {
        const target = worldAt(x,y);
        const next = clamp(zoom*factor,1,128);
        const nextWidth = 440*next*unitScale;
        const nextHeight = 220*next*unitScale;
        navigate(target.x-(x-430)/nextWidth,target.y-(y-430)/nextHeight,next);
    }
    function resetView() {navigate(.8168275,.3747605,3);selectedPin = "";}
    function addPinAt(x,y) {
        if (pins.count >= pinLimit || !inside(x,y)) return;
        const p=worldAt(x,y);
        const id=String(Date.now())+"-"+String(Math.random()).slice(2);
        pins.append({pid:id,px:p.x,py:p.y,pstyle:0}); selectedPin=id; savePins();
    }
    function interactPin(index,button) {
        const p=pins.get(index); if(!p)return;
        if(button===Qt.RightButton) {
            pins.remove(index);
            if(selectedPin===p.pid)selectedPin="";
        } else {
            pins.setProperty(index,"pstyle",(p.pstyle+1)%3);
            selectedPin=p.pid;
        }
        savePins();
    }
    function savePins() {
        const list=[];
        for(let i=0;i<pins.count;i++) {
            const p=pins.get(i);list.push({id:p.pid,x:p.px,y:p.py,style:p.pstyle});
        }
        storage.pinsJson=JSON.stringify(list);
    }
    function selectedCoords() {
        for(let i=0;i<pins.count;i++) {
            const p=pins.get(i);if(p.pid!==selectedPin)continue;
            const lat=90-p.py*180,lon=p.px*360-180;
            return "PIN "+String(i+1).padStart(2,"0") +"     "+(lat<0?"S":"N")+" "+Math.abs(lat).toFixed(2)+"°     "+(lon<0?"W":"E")+" "+Math.abs(lon).toFixed(2)+"°";
        }
        return "";
    }
    onPresentedChanged: if (presented) forceActiveFocus();
    Keys.onPressed: event => {
        if(!presented || (event.modifiers & (Qt.ControlModifier|Qt.AltModifier|Qt.MetaModifier)))return;
        const step=40;
        if(event.key===Qt.Key_Left)panFrom(0,0,cx,cy,step,0);
        else if(event.key===Qt.Key_Right)panFrom(0,0,cx,cy,-step,0);
        else if(event.key===Qt.Key_Up)panFrom(0,0,cx,cy,0,step);
        else if(event.key===Qt.Key_Down)panFrom(0,0,cx,cy,0,-step);
        else if(event.key===Qt.Key_Plus || event.key===Qt.Key_Equal)zoomAt(1.5,430,430);
        else if(event.key===Qt.Key_Minus)zoomAt(1/1.5,430,430);
        else if(event.key===Qt.Key_Backspace || event.key===Qt.Key_Delete) {
            for(let i=0;i<pins.count;i++) if(pins.get(i).pid===selectedPin) {pins.remove(i);savePins();break;}
            selectedPin="";
        }
        else if(event.key===Qt.Key_Escape){if(!selectedPin)return;selectedPin="";}
        else return;
        event.accepted=true;saveCamera.restart();
    }
    Settings {
        id: storage
        category: "WorldMap"
        property real cameraX: .8168275
        property real cameraY: .3747605
        property real cameraZoom: 3
        property string pinsJson: "[]"
    }
    Timer {
        id: saveCamera
        interval: 250
        onTriggered: {
            storage.cameraX=root.cx;
            storage.cameraY=root.cy;
            storage.cameraZoom=root.zoom;
        }
    }
    ListModel {id:pins}
    Component.onCompleted: {
        const x=Number(storage.cameraX),y=Number(storage.cameraY),z=Number(storage.cameraZoom);
        if(Number.isFinite(x)&&Number.isFinite(y)&&Number.isFinite(z)) {
            cx=wrap(x);zoom=clamp(z,1,128);cy=constrainY(y,zoom);
        }
        try {
            const data=JSON.parse(storage.pinsJson);
            if(Array.isArray(data)) for(let i=0;i<Math.min(pinLimit,data.length);i++) {
                const p=data[i];if(!p||!Number.isFinite(p.x)||!Number.isFinite(p.y))continue;
                pins.append({pid:String(p.id||i),px:wrap(p.x),py:clamp(p.y,0,1),pstyle:clamp(Math.floor(Number(p.style)||0),0,2)});
            }
        }catch(e){console.warn("WorldMap: archive unreadable; original data preserved",e);}
    }

    // The map is larger than its page: exactly the original centre-backdrop disc.
    Item {
        id: disc
        x: -135; y: -126; width: 860; height: 860
        z: 0
        // Vector terrain, original EndfieldHUD EHUDMAP1 + EHUDCTY1.
        // A native QPainter renderer replaces the fixed 2048px texture.
        WorldMapRenderer {
            id: nativeMap
            anchors.fill: parent
            centerX: root.cx
            centerY: root.cy
            zoom: root.zoom
            accent: root.accent
        }
        Text {
            anchors.centerIn: parent
            width: 560
            text: nativeMap.error
            color: root.accent
            font.pixelSize: 17
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: nativeMap.error.length > 0
        }
        // Only the original 216-unit round viewing area handles the camera.
        MouseArea {
            id: mapMouse
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            preventStealing: true
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            property real startX:0
            property real startY:0
            property real startCX:0
            property real startCY:0
            property bool moved:false
            onPressed: mouse => {
                if(!root.inside(mouse.x,mouse.y)){mouse.accepted=false;return;}
                startX=mouse.x;startY=mouse.y;startCX=root.cx;startCY=root.cy;moved=false;
                if(mouse.button===Qt.RightButton)root.addPinAt(mouse.x,mouse.y);
            }
            onPositionChanged: mouse => {
                if(!(pressedButtons&Qt.LeftButton))return;
                if(!root.inside(startX,startY))return;
                if(Math.abs(mouse.x-startX)+Math.abs(mouse.y-startY)>3)moved=true;
                if(moved)root.panFrom(startX,startY,startCX,startCY,mouse.x,mouse.y);
            }
            onReleased: mouse => {
                if(moved){saveCamera.restart();return;}
                if(mouse.button===Qt.LeftButton&&root.inside(mouse.x,mouse.y)){
                    if(root.selectedPin)root.selectedPin="";
                    else { const p=root.worldAt(mouse.x,mouse.y);root.navigate(p.x,p.y,root.zoom); }
                }
            }
            onWheel: wheel => {
                if(!root.inside(wheel.x,wheel.y))return;
                const steps=root.clamp(wheel.angleDelta.y/120,-6,6);
                if(steps!==0)root.zoomAt(Math.pow(1.12,steps),wheel.x,wheel.y);
                wheel.accepted=true;
            }
        }
        Repeater {
            model: pins
            delegate: Item {
                id: marker
                required property int index
                required property string pid
                required property real px
                required property real py
                required property int pstyle
                readonly property point p: root.screenAt(px,py)
                readonly property real distance: Math.hypot(p.x-430,p.y-430)
                readonly property color ink: pstyle === 1 ? "#A8F233" : "#FFFC4E"
                readonly property real k: root.unitScale
                width: 48*k; height: 48*k
                x: p.x-width/2; y: p.y-height/2
                visible: distance < 430 && root.presented
                opacity: distance <= 326 ? 1 : Math.max(0,(430-distance)/104)
                z: 3
                // The 5.3 / 8 / 4 / 1.8 radii match WorldMapSurface.makeMarker().
                Rectangle {
                    anchors.centerIn:parent
                    width: 10.6*marker.k; height: width; radius: width/2
                    color: "#D90F0F0F"
                    visible: marker.pstyle !== 2
                }
                Rectangle {
                    id: pulse
                    anchors.centerIn:parent
                    width: 16*marker.k; height: width; radius: width/2
                    color: "transparent"; border.width: .55*marker.k; border.color:marker.ink
                    visible: marker.pstyle !== 2
                    SequentialAnimation on scale {
                        running: marker.visible && marker.pstyle !== 2 && !settingsController.reduceMotion && marker.index < 12
                        loops: Animation.Infinite
                        NumberAnimation {from:1;to:1.35;duration:900;easing.type:Easing.OutQuad}
                        NumberAnimation {from:1.35;to:1;duration:900;easing.type:Easing.InQuad}
                    }
                }
                Rectangle {
                    anchors.centerIn:parent
                    width: 8*marker.k; height: width; radius:width/2
                    color:"transparent";border.width:1.2*marker.k;border.color:marker.ink
                    visible: marker.pstyle !== 2
                }
                Rectangle {
                    anchors.centerIn:parent
                    width: 3.6*marker.k; height: width; radius:width/2
                    color:marker.ink
                    visible: marker.pstyle !== 2
                }
                // Source 3 sprite images are used for the player marker.
                Image {
                    anchors.centerIn:parent
                    width:48*marker.k;height:52*marker.k
                    source:"qrc:/assets/world-map/player-halo.png"
                    visible:marker.pstyle===2
                    opacity:.149
                    fillMode:Image.Stretch
                }
                Image {
                    x:(parent.width-6*marker.k)/2;y:parent.height/2-106*marker.k
                    width:6*marker.k;height:102*marker.k
                    source:"qrc:/assets/world-map/player-beam.png"
                    visible:marker.pstyle===2
                    opacity:.72
                    fillMode:Image.Stretch
                }
                Image {
                    anchors.centerIn:parent
                    width:24*marker.k;height:24*marker.k
                    source:"qrc:/assets/world-map/player-glyph.png"
                    visible:marker.pstyle===2
                    fillMode:Image.PreserveAspectFit
                    mipmap:true
                }
                MouseArea {
                    anchors.fill:parent
                    acceptedButtons:Qt.LeftButton|Qt.RightButton
                    cursorShape:Qt.PointingHandCursor
                    onClicked: mouse => root.interactPin(marker.index,mouse.button)
                }
            }
        }
    }
    // Source map header / technical annotation; keep above the masked terrain.
    Rectangle {
        z:8;x:-15;y:-9;width:620;height:132
        gradient:Gradient {
            GradientStop{position:0;color:"#D8111214"}
            GradientStop{position:.55;color:"#95111214"}
            GradientStop{position:1;color:"#00111214"}
        }
    }
    SettingsHeader {
        z:10
        title:qsTr("MAP")
        english:"MAP"
        crumbs:"MAP"
        code:"MOD-13"
        count:String(pins.count).padStart(2,"0")+" PINS"
    }
    Rectangle {
        z:12;x:235;y:91;width:115;height:25
        color:"#E0161718";border.color:"#796C7171";border.width:1
        Text {
            anchors.centerIn:parent
            text:root.zoom.toFixed(1)+"×"
            color:root.accent
            font.family:harmonyBold.name;font.pixelSize:15
            renderType:Text.CurveRendering
        }
    }
    Column {
        z:12;x:22;y:228;spacing:5
        Repeater {
            model:[{glyph:"+",action:"in",tip:qsTr("Zoom in")},
                   {glyph:"−",action:"out",tip:qsTr("Zoom out")},
                   {glyph:"↺",action:"reset",tip:qsTr("Reset view")}]
            Rectangle {
                id:zoomButton
                required property var modelData
                width:43;height:43
                color:pointer.containsMouse?root.accent:"#DF202223"
                border.color:pointer.containsMouse?root.accent:"#666B6D"
                border.width:1
                Text {
                    anchors.centerIn:parent
                    text:zoomButton.modelData.glyph
                    color:pointer.containsMouse?"#161718":root.labelWhite
                    font.family:harmonyBold.name;font.pixelSize:25
                }
                MouseArea {
                    id:pointer;anchors.fill:parent;hoverEnabled:true
                    cursorShape:Qt.PointingHandCursor
                    onClicked: {
                        if(zoomButton.modelData.action==="in")root.zoomAt(1.5,430,430);
                        else if(zoomButton.modelData.action==="out")root.zoomAt(1/1.5,430,430);
                        else root.resetView();
                    }
                }
            }
        }
    }
    Rectangle {
        z:12;x:520;y:275;width:43;height:43;radius:22
        color:pinButton.containsMouse?root.accent:"#DF202223"
        border.color:pinButton.containsMouse?root.accent:"#74797A"
        border.width:1
        Text{anchors.centerIn:parent;text:"⊕";font.pixelSize:26;color:pinButton.containsMouse?"#171819":root.labelWhite}
        MouseArea {
            id:pinButton;anchors.fill:parent;hoverEnabled:true
            cursorShape:Qt.PointingHandCursor
            onClicked:root.addPinAt(430,430)
        }
    }
    Rectangle {
        z:12;x:190;y:436;width:210;height:58
        visible:root.selectedCoords()!==""
        color:"#EE131415";border.width:1;border.color:"#737879"
        Rectangle{width:3;height:parent.height;color:root.accent}
        Text {
            anchors.centerIn:parent
            text:root.selectedCoords()
            color:root.accent
            font.family:harmonyMedium.name;font.pixelSize:12
            horizontalAlignment:Text.AlignHCenter
            renderType:Text.CurveRendering
        }
    }
    Text {
        z:12;x:25;y:499;width:540;height:20
        text:qsTr("Roda: zoom  ·  Arrastar: mover  ·  Botão direito: marcador")
        color:Appearance.tone("#888E8F")
        font.family:harmonyRegular.name;font.pixelSize:10
        elide:Text.ElideRight
        renderType:Text.CurveRendering
    }
}
