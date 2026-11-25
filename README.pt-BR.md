<p align="center"><img src="assets/brand/banner.png" alt="Irideshell — Um desktop. Infinitas identidades." width="100%"></p>

<p align="center"><a href="README.md">English</a> · <a href="CREDITS.md">Créditos</a> · <a href="LICENSE">GPL-3.0</a> · <a href="docs/DEVELOPMENT.md">Guia técnico</a></p>

> **Prévia de desenvolvimento (somente código-fonte) — meta: v0.9.0-beta.** Disponível na branch development; ainda sem release beta. A montagem e a simulação foram testadas no Arch de origem; a instalação limpa e o funcionamento visual do pacote montado ainda não foram validados. A distribuição do pacote montado e a beta oficial dependem da [auditoria](RELEASE-AUDIT.md).

## Um desktop. Infinitas identidades.

Irideshell é uma configuração modular de desktop Hyprland derivada do illogical-impulse e do end4-pC. Sua proposta é integrar os temas: ao escolher um wallpaper, recuperar a paleta, a organização dos widgets e o perfil de mosaico associados. Instale somente os componentes que deseja.

### Destaques

- **Temas por wallpaper:** paletas nomeadas, edição de cores primária, secundária e terciária, e associação de imagens.
- **Layouts persistentes:** posições, dimensões e imagens dos widgets por wallpaper; mosaicos por esquema.
- **Gerenciador de wallpapers:** bibliotecas estática e animada, importação e prévias.
- **Theme Studio:** edição de cores, contraste, opacidade, avatar e imagens dos cards.
- **Integração do terminal:** configurações opcionais do Kitty, Fish e Fastfetch, com sincronização de temas.
- **Instalação modular:** simulação por padrão, backups de arquivos, atualização e remoção seletivas.

As funcionalidades combinam contribuições dos projetos originais e modificações desta versão; consulte o [histórico de alterações](MODIFICATIONS.md). Elas são demonstradas pelo desktop de origem; o instalador montado ainda não passou por validação visual.

## Galeria e demonstrações

![As 15 paletas escuras do Irideshell](assets/gallery/palettes.svg)

A galeria usa as cores reais dos JSONs de temas publicados. É uma referência de paletas, não uma captura do desktop. Consulte a [tabela completa](docs/PALETTES.md).

Capturas e dois vídeos permanecem fora do repositório até a revisão dos direitos das artes e da privacidade. Wallpapers pessoais e layouts privados completos não acompanham o pacote. Veja o [plano de mídia](docs/MEDIA-PLAN.md).

## Módulos

| Módulo | Conteúdo | Requisitos |
| --- | --- | --- |
| `launcher` | Rofi compacto e dashboard | Rofi |
| `terminal` | Kitty, Fish, Fastfetch e auxiliares | Kitty, Fish, Fastfetch |
| `themes` | 15 esquemas de cores | Shell compatível |
| `shell` | Quickshell, widgets, wallpapers e mosaicos | Base preparada e dependências compatíveis |
| `desktop-base` | Hyprland e Matugen | Base preparada; seleciona também shell |
| `desktop` | Todos os módulos acima | Todos os requisitos aplicáveis |

Widgets e ferramentas de wallpaper fazem parte de `shell`, não são módulos independentes nesta versão. HyprEndfield possui somente código de integração opcional; o aplicativo e o SDDM não estão incluídos.

## Experimente o instalador em ambiente descartável

Execute como usuário comum. Não teste a instalação real sobre seu desktop de uso diário. Os comandos abaixo somente listam ou simulam:

```bash
./setup list
./setup install --modules launcher
./setup install --modules terminal
./setup doctor
```

Para o shell ou desktop completo, `./setup prepare --apply` baixa as revisões fixadas dos projetos originais e monta `prepared/`, sem modificar o desktop. `./setup install` simula a instalação completa. O instalador de arquivos não instala dependências do sistema; o `bootstrap` experimental separado chama o instalador original e não é coberto por nossos backups. Consulte o [guia técnico](docs/DEVELOPMENT.md) antes de qualquer instalação real.

## Gerenciamento

| Comando | Função |
| --- | --- |
| `./setup update` | Simular atualização pela versão local |
| `./setup backup` | Backup dos arquivos gerenciados |
| `./setup restore` | Reverter a última transação concluída |
| `./setup uninstall --modules launcher` | Simular remoção seletiva |
| `./setup doctor` | Diagnóstico estático |
| `./setup audit` | Auditoria heurística, sem certificação |

Operações de escrita exigem `--apply`; substituições exigem `--replace` quando aceito. Os backups não abrangem os wallpapers/layouts pessoais nem mudanças em pacotes do sistema. Não há atualização automática pela rede ou remoção de pacotes.

## Privacidade e serviços externos

O atalho alternativo de pesquisa por captura (`Super+Shift+A`, quando o Quickshell não está em execução) pede confirmação antes de enviar a região selecionada ao uguu.se e abrir o Google Lens com a URL. A retenção remota depende desses serviços. Cancele se houver informações privadas na tela. O shell original possui recursos online próprios, cujo comportamento de rede ainda não foi integralmente revisado. Consulte a [auditoria](RELEASE-AUDIT.md).

## Licença e créditos

Projeto derivado de [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) e [pctrade/end4-pC](https://github.com/pctrade/end4-pC), mantido por [pedrogonzalez-png](https://github.com/pedrogonzalez-png). O código abrangido pela GPL continua sob GPL v3. Licenças e avisos de terceiros permanecem aplicáveis. Consulte [créditos](CREDITS.md), [revisões originais](upstream-lock.json) e [auditoria](RELEASE-AUDIT.md). Não há vínculo oficial com os titulares das artes e marcas.
