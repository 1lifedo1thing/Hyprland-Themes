import QtQuick
import QtQuick.Shapes
import QtQuick.Controls
import "Appearance.js" as Appearance

// HYPR_ENDFIELD_WALLPAPER_STAGE16
// Promotional area adapted into a wallpaper carousel. Only still previews:
// video thumbnails are produced by WallpaperController, never played in HUD.
Item {
    id: root
    width: 1920
    height: 1080
    readonly property var gallery: wallpaperController.state
    readonly property var entry: gallery.items.length > 0 ? gallery.items[gallery.index] : ({name: "", path: "", preview: "", video: false})
    readonly property bool activeWallpaper: !!entry.path && entry.path === gallery.activePath
    property bool expanded: false
    property bool colorsOpen: false // HYPR_ENDFIELD_SETTINGS_HUB_20A
    // O banner segue no plano 3D, mas a janela deve ficar no overlay 2D do Window.
    // Assim, a perspectiva do MenuPlane nunca inclina/escurece a tela toda.
    onExpandedChanged: {
        if (expanded) {
            wallpaperController.syncActive();
            galleryPopup.open();
        } else {
            root.colorsOpen = false;
            galleryPopup.close();
        }
    }
    Component.onCompleted: wallpaperController.refresh()
    Connections {
        target: appController
        function onHudOpenChanged() {
            if (appController.hudOpen) wallpaperController.syncActive();
            else root.expanded = false;
        }
    }
    Timer {
        interval: 6500; repeat: true
        running: appController.hudOpen && !root.expanded && !bannerHover.hovered && root.gallery.items.length > 1
        onTriggered: wallpaperController.next()
    }
    Timer {
        interval: 4000; repeat: true
        running: appController.hudOpen
        onTriggered: wallpaperController.syncActive()
    }

    // Place at the top-right, just above the original right-hand navigation.
    // Keep the HUD's established ink/accent palette unchanged.
    Item {
        id: banner
        objectName: "wallpaperBanner"
        x: 1530; y: 22; width: 355; height: 165
        HoverHandler { id: bannerHover }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 2
                strokeColor: Appearance.accent("#FFFA00")
                fillColor: Appearance.tone("#171719")
                PathSvg { path: "M12 0H339L355 15V151L342 165H0V14Z" }
            }
        }
        Item {
            x: 7; y: 18; width: 341; height: 119; clip: true
            Image {
                anchors.fill: parent
                source: root.entry.preview || ""
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                smooth: true; mipmap: true
                visible: status === Image.Ready
            }
            Rectangle { anchors.fill: parent; color: "#40000000" }
            Text {
                anchors.centerIn: parent
                visible: !root.entry.preview
                text: root.gallery.loading ? qsTr("加载壁纸...") : root.gallery.items.length === 0 ? qsTr("未找到壁纸") : qsTr("预览不可用")
                color: "#C4C4C4"; font.family: harmonyMedium.name; font.pixelSize: 15
            }
            Rectangle { x: 0; y: 0; width: 4; height: parent.height; color: Appearance.accent("#FFFA00"); opacity: .85 }
            Text {
                x: 14; y: 12; width: 292; elide: Text.ElideRight
                text: root.entry.name || "WALLPAPER"
                font.family: harmonyBold.name; font.pixelSize: 20; color: "#F7F7F4"
                style: Text.Outline; styleColor: "#55000000"
            }
            Text {
                x: 15; y: 40
                text: root.entry.video ? "VIDEO · PREVIEW" : "IMAGE · PREVIEW"
                font.family: harmonyMedium.name; font.pixelSize: 11; color: Appearance.accent("#FFFA00")
            }
            Rectangle {
                x: 14; y: 88; width: 95; height: 20; radius: 2
                color: root.activeWallpaper ? Appearance.accent("#FFFA00") : "#A5202020"
                Text { anchors.centerIn: parent; text: root.activeWallpaper ? "ATIVO" : "VISUALIZAR"; color: root.activeWallpaper ? "#111111" : "#F0F0F0"; font.family: harmonyBold.name; font.pixelSize: 10 }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { if (root.gallery.items.length) root.expanded = true; }
            }
        }
        Text {
            x: 14; y: 1; text: "// WALLPAPER SELECTOR"
            color: Appearance.accent("#FFFA00"); font.family: harmonyBold.name; font.pixelSize: 10; font.letterSpacing: 1.2
        }
        Rectangle { x: 10; y: 143; width: 335; height: 16; color: "#25000000" }
        Text {
            x: 17; y: 145; width: 205; elide: Text.ElideRight
            text: root.gallery.items.length ? (root.gallery.index + 1) + " / " + root.gallery.items.length + "   //  CLICAR PARA ABRIR" : "//  SEM IMAGENS"
            color: "#BCBDB8"; font.family: harmonyMedium.name; font.pixelSize: 10
        }
        Rectangle {
            x: 277; y: 140; width: 32; height: 22; color: leftArrow.containsMouse ? Appearance.accent("#FFFA00") : "#404040"; radius: 2
            Text { anchors.centerIn: parent; text: "‹"; color: leftArrow.containsMouse ? "#111111" : "#F2F2F2"; font.pixelSize: 19 }
            MouseArea { id: leftArrow; anchors.fill: parent; hoverEnabled: true; enabled: root.gallery.items.length > 1; cursorShape: Qt.PointingHandCursor; onClicked: wallpaperController.previous() }
        }
        Rectangle {
            x: 314; y: 140; width: 32; height: 22; color: rightArrow.containsMouse ? Appearance.accent("#FFFA00") : "#404040"; radius: 2
            Text { anchors.centerIn: parent; text: "›"; color: rightArrow.containsMouse ? "#111111" : "#F2F2F2"; font.pixelSize: 19 }
            MouseArea { id: rightArrow; anchors.fill: parent; hoverEnabled: true; enabled: root.gallery.items.length > 1; cursorShape: Qt.PointingHandCursor; onClicked: wallpaperController.next() }
        }
    }

    // HYPR_ENDFIELD_WALLPAPER_POLISH_STAGE16A
    // Popup.Item vive em Overlay.overlay (window real): sem plano 3D por trás.
    Popup {
        id: galleryPopup
        parent: Overlay.overlay
        popupType: Popup.Item
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        width: parent ? Math.min(800, Math.max(300, parent.width - 36)) : 800
        height: parent ? Math.min(598, Math.max(310, parent.height - 36)) : 598
        padding: 0
        modal: true
        dim: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        Overlay.modal: Rectangle { color: "#94000000" }
        onClosed: { if (root.expanded) root.expanded = false; }

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 190; easing.type: Easing.OutCubic }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 130 }
        }

        background: Rectangle {
            color: Appearance.tone("#171719")
            border.width: 1
            border.color: Appearance.accent("#FFFA00")
        }
        contentItem: Item {
            id: popupContent
            implicitWidth: 800
            implicitHeight: 598
            readonly property real sizeFactor: Math.min(width / 800, height / 598)

            Item {
                id: dialog
                width: 800; height: 598
                transformOrigin: Item.TopLeft
                scale: popupContent.sizeFactor
                x: (popupContent.width - 800 * popupContent.sizeFactor) / 2
                y: (popupContent.height - 598 * popupContent.sizeFactor) / 2

                // Cabeçalho técnico — paleta original, menos amarelo chapado.
                Rectangle { x: 0; y: 0; width: 800; height: 5; color: Appearance.accent("#FFFA00") }
                Rectangle { x: 1; y: 5; width: 798; height: 64; color: Appearance.tone("#202022") }
                Text {
                    x: 25; y: 17; text: "// WALLPAPER GALLERY"
                    color: "#F2F2EE"; font.family: harmonyBold.name
                    font.pixelSize: 22; font.letterSpacing: 1.1
                }
                Text {
                    x: 26; y: 47; text: "DESKTOP / PERSONALIZAÇÃO"
                    color: "#999B98"; font.family: harmonyMedium.name
                    font.pixelSize: 10; font.letterSpacing: 2
                }
                Text {
                    x: 640; y: 43; width: 95; horizontalAlignment: Text.AlignRight
                    text: "GALERIA  //  016"
                    color: "#777A75"; font.family: harmonyMedium.name; font.pixelSize: 10
                }
                Rectangle {
                    x: 745; y: 18; width: 34; height: 32
                    color: closePointer.containsMouse ? Appearance.accent("#FFFA00") : "#2F3030"
                    border.color: closePointer.containsMouse ? Appearance.accent("#FFFA00") : "#515351"
                    Text { anchors.centerIn: parent; text: "×"; color: closePointer.containsMouse ? "#111111" : "#E8E8E5"; font.pixelSize: 25 }
                    MouseArea { id: closePointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.expanded = false }
                }
                // HYPR_ENDFIELD_SETTINGS_HUB_20A: cores e papéis na mesma galeria.
                Rectangle {
                    x: 488; y: 30; width: 140; height: 31
                    color: root.colorsOpen ? Appearance.accent("#FFFA00") : "#303032"
                    border.color: root.colorsOpen ? Appearance.accent("#FFFA00") : "#646464"
                    Text { anchors.centerIn:parent; text:root.colorsOpen ? "← WALLPAPERS" : "CORES & PALETAS"; color:root.colorsOpen ? "#141414" : "#EEEEEE"; font.family:harmonyBold.name; font.pixelSize:11 }
                    MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked:root.colorsOpen=!root.colorsOpen }
                }
                Rectangle { x: 0; y: 69; width: 800; height: 1; color: "#3A3B39" }

                // Prévia original inteira; o vídeo nunca é reproduzido no seletor.
                Rectangle {
                    id: previewSurface
                    x: 22; y: 84; width: 756; height: 346
                    color: "#101011"; border.color: "#41423F"; border.width: 1
                    Item {
                        x: 1; y: 1; width: 754; height: 344; clip: true
                        Image {
                            id: galleryImage
                            anchors.fill: parent
                            source: root.entry.preview || ""
                            asynchronous: true
                            fillMode: Image.PreserveAspectFit
                            smooth: true; mipmap: true
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: galleryImage.status !== Image.Ready
                            text: root.gallery.loading ? qsTr("Carregando prévia...") : qsTr("Miniatura indisponível")
                            color: "#B5B8B4"; font.family: harmonyMedium.name; font.pixelSize: 14
                        }
                        Rectangle {
                            x: 12; y: 12; width: root.entry.video ? 84 : 88; height: 24
                            color: "#C9101011"; border.color: "#80807C"; border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: root.entry.video ? "◼  VIDEO" : "▣  IMAGE"
                                color: "#F3F3F0"; font.family: harmonyBold.name; font.pixelSize: 11
                            }
                        }
                        Rectangle {
                            x: 12; y: 312; width: 140; height: 24
                            visible: root.activeWallpaper
                            color: Appearance.accent("#FFFA00")
                            Text { anchors.centerIn: parent; text: "●  EM USO"; color: "#171717"; font.family: harmonyBold.name; font.pixelSize: 11 }
                        }
                    }
                }
                Rectangle { x: 22; y: 441; width: 18; height: 3; color: Appearance.accent("#FFFA00") }
                Rectangle { x: 43; y: 442; width: 735; height: 1; color: "#41423F" }

                Text {
                    x: 23; y: 457; width: 710; elide: Text.ElideRight
                    text: root.entry.name || qsTr("Nenhum wallpaper encontrado")
                    color: "#F1F1ED"; font.family: harmonyBold.name; font.pixelSize: 23
                }
                Text {
                    x: 24; y: 490; width: 550; elide: Text.ElideRight
                    text: root.entry.video ? "VÍDEO  /  Prévia estática — animação somente no desktop" : "IMAGEM  /  Wallpaper estático"
                    color: "#A8AAA5"; font.family: harmonyRegular.name; font.pixelSize: 12
                }
                Text {
                    x: 588; y: 491; width: 188; horizontalAlignment: Text.AlignRight
                    text: root.gallery.items.length ? (root.gallery.index + 1) + " / " + root.gallery.items.length : "0 / 0"
                    color: Appearance.accent("#FFFA00"); font.family: harmonyBold.name; font.pixelSize: 15
                }
                Text {
                    x: 23; y: 515; width: 752; elide: Text.ElideRight
                    text: root.gallery.error || root.gallery.message || ""
                    visible: !!(root.gallery.error || root.gallery.message)
                    color: root.gallery.error ? "#FF8686" : "#B4B4AD"
                    font.family: harmonyMedium.name; font.pixelSize: 11
                }
                Rectangle { x: 1; y: 536; width: 798; height: 61; color: Appearance.tone("#202022") }
                Rectangle { x: 1; y: 535; width: 798; height: 1; color: "#42433F" }

                Rectangle {
                    x: 23; y: 548; width: 68; height: 37
                    color: prevPointer.containsMouse ? Appearance.accent("#FFFA00") : "#363735"
                    border.color: "#575955"
                    opacity: root.gallery.items.length > 1 ? 1 : .4
                    Text { anchors.centerIn: parent; text: "‹"; font.pixelSize: 27; color: prevPointer.containsMouse ? "#111111" : "#F1F1EF" }
                    MouseArea { id: prevPointer; anchors.fill: parent; hoverEnabled: true; enabled: root.gallery.items.length > 1; cursorShape: Qt.PointingHandCursor; onClicked: wallpaperController.previous() }
                }
                Rectangle {
                    x: 101; y: 548; width: 68; height: 37
                    color: nextPointer.containsMouse ? Appearance.accent("#FFFA00") : "#363735"
                    border.color: "#575955"
                    opacity: root.gallery.items.length > 1 ? 1 : .4
                    Text { anchors.centerIn: parent; text: "›"; font.pixelSize: 27; color: nextPointer.containsMouse ? "#111111" : "#F1F1EF" }
                    MouseArea { id: nextPointer; anchors.fill: parent; hoverEnabled: true; enabled: root.gallery.items.length > 1; cursorShape: Qt.PointingHandCursor; onClicked: wallpaperController.next() }
                }
                Rectangle {
                    x: 183; y: 548; width: 117; height: 37
                    color: reloadPointer.containsMouse ? "#4B4C48" : "#343533"
                    border.color: "#555653"
                    Text { anchors.centerIn: parent; text: "ATUALIZAR"; color: "#F0F0EA"; font.family: harmonyMedium.name; font.pixelSize: 12 }
                    MouseArea { id: reloadPointer; anchors.fill: parent; hoverEnabled: true; enabled: !root.gallery.busy && !root.gallery.loading; cursorShape: Qt.PointingHandCursor; onClicked: wallpaperController.refresh() }
                }
                Rectangle {
                    x: 528; y: 545; width: 250; height: 41
                    color: root.gallery.busy || root.activeWallpaper ? "#565751" : Appearance.accent("#FFFA00")
                    Text {
                        anchors.centerIn: parent
                        text: root.gallery.busy ? "APLICANDO..." : root.activeWallpaper ? "JÁ ESTÁ ATIVO" : "APLICAR WALLPAPER"
                        color: "#111111"; font.family: harmonyBold.name; font.pixelSize: 14
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        enabled: !root.gallery.busy && !root.gallery.loading && !!root.entry.path && !root.activeWallpaper
                        onClicked: wallpaperController.applySelected()
                    }
                }
                // HYPR_ENDFIELD_SETTINGS_HUB_20A — paletas no mesmo popup 2D.
                QuickshellColorsPanel {
                    x: 1; y: 70; width: 798; height: 527; z: 55
                    visible: root.colorsOpen
                }
            }
        }
    }
}
