# My dotfiles

My personal dotfiles for **macOS** and **Fedora Linux (GNOME)**.

## Install

```shell
curl -o- https://raw.githubusercontent.com/lyralemos/dotfiles/main/install.sh | bash
```

The installation script automatically detects the operating system (**macOS** or **Fedora**) and installs the appropriate packages and configurations.

### Common Tools (macOS & Fedora)

* git
* zsh (set as default shell on Fedora)
* uv
* fzf
* zoxide
* Starship
* eza
* stow
* lua
* Node.js
* Bun
* Ghostty

### macOS Specific

* Homebrew
* switchaudio-osx
* nowplaying-cli
* SketchyBar (with SbarLua)
* AeroSpace
* Janky Borders
* Fonts & Symbols (`sf-symbols`, `font-sf-mono`, `font-sf-pro`, `font-sketchybar-app-font`)

### Fedora (GNOME) Specific

* Extension Manager (`com.mattjakeman.ExtensionManager` via Flatpak)
* GNOME Shell Extensions:
  * AppIndicator and KStatusNotifierItem Support (`appindicatorsupport@rgcjonas.gmail.com`)
  * Blur my Shell (`blur-my-shell@aunetx`)
  * Disable Workspace Switch Animation (`instantworkspaceswitcher@amalantony.net`)
  * O-tiling (`o-tiling@oliwebd.github.com`)

---

Dotfiles are managed by [GNU Stow](https://www.gnu.org/software/stow/).

SketchyBar (on macOS) is a simplified version of [Felix Kratz's](https://github.com/FelixKratz/dotfiles) config with support for AeroSpace.

![Alt Text](screen.png)
