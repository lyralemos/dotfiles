#!/usr/bin/env bash

if ! command -v brew &> /dev/null; then
    echo "Homebrew is not installed"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

brew install \
    git uv fzf zoxide starship eza stow \
    lua switchaudio-osx nowplaying-cli

# Ghostty
brew install --cask ghostty

# Sketchybar
brew tap FelixKratz/formulae
brew install sketchybar

# Aerospace
brew install --cask nikitabobko/tap/aerospace

# Janky Borders
brew tap FelixKratz/formulae
brew install borders

# Fonts
brew install --cask sf-symbols
brew install --cask font-sf-mono
brew install --cask font-sf-pro
brew install --cask font-sketchybar-app-font

# install dotfiles
stow aerospace
stow ghostty
stow sketchybar
stow starship

# install zshrc
[ -f ~/.zshrc ] && mv ~/.zshrc ~/.zshrc.bak && echo "Backup created: ~/.zshrc.bak" || echo ".zshrc does not exist"
stow zsh

# SbarLua
FILE="$HOME/.local/share/sketchybar_lua/sketchybar.so"
if [ ! -f "$FILE" ]; then
    git clone https://github.com/FelixKratz/SbarLua.git /tmp/SbarLua 
    cd /tmp/SbarLua/ 
    make install 
    rm -rf /tmp/SbarLua/
    cd $HOME
fi

# dev
curl -fsSL https://bun.com/install | bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash

source ~/.zshrc