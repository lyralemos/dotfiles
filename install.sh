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
    brew install --cask font-caskaydia-cove-nerd-font

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
        lua nodejs ghostty zsh unzip

    if ! fc-list | grep -qi "CaskaydiaCove Nerd Font"; then
        echo "==> Installing CaskaydiaCove Nerd Font..."
        local font_dir="$HOME/.local/share/fonts/CaskaydiaCoveNerdFont"
        local font_zip="/tmp/CascadiaCode.zip"
        mkdir -p "$font_dir"
        curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaCode.zip" -o "$font_zip"
        unzip -oq "$font_zip" -d "$font_dir"
        rm -f "$font_zip"
        fc-cache -f "$font_dir"
    fi

    if ! command -v snx-rs &> /dev/null; then
        echo "==> Installing snx-rs (Check Point VPN Client)..."
        local arch
        arch="$(uname -m)"
        [ "$arch" = "aarch64" ] && arch="arm64"
        local snx_rpm_url
        snx_rpm_url="$(curl -fsSL https://api.github.com/repos/ancwrd1/snx-rs/releases/latest \
            | python3 -c "import sys, json; assets = json.load(sys.stdin).get('assets', []); print(next((a['browser_download_url'] for a in assets if a['name'].endswith('linux-${arch}.rpm') and 'webkit' not in a['name']), ''))" 2>/dev/null || true)"

        if [ -n "$snx_rpm_url" ]; then
            sudo dnf install -y "$snx_rpm_url"
            sudo systemctl enable --now snx-rs.service
        else
            echo "Warning: Could not find snx-rs RPM for architecture $arch"
        fi
    fi

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

    if command -v dconf &> /dev/null; then
        echo "==> Configuring GNOME workspaces, shortcuts, and O-tiling settings..."
        dconf load / <<'DCONF_EOF'
[org/gnome/mutter]
dynamic-workspaces=false
edge-tiling=false
focus-change-on-pointer-rest=false
overlay-key=''

[org/gnome/mutter/keybindings]
switch-monitor=['XF86Display']
toggle-tiled-left=@as []
toggle-tiled-right=@as []

[org/gnome/desktop/wm/preferences]
button-layout='appmenu:close'
num-workspaces=5

[org/gnome/shell/keybindings]
shift-overview-down=['<Super><Alt>Down']
shift-overview-up=['<Super><Alt>Up']
switch-to-application-1=@as []
switch-to-application-2=@as []
switch-to-application-3=@as []
switch-to-application-4=@as []
switch-to-application-5=@as []
toggle-overview=['<Super>space']
toggle-quick-settings=@as []

[org/gnome/desktop/wm/keybindings]
maximize=@as []
minimize=@as []
move-to-monitor-down=@as []
move-to-monitor-left=@as []
move-to-monitor-right=@as []
move-to-monitor-up=@as []
move-to-workspace-1=['<Shift><Super>1']
move-to-workspace-2=['<Shift><Super>2']
move-to-workspace-3=['<Shift><Super>3']
move-to-workspace-4=['<Shift><Super>4']
move-to-workspace-5=['<Shift><Super>5']
switch-input-source=['XF86Keyboard']
switch-to-workspace-1=['<Super>1']
switch-to-workspace-2=['<Super>2']
switch-to-workspace-3=['<Super>3']
switch-to-workspace-4=['<Super>4']
switch-to-workspace-5=['<Super>5']
switch-to-workspace-left=['<Super>Page_Up', '<Super>KP_Prior', '<Control><Alt>Left', '<Super><Alt>Left']
switch-to-workspace-right=['<Super>Page_Down', '<Super>KP_Next', '<Control><Alt>Right', '<Super><Alt>Right']
unmaximize=@as []

