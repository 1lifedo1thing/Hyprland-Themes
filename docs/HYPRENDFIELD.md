# Optional HyprEndfield integration — Stage 7 preview

The native dashboard remains the default. The public shell overlay already contains the `hyprendfieldConfig`, `hyprendfieldBridge` and `hyprendfieldSettings` IPC targets. The Hyprland overlay also defines the HUD submap (Escape and Super+Alt+Down close the HUD; Ctrl+Shift+Escape resets the submap). The existing HUD must be installed separately before choosing Endfield as the settings style. The wrapper must be at `$HOME/.local/bin/hyprendfield` and support `--show` and `--hide`.

## Local build check (no installation)

Use your own authorized source archive, including its required assets. The HUD source and assets are not distributed by Irideshell. Inspect source and resources before building; do not build untrusted archives. The helper extracts only the expected project directories to a fresh temporary directory and does not install the binary, change the live HUD or write its settings.

```sh
python3 scripts/build_hyprendfield.py --archive "$HOME/Downloads/HyprEndfield-revisao.tar.gz"
python3 scripts/build_hyprendfield.py --archive "$HOME/Downloads/HyprEndfield-revisao.tar.gz" --apply
```

Requires C++20, CMake 3.25+, Ninja, Qt 6.8+ (including Multimedia, PDF, WebEngine, ShaderTools), LayerShellQt, pkg-config, PulseAudio, libvterm 0.3.3+, Wayland, libsecret, PAM, libzip, GIO and Wayland protocol/scanner files. CMake checks exact dependencies. Build success is not GUI validation. Do not launch a second instance against a running HUD; it can share the existing session and local storage.

To use the revised submap in an already prepared installer, rebuild the prepared tree through `scripts/refresh_prepared.py` (local checks required), then inspect the desktop-base update simulation. No live changes are made by this patch itself.

## Licensing and release status

HyprEndfield is a Linux port by AmeoInoru of DDDuoDuo's [EndfieldHUD](https://github.com/DDDuoDuo/EndfieldHUD). Both MIT notices are present in the supplied local source. Preserve these and other notices when redistributing permitted code. Game-derived assets and map data are not automatically licensed by the MIT text; the current CMake resource list requires such assets. No source or HUD assets are included in this integration preview. A self-contained module (`./setup install --modules hyprendfield`) is not available yet. Build, graphical behavior, missing-HUD fallback, and licensing of the required resources must be resolved before enabling it.

## Optional local installation

This is a separate application installation, not an overlay managed by `setup install`.
Supply your own trusted and authorized source archive, including its required assets.
No download of HUD source, automatic package installation or redistribution is performed.

```sh
./setup hud --archive "$HOME/Downloads/HyprEndfield-revisao.tar.gz" --install
./setup hud --archive "$HOME/Downloads/HyprEndfield-revisao.tar.gz" --install --apply
```

The first command previews; the second compiles and installs the binary and four license notices under `~/.local/share/irideshell/hyprendfield/` and creates `~/.local/bin/hyprendfield`. It refuses to replace either destination, including an existing manually installed HUD. It does not launch the application or change desktop settings. Install in a disposable user account for a fresh-install test. Existing users can keep their current wrapper. Application data, sessions, updates and removal are not managed by the Irideshell overlay lifecycle. Before selecting the Endfield dashboard, ensure the wrapper runs and the revised Hyprland overlay is active. To return to the native dashboard if the HUD is missing, use `qs -c end4-pC ipc call hyprendfieldSettings useQuickshell`.

This local archive workflow does not supply the HUD to new users without an authorized source archive. A distributable self-contained module is still blocked by required asset provenance and runtime validation.
