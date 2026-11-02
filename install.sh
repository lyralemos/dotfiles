#!/usr/bin/env bash

set -eo pipefail

# ------------------------------------------------------------------------------
# 0. Environment Detection
# ------------------------------------------------------------------------------
OS_TYPE=""
if [ "$(uname -s)" = "Darwin" ]; then
    OS_TYPE="macos"
elif [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    if [ "$ID" = "fedora" ]; then
        OS_TYPE="fedora"
    fi
fi

if [ -z "$OS_TYPE" ]; then
    echo "Error: Unsupported operating system. Only macOS and Fedora Linux are supported."
    exit 1
fi

echo "========================================"
echo "  Setting up $OS_TYPE dotfiles & tools"
echo "========================================"

# ------------------------------------------------------------------------------
# 1. OS-Specific Package Installation
# ------------------------------------------------------------------------------
install_macos_packages() {
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

    # Casks & GUI Applications
    echo "==> Installing Casks..."
    brew install --cask ghostty
    brew install --cask nikitabobko/tap/aerospace

    # Fonts & Symbols
    echo "==> Installing Fonts & Symbols..."
    brew install --cask sf-symbols
    brew install --cask font-sf-mono
    brew install --cask font-sf-pro
    brew install --cask font-sketchybar-app-font

    # SbarLua (SketchyBar Lua module)
    SBAR_LUA_FILE="$HOME/.local/share/sketchybar_lua/sketchybar.so"
    if [ ! -f "$SBAR_LUA_FILE" ]; then
        echo "==> Building and installing SbarLua..."
        mkdir -p "$HOME/.local/share/sketchybar_lua"
        rm -rf /tmp/SbarLua
        git clone https://github.com/FelixKratz/SbarLua.git /tmp/SbarLua
        (cd /tmp/SbarLua && make install)
        rm -rf /tmp/SbarLua
    fi
}

install_fedora_packages() {
    echo "==> Enabling COPR repositories (starship, ghostty)..."
    sudo dnf copr enable -y atim/starship
    sudo dnf copr enable -y scottames/ghostty

    echo "==> Installing CLI tools & applications via DNF..."
    sudo dnf install -y \
        git uv fzf zoxide starship eza stow \
        lua nodejs ghostty zsh

    echo "==> Installing Flatpak applications (Extension Manager)..."
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub com.mattjakeman.ExtensionManager

    if command -v gnome-shell &> /dev/null && command -v gnome-extensions &> /dev/null; then
        echo "==> Installing and enabling GNOME Shell extensions..."
        local gnome_ver
        gnome_ver="$(gnome-shell --version | awk '{print $3}' | cut -d. -f1)"
        local extensions=(
            "appindicatorsupport@rgcjonas.gmail.com"
            "blur-my-shell@aunetx"
            "instantworkspaceswitcher@amalantony.net"
            "o-tiling@oliwebd.github.com"
        )

        for uuid in "${extensions[@]}"; do
            echo "  -> Installing GNOME extension: $uuid"
            local download_url
            download_url="$(curl -fsSL "https://extensions.gnome.org/extension-info/?uuid=${uuid}&shell_version=${gnome_ver}" \
                | python3 -c "import sys, json; print(json.load(sys.stdin).get('download_url', ''))" 2>/dev/null || true)"

            if [ -n "$download_url" ]; then
                local tmp_zip="/tmp/${uuid}.shell-extension.zip"
                curl -fsSL "https://extensions.gnome.org${download_url}" -o "$tmp_zip"
                gnome-extensions install --force "$tmp_zip"
                rm -f "$tmp_zip"
                gnome-extensions enable "$uuid" 2>/dev/null || true
            else
                echo "     Warning: Could not find download URL for $uuid (GNOME $gnome_ver)"
            fi
        done

        # Ensure all 4 extensions are registered in gsettings enabled-extensions
        if command -v gsettings &> /dev/null; then
            python3 - "${extensions[@]}" <<'PYEOF'
import ast, subprocess, sys

try:
    raw = subprocess.check_output(
        ["gsettings", "get", "org.gnome.shell", "enabled-extensions"],
        text=True,
    ).strip()
    if raw.startswith("@as "):
        raw = raw[4:]
    current = list(ast.literal_eval(raw))
except Exception:
    current = []

for ext in sys.argv[1:]:
    if ext not in current:
        current.append(ext)

subprocess.run(
    ["gsettings", "set", "org.gnome.shell", "enabled-extensions", str(current)],
    check=False,
)
PYEOF
        fi
    fi

    local zsh_path
    zsh_path="$(command -v zsh)"
    local current_shell
    current_shell="$(getent passwd "$USER" | cut -d: -f7)"

    if [ -n "$zsh_path" ] && [ "$current_shell" != "$zsh_path" ]; then
        echo "==> Setting zsh ($zsh_path) as the default shell for $USER..."
        sudo usermod -s "$zsh_path" "$USER"
    fi
}

