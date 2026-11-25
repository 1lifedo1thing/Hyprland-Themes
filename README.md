<p align="center"><img src="assets/brand/banner.png" alt="Irideshell — One desktop. Infinite identities." width="100%"></p>

<p align="center"><a href="README.pt-BR.md">Português (Brasil)</a> · <a href="CREDITS.md">Credits</a> · <a href="LICENSE">GPL-3.0</a> · <a href="docs/DEVELOPMENT.md">Development guide</a></p>

> **Source-only development preview — target: v0.9.0-beta.** Public development preview; no tagged beta yet. Assembly and dry-run were tested on the source Arch machine; clean-system installation and graphical runtime of the assembled package remain untested. The assembled distribution and official beta remain pending the [release audit](RELEASE-AUDIT.md).

## Make the desktop yours

Irideshell is a modular Hyprland desktop configuration derived from illogical-impulse and end4-pC. Its focus is a coherent theme experience: change a wallpaper and recover the associated palette, widget layout and collage profile. Choose the components you need instead of replacing your entire desktop.

### Highlights

- **Wallpaper-linked themes:** named palettes, primary/secondary/tertiary color editing and image associations.
- **Persistent layouts:** per-wallpaper widget positions, sizes and images; per-scheme collage profiles.
- **Wallpaper manager:** static and animated libraries, import and preview controls.
- **Theme Studio:** color editing, contrast, opacity, theme avatar and card images.
- **Terminal integration:** optional Kitty, Fish and Fastfetch configuration and theme synchronization.
- **Modular setup:** dry-run by default, file-level backups, selective updates and uninstall.

These features originate in both upstream projects and the derivative's modifications; see [modification history](MODIFICATIONS.md). The original desktop demonstrates them; the assembled installer has not yet been visually validated.

## Showcase

### Video demonstrations

Watch the two desktop demonstrations directly below.

https://github.com/user-attachments/assets/ddf77c0c-b26d-4b93-bf22-047db4aca6f7

https://github.com/user-attachments/assets/5a3277e7-48ab-42ac-bda9-a0e4e2501030

Full-resolution originals: [Irideshell Showcase (1:00)](assets/videos/showcase.mp4) · [Dynamic Theme Switching (1:05)](assets/videos/theme-switching.mp4).

The recordings demonstrate the original desktop. Optional integrations such as HyprEndfield require separate installation.

### Desktop screenshots

**Bibian**

![Bibian](assets/screenshots/bibian.webp)

**Haimiya**

![Haimiya](assets/screenshots/haimiya.webp)

**Multi-wallpaper collage**

![Multi-wallpaper collage](assets/screenshots/collage.webp)

**Shorekeeper**

![Shorekeeper](assets/screenshots/shorekeeper.webp)

**Pastis**

![Pastis](assets/screenshots/pastis.webp)

**Wallpaper picker**

![Wallpaper picker](assets/screenshots/wallpaper-picker.webp)

**Animated wallpapers**

![Animated wallpapers](assets/screenshots/animated-wallpapers.webp)

**Color editor**

![Color editor](assets/screenshots/color-editor.webp)

**Application dashboard**

![Application dashboard](assets/screenshots/dashboard.webp)

### Palettes

![The 15 Irideshell dark palettes](assets/gallery/palettes.svg)

The swatches are derived from the actual published theme JSON files. This is a palette reference, not a screenshot of a running desktop. See the [full palette table](docs/PALETTES.md).

Screenshots and full videos are maintainer-provided demonstrations, not wallpapers distributed by the installer. Third-party artwork and trademarks remain subject to their respective owners’ rights and are not licensed by the code’s GPL. Clean-system installation is not validated. See [media plan](docs/MEDIA-PLAN.md).

## Modules

| Module | Scope | Requirements |
| --- | --- | --- |
| `launcher` | Rofi compact launcher and dashboard | Rofi |
| `terminal` | Kitty, Fish, Fastfetch and helpers | Kitty, Fish, Fastfetch |
| `themes` | 15 named color schemes | Compatible shell |
| `shell` | Quickshell, widgets, wallpapers, collage | Prepared base and compatible dependencies |
| `desktop-base` | Hyprland and Matugen configuration | Prepared base; also selects shell |
| `desktop` | All of the above | All applicable requirements |

Widgets and wallpaper tools are part of `shell`, not separately installable modules yet. HyprEndfield is optional: [local build and installation from an authorized source archive](docs/HYPRENDFIELD.md). [Personalized HUD source](vendor/hyprendfield/IRIDESHELL.md) is available for review; the compiled application, required game-derived assets and SDDM are not bundled.

## Quick start — development preview

**Use a disposable Arch Linux VM or test account, not your everyday desktop.** A clean graphical installation has not been validated. Start with Git, Bash and Python 3 available; the selected modules require their own installed programs.

### 1. Get the project

```bash
git clone --depth 1 https://github.com/pedrogonzalez-png/Irideshell.git
cd Irideshell
./setup list
./setup doctor
```

### 2. Choose a module and preview

```bash
./setup install --modules launcher
./setup install --modules terminal
```

These commands do not change your configuration. Rofi, or Kitty/Fish/Fastfetch respectively, must already be installed before applying the corresponding module. Themes require a compatible shell.

### 3. Prepare the full desktop (optional)

```bash
./setup prepare --apply
./setup install
```

Preparation downloads the pinned upstream repositories and assembles `prepared/` inside the checkout, not your desktop. The second command only previews the configuration overlay. The overlay does not install system dependencies. The separate experimental upstream bootstrap may change packages, services and existing configurations; use it only in a disposable VM after taking a snapshot.

### 4. Apply only in a test environment

For example, once the launcher prerequisites are installed and its preview has been reviewed:

```bash
./setup install --modules launcher --apply
```

Different existing files are refused unless you explicitly authorize replacement with `--replace`. Do not use that option blindly. The installer does not automatically reload the desktop. For full desktop installation, recovery, dependency boundaries and backup limitations, read the [technical guide](docs/DEVELOPMENT.md) first. The native dashboard is the default; [HyprEndfield](docs/HYPRENDFIELD.md) is optional and requires authorized local resources.

## Manage your installation

| Command | Purpose |
| --- | --- |
| `./setup update` | Preview an update from the local project version |
| `./setup backup` | Back up managed configuration files |
| `./setup restore` | Reverse the latest completed transaction |
| `./setup uninstall --modules launcher` | Preview selective removal |
| `./setup doctor` | Static dependency and managed-file checks |
| `./setup audit` | Release preflight (heuristic, not certification) |

Mutating operations require `--apply`; replacements require `--replace` where supported. File backups do not include personal wallpaper/layout state or system package changes. The installer does not automatically fetch updates or remove system packages.

## Privacy and external services

The fallback screenshot-search shortcut (`Super+Shift+A`, when Quickshell is not running) asks for confirmation before uploading the selected screenshot to uguu.se and opening Google Lens with its URL. Remote retention is controlled by those services. Cancel if the screen contains private information. The pinned upstream shell has its own online features; their network behavior has not been fully reviewed. See [release audit](RELEASE-AUDIT.md).

## License and attribution

Irideshell is a derivative of [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) and [pctrade/end4-pC](https://github.com/pctrade/end4-pC), maintained by [pedrogonzalez-png](https://github.com/pedrogonzalez-png). The GPL-covered code remains under GPL v3. Third-party notices and licenses remain applicable. See [credits](CREDITS.md), [upstream revisions](upstream-lock.json) and [release audit](RELEASE-AUDIT.md). No affiliation with the game or character rights holders is claimed.
