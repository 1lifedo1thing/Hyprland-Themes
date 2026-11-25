//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF

Scope {
    id: root

    readonly property real sizeScale: Config.options.settings.style === "minimal" ? 0.75 : 1.0
    property bool isMinimal: Config.options.settings.style === "minimal"

    Component.onCompleted: {
        GlobalStates.settingsOpen = false;
    }

    // HYPR_ENDFIELD_SETTINGS_STAGE17
    // Valores persistidos pelo JsonAdapter existente. O sufixo guarda a UI nativa anterior.
    readonly property bool endfieldSelected: String(Config.options.settings.style).indexOf("endfield-") === 0

    Connections {
        target: GlobalStates
        function onSettingsOpenChanged() {
            if (GlobalStates.settingsOpen && root.endfieldSelected) {
                GlobalStates.settingsOpen = false;
                Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/hyprendfield", "--show"]);
            }
        }
    }
    // HYPR_ENDFIELD_SETTINGS_HUB_20A: exporta SOMENTE opções simples do
    // catálogo oficial; não replica o config.json, não toca em settings.style.
    DashboardSettingsCatalog { id: hyprEndfieldCatalog }

    IpcHandler {
        target: "hyprendfieldConfig"
        function permitted(key: string, type: string): bool {
            if (!["toggle","spin","slider","select","combo","text"].includes(type)) return false;
            if (key.startsWith("interface:Settings Panel") || key==="interface:Border color" ||
                key.startsWith("interface:Color scheme") || key.startsWith("interface:Palette") ||
                key.startsWith("desktop:Wallpaper/Wallpaper") ||
                key.indexOf("Settings panel") >= 0) return false;
            const forbidden = /password|token|secret|credential|api.?key|system.prompt|shell.command|auth|private.?key/i;
            return !forbidden.test(key);
        }
        function snapshot(): string {
            const sections = [];
            for (const section of hyprEndfieldCatalog.sections) {
                const controls = [];
                for (const card of section.cards) {
                    if (!card.key || !permitted(card.key, card.type)) continue;
                    const control = hyprEndfieldCatalog.controlFor(card.key);
                    if (!control || typeof control.get !== "function" || typeof control.set !== "function") continue;
                    try {
                        const val = control.get();
                        if (!["string","number","boolean"].includes(typeof val)) continue;
                        if (card.type==="toggle" && typeof val!=="boolean") continue;
                        if (["spin","slider"].includes(card.type) && (typeof val!=="number" || !Number.isFinite(val))) continue;
                        const options = (control.options || []).filter(v => v && ["string","number","boolean"].includes(typeof v.value))
                            .map(v => ({label: String(v.displayName ?? v.value), value:v.value}));
                        controls.push({key:card.key,title:String(card.title),type:card.type,value:val,
                            options:options,from:control.from, to:control.to,step:control.stepSize??1});
                    } catch(e) { /* controle incompatível não é exportado */ }
                }
                if (controls.length) sections.push({group:String(section.page),title:String(section.title),controls:controls});
            }
            const matchingBar = sections.find(s=>s.controls.some(c=>c.key.startsWith("bar:")));
            sections.push({group:matchingBar?matchingBar.group:"Barra",title:"POSIÇÃO DA BARRA",controls:[{
                key:"__bar_position__",title:"Posição da barra",type:"select",
                value:Config.options.bar.vertical?(Config.options.bar.bottom?"right":"left"):(Config.options.bar.bottom?"bottom":"top"),
                options:[{label:"Superior",value:"top"},{label:"Inferior",value:"bottom"},
                         {label:"Esquerda",value:"left"},{label:"Direita",value:"right"}]
            }]});
            return JSON.stringify({sections:sections});
        }
        function write(key: string, encoded: string): string {
            if (key.length>180 || encoded.length>2048) return "REJECTED";
            if (key==="__bar_position__") {
                let v;try{v=JSON.parse(encoded).value;}catch(e){return "REJECTED";}
                if (!["top","bottom","left","right"].includes(v))return "REJECTED";
                Config.options.bar.vertical=v==="left"||v==="right";
                Config.options.bar.bottom=v==="bottom"||v==="right";
                return "OK";
            }
            for (const section of hyprEndfieldCatalog.sections) for (const card of section.cards) {
                if (card.key !== key || !permitted(key,card.type)) continue;
                const ctl=hyprEndfieldCatalog.controlFor(key);
                if (!ctl || typeof ctl.get!=="function" || typeof ctl.set!=="function") return "REJECTED";
                let v;
                try { v=JSON.parse(encoded).value; } catch(e) {return "REJECTED";}
                const previous=ctl.get();
                if (typeof v !== typeof previous) return "REJECTED";
                if (typeof v==="string" && v.length>240) return "REJECTED";
                if (typeof v==="number" && (!Number.isFinite(v) || (ctl.from!==undefined&&v<ctl.from) || (ctl.to!==undefined&&v>ctl.to))) return "REJECTED";
                if (["select","combo"].includes(card.type) && !(ctl.options||[]).some(o=>o.value===v)) return "REJECTED";
                try {ctl.set(v);return "OK";}catch(e){return "ERROR";}
            }
            return "REJECTED";
        }
        function addScheme(): void {ColorSchemes.addScheme();}
        function openSchemes(): void {ColorSchemes.openFolder();}
        function reloadSchemes(): void {ColorSchemes.reload();}
        function setAccent(slot: string, name: string): void {
            if (["primary","secondary"].includes(slot) && /^[A-Za-z0-9_-]{1,80}$/.test(name))
                ColorSchemes.setAccent(slot,name,false);
        }
    }

    // HYPR_ENDFIELD_BRIDGE_STAGE18A: controla temas pelo serviço EXISTENTE,
    // nunca escreve config.json diretamente e nunca modifica a paleta do HUD.
    IpcHandler {
        target: "hyprendfieldBridge"
        function setScheme(id: string): void {
            const scheme = id === "__material__" ? "" : id;
            if (scheme !== "" && !ColorSchemes.schemeIds.includes(scheme)) {
                console.warn("HyprEndfield: esquema indisponível:", scheme);
                return;
            }
            ColorSchemes.setScheme(scheme, false);
        }
    }

    IpcHandler {
        target: "hyprendfieldSettings"
        function useQuickshell(): void {
            const current = String(Config.options.settings.style);
            const previous = current.indexOf("endfield-") === 0 ? current.slice(9) : current;
            Config.options.settings.style = (["default", "minimal", "dashboard"].includes(previous) ? previous : "dashboard");
            GlobalStates.settingsOpen = true;
        }
    }

    Dashboard {}

    PanelWindow {
        id: panelWindow
        visible: GlobalStates.settingsOpen && Config.options.settings.style !== "dashboard" && !root.endfieldSelected

        function hide() {
            GlobalStates.settingsOpen = false;
        }

        exclusiveZone: 0
        WlrLayershell.namespace: "quickshell:settings"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: GlobalStates.settingsOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        onVisibleChanged: {
            if (visible) {
                GlobalFocusGrab.addDismissable(panelWindow);
                settingsWindow.userMoved = false;
            } else {
                GlobalFocusGrab.removeDismissable(panelWindow);
            }
        }

        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                if (panelWindow.visible) panelWindow.hide();
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            opacity: GlobalStates.settingsOpen ? 1 : 0
            z: 0
            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            MouseArea {
                anchors.fill: parent
                propagateComposedEvents: false
                onClicked: panelWindow.hide()
            }
        }

        Rectangle {
            id: settingsWindow
            width: Config.options.settings.style === "minimal" ? Math.min(parent.width - 70, 980 * sizeScale) : Math.min(parent.width - 80, 980 * sizeScale)
            height: Math.min(parent.height - 80, 665 * sizeScale)
            color: Appearance.colors.colUiBackground
            border.width: Config.options.settings.borderSize
            border.color: CF.ColorUtils.transparentize(Appearance.getColorFromName(Config.options.settings.borderColor), 0.8)
            radius: !isMinimal ? Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 5 : Appearance.rounding.screenRounding + 5
            z: 1

            property bool userMoved: false
            anchors.centerIn: userMoved ? undefined : parent

            opacity: GlobalStates.settingsOpen ? 1 : 0
            scale: GlobalStates.settingsOpen ? 1 : 0.95

            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            Keys.onTabPressed: (event) => {
            const count = settingsContent.pages.length;
            settingsContent.currentPage = (settingsContent.currentPage + 1) % count;
            settingsContent.showingProfile = false;
            event.accepted = true;
        }

        Keys.onBacktabPressed: (event) => {
            const count = settingsContent.pages.length;
            settingsContent.currentPage = (settingsContent.currentPage - 1 + count) % count;
            settingsContent.showingProfile = false;
            event.accepted = true;
        }

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                panelWindow.hide();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                const instance = GlobalStates.currentPageInstance;
                if (instance && instance.contentY !== undefined) {
                    const step = 60;
                    const delta = event.key === Qt.Key_Down ? step : -step;
                    const maxY = Math.max(0, (instance.contentHeight ?? 0) - instance.height);
                    instance.contentY = Math.max(0, Math.min(maxY, instance.contentY + delta));
                }
                event.accepted = true;
                return;
            }
        }

            Rectangle {
                id: dragHandle
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 32
                color: "transparent"
                z: 2

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SizeAllCursor
                    drag.target: settingsWindow
                    drag.axis: Drag.XAndYAxis
                    onPressed: settingsWindow.userMoved = true
                    onDoubleClicked: settingsWindow.userMoved = false
                }
            }

            SettingsContent {
                id: settingsContent
                anchors.fill: parent
            }
        }
    }

    IpcHandler {
        target: "settings"
        function toggle(): void { GlobalStates.settingsOpen = !GlobalStates.settingsOpen; }
        function open(): void   { GlobalStates.settingsOpen = true; }
        function close(): void  { GlobalStates.settingsOpen = false; }
    }

    CompositorGlobalShortcut {
        name: "settingsToggle"
        description: "Toggles settings panel"
        onPressed: GlobalStates.settingsOpen = !GlobalStates.settingsOpen;
    }
    // Super + / : abrir/fechar a pagina de atalhos do Dashboard
    CompositorGlobalShortcut {
        name: "cheatsheetToggle"
        description: "Toggle bilingual shortcut guide"
        onPressed: {
            if (GlobalStates.settingsOpen && GlobalStates.dashboardPage === 5) {
                GlobalStates.settingsOpen = false;
            } else {
                GlobalStates.dashboardPage = 5;
                GlobalStates.settingsOpen = true;
            }
        }
    }

}