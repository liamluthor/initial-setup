#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=== Environment Setup Script ==="
echo ""

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    echo -e "${BLUE}ℹ${NC} Detected OS: macOS"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    echo -e "${BLUE}ℹ${NC} Detected OS: Linux"
else
    OS="unknown"
    echo -e "${YELLOW}!${NC} Unknown OS: $OSTYPE"
fi

# Detect Shell
CURRENT_SHELL=$(basename "$SHELL")
echo -e "${BLUE}ℹ${NC} Detected Shell: $CURRENT_SHELL"

# Determine config file
if [[ "$CURRENT_SHELL" == "zsh" ]]; then
    RC_FILE="$HOME/.zshrc"
elif [[ "$CURRENT_SHELL" == "bash" ]]; then
    RC_FILE="$HOME/.bashrc"
else
    RC_FILE="$HOME/.bashrc"
    echo -e "${YELLOW}!${NC} Unknown shell, defaulting to .bashrc"
fi
echo -e "${BLUE}ℹ${NC} Using config file: $RC_FILE"
echo ""

# Check/Create SSH Key
echo "Checking SSH key..."
if [ -f ~/.ssh/id_rsa.pub ]; then
    echo -e "${GREEN}✓${NC} SSH key already exists at ~/.ssh/id_rsa.pub"
else
    echo -e "${YELLOW}!${NC} SSH key not found. Creating new key..."
    mkdir -p ~/.ssh
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -C "$(whoami)@$(hostname)"
    echo -e "${GREEN}✓${NC} SSH key created"
    echo ""
    echo "Your public key:"
    cat ~/.ssh/id_rsa.pub
fi
echo ""

# Set PS1 Prompt
echo "Configuring shell prompt..."
PROMPT_LINE='export PS1='"'"'[\[\e[1;37m\]\u\[\e[1;37m\]@\[\e[1;33m\]\h \[\e[1;37m\]\W\[\e[0m\]] \[\e[0;32m\]:)\[\e[0m\] '"'"

if grep -qF "$PROMPT_LINE" "$RC_FILE" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Prompt already configured in $RC_FILE"
else
    touch "$RC_FILE"
    echo "" >> "$RC_FILE"
    echo "# Custom prompt" >> "$RC_FILE"
    echo "$PROMPT_LINE" >> "$RC_FILE"
    echo -e "${GREEN}✓${NC} Prompt added to $RC_FILE"
fi
echo ""

# Check Node.js and npm
echo "Checking Node.js and npm..."
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    echo -e "${GREEN}✓${NC} Node.js installed: $NODE_VERSION"
else
    echo -e "${RED}✗${NC} Node.js not installed"
    if [[ "$OS" == "macos" ]]; then
        echo "  Install with: brew install node"
    else
        echo "  Install with: curl -fsSL https://deb.nodesource.com/setup_lts.sh | sudo -E bash - && sudo apt-get install -y nodejs"
        echo "  Or use nvm: curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash"
    fi
fi

if command -v npm &> /dev/null; then
    NPM_VERSION=$(npm --version)
    echo -e "${GREEN}✓${NC} npm installed: $NPM_VERSION"
else
    echo -e "${RED}✗${NC} npm not installed (usually comes with Node.js)"
fi
echo ""

# Check pip3
echo "Checking pip3..."
if command -v pip3 &> /dev/null; then
    PIP_VERSION=$(pip3 --version)
    echo -e "${GREEN}✓${NC} pip3 installed: $PIP_VERSION"
else
    echo -e "${RED}✗${NC} pip3 not installed"
    if [[ "$OS" == "macos" ]]; then
        echo "  Install with: brew install python3"
    else
        echo "  Install with: sudo apt-get install python3-pip"
    fi
fi
echo ""

# Check VS Code
echo "Checking VS Code..."
if command -v code &> /dev/null; then
    CODE_VERSION=$(code --version | head -n 1)
    echo -e "${GREEN}✓${NC} VS Code installed: $CODE_VERSION"
else
    echo -e "${RED}✗${NC} VS Code not installed"
    if [[ "$OS" == "macos" ]]; then
        echo "  Install with: brew install --cask visual-studio-code"
        echo "  Or download from: https://code.visualstudio.com/"
    else
        echo "  Install with snap: sudo snap install code --classic"
        echo "  Or with apt:"
        echo "    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg"
        echo "    sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg"
        echo "    sudo sh -c 'echo \"deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main\" > /etc/apt/sources.list.d/vscode.list'"
        echo "    sudo apt-get update && sudo apt-get install code"
    fi
fi
echo ""

echo "=== Setup Complete ==="
echo "Run 'source $RC_FILE' to apply the new prompt in this session"
