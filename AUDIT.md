# Stage 1 — private audit snapshot

75/75 manifest SHA-256 values matched. All 18 original review alerts were inspected: 8 credential-related strings were UI text/examples or a passwd command; 5 generic path examples; 5 occurrences of a personal path (three source occurrences, two duplicates in the original patch). No actual credentials identified in those alerts. This is not a guarantee of secret-free source.

Three personal path examples in two source files were generalized. Original raw patch and manifest are deliberately not distributed here; regenerate diff from the clean source and the pinned base. ColorWheelSpectrum.png is omitted pending provenance confirmation; its QML reference remains, so this bundle is NOT installable.

The exported shell is based on pctrade commit 8fbb6716cba628a13103e665e9538021683a7250. Missing complete upstream tree, terminal helpers (terminal_theme_manager.py, kitty_paleta_auto.py), current Hyprland/Kitty/Fish/Fastfetch/Rofi/Matugen configs, optional HyprEndfield code, actual wallpaper layout profiles, and redistribution rights for artwork. The local config.json and user wallpaper profiles intentionally remain private.

Potential conflict: switchwall.sh now chooses a matching scheme directly, while end4-wallpaper-theme can separately write namedScheme from the saved associations. Retain for analysis, do not enable both blindly. The older collage_por_tema.py uses a separate registry; QML currently owns themeProfiles. Do not deploy that old script as a second writer.

Static checks on supplied source: Bash syntax, Python AST parsing, JSON parsing passed. No QML/runtime/VM tests yet. Additional font notices include OFL 1.1 and Apache 2.0; shapes LICENSE is Apache 2.0. Preserve applicable copyright/license notices.

No GitHub mutations performed. No changes made to the user's installation.

Generalized files:
- source/quickshell/scripts/theme-images-manager.py
- source/quickshell/modules/ii/settings/pages/BackgroundConfig.qml