[org/gnome/shell/extensions/o-tiling]
cleared-system-bindings='{"tile-enter":[{"schema_id":"org.gnome.mutter.keybindings","key":"switch-monitor","accelerator":"<Super>p","expected":["XF86Display"]}],"focus-left":[{"schema_id":"org.gnome.desktop.wm.keybindings","key":"minimize","accelerator":"<Super>h","expected":[]}],"toggle-stacking-global":[{"schema_id":"org.gnome.shell.keybindings","key":"toggle-quick-settings","accelerator":"<Super>s","expected":[]}],"tile-move-down-global":[{"schema_id":"org.gnome.desktop.wm.keybindings","key":"move-to-monitor-down","accelerator":"<Super><Shift>Down","expected":[]}],"tile-move-up-global":[{"schema_id":"org.gnome.desktop.wm.keybindings","key":"move-to-monitor-up","accelerator":"<Super><Shift>Up","expected":[]}]}'
focus-down=['<Super>Down', '<Super>j']
focus-left=['<Super>Left', '<Super>h']
focus-right=['<Super>Right', '<Super>l']
focus-up=['<Super>Up', '<Super>k']
gap-inner=uint32 3
gap-outer=uint32 3
hide-panel-icon=false
panel-transparency=true
panel-transparency-opacity=uint32 40
pop-workspace-down=['<Super><Shift>j']
pop-workspace-up=['<Super><Shift>k']
show-minimize-maximize-buttons=false
show-overview-button-in-indicator=false
skip-overview=true
stacking-with-mouse=false
theme-consistency-style='default'
tile-enter=['<Super>p']
tile-move-down-global=['<Super><Shift>Down']
tile-move-left-global=['<Super><Shift>Left']
tile-move-right-global=['<Super><Shift>Right']
tile-move-up-global=['<Super><Shift>Up']
tile-resize-left=['<Super>Equal', '<Shift>KP_Left', '<Shift>h']
tile-resize-right=['<Super>Minus', '<Shift>KP_Right', '<Shift>l']
tile-swap-left=['<Primary><Super>Left', '<Primary><Super>h']
tile-swap-right=['<Primary><Super>Right', '<Primary><Super>l']
window-animation-style='hyprland'
workspace-animation-style='none'
workspace-number-indicator=false
workspace-switcher-style=true

[org/gnome/settings-daemon/plugins/media-keys]
custom-keybindings=['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/']

[org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0]
binding='<Shift><Super>Return'
command='firefox'
name='Abrir navegador'

[org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1]
binding='<Super>Return'
command='ghostty'
name='Abrir Terminal'
DCONF_EOF
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
# Essential: Ensure ~/.config and ~/.config/Code/User exist as real directories to avoid Stow folding
mkdir -p "$HOME/.config" "$HOME/.config/Code/User" "$HOME/.local/share" "$HOME/.local/bin"

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
backup_if_exists "$HOME/.config/snx-rs"
backup_if_exists "$HOME/.config/starship.toml"
backup_if_exists "$HOME/.config/zsh"
backup_if_exists "$HOME/.config/Code/User/settings.json"

if [ "$OS_TYPE" = "macos" ]; then
    backup_if_exists "$HOME/.config/aerospace"
    backup_if_exists "$HOME/.config/sketchybar"
fi

# ------------------------------------------------------------------------------
# 5. Stow Dotfiles Packages
# ------------------------------------------------------------------------------
echo "==> Stowing packages..."
if [ "$OS_TYPE" = "macos" ]; then
    PACKAGES=(aerospace ghostty sketchybar snx-rs starship vscode zsh)
else
    PACKAGES=(ghostty snx-rs starship vscode zsh)
fi

for pkg in "${PACKAGES[@]}"; do
    if [ -d "$DOTFILES_DIR/$pkg" ]; then
        echo "  -> Stowing $pkg"
        stow -R -t "$HOME" "$pkg"
    fi
done

if [ "$OS_TYPE" = "macos" ]; then
    # Link VS Code settings.json to macOS Application Support directory
    MACOS_VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
    mkdir -p "$MACOS_VSCODE_USER_DIR"
    backup_if_exists "$MACOS_VSCODE_USER_DIR/settings.json"
    ln -sf "$HOME/.config/Code/User/settings.json" "$MACOS_VSCODE_USER_DIR/settings.json"

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
# 6. VS Code Extensions
# ------------------------------------------------------------------------------
if command -v code &> /dev/null; then
    echo "==> Installing VS Code extensions..."
    VSCODE_EXTENSIONS=(
        "iwyvi.chinolor"
        "miguelsolorio.symbols"
        "ms-vscode.makefile-tools"
        "ms-python.python"
        "batisteo.vscode-django"
    )
    for ext in "${VSCODE_EXTENSIONS[@]}"; do
        echo "  -> Installing VS Code extension: $ext"
        code --install-extension "$ext" --force
    done
fi

# ------------------------------------------------------------------------------
# 7. Completion Notice
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
