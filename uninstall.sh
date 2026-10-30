#!/bin/zsh
# Stops Switcher, removes it from login items and deletes the app.
~/Applications/Switcher.app/Contents/MacOS/Switcher --uninstall 2>/dev/null || true
pkill -x Switcher 2>/dev/null || true
rm -rf ~/Applications/Switcher.app
tccutil reset Accessibility com.pivden.switcher >/dev/null 2>&1 || true
tccutil reset ListenEvent com.pivden.switcher >/dev/null 2>&1 || true
echo "Switcher removed."
