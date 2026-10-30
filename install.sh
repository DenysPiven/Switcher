#!/bin/zsh
# Builds, installs to ~/Applications and starts Switcher (it also adds itself to login items).
set -e
cd "$(dirname "$0")"
./build.sh
pkill -x Switcher 2>/dev/null || true
mkdir -p ~/Applications
rm -rf ~/Applications/Switcher.app
cp -R build/Switcher.app ~/Applications/
# A new build has a new signature, so the old Accessibility entry no longer matches.
tccutil reset Accessibility com.pivden.switcher >/dev/null 2>&1 || true
tccutil reset ListenEvent com.pivden.switcher >/dev/null 2>&1 || true
open ~/Applications/Switcher.app
echo "Switcher started. Allow it in System Settings → Privacy & Security → Accessibility (and Input Monitoring)."
