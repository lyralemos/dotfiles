#!/usr/bin/env bash

set -eo pipefail

echo "========================================"
echo "  Setting up macOS dotfiles & tools"
echo "========================================"

# ------------------------------------------------------------------------------
# 1. Homebrew Setup
# ------------------------------------------------------------------------------
# Add Homebrew to PATH if already installed in standard locations
if ! command -v brew &> /dev/null; then
    if [ -x "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x "/usr/local/bin/brew" ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

# Install Homebrew if still not found
if ! command -v brew &> /dev/null; then
    echo "==> Homebrew is not installed. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Load brew environment into current subshell
    if [ -x "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x "/usr/local/bin/brew" ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

if ! command -v brew &> /dev/null; then
    echo "Error: Homebrew installation failed or 'brew' is not in PATH."
    exit 1
fi

# ------------------------------------------------------------------------------
# 2. Homebrew Taps & Formulas
# ------------------------------------------------------------------------------
echo "==> Setting up Homebrew taps..."
brew tap FelixKratz/formulae
brew tap nikitabobko/tap

# Support Homebrew 6.0+ tap trusting if available
if brew commands | grep -q "^trust$"; then
    brew trust FelixKratz/formulae 2>/dev/null || true
    brew trust nikitabobko/tap 2>/dev/null || true
fi

echo "==> Installing CLI tools & formulas..."
brew install \
    git uv fzf zoxide starship eza stow \
    lua switchaudio-osx nowplaying-cli \
    node

# Sketchybar & Janky Borders
echo "==> Installing SketchyBar and JankyBorders..."
brew install sketchybar
brew install borders

# ------------------------------------------------------------------------------
# 3. Casks & GUI Applications
# ------------------------------------------------------------------------------
echo "==> Installing Casks..."
brew install --cask ghostty
brew install --cask nikitabobko/tap/aerospace

# Fonts & Symbols
echo "==> Installing Fonts & Symbols..."
brew install --cask sf-symbols
brew install --cask font-sf-mono
brew install --cask font-sf-pro
brew install --cask font-sketchybar-app-font

# ------------------------------------------------------------------------------
# 4. Dev Tools (Bun)
# ------------------------------------------------------------------------------
# Bun
if ! command -v bun &> /dev/null && [ ! -f "$HOME/.bun/bin/bun" ]; then
    echo "==> Installing Bun..."
    curl -fsSL https://bun.sh/install | bash
fi

# ------------------------------------------------------------------------------
# 5. SbarLua (SketchyBar Lua module)
# ------------------------------------------------------------------------------
SBAR_LUA_FILE="$HOME/.local/share/sketchybar_lua/sketchybar.so"
if [ ! -f "$SBAR_LUA_FILE" ]; then
    echo "==> Building and installing SbarLua..."
    mkdir -p "$HOME/.local/share/sketchybar_lua"
    rm -rf /tmp/SbarLua
    git clone https://github.com/FelixKratz/SbarLua.git /tmp/SbarLua
    (cd /tmp/SbarLua && make install)
    rm -rf /tmp/SbarLua
fi

# ------------------------------------------------------------------------------
# 6. Locate / Clone Dotfiles Directory
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/aerospace" ]; then
    DOTFILES_DIR="$SCRIPT_DIR"
else
    DOTFILES_DIR="$HOME/dotfiles"
    if [ ! -d "$DOTFILES_DIR" ]; then
        echo "==> Cloning dotfiles into $DOTFILES_DIR..."
        git clone https://github.com/lyralemos/dotfiles.git "$DOTFILES_DIR"
    else
        echo "==> Dotfiles directory already exists at $DOTFILES_DIR"
    fi
fi

cd "$DOTFILES_DIR" || exit 1

# ------------------------------------------------------------------------------
# 7. Prepare Target Directories & Safe Backups
# ------------------------------------------------------------------------------
echo "==> Preparing configurations for GNU Stow..."
# Essential: Ensure ~/.config exists as a real directory to avoid Stow folding
mkdir -p "$HOME/.config" "$HOME/.local/share" "$HOME/.local/bin"

backup_if_exists() {
    local target="$1"
    # If it's a real file or directory (not a symlink)
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        local backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
        echo "==> Backing up existing non-symlink $(basename "$target") to $backup"
        mv "$target" "$backup"
    elif [ -L "$target" ] && [ ! -e "$target" ]; then
        # Remove broken symlink if any
        rm "$target"
    fi
}

# Backup existing configs only if they are real files/directories (not symlinks)
backup_if_exists "$HOME/.zshrc"
backup_if_exists "$HOME/.config/aerospace"
backup_if_exists "$HOME/.config/ghostty"
backup_if_exists "$HOME/.config/sketchybar"
backup_if_exists "$HOME/.config/starship.toml"
backup_if_exists "$HOME/.config/zsh"

# ------------------------------------------------------------------------------
# 8. Stow Dotfiles Packages
# ------------------------------------------------------------------------------
echo "==> Stowing packages..."
PACKAGES=(aerospace ghostty sketchybar starship zsh)

for pkg in "${PACKAGES[@]}"; do
    if [ -d "$DOTFILES_DIR/$pkg" ]; then
        echo "  -> Stowing $pkg"
        stow -R -t "$HOME" "$pkg"
    fi
done

# Ensure sketchybarrc is executable
if [ -f "$HOME/.config/sketchybar/sketchybarrc" ]; then
    chmod +x "$HOME/.config/sketchybar/sketchybarrc"
fi

# Build Sketchybar helper event providers if present
if [ -d "$HOME/.config/sketchybar/helpers" ]; then
    echo "==> Building SketchyBar helpers..."
    make -C "$HOME/.config/sketchybar/helpers" || echo "Warning: Sketchybar helpers build failed"
fi

# ------------------------------------------------------------------------------
# 9. Completion Notice
# ------------------------------------------------------------------------------
echo ""
echo "============================================================"
echo "  Dotfiles installation complete!"
echo "============================================================"
echo ""
echo "Next steps:"
echo "1. Restart your terminal or reload your shell:"
echo "     exec zsh"
echo ""
echo "2. Grant macOS Accessibility permissions:"
echo "     System Settings -> Privacy & Security -> Accessibility"
echo "     Enable permissions for: AeroSpace, SketchyBar, Ghostty"
echo ""
echo "3. (Optional) Start or reload AeroSpace & SketchyBar:"
echo "     aerospace reload-config"
echo "     sketchybar --reload"
echo ""