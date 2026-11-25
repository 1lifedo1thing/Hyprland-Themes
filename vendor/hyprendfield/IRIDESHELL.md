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
