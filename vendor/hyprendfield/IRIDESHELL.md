# HyprEndfield — Irideshell source preview

This is the personalized Linux HUD source exported from the maintainer's desktop on 2026-11-25. It is based on [OctoberPrayRain/HyprEndfield](https://github.com/OctoberPrayRain/HyprEndfield) (AmeoInoru, MIT), a Linux port of [DDDuoDuo/EndfieldHUD](https://github.com/DDDuoDuo/EndfieldHUD) (MIT). The original README, license and source notices are preserved, together with the notices for Matter.js and HarmonyOS Sans. The exact port base commit is not established. No claim of affiliation with Hypergryph is made. The modifications include Quickshell integration, wallpaper controls and map functionality. Source provenance review is preliminary; the asset inventory does not establish permission to distribute third-party content.

This tree intentionally omits the entire `assets/` directory, build products, backups, account data, and Git history. The CMake project is not buildable until all required assets are provided locally. The manifest records the exact size and SHA-256 of each resource from the maintainer's archive; it does not contain the resources themselves. Users must supply their own trusted, authorized matching archive, and must not redistribute the resulting archive. A compatible asset acquisition workflow for new users remains unresolved.

From the root of Irideshell:

```sh
python3 vendor/hyprendfield/assemble-local.py --assets-archive "$HOME/Downloads/HyprEndfield-revisao.tar.gz" --output "$HOME/Downloads/HyprEndfield-local-build.tar.gz"
```

Add `--apply` to create the archive after successful verification. Then run `./setup hud --archive "$HOME/Downloads/HyprEndfield-local-build.tar.gz" --install` to preview the optional installer. Only use its `--apply` option in a test account without an existing HUD. The original desktop remains untouched by assembly. No clean Arch GUI validation has been performed. Do not publish the assembled archive.

## Português

Código personalizado do HUD, com os avisos MIT originais preservados. Os recursos gráficos, dados do jogo, fontes binárias e áudio não estão incluídos. O comando acima verifica os recursos de um arquivo local autorizado; `--apply` gera uma cópia local para o instalador já publicado. O manifesto exige os arquivos exatos desta versão. A obtenção de recursos compatíveis para novos usuários ainda não foi resolvida. Não publique o arquivo montado. A montagem não modifica o desktop nem executa o HUD.

## Alternative: assemble from local folders / Montagem a partir de pastas

If you already have an authorized matching HyprEndfield checkout, you no longer need to create an input tarball:

```sh
python3 vendor/hyprendfield/assemble-local.py --assets-dir "$HOME/Apps/HyprEndfield" --output "$HOME/Downloads/HyprEndfield-local-build.tar.gz"
```

Add `--apply` only after verification succeeds. The output must not exist yet. You can repeat `--assets-dir` to combine project roots containing the expected `assets/` paths. Each file must match the exact size and SHA-256 in the manifest; missing, mismatching and symbolic-link resources are refused. The helper makes no network requests.

### Provenance inventory (2026-11-25)

The [Linux port tree at e040bbd](https://github.com/OctoberPrayRain/HyprEndfield/tree/e040bbdc6fa1e348aa33baaf225beb22048977d2) contains 365 of 373 expected resource paths with matching sizes; byte identity for these 365 has not been established. The two map binaries `Countries.bin` and `Terrain.bin` match the corresponding [EndfieldHUD upstream map files](https://github.com/DDDuoDuo/EndfieldHUD/tree/97cab1497e3993d2f5018717448073e977ce1e69/Resources/WorldMap) by Git blob SHA-1. Six map PNGs remain without established provenance: disc-mask, player-beam, player-glyph, player-halo, terrain and world-detail. Availability and matching hashes do not establish permission to use or redistribute artwork. Supply only resources you are authorized to use. This is not an automatic fresh-install acquisition workflow.

Em português: use `--assets-dir` com uma pasta local autorizada que contenha `assets/`. É possível repetir o argumento para combinar pastas. A montagem verifica os hashes, não baixa nada e não modifica o desktop. Seis imagens do mapa ainda precisam de revisão de origem e direitos.
