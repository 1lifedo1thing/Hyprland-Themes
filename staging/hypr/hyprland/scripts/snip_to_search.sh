#!/usr/bin/env bash
# Modified by Irideshell, 2026-11-25: require consent and use private temporary storage.
set -euo pipefail
kdialog --title 'External image search' --yesno 'The selected screenshot will be uploaded to uguu.se and its URL shared with Google Lens. The remote copy may be retained. Continue?' || exit 0
region=$(slurp) || exit 0
[[ -n "$region" ]] || exit 0
tmp=$(mktemp --suffix=.png)
trap 'rm -f -- "$tmp"' EXIT
grim -g "$region" "$tmp"
imageLink=$(curl --fail --silent --show-error --max-time 60 -F "files[]=@$tmp" 'https://uguu.se/upload' | jq -er '.files[0].url | select(type == "string" and startswith("https://")) | @uri')
xdg-open "https://lens.google.com/uploadbyurl?url=${imageLink}"
