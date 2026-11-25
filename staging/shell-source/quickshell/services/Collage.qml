pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.services

Singleton {
    id: root

    readonly property var settings: Config.options.background.collage
    // END4_COLLAGE_PER_THEME_V4
    // One active collage is rendered; each named color scheme has its own persisted snapshot.
    // Changes are made in the same JsonAdapter as the active theme: no external Python race.
    property bool profileReady: false
    property bool restoringProfile: false
    property string currentProfileKey: ""

    function profileKey(scheme) {
        const name = (scheme ?? "").toString()
        return name === "" ? "__material__" : name
    }

    function profiles() {
        try {
            const parsed = JSON.parse(root.settings.themeProfiles || "{}")
            if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) return parsed
        } catch (error) {
            console.warn("[Collage] Invalid themeProfiles JSON:", error)
        }
        return ({})
    }

    // END4_COLLAGE_PER_THEME_V5: consultar sempre o perfil salvo do tema.
    function enabledForProfile(key) {
        const profile = root.profiles()[key]
        return !!profile && profile.enable === true
    }

    // Atualiza o perfil atual e, por compatibilidade, a projeção global.
    function setEnabled(checked) {
        if (!root.profileReady) root.initializeProfiles()
        if (!root.profileReady) return
        const key = root.profileKey(Config.options.appearance.palette.namedScheme)
        if (root.currentProfileKey !== key) root.switchToScheme(key)
        const all = root.profiles()
        const existing = all[key] || root.blankProfile()
        existing.enable = checked === true
        all[key] = existing
        root.settings.themeProfiles = JSON.stringify(all)
        root.settings.enable = checked === true
    }

    function snapshot() {
        return {
            enable: root.enabledForProfile(root.currentProfileKey),
            gap: root.settings.gap,
            margin: root.settings.margin,
            radius: root.settings.radius,
            primaryId: root.settings.primaryId,
            nextId: root.settings.nextId,
            tree: root.settings.tree
        }
    }

    function blankProfile() {
        return {
            enable: false,
            gap: 30, margin: 30, radius: 30,
            primaryId: 1, nextId: 2,
            tree: JSON.stringify({ t: "leaf", id: 1, img: "" })
        }
    }

    function restore(profile) {
        const defaults = root.blankProfile()
        const p = profile && typeof profile === "object" ? profile : defaults
        root.settings.enable = p.enable === true
        root.settings.gap = typeof p.gap === "number" ? p.gap : defaults.gap
        root.settings.margin = typeof p.margin === "number" ? p.margin : defaults.margin
        root.settings.radius = typeof p.radius === "number" ? p.radius : defaults.radius
        root.settings.primaryId = Number.isInteger(p.primaryId) ? p.primaryId : 1
        root.settings.nextId = Number.isInteger(p.nextId) ? p.nextId : 2
        root.settings.tree = typeof p.tree === "string" ? p.tree : defaults.tree
    }

    // END4_COLLAGE_ISOLAMENTO_V7: cada perfil e a fonte oficial da arvore.
    // Nao copiar para ele uma arvore global possivelmente recarregada por outro processo.
    function storeActiveProfile() {
        if (!root.profileReady || root.restoringProfile) return
        if (root.profileKey(Config.options.appearance.palette.namedScheme) !== root.currentProfileKey) return
        const all = root.profiles()
        const existing = all[root.currentProfileKey]
        const next = root.snapshot()
        if (existing && typeof existing.tree === "string") next.tree = existing.tree
        all[root.currentProfileKey] = next
        root.settings.themeProfiles = JSON.stringify(all)
    }

    function initializeProfiles() {
        if (!Config.ready || root.profileReady) return
        root.restoringProfile = true
        root.currentProfileKey = root.profileKey(Config.options.appearance.palette.namedScheme)
        const all = root.profiles()
        if (Object.prototype.hasOwnProperty.call(all, root.currentProfileKey))
            root.restore(all[root.currentProfileKey])
        else
            all[root.currentProfileKey] = root.snapshot()
        root.settings.themeProfiles = JSON.stringify(all)
        root.profileReady = true
        root.restoringProfile = false
    }

    function switchToScheme(scheme) {
        if (!root.profileReady) root.initializeProfiles()
        if (!root.profileReady) return
        const next = root.profileKey(scheme)
        if (next === root.currentProfileKey) return
        root.restoringProfile = true
        const all = root.profiles()
        // As alteracoes intencionais ja foram gravadas no perfil pela propria edicao.
        // Nao sobrescrever o tema anterior a partir do espelho global.
        if (!Object.prototype.hasOwnProperty.call(all, root.currentProfileKey))
            all[root.currentProfileKey] = root.snapshot()
        root.currentProfileKey = next
        const target = Object.prototype.hasOwnProperty.call(all, next)
            ? all[next] : root.blankProfile()
        root.restore(target)
        all[next] = target
        root.settings.themeProfiles = JSON.stringify(all)
        root.restoringProfile = false
    }

    function syncActiveProjection() {
        if (!root.profileReady || root.restoringProfile) return
        const key = root.profileKey(Config.options.appearance.palette.namedScheme)
        if (root.currentProfileKey !== key) return
        const profile = root.profiles()[key]
        if (!profile || typeof profile.tree !== "string") return
        // Restaura depois do reload de um script de cores que deixou a arvore global antiga.
        if (root.settings.tree !== profile.tree) {
            root.restoringProfile = true
            root.restore(profile)
            root.restoringProfile = false
        }
    }

    Component.onCompleted: {
        if (Config.ready) root.initializeProfiles()
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) root.initializeProfiles()
        }
    }

    // Also support a scheme changed externally (not through the dashboard).
    Connections {
        target: Config.options.appearance.palette
        function onNamedSchemeChanged() {
            root.cropEditTileId = -1
            if (!Config.ready) return
            root.switchToScheme(Config.options.appearance.palette.namedScheme)
            // Aguarda todas as propriedades do reload externo terminarem de atualizar.
            Qt.callLater(() => root.syncActiveProjection())
        }
    }

    readonly property bool enabled: root.enabledForProfile(root.profileKey(Config.options.appearance.palette.namedScheme))
    readonly property int maxTiles: 6
    readonly property int gap: root.settings.gap
    readonly property int margin: root.settings.margin
    readonly property int radius: root.settings.radius
    readonly property int primaryId: root.settings.primaryId
    readonly property var tree: {
        try {
            return JSON.parse(root.settings.tree)
        } catch (error) {
            return { t: "leaf", id: 1, img: "" }
        }
    }
    readonly property int leafCount: root.countLeaves(root.tree)
    readonly property string primaryImage: root.imageForLeaf(root.findLeaf(root.tree, root.primaryId) ?? root.firstLeaf(root.tree))

    property bool dragging: false
    property var liveRatios: ({})

    // END4_CROP_PER_TILE_V2: somente estado da edição; o enquadramento é salvo na árvore.
    property int cropEditTileId: -1

    function toggleCropEdit(id) {
        root.cropEditTileId = root.cropEditTileId === id ? -1 : id
    }

    function clampCrop(value, fallback, low, high) {
        const number = Number(value)
        return Number.isFinite(number) ? Math.max(low, Math.min(high, number)) : fallback
    }

    // END4_CROP_OVERLAY_V4: pan direto, com captura de arrasto na camada do editor.
    // Estado temporário: nunca é persistido antes de soltar o mouse.
    property int cropDragTileId: -1
    property real liveCropPanX: 0
    property real liveCropPanY: 0

    // Ajustes antigos mantidos; a árvore só muda quando o mouse é solto.
    function setCrop(id, cropX, cropY, cropZoom, panX, panY) {
        const next = root.mapLeaf(root.tree, id, leaf => Object.assign({}, leaf, {
            cropX: Math.round(root.clampCrop(cropX, 0.5, 0, 1) * 10000) / 10000,
            cropY: Math.round(root.clampCrop(cropY, 0.5, 0, 1) * 10000) / 10000,
            cropZoom: Math.round(root.clampCrop(cropZoom, 1, 0.15, 6) * 10000) / 10000,
            cropPanX: Math.round(root.clampCrop(
                panX === undefined ? leaf.cropPanX : panX, 0, -20, 20) * 10000) / 10000,
            cropPanY: Math.round(root.clampCrop(
                panY === undefined ? leaf.cropPanY : panY, 0, -20, 20) * 10000) / 10000
        }))
        root.save(next)
    }

    function resetCrop(id) { root.setCrop(id, 0.5, 0.5, 1, 0, 0) }

    property bool armed: false
    property bool entranceActive: false
    property int entranceSerial: 0

    function armEntrance() {
        root.armed = true
        armTimer.restart()
    }

    function startEntrance(reason) {
        if (!root.armed || !root.enabled) return
        root.armed = false
        armTimer.stop()
        root.entranceActive = true
        root.entranceSerial += 1
        activeTimer.restart()
    }

    Timer {
        id: armTimer
        interval: 8000
        onTriggered: {
            root.armed = false
        }
    }

    Timer {
        id: activeTimer
        interval: 6000
        onTriggered: {
            root.entranceActive = false
        }
    }

    Connections {
        target: root.settings
        function onTreeChanged() {
            // Apenas Collage.save() grava uma arvore nova no perfil primeiro.
            // Uma escrita externa no config.json nao pode copiar outra arvore para o tema.
            if (root.profileReady && !root.restoringProfile
                    && root.profileKey(Config.options.appearance.palette.namedScheme) === root.currentProfileKey) {
                const profile = root.profiles()[root.currentProfileKey]
                if (profile && typeof profile.tree === "string"
                        && root.settings.tree !== profile.tree) {
                    root.restoringProfile = true
                    root.settings.tree = profile.tree
                    root.restoringProfile = false
                }
            }
            root.startEntrance("tree changed")
        }
        function onEnableChanged() {
            root.storeActiveProfile()
            root.startEntrance("enabled")
        }
        function onGapChanged() { root.storeActiveProfile() }
        function onMarginChanged() { root.storeActiveProfile() }
        function onRadiusChanged() { root.storeActiveProfile() }
        function onPrimaryIdChanged() { root.storeActiveProfile() }
        function onNextIdChanged() { root.storeActiveProfile() }
    }

    function countLeaves(node) {
        return node.t === "leaf" ? 1 : root.countLeaves(node.a) + root.countLeaves(node.b)
    }

    function firstLeaf(node) {
        return node.t === "leaf" ? node : root.firstLeaf(node.a)
    }

    function findLeaf(node, id) {
        if (node.t === "leaf") return node.id === id ? node : null
        return root.findLeaf(node.a, id) ?? root.findLeaf(node.b, id)
    }

    function imageForLeaf(leaf) {
        return leaf.img || Config.options.background.wallpaperPath
    }

    function barInsets(screenName) {
        const bar = Config.options.bar
        const frame = bar.showFrame ? bar.frameThickness : 0
        const insets = { left: frame, right: frame, top: frame, bottom: frame }
        const onScreen = bar.screenList.length === 0 || bar.screenList.includes(screenName)
        if (GlobalStates.barOpen && !GlobalStates.screenLocked && onScreen && !bar.autoHide.enable) {
            const thickness = bar.vertical ? Appearance.sizes.verticalBarWidth : Appearance.sizes.barHeight
            const edge = bar.vertical ? (bar.bottom ? "right" : "left") : (bar.bottom ? "bottom" : "top")
            insets[edge] = Math.max(insets[edge], thickness)
        }
        return insets
    }

    function layout(width, height, insets) {
        const leaves = []
        const splits = []
        const gap = root.gap
        const eps = 0.0005
        const margin = root.margin
        const x0 = margin + insets.left
        const y0 = margin + insets.top
        const areaWidth = Math.max(1, width - x0 - margin - insets.right)
        const areaHeight = Math.max(1, height - y0 - margin - insets.bottom)

        function walk(node, fx, fy, fw, fh, path) {
            if (node.t === "leaf") {
                const left = fx < eps ? 0 : gap / 2
                const right = fx + fw > 1 - eps ? 0 : gap / 2
                const top = fy < eps ? 0 : gap / 2
                const bottom = fy + fh > 1 - eps ? 0 : gap / 2
                leaves.push({
                    id: node.id,
                    src: root.imageForLeaf(node),
                    cropX: root.clampCrop(node.cropX, 0.5, 0, 1),
                    cropY: root.clampCrop(node.cropY, 0.5, 0, 1),
                    cropZoom: root.clampCrop(node.cropZoom, 1, 0.15, 6),
                    cropPanX: root.clampCrop(node.cropPanX, 0, -20, 20),
                    cropPanY: root.clampCrop(node.cropPanY, 0, -20, 20),
                    x: x0 + fx * areaWidth + left,
                    y: y0 + fy * areaHeight + top,
                    w: Math.max(1, fw * areaWidth - left - right),
                    h: Math.max(1, fh * areaHeight - top - bottom)
                })
                return
            }
            const ratio = root.liveRatios[path] ?? node.r
            const vertical = node.d === "v"
            const edgeStart = vertical ? (fy < eps ? 0 : gap / 2) : (fx < eps ? 0 : gap / 2)
            const edgeEnd = vertical ? (fy + fh > 1 - eps ? 0 : gap / 2) : (fx + fw > 1 - eps ? 0 : gap / 2)
            splits.push({
                path: path,
                d: node.d,
                r: ratio,
                fx: fx, fy: fy, fw: fw, fh: fh,
                line: vertical ? x0 + (fx + fw * ratio) * areaWidth : y0 + (fy + fh * ratio) * areaHeight,
                from: vertical ? y0 + fy * areaHeight + edgeStart : x0 + fx * areaWidth + edgeStart,
                to: vertical ? y0 + (fy + fh) * areaHeight - edgeEnd : x0 + (fx + fw) * areaWidth - edgeEnd
            })
            if (vertical) {
                walk(node.a, fx, fy, fw * ratio, fh, path + "a")
                walk(node.b, fx + fw * ratio, fy, fw * (1 - ratio), fh, path + "b")
            } else {
                walk(node.a, fx, fy, fw, fh * ratio, path + "a")
                walk(node.b, fx, fy + fh * ratio, fw, fh * (1 - ratio), path + "b")
            }
        }

        walk(root.tree, 0, 0, 1, 1, "")
        return { leaves: leaves, splits: splits, area: { x: x0, y: y0, w: areaWidth, h: areaHeight } }
    }

    function clone(node) {
        return JSON.parse(JSON.stringify(node))
    }

    function save(tree) {
        if (!root.profileReady) root.initializeProfiles()
        const key = root.profileKey(Config.options.appearance.palette.namedScheme)
        if (root.profileReady && root.currentProfileKey !== key) root.switchToScheme(key)
        const serialized = JSON.stringify(tree)
        if (root.profileReady && root.currentProfileKey === key) {
            // Grava primeiro no perfil do tema para onTreeChanged nao confundir com reload.
            const all = root.profiles()
            const profile = root.snapshot()
            profile.tree = serialized
            all[key] = profile
            root.settings.themeProfiles = JSON.stringify(all)
        }
        root.settings.tree = serialized
    }

    function mapLeaf(node, id, replacement) {
        if (node.t === "leaf") return node.id === id ? replacement(node) : node
        return { t: "split", d: node.d, r: node.r, a: root.mapLeaf(node.a, id, replacement), b: root.mapLeaf(node.b, id, replacement) }
    }

    function splitLeaf(id, direction) {
        if (root.leafCount >= root.maxTiles) return
        const newId = root.settings.nextId
        const next = root.mapLeaf(root.tree, id, leaf => ({
            t: "split", d: direction, r: 0.5,
            a: leaf,
            b: { t: "leaf", id: newId, img: root.imageForLeaf(leaf) }
        }))
        root.settings.nextId = newId + 1
        root.save(next)
    }

    function removeNode(node, id) {
        if (node.t === "leaf") return node
        if (node.a.t === "leaf" && node.a.id === id) return node.b
        if (node.b.t === "leaf" && node.b.id === id) return node.a
        return { t: "split", d: node.d, r: node.r, a: root.removeNode(node.a, id), b: root.removeNode(node.b, id) }
    }

    function removeLeaf(id) {
        if (root.leafCount <= 1) return
        const next = root.removeNode(root.tree, id)
        root.save(next)
        if (id === root.primaryId) root.setPrimary(root.firstLeaf(next).id)
    }

    function setRatio(path, ratio) {
        const next = root.clone(root.tree)
        let node = next
        for (const step of path) node = step === "a" ? node.a : node.b
        node.r = Math.max(0.15, Math.min(0.85, ratio))
        root.save(next)
    }

    function setImage(id, path) {
        root.save(root.mapLeaf(root.tree, id, leaf => ({ t: "leaf", id: leaf.id, img: path })))
    }

    function setPrimary(id) {
        root.settings.primaryId = id
    }

    function leaf() {
        return { t: "leaf" }
    }

    function split(d, r, a, b) {
        return { t: "split", d: d, r: r, a: a, b: b }
    }

    readonly property var presets: {
        const L = root.leaf
        const S = root.split
        return [
            { name: "duo", tree: S("v", 0.5, L(), L()) },
            { name: "stack", tree: S("h", 0.5, L(), L()) },
            { name: "heroLeft", tree: S("v", 0.62, L(), S("h", 0.5, L(), L())) },
            { name: "heroRight", tree: S("v", 0.38, S("h", 0.5, L(), L()), L()) },
            { name: "heroTop", tree: S("h", 0.6, L(), S("v", 0.5, L(), L())) },
            { name: "columns", tree: S("v", 0.333, L(), S("v", 0.5, L(), L())) },
            { name: "grid", tree: S("v", 0.5, S("h", 0.5, L(), L()), S("h", 0.5, L(), L())) },
            { name: "heroThree", tree: S("v", 0.6, L(), S("h", 0.333, L(), S("h", 0.5, L(), L()))) },
            { name: "mosaic", tree: S("v", 0.5, S("h", 0.5, L(), S("v", 0.5, L(), L())), S("h", 0.5, S("v", 0.5, L(), L()), L())) },
            { name: "sixGrid", tree: S("v", 0.333, S("h", 0.5, L(), L()), S("v", 0.5, S("h", 0.5, L(), L()), S("h", 0.5, L(), L()))) },
            { name: "triptychRows", tree: S("h", 0.333, L(), S("h", 0.5, L(), L())) },
            { name: "pillar", tree: S("v", 0.25, L(), S("v", 0.667, L(), L())) },
            { name: "heroBottom", tree: S("h", 0.62, S("v", 0.5, L(), L()), L()) },
            { name: "sidebarStack", tree: S("v", 0.3, S("h", 0.333, L(), S("h", 0.5, L(), L())), L()) },
            { name: "filmstrip", tree: S("h", 0.7, L(), S("v", 0.333, L(), S("v", 0.5, L(), L()))) },
            { name: "twinRail", tree: S("v", 0.7, S("h", 0.5, L(), L()), S("h", 0.25, L(), S("h", 0.333, L(), S("h", 0.5, L(), L())))) },
            { name: "topThree", tree: S("h", 0.5, S("v", 0.333, L(), S("v", 0.5, L(), L())), S("v", 0.5, L(), L())) },
            { name: "bigPlusFour", tree: S("v", 0.5, L(), S("h", 0.5, S("v", 0.5, L(), L()), S("v", 0.5, L(), L()))) },
            { name: "heroFive", tree: S("v", 0.5, L(), S("h", 0.5, S("v", 0.5, L(), L()), S("v", 0.333, L(), S("v", 0.5, L(), L())))) },
            { name: "cornerFour", tree: S("v", 0.5, L(), S("h", 0.5, L(), S("v", 0.5, L(), L()))) },
            { name: "wideBanner", tree: S("h", 0.3, L(), S("v", 0.5, L(), L())) },
            { name: "unevenRight", tree: S("v", 0.5, L(), S("h", 0.7, L(), L())) },
            { name: "unevenLeft", tree: S("v", 0.5, S("h", 0.35, L(), L()), L()) },
            { name: "railThree", tree: S("v", 0.35, L(), S("h", 0.333, L(), S("h", 0.5, L(), L()))) },
            { name: "fourColumns", tree: S("v", 0.5, S("v", 0.5, L(), L()), S("v", 0.5, L(), L())) },
            { name: "fourRows", tree: S("h", 0.5, S("h", 0.5, L(), L()), S("h", 0.5, L(), L())) },
            { name: "centerHero", tree: S("v", 0.25, S("h", 0.5, L(), L()), S("v", 0.667, L(), S("h", 0.5, L(), L()))) },
            { name: "heroTwoRows", tree: S("h", 0.55, L(), S("h", 0.5, S("v", 0.5, L(), L()), S("v", 0.5, L(), L()))) },
            { name: "cornerSix", tree: S("v", 0.6, S("h", 0.6, L(), S("v", 0.5, L(), L())), S("h", 0.333, L(), S("h", 0.5, L(), L()))) },
            { name: "staggered", tree: S("v", 0.5, S("h", 0.333, L(), S("h", 0.5, L(), L())), S("h", 0.5, L(), L())) }
        ]
    }

    function presetLabel(name) {
        const words = name.replace(/([A-Z])/g, " $1").toLowerCase()
        return words.charAt(0).toUpperCase() + words.slice(1)
    }

    readonly property var presetOptions: [{ displayName: Translation.tr("Custom"), value: "" }].concat(
        root.presets.map(preset => ({
            displayName: root.presetLabel(preset.name) + " (" + root.countLeaves(preset.tree) + ")",
            value: preset.name
        }))
    )

    readonly property string currentPreset: {
        const current = root.signature(root.tree)
        const match = root.presets.find(preset => root.signature(preset.tree) === current)
        return match ? match.name : ""
    }

    function applyPresetByName(name) {
        const match = root.presets.find(preset => preset.name === name)
        if (match) root.applyPreset(match.tree)
    }

    function signature(node) {
        if (node.t === "leaf") return "L"
        return node.d + Math.round(node.r * 100) + "(" + root.signature(node.a) + "," + root.signature(node.b) + ")"
    }

    function collectLeaves(node, out) {
        if (node.t === "leaf") out.push(node)
        else {
            root.collectLeaves(node.a, out)
            root.collectLeaves(node.b, out)
        }
        return out
    }

    function rects(node, x, y, w, h, out) {
        if (node.t === "leaf") {
            out.push({ x: x, y: y, w: w, h: h })
        } else if (node.d === "v") {
            root.rects(node.a, x, y, w * node.r, h, out)
            root.rects(node.b, x + w * node.r, y, w * (1 - node.r), h, out)
        } else {
            root.rects(node.a, x, y, w, h * node.r, out)
            root.rects(node.b, x, y + h * node.r, w, h * (1 - node.r), out)
        }
        return out
    }

    function applyPreset(spec) {
        const current = root.collectLeaves(root.tree, [])
        const primary = root.findLeaf(root.tree, root.primaryId) ?? current[0]
        // Mantém o enquadramento vinculado à imagem ao aplicar outro layout.
        const sources = [primary].concat(current.filter(l => l !== primary))
        let nextId = 1
        function assign(node) {
            if (node.t === "leaf") {
                const id = nextId++
                const original = sources[(id - 1) % sources.length]
                return {
                    t: "leaf", id: id, img: root.imageForLeaf(original),
                    cropX: root.clampCrop(original.cropX, 0.5, 0, 1),
                    cropY: root.clampCrop(original.cropY, 0.5, 0, 1),
                    cropZoom: root.clampCrop(original.cropZoom, 1, 0.15, 6),
                    cropPanX: root.clampCrop(original.cropPanX, 0, -20, 20),
                    cropPanY: root.clampCrop(original.cropPanY, 0, -20, 20)
                }
            }
            return { t: "split", d: node.d, r: node.r, a: assign(node.a), b: assign(node.b) }
        }
        const next = assign(spec)
        root.settings.nextId = nextId
        root.settings.primaryId = 1
        root.save(next)
    }

    function reset() {
        root.settings.nextId = 2
        root.settings.primaryId = 1
        root.save({ t: "leaf", id: 1, img: Config.options.background.wallpaperPath })
    }

    function isImagePath(path) {
        return /\.(png|jpe?g|webp|bmp|gif)$/i.test(path)
    }

    function dropImage(id, urls) {
        if (!urls || urls.length !== 1) return false
        const path = FileUtils.trimFileProtocol(decodeURIComponent(urls[0].toString()))
        if (!root.isImagePath(path)) return false
        root.setImage(id, path)
        return true
    }

    function dropShapeImage(urls) {
        if (!urls || urls.length !== 1) return false
        const path = FileUtils.trimFileProtocol(decodeURIComponent(urls[0].toString()))
        if (!root.isImagePath(path)) return false
        Config.options.background.centeredWallpaperImage = path
        return true
    }

    Process {
        id: pickProc
        property int tileId: -1
        stdout: StdioCollector {
            id: pickOutput
        }
        onExited: code => {
            if (code !== 0) return
            const path = pickOutput.text.trim()
            if (path !== "") root.setImage(pickProc.tileId, path)
        }
    }

    function pickImage(id) {
        const startDir = FileUtils.trimFileProtocol(Wallpapers.directory.toString()) || (Quickshell.env("HOME") + "/Pictures")
        pickProc.tileId = id
        pickProc.command = ["kdialog", "--getopenfilename", startDir, "image/png image/jpeg image/webp image/gif"]
        pickProc.running = true
    }

}
