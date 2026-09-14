#!/bin/bash
# Install Nerd Fonts used by this setup (Inter, FiraCode, DroidSansM).
# Downloads from github.com/ryanoasis/nerd-fonts releases into ~/.local/share/fonts.
set -euo pipefail
VER="v3.2.1"
BASE="https://github.com/ryanoasis/nerd-fonts/releases/download/$VER"
DEST="$HOME/.local/share/fonts"
mkdir -p "$DEST"
cd "$DEST"

for fam in Inter FiraCode DroidSansMono; do
    if ls "$fam"* 1>/dev/null 2>&1 || ls "$DEST/$fam"* 1>/dev/null 2>&1; then
        echo "$fam already present, skipping"
        continue
    fi
    echo "downloading $fam..."
    curl -fL -o "$fam.zip" "$BASE/$fam.zip"
    unzip -o -q "$fam.zip" -d "$fam"
    rm "$fam.zip"
done

fc-cache -f >/dev/null 2>&1 || true
echo "fonts installed. Verify: fc-list | grep -i 'nerd font' | head"
