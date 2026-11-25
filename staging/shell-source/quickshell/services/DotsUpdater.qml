pragma Singleton

import qs
import QtQuick
import Quickshell

Singleton {
    id: root

    function runSystemUpdate() {
        Quickshell.execDetached([
            "kitty", "--hold",
            "fish", "-i", "-l", "-c",
            "yay -Syu --combinedupgrade=false"
        ])
        Qt.callLater(() => GlobalStates.settingsOpen = false)
    }

    function runUpdateDots() {
        Quickshell.execDetached([
            "notify-send", "Hyprland Themes",
            "Update the project checkout, prepare the pinned bases, and review ./setup update before applying.",
            "-a", "Hyprland Themes"
        ])
    }
}
