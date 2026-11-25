pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

// END4_CONTRAST_V1
// Preferências de contraste independentes para cada ID de paleta.
Singleton {
    id: root

    readonly property string schemeId: Config.options.appearance.palette.namedScheme || "__material__"
    readonly property bool activeForScheme: schemeId !== "__material__"
    readonly property string configPath: Quickshell.env("HOME") + "/.config/illogical-impulse/theme-contrast.json"
    property var schemes: ({})
    readonly property var defaults: ({ automatic: true, opacity: 70, text: 85, preset: "medio" })
    readonly property var chosen: schemes[schemeId] ?? defaults
    readonly property bool automatic: chosen.automatic !== false
    readonly property int manualOpacity: Number(chosen.opacity ?? 70)
    readonly property int manualText: Number(chosen.text ?? 85)
    readonly property string preset: chosen.preset ?? "medio"

    property string statusMessage: ""
    property bool loadedOnce: false

    readonly property string wallpaperPath: Config.options.background.wallpaperPath ?? ""
    readonly property bool wallpaperIsVideo: /\.(mp4|webm|mkv|avi|mov)$/i.test(wallpaperPath)
    ColorQuantizer {
        id: wallpaperAnalysis
        source: Qt.resolvedUrl(root.wallpaperIsVideo
            ? Config.options.background.thumbnailPath : root.wallpaperPath)
        depth: 0
        rescaleSize: 10
    }
    readonly property real wallpaperLightness: {
        const color = wallpaperAnalysis.colors[0]
        const n = color ? color.hslLightness : 0.5
        return isFinite(n) ? Math.max(0, Math.min(1, n)) : 0.5
    }
    readonly property bool lightWallpaper: wallpaperLightness >= 0.58
    readonly property int effectiveOpacity: root.automatic
        ? Math.round(Math.max(54, Math.min(92, 50 + wallpaperLightness * 45)))
        : root.manualOpacity
    readonly property real contentTransparency: 1 - effectiveOpacity / 100
    readonly property real widgetOpacity: effectiveOpacity / 100
    readonly property real textStrength: root.automatic
        ? Math.max(0.6, Math.min(0.95, 0.68 + wallpaperLightness * 0.28))
        : Math.max(0, Math.min(1, root.manualText / 100))

    // Estima a cor visível atrás de uma camada. Não modifica o HEX do tema.
    function adjustedText(original, surface, overlayTransparency) {
        const fg = Qt.color(original)
        const bg = Qt.color(surface)
        const under = root.wallpaperLightness
        const k = Math.max(0, Math.min(1, overlayTransparency))
        const visible = (0.2126 * bg.r + 0.7152 * bg.g + 0.0722 * bg.b) * (1 - k) + under * k
        const target = visible > 0.54 ? Qt.color("#19202f") : Qt.color("#f8f5ff")
        const strength = root.textStrength
        return Qt.rgba(fg.r * (1-strength) + target.r*strength,
                       fg.g * (1-strength) + target.g*strength,
                       fg.b * (1-strength) + target.b*strength, fg.a)
    }

    function setValue(key, value) {
        // Sem trocar a paleta nem reescrever qualquer JSON do esquema de cores.
        const previous = root.schemes[root.schemeId] ?? root.defaults
        let next = Object.assign({}, previous)
        if (key === "automatic") next.automatic = Boolean(value)
        else if (key === "opacity") { next.opacity = Math.max(35, Math.min(100, Math.round(value))); next.automatic = false; next.preset = "custom" }
        else if (key === "text") { next.text = Math.max(0, Math.min(100, Math.round(value))); next.automatic = false; next.preset = "custom" }
        else if (key === "preset") {
            next.preset = value
            next.automatic = false
            const settings = ({suave:[55,65],medio:[72,82],forte:[92,100]})[value]
            if (settings) { next.opacity = settings[0]; next.text = settings[1] }
        }
        const snapshot = Object.assign({}, root.schemes)
        snapshot[root.schemeId] = next
        root.schemes = snapshot
        saveLater.restart()
    }

    Timer {
        id: saveLater
        interval: 320
        repeat: false
        onTriggered: {
            try {
                stateFile.setText(JSON.stringify({version: 1, schemes: root.schemes}, null, 2) + "\n")
                root.statusMessage = "Preferências salvas para " + root.schemeId
            } catch (e) { root.statusMessage = "Falha ao salvar: " + e }
        }
    }

    FileView {
        id: stateFile
        path: root.configPath
        watchChanges: true
        printErrors: false
        onFileChanged: {
            if (!saveLater.running) stateFile.reload()
        }
        onLoaded: {
            // Evita sobrescrever uma alteração local enquanto ela está sendo salva.
            if (saveLater.running) return
            try {
                const parsed = JSON.parse(text())
                if (parsed && typeof parsed.schemes === "object" && !Array.isArray(parsed.schemes))
                    root.schemes = parsed.schemes
                root.loadedOnce = true
            } catch (e) {
                root.statusMessage = "Arquivo de contraste inválido; sem sobrescrever dados."
            }
        }
        onSaveFailed: error => root.statusMessage = "Falha ao salvar contraste: " + error
    }
}
