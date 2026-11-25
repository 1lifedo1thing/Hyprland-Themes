# Hyprland-Themes — Stage 4 (private development preview)

Integrated, modular desktop derived from end-4 and pctrade. GPL-3.0; see LICENSE, CREDITS-DRAFT.md and upstream notices. **Not a release. Do not run the bootstrap or install the desktop on your working PC.** No personal wallpaper images or user layout state are included. The 15 named schemes are available; sample desktop layouts and artwork rights remain outstanding.

## Prepare without touching the desktop

Extract this archive to a new folder. Run as a normal user, not root:

```bash
./setup list
./setup prepare --apply
```

`prepare` downloads the pinned Git repositories into an isolated temporary directory, overlays the recovered source, generates an original HSV color-wheel texture, preserves upstream notices, and produces `prepared/` with an SHA-256 manifest. No package installations or modifications to HOME config. Existing prepared directories are refused. Internet and Git required. The pctrade revision matches the actual source machine; end-4 is a contemporaneous candidate, not a proven exact match. `prepared/` is ignored by Git. Full upstream sources still need license and asset review before release.

## First end-to-end test: disposable Arch VM only

After preparation, in a fresh Arch VM with a normal user and working network:

```bash
./setup bootstrap
./setup bootstrap --apply --test-environment
./setup install
./setup install --apply --replace
```

Bootstrap delegates to the pinned **original end-4 setup install**, including dependency installation, permission/service changes and upstream configuration copying; this is NOT covered by our file-level backup. It may prompt for sudo and user selections. Take a VM snapshot first. It is intentionally a separate step until real integration is verified. Upstream dependencies can change despite the Git pins. `install` defaults to desktop and only prints the plan; `--apply --replace` writes the selected files to ~/.config and authorizes replacing existing files with backups. Check the plan first. Log out and back in only in the VM. No services are enabled by our overlay installer; it does not reload the running desktop. An original shell `ii` may remain alongside the derived shell. Complete package/dependency detection, fresh-login runtime checks and rollback of system changes remain unimplemented.

## Modular installation

```bash
./setup install --modules launcher
./setup install --modules themes
./setup install --modules terminal
./setup install --modules shell
./setup install --modules themes,terminal
```

Add `--apply` only on a test installation after reviewing the simulation. Differing existing files require `--replace`. Rofi and terminal modules don't need `prepare`. Themes require a compatible shell; shell and desktop-base require `prepare` and dependencies already installed. Shell installs helpers without activating automatic Kitty/Fish synchronization; terminal installs an opt-in marker. Other existing upstream theme integrations and manual edits in the terminal UI may still touch terminal settings. Shell contains the widgets, static/animated wallpaper selector and collage as tightly coupled features, not independent standalone modules. HyprEndfield integration code exists but the separate application is not shipped; do not select its settings style. SDDM not included. No automatic legacy wallpaper/theme watcher or older collage Python writer is installed. The updated switchwall reads explicit wallpaper bindings and falls back to name matching. Existing unmatched wallpapers retain the current scheme.

Backups: `~/.local/share/Hyprland-Themes/backups/` (or XDG_DATA_HOME). Existing-file copies and manifest for each overlay transaction; attempts rollback on ordinary failure. Does not guarantee rollback after interrupted system installs, crashes or power loss. File-level lifecycle commands are now available; see below. Symlinks are refused at installation destinations, except the two known end4-pC SVG icon aliases when they point directly to a regular file in the same directory and both prepared files and the existing target have identical SHA-256 hashes. Such aliases are left untouched. No root execution of our installer. Only default ~/.config supported. See STAGE3-AUDIT.md for test scope and caveats.

## File lifecycle (Stage 4)

```bash
./setup doctor
./setup backup
./setup backup --apply
./setup update
./setup update --apply
./setup restore
./setup restore --apply
./setup uninstall --modules launcher
./setup uninstall --modules launcher --apply
```

All mutating commands default to simulation. `doctor` is read-only and checks command availability, managed file hashes and original backup integrity, not runtime or services. `update` uses the **local project version**, not GitHub; acquire a new reviewed version and prepare its pinned bases separately first. By default it updates managed modules only. Files modified since installation require explicit `--apply --replace`, with a backup; obsolete files are not automatically removed. `uninstall` defaults to all managed modules, restores the original when a file was replaced and removes files created by the installer, but only when the installed hash still matches. Locally modified or missing files remain registered for review. Identical pre-existing files are not claimed or removed. Shared files are retained until their last recorded module is removed; uninstalling shell while other managed desktop-base/themes remain is refused.

`backup` captures only managed files (including local edits), not the whole desktop or private wallpaper/layout state. `restore` reverses the **latest** completed Stage 4 transaction, including a manual backup; `--id` may specify that latest ID. It refuses intervening changes unless `--apply --replace` explicitly authorizes saving the current version and restoring the snapshot. Every restore is itself a new transaction. Older Stage 3 backup manifests can still be used manually but are not automatically adopted; this avoids claiming existing configurations. Backups contain private copies of files and must not be committed to Git.

An interrupted transaction leaves a pending marker and blocks further operations. Preserve the backup and inspect manually; automatic recovery from power loss or forced termination is not implemented. Ordinary write failures attempt rollback. This is a user-file manager, not a package/service uninstaller; it does not remove pacman/AUR packages, undo bootstrap, reload sessions, change boot configuration, or manage files not installed by this tool. No VM or real Arch installation test is planned for this development preview, by project decision.

## Release preflight (Stage 5)

`./setup audit` is a read-only inspection of the project and assembled modules; it is not a license clearance or runtime test. See [RELEASE-AUDIT.md](../RELEASE-AUDIT.md), [CREDITS.md](../CREDITS.md), and [MODIFICATIONS.md](../MODIFICATIONS.md). Do not commit the local audit report or prepared repository copies. This remains a private development preview.

### Refresh a previously prepared development tree

After applying the Stage 5 follow-up patch, run `python3 scripts/refresh_prepared.py` from this project. It rebuilds only `prepared/` using the already downloaded pinned Git checkouts, preserves the old tree as an ignored `.prepare-backup-*` directory, and verifies the old manifest first. It does not install or change HOME configuration. Run `./setup audit` again afterwards. This is still a private preview; no clean Arch test was performed.
