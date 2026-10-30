#!/bin/zsh
# Points the Homebrew cask in DenysPiven/homebrew-tap at a published release.
# Usage: scripts/update_cask.sh 1.2.3   (run after the Release workflow has finished)
set -e
VERSION="${1:?usage: $0 VERSION}"
URL="https://github.com/DenysPiven/Switcher/releases/download/v$VERSION/Switcher.zip"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

curl -fsSL "$URL" -o "$WORK/Switcher.zip"
SHA="$(shasum -a 256 "$WORK/Switcher.zip" | cut -d' ' -f1)"

gh repo clone DenysPiven/homebrew-tap "$WORK/tap" -- -q
CASK="$WORK/tap/Casks/switcher.rb"
sed -i '' -E "s/^  version \".*\"/  version \"$VERSION\"/; s/^  sha256 \".*\"/  sha256 \"$SHA\"/" "$CASK"
git -C "$WORK/tap" commit -qam "switcher $VERSION"
git -C "$WORK/tap" push -q
echo "Cask updated to $VERSION ($SHA)"