if [ "$OS_TYPE" = "macos" ]; then
    install_macos_packages
elif [ "$OS_TYPE" = "fedora" ]; then
    install_fedora_packages
fi

# ------------------------------------------------------------------------------
# 2. Dev Tools (Bun)
# ------------------------------------------------------------------------------
if ! command -v bun &> /dev/null && [ ! -f "$HOME/.bun/bin/bun" ]; then
    echo "==> Installing Bun..."
    curl -fsSL https://bun.sh/install | bash
fi

# ------------------------------------------------------------------------------
# 3. Locate / Clone Dotfiles Directory
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/zsh" ]; then
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
# 4. Prepare Target Directories & Safe Backups
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
backup_if_exists "$HOME/.config/ghostty"
backup_if_exists "$HOME/.config/starship.toml"
backup_if_exists "$HOME/.config/zsh"

if [ "$OS_TYPE" = "macos" ]; then
    backup_if_exists "$HOME/.config/aerospace"
    backup_if_exists "$HOME/.config/sketchybar"
fi

# ------------------------------------------------------------------------------
# 5. Stow Dotfiles Packages
# ------------------------------------------------------------------------------
echo "==> Stowing packages..."
if [ "$OS_TYPE" = "macos" ]; then
    PACKAGES=(aerospace ghostty sketchybar starship zsh)
else
    PACKAGES=(ghostty starship zsh)
fi

for pkg in "${PACKAGES[@]}"; do
    if [ -d "$DOTFILES_DIR/$pkg" ]; then
        echo "  -> Stowing $pkg"
        stow -R -t "$HOME" "$pkg"
    fi
done

if [ "$OS_TYPE" = "macos" ]; then
    # Ensure sketchybarrc is executable
    if [ -f "$HOME/.config/sketchybar/sketchybarrc" ]; then
        chmod +x "$HOME/.config/sketchybar/sketchybarrc"
    fi

    # Build Sketchybar helper event providers if present
    if [ -d "$HOME/.config/sketchybar/helpers" ]; then
        echo "==> Building SketchyBar helpers..."
        make -C "$HOME/.config/sketchybar/helpers" || echo "Warning: Sketchybar helpers build failed"
    fi
fi

# ------------------------------------------------------------------------------
# 6. Completion Notice
# ------------------------------------------------------------------------------
echo ""
echo "============================================================"
echo "  Dotfiles installation complete! ($OS_TYPE)"
echo "============================================================"
echo ""
echo "Next steps:"
echo "1. Restart your terminal or reload your shell:"
echo "     exec zsh"
echo ""

if [ "$OS_TYPE" = "macos" ]; then
    echo "2. Grant macOS Accessibility permissions:"
    echo "     System Settings -> Privacy & Security -> Accessibility"
    echo "     Enable permissions for: AeroSpace, SketchyBar, Ghostty"
    echo ""
    echo "3. (Optional) Start or reload AeroSpace & SketchyBar:"
    echo "     aerospace reload-config"
    echo "     sketchybar --reload"
    echo ""
fi
