# Stage 5 release preflight — not a release approval

## Known results

- Exact pctrade revision confirmed by the local inventory; candidate end-4 revision pinned. User successfully prepared both real repositories and completed the full dry-run (12 proposed changes, zero desktop writes). Stage 4 doctor on source machine reported no managed files, no transaction, and all minimal module commands available.
- GPL v3 license texts retained. Upstream notices and separate licenses must not be stripped. See `CREDITS.md` and `upstream-lock.json`.
- Personal layouts, original wallpapers, application histories and secrets were excluded by the prior export. No automatic proof of secret absence or media rights is possible. The source staging directory is not a release-ready public tree.
- `DotsUpdater.qml` has an early return before the old destructive upstream replacement code. Do not remove that guard. Before publishing, replace that dead updater with an explicit message directing users to the local versioned `setup update` workflow; do not activate upstream overwrite. The follow-up patch replaces the old dead updater with a notification; reassembly is required to apply the new source to prepared/.
- Some copied files retain optional HyprEndfield UI calls, although the application is not included. Audit its license independently, or keep it out of the initial release. SDDM is not included.
- The image-search script can upload a screenshot to a third-party host when invoked; document opt-in/external services before release. Review other online integrations separately.

## Run from the prepared project (normal user)

```bash
./setup audit > "$HOME/relatorio-stage5.txt" 2>&1
```

The report inventories source files and the actual assembled modules, checks all prepared hashes against the manifest and lock, lists license notices and media hashes, flags selected patterns for review, and checks command availability. It never reads the live HOME configuration or prints matching secret values. File names may still identify local information; inspect before sharing. Exit status 0 means no *selected credential pattern* was matched, **not** clearance to publish; 1 means possible credential match, 2 means scan/integrity error. Other findings always require manual review. Binary files and large files are not content-scanned; the audit does not scan Git history or upstream repository working copies.

## Dependency boundaries

| Component | Current check / dependency |
|---|---|
| Preparation | Bash, Python 3, Git, network access |
| Shell | qs, jq, matugen, upstream Qt/QML libraries and Python environment |
| Desktop base | Hyprland/hyprctl, hypridle, hyprlock, upstream services and desktop tools |
| Launcher | rofi, with launcher actions needing their own applications |
| Terminal | kitty, fish, fastfetch; image/video palette extraction also uses ffmpeg/ffprobe |
| Static wallpapers | kdialog, notify-send, xdg-user-dir, gsettings, bc, image tools where used |
| Animated wallpapers | mpvpaper and ffmpeg (not mandatory for static themes) |

The original bootstrap handles upstream dependencies; it is a distinct explicit operation with package and service side effects. No validated package version lock exists, and availability of a binary is not runtime compatibility. Do not copy the source machine's installed package inventory into the public dependency list. No new package installs are performed by the audit.

## Gates before public beta

1. Review actual prepared media inventory and associated copyright notices. Do not assume GPL covers all images, fonts, sounds, screenshots or trademarks; keep unverified personal art out of releases.
2. Review scanner findings and public source export allowlist; exclude obsolete watcher and private staging material not needed by the release. Inspect Git diff and history before pushing; never commit `prepared/repos/`, local reports or backup state.
3. Clean the legacy updater and document optional external integrations. Validate dependency mapping and complete setup instructions for individual modules.
4. Mark first release as untested on clean Arch (VM skipped by project decision). Do not claim functional fresh-install certification; prepared check and dry-run are not GUI tests.

## Stage 5 follow-up — received audit

903 assembled files matched; 23 heuristics: five path matches and 18 compiled shaders. The path matches in upstream Profile.qml and es_ES.json are `/home/youruser` examples, as is the staged en_US translation; the test match is synthetic. No selected credential pattern was reported. All 18 QSB files occur in the pinned pctrade tree, but no `.frag` source files appear there. Their provenance and corresponding editable source remain unresolved; do not ship compiled bundles until resolved. The font-specific notice covers the handwriting fonts (OFL 1.1 or Apache 2.0); Material Symbols notices, other SVG rights, the default wallpaper and two OGG files require further review. Do not claim clearance on the basis of upstream inclusion alone. The six known showcase PNGs are excluded from new assemblies; upstream READMEs retain attribution and link to the pinned originals. The locally generated color wheel is procedural. No personal art or font binaries are included in this patch.

Rebuild the prepared directory using `python3 scripts/refresh_prepared.py` (no network or HOME writes; old prepared preserved as a project-local ignored backup). It verifies the old manifest and both pinned checkouts first. This refresh is not an install, and does not validate QML runtime. Do not publish the prepared directory or its backups. The public release remains blocked pending source/media review and the public export allowlist.

## Source-only publication candidate

This archive is a review candidate, not a released binary distribution. It includes the source overlays, installer and approved brand artwork only; no prepared upstream clones, compiled shaders, fonts, raw screenshots, videos or personal layout state. Dormant alternate collage/wallpaper writers and local systemd staging were excluded. Source-specific notices remain to be verified; compiled shader and other upstream media rights remain unresolved, so do not publish an assembled release or claim clearance.

## Final local follow-up

The fallback screenshot search now requires explicit consent and uses private temporary storage. Both READMEs document the upload. This does not validate other upstream network integrations or resolve upstream media rights. Offline CI runs the fixture tests, not a clean Arch GUI installation.

## Published source review — 2026-11-25

The development branch was pushed at `0a20b57e465b3e35821e63dc859a04e7d15e61b9`. [Offline GitHub Actions tests](https://github.com/pedrogonzalez-png/Hyprland-Themes/actions/runs/45565469777) completed successfully. This is not clean-system or graphical runtime validation.

The root GPL text, the three end-4 license directory files (MIT, LGPL-3.0 and README), the Ollama helper Apache notice, the pctrade root license, handwriting font notices, and shapes Apache notice all have Git blob hashes identical to the respective pinned upstream copies (8 of 8). A path-based comparison of 90 staging files found 34 identical to the corresponding pinned upstream path, 38 changed, and 18 with no corresponding path at the selected revisions. This is a provenance inventory, not a comprehensive individual copyright review. No clearance is asserted for upstream media or compiled shaders. Keep the assembled tree, videos and raw screenshots out of public release assets pending review.

## Latest HUD and documentation review — 2026-11-25

The published HUD port MIT notice matches the upstream Git blob `8aa79a49fc9e87818b78b47312856348ef369443`. The settings notice matches DDDuoDuo's upstream MIT blob `a42cf5d680bfead3e7312137a455db9aa79e6901`; the core notice has equivalent text after normalizing line endings and outer whitespace. The Matter.js MIT and HarmonyOS Sans notices are present, without a comprehensive independent review of their coverage. See [credits](CREDITS.md).

The maintainer ran the local-directory assembly dry run successfully (242 source files present, 373 local resources matching the size and SHA-256 manifest). No archive was written and no installation was performed. The [offline CI for directory assembly](https://github.com/pedrogonzalez-png/Irideshell/actions/runs/45655878826) passed. The native dashboard remains the default. A standalone HUD installation for a new user without compatible authorized resources is unresolved.

The current public repository includes maintainer-provided demonstration screenshots and videos, unlike the earlier source-only candidate described above. The maintainer approved their public display, but underlying artwork rights have not been independently verified. This review does not approve redistributing the assembled desktop, HUD resources, or those demonstration files in release archives. A clean Arch graphical installation remains untested. The release remains a draft pending review of unresolved rights and distribution scope.
