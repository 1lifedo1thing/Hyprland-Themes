# Irideshell v0.9.0-beta — draft release notes

**Status: draft, not a tagged release.** Source-only development preview; assembled redistributable package not approved.

## Highlights

- 15 named color schemes with wallpaper-linked palette selection.
- Per-wallpaper widget layouts and per-theme collage profiles in the source overlays.
- Modular shell, desktop-base, themes, launcher and terminal setup.
- Read-only installation preview by default; file-level backup, update, restore and uninstall safeguards.
- English and Brazilian Portuguese documentation; black, gold and white branding.
- Confirmation before screenshot upload through the alternate image search helper.

## Validation

All five offline test programs passed locally and [GitHub Actions](https://github.com/pedrogonzalez-png/Hyprland-Themes/actions/runs/45565469777) passed on the published installer commit. No clean Arch GUI test has been performed. See [development guide](DEVELOPMENT.md) and [release audit](../RELEASE-AUDIT.md).

## Known limitations / release gates

- Individual source provenance review is not exhaustive; preserve upstream copyright and licensing notices.
- Compiled upstream shader source and third-party media rights are unresolved. Do not distribute prepared bundles.
- The maintainer-approved screenshots and full recordings are demonstration assets, not installer content. Third-party artwork rights have not been independently verified.
- HyprEndfield is not bundled; optional integration remains experimental.
- A tagged beta and default-branch changes are not performed by this draft.

## Português (Brasil)

Prévia de desenvolvimento com 15 temas, integração de wallpapers, layouts de widgets, mosaicos por tema, instalador modular e gerenciamento de backups. Os testes offline passaram localmente e no GitHub. A instalação limpa e a interface do pacote montado ainda não foram validadas. As mídias de demonstração foram aprovadas pelo mantenedor. A release oficial ainda aguarda a revisão de direitos. Consulte a [documentação](../README.pt-BR.md).
