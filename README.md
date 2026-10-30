# Switcher

[![Release](https://img.shields.io/github/v/release/DenysPiven/Switcher)](https://github.com/DenysPiven/Switcher/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/DenysPiven/Switcher/total)](https://github.com/DenysPiven/Switcher/releases)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black?logo=apple)
[![License: MIT](https://img.shields.io/github/license/DenysPiven/Switcher)](LICENSE)

An invisible automatic keyboard layout switcher for macOS, a free and open-source alternative to Punto Switcher.
Type in the wrong layout and Switcher fixes the word as soon as you press space.
It has no Dock icon, no menu bar icon and no windows.

![Switcher demo](docs/demo.gif)

## Install

### Homebrew

```bash
brew install --cask denyspiven/tap/switcher
```

### Download

1. Download **Switcher.zip** from the [latest release](https://github.com/DenysPiven/Switcher/releases/latest).
2. Unzip it and move **Switcher.app** to **Applications**.
3. Open it. Switcher is not notarized by Apple, so macOS blocks the first launch.
   Go to **System Settings → Privacy & Security**, scroll down and click **Open Anyway**.
   Or run this once in Terminal:

   ```bash
   xattr -dr com.apple.quarantine /Applications/Switcher.app
   ```

### Build from source

Needs Xcode or the Command Line Tools.

```bash
git clone https://github.com/DenysPiven/Switcher.git && cd Switcher && ./install.sh
```

### Permissions

On first launch, allow Switcher in **System Settings → Privacy & Security**:
**Accessibility** and **Input Monitoring**. It starts working within 2 seconds, no restart needed.
Switcher adds itself to login items, so it starts with your Mac.

## Features

- **Auto-correction**: type `ghbdsn` and press space, and you get `привіт ` with the layout switched to Ukrainian.
  The same goes the other way: `руддщ` becomes `hello`.
- **Double Shift**: converts the last word to the other layout. If the word was just auto-corrected,
  double Shift undoes the correction and remembers the word as an exception, so it is never corrected again.
- Auto-correction is off in terminals and code editors (Terminal, iTerm, Warp, Ghostty, Xcode, VS Code, Cursor, JetBrains).
  Double Shift still works there.
- Works with any Latin layout (ABC, U.S., ...) paired with a Cyrillic one (Ukrainian, Russian, ...).

## Why Switcher

- **Free and open source** under the MIT license.
- **Invisible**: no Dock icon, no menu bar icon, no windows, no notifications.
- **No lag**: each keystroke is only appended to an array; the dictionary is checked only on space,
  in less than 1 ms. When idle, the app uses no CPU.
- **Native**: a 300 KB Swift app for Apple Silicon and Intel, no Electron, no background services.

## Privacy

Switcher needs to see your keystrokes to do its job, so here is exactly what it does with them:

- Keys are kept **in memory only for the word you are typing** and dropped on space, Return, a click or an app switch.
- **Nothing is sent anywhere.** The app has no network code at all.
- **Nothing you type is saved**, with one exception: words you un-correct with double Shift are stored locally
  so Switcher never corrects them again (`defaults read com.pivden.switcher Exceptions`).
- **Password fields are invisible to it**: macOS blocks keyboard access for every app while you type a password.
- Every line of code is in this repository. The release builds are made from it by
  [GitHub Actions](.github/workflows/release.yml).

## How it decides

A word is corrected only when the typed text is **not** a word and the same keys in the other layout **are** a word.
The check uses the spell checker built into macOS (English, Ukrainian, Russian and more).
One-letter words are never corrected.

## Usage

Stop:

```bash
pkill -x Switcher
```

Start:

```bash
open -a Switcher
```

Uninstall (Homebrew users: `brew uninstall --cask switcher`):

```bash
./uninstall.sh
```

Add your own apps where auto-correction is off (bundle IDs):

```bash
defaults write com.pivden.switcher ExcludedApps -array com.tinyspeck.slackmacgap
```

Clear the list of word exceptions:

```bash
defaults delete com.pivden.switcher Exceptions
```

Check detection without installing:

```bash
swift run -c release Switcher --test
```

## Structure

- `Sources/Switcher/Engine.swift`: keyboard interception (CGEventTap), word buffer, text replacement.
- `Sources/Switcher/Layouts.swift`: layouts, key → character tables, switching.
- `Sources/Switcher/Detector.swift`: decides whether to correct a word.
- `Sources/Switcher/main.swift`: startup, permissions, login item.
- `scripts/make_demo_gif.py`, `scripts/make_social_preview.py`: render the images in `docs/` (need Pillow).

## Releasing

1. `git tag v1.2.3 && git push origin v1.2.3`: GitHub Actions builds `Switcher.zip` and publishes the release.
2. `scripts/update_cask.sh 1.2.3`: points the Homebrew cask at the new release.

## License

MIT, see [LICENSE](LICENSE).
