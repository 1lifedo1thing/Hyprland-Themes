import QtQuick
import QtQuick.Layouts
import qs.modules.common

// Card acoplado ao DashboardSettingsPage.qml: herda as cores do painel;
// as cores mostradas na prévia do terminal continuam independentes.
Rectangle {
    id: root
    radius: 18
    color: Appearance.m3colors.m3surfaceContainerLow
    border.width: 1
    border.color: Appearance.colors.colOutlineVariant
    clip: true

    Flickable {
        id: viewport
        anchors.fill: parent
        anchors.margins: 12
        clip: true
        contentWidth: width
        contentHeight: editor.implicitHeight
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds

        TerminalThemeEditor {
            id: editor
            width: viewport.width
            height: implicitHeight
        }
    }
}
