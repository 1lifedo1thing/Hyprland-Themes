# Development publication candidate — 2026-11-25

This source-only candidate consolidates Stages 4–6 and the approved black/gold/white branding. It deliberately excludes `prepared/`, compiled shaders, bundled fonts, upstream images/audio, personal screenshots and recordings, backups, live settings, and dormant alternate local wallpaper services. `prepare` still retrieves pinned upstream code and resources locally. The assembled result is not cleared for redistribution.

All five offline test programs (smoke, stage3, stage4, stage5, wallpaper_links) passed on this candidate. Python/JSON/SVG parsing and Bash syntax checks also passed (the upstream emoji dictionary script is not a conventional shell-only file and was excluded from Bash parsing). The source-tree credential-pattern scan identified no matching token pattern; two generic/synthetic path matches remain. This is not proof of absence of secrets or license clearance. The original upstream MIT/LGPL notice copies match the pinned Git blob IDs. Individual source notices, upstream compiled shader source and media rights are still subject to the release audit. No clean Arch GUI/VM test was performed, by project decision.

Review the candidate and existing repository history before pushing any code to the public development branch. No beta release, tag, or default branch change is authorized by this candidate. The original desktop is not modified by the publication preparation script.

## Final documentation handoff — 2026-11-25

The preceding text records the original private candidate, not the current public repository. Both README languages, credits, technical installation guide, HUD local assembly instructions and beta candidate notes are now consolidated. The local HUD dry run and offline CI passed; clean Arch GUI validation was explicitly declined by the maintainer. No additional development or VM test is required for this documentation handoff. Publication status is controlled by GitHub Releases, not this file.

The source preview is not an approved assembled distribution. Keep compiled HUD binaries, prepared trees and local asset archives out of release attachments. Demonstration screenshots and videos remain visible in the repository but are marked export-ignore for git archive. Verify generated archives before redistribution. Underlying artwork rights and other unresolved third-party permissions remain open; this handoff does not waive them.
