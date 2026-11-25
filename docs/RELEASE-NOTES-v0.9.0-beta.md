# Irideshell v0.9.0-beta — release candidate

**One desktop. Infinite identities.**

Experimental source preview; not a production-ready desktop distribution. The GitHub Releases page is the authoritative publication status.

## Highlights

- 15 named color schemes with wallpaper-linked palette selection.
- Per-wallpaper widget layouts and per-theme collage profiles.
- Static and animated wallpaper management and Theme Studio.
- Modular shell, desktop-base, themes, launcher and terminal setup.
- Dry-run by default; file-level backup, update, restore and uninstall.
- Optional experimental HyprEndfield integration with separately supplied authorized resources.
- English and Brazilian Portuguese documentation.
- Explicit confirmation before screenshot upload through the alternate search helper.

## Validation

The original offline tests passed locally. [Installer and HUD assembly CI](https://github.com/pedrogonzalez-png/Irideshell/actions/runs/45655878826) passed. The maintainer's local dry run verified 242 source files and the exact hashes of 373 local HUD resources. No archive was written or installation performed in that check. Clean Arch GUI testing was not performed, by project decision. Offline tests do not establish runtime compatibility.

## Installation and limitations

Start with the [README](../README.md) or [Portuguese README](../README.pt-BR.md). Read the [technical guide](DEVELOPMENT.md) before applying changes. The native dashboard is the default. The [HUD source and local assembly instructions](../vendor/hyprendfield/IRIDESHELL.md) do not provide a standalone acquisition workflow.

No prepared bundle, compiled HUD or game-derived HUD resources are supplied. Source provenance review is not exhaustive; upstream shader source and third-party media rights remain unresolved. Preserve the [credits and applicable licenses](../CREDITS.md). Maintainer-approved demonstration media remains in the repository; underlying artwork rights have not been independently verified. Git archive export rules exclude the demonstration screenshots and MP4 files; verify any archive before redistributing it. Do not attach the assembled desktop or HUD resource archive to a release. See [release audit](../RELEASE-AUDIT.md). This document is not a legal clearance or an assertion that a release has been published.

## Português (Brasil)

Prévia experimental de código-fonte com 15 temas, wallpapers, widgets, mosaicos, integração opcional do HyprEndfield e instalador modular. Os testes offline passaram e os 373 recursos locais do HUD tiveram seus hashes conferidos. A instalação gráfica em Arch limpo não foi validada por decisão do projeto. O dashboard nativo é padrão; o HUD exige recursos locais autorizados. Não distribuímos o desktop montado ou o binário do HUD. Direitos de mídias e recursos de terceiros permanecem em revisão. Consulte o [README em português](../README.pt-BR.md) e os [créditos](../CREDITS.md). O estado da publicação oficial deve ser consultado na página de Releases do GitHub.
