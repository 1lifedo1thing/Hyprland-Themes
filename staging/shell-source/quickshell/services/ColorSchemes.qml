pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    readonly property string scriptPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/colors/named_scheme.py`)
    readonly property string userDir: FileUtils.trimFileProtocol(`${Directories.shellConfig}/schemes`)
    readonly property string templatePath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/colors/schemes/_template.json`)
    property var schemes: ({})
    readonly property var schemeIds: Object.keys(root.schemes)

    readonly property string current: Config.options.appearance.palette.namedScheme
    readonly property var currentData: root.schemes[root.current] ?? null

    function schemeOptions() {
        const options = [{ displayName: "Material", value: "" }]
        for (const id of root.schemeIds)
            options.push({ displayName: root.schemes[id].name, value: id })
        return options
    }

    function materialPreview() {
        const colors = Appearance.colors
        return [
            { value: "primary", color: colors.colPrimary, displayName: "Primary" },
            { value: "secondary", color: colors.colSecondary, displayName: "Secondary" },
            { value: "tertiary", color: colors.colTertiary, displayName: "Tertiary" },
            { value: "primaryContainer", color: colors.colPrimaryContainer, displayName: "Primary container" },
            { value: "secondaryContainer", color: colors.colSecondaryContainer, displayName: "Secondary container" },
            { value: "tertiaryContainer", color: colors.colTertiaryContainer, displayName: "Tertiary container" },
            { value: "error", color: colors.colError, displayName: "Error" }
        ]
    }

    function accentOptions() {
        const data = root.currentData
        if (!data) return root.materialPreview()
        const accents = data.accents[Appearance.m3colors.darkmode ? "dark" : "light"]
        return Object.keys(accents).map(name => ({
            value: name,
            color: accents[name],
            displayName: name.charAt(0).toUpperCase() + name.slice(1)
        }))
    }

    function currentAccent(slot) {
        const data = root.currentData
        if (!data) return slot === "primary" ? "primary" : "secondary"
        const chosen = Config.options.appearance.palette[slot === "primary" ? "namedSchemePrimary" : "namedSchemeSecondary"]
        const accents = data.accents[Appearance.m3colors.darkmode ? "dark" : "light"]
        return chosen in accents ? chosen : data.defaults[slot]
    }

    property var pendingArgs: []
    // END4_AUTO_SELECT_SAVED_COLOR_V3
    property string pendingSavedAccentSchemeId: ""

    function run(args, closeSettings = true) {
        const shouldClose = closeSettings && Config.options.settings.style !== "dashboard"
        root.pendingArgs = args
        if (shouldClose) GlobalStates.settingsOpen = false
        applyTimer.interval = shouldClose ? 800 : 100
        applyTimer.restart()
    }

    // END4_COLORS_APPLY_AFTER_PROCESS_V2
    // Apply only after the palette generator finishes; don't trust file watches alone.
    Process {
        id: paletteApplyProcess
        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("[ColorSchemes] Failed to apply color scheme, exit code:", exitCode)
                return
            }
            // A collage theme may change without background.wallpaperPath changing.
            // Explicitly switch back to the live palette and request a reload.
            MaterialThemeLoader.useLiveTheme()
            MaterialThemeLoader.reapplyTheme()
            // END4_AUTO_SELECT_SAVED_COLOR_V3: replica um clique no ponto da cor primaria
            // apos o gerador terminar. A flag e consumida antes do clique: sem loop.
            const selectedScheme = root.pendingSavedAccentSchemeId
            root.pendingSavedAccentSchemeId = ""
            if (selectedScheme !== "" && root.current === selectedScheme) {
                const data = root.schemes[selectedScheme]
                const savedPrimary = data && data.defaults ? data.defaults.primary : ""
                if (savedPrimary) {
                    console.log("[ColorSchemes] Selecionando cor salva", selectedScheme, savedPrimary)
                    root.setAccent("primary", savedPrimary, false)
                } else {
                    console.warn("[ColorSchemes] Cor primaria nao disponivel para", selectedScheme)
                }
            }
        }
    }

    Timer {
        id: applyTimer
        interval: 800
        onTriggered: {
            const normalWallpaper = Config.options.background.wallpaperPath
            const colorSource = Collage.enabled && Collage.primaryImage
                ? Collage.primaryImage : normalWallpaper
            paletteApplyProcess.running = false
            paletteApplyProcess.command = [
                "bash", FileUtils.trimFileProtocol(Directories.wallpaperSwitchScriptPath),
                "--noswitch", "--image", colorSource, ...root.pendingArgs
            ]
            paletteApplyProcess.running = true
        }
    }

    // BEGIN END4_KITTY_DIRECT_SYNC_V2
    // Usa o ID clicado: independe de notificacoes do arquivo config.json.
    property string pendingTerminalSchemeId: ""
    Timer {
        id: directTerminalSchemeSyncTimer
        interval: 280
        repeat: false
        onTriggered: {
            Quickshell.execDetached([
                "python3",
                (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config"))
                    + "/illogical-impulse/terminal_theme_manager.py",
                "sync",
                root.pendingTerminalSchemeId
            ])
        }
    }
    // END END4_KITTY_DIRECT_SYNC_V2

    // END4_COLLAGE_PER_THEME_V4: same-memory switch before wallpaper color generation.


    function setScheme(id, closeSettings = true) {
        // Preserve the previous layout and restore the target before changing the palette.
        if (id !== root.current) {
            Collage.switchToScheme(id)
            Config.options.appearance.palette.namedScheme = id
            Config.options.appearance.palette.namedSchemePrimary = ""
            Config.options.appearance.palette.namedSchemeSecondary = ""
        }
        // Reaplicar a cor salva do novo tema apos o processo finalizar.
        root.pendingSavedAccentSchemeId = id
        root.run(["--scheme-name", id === "" ? "clear" : id], closeSettings)
        // Keep the existing terminal profile sync independent of the collage.
        root.pendingTerminalSchemeId = id
        directTerminalSchemeSyncTimer.restart()
    }

    function setAccent(slot, name, closeSettings = true) {
        if (root.current === "") return
        root.run(["--scheme-name", root.current, slot === "primary" ? "--scheme-primary" : "--scheme-secondary", name], closeSettings)
    }

    function reload() {
        listProc.running = false
        listProc.running = true
    }

    function openFolder() {
        GlobalStates.settingsOpen = false
        Quickshell.execDetached(["bash", "-c",
            `mkdir -p "${root.userDir}" && cp -n "${root.templatePath}" "${root.userDir}/_template.json"; xdg-open "${root.userDir}"`])
    }

    function addScheme() {
        GlobalStates.settingsOpen = false
        pickTimer.restart()
    }

    Timer {
        id: pickTimer
        interval: 500
        onTriggered: {
            pickProc.running = false
            pickProc.running = true
        }
    }

    Process {
        id: pickProc
        command: ["kdialog", "--getopenfilename", Quickshell.env("HOME"), "application/json"]
        stdout: StdioCollector { id: pickOutput }
        onExited: code => {
            const path = pickOutput.text.trim()
            if (code !== 0 || path === "") return
            importProc.command = ["python3", root.scriptPath, "--import-file", path]
            importProc.running = true
        }
    }

    Process {
        id: importProc
        stdout: StdioCollector { id: importOutput }
        stderr: StdioCollector { id: importError }
        onExited: code => {
            if (code === 0) {
                root.reload()
                Quickshell.execDetached(["notify-send", Translation.tr("Color scheme added"), importOutput.text.trim(), "-a", "Shell"])
            } else {
                Quickshell.execDetached(["notify-send", Translation.tr("Invalid color scheme"), importError.text.trim(), "-a", "Shell", "-u", "critical"])
            }
        }
    }

    Process {
        id: listProc
        command: ["python3", root.scriptPath, "--list"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.schemes = JSON.parse(text)
                } catch (e) {
                    console.warn("[ColorSchemes] could not parse scheme list:", e)
                }
            }
        }
    }
}
