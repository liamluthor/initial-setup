#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo "=== Kali-Style Tools Setup Script ==="
echo ""

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    PKG_MANAGER="brew"
    echo -e "${BLUE}ℹ${NC} Detected OS: macOS"
    echo -e "${BLUE}ℹ${NC} Package Manager: Homebrew"
    
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        echo -e "${RED}✗${NC} Homebrew not found!"
        echo "Install with: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    PKG_MANAGER="apt"
    echo -e "${BLUE}ℹ${NC} Detected OS: Linux"
    echo -e "${BLUE}ℹ${NC} Package Manager: apt"
    
    # Check if running as root or with sudo
    if [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}!${NC} This script needs sudo privileges for package installation"
        SUDO="sudo"
    else
        SUDO=""
    fi
else
    OS="unknown"
    echo -e "${RED}✗${NC} Unknown OS: $OSTYPE"
    exit 1
fi
echo ""

# Function to install package
install_package() {
    local package=$1
    local brew_name=${2:-$package}
    local apt_name=${3:-$package}
    
    if command -v "$package" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $package already installed"
        return 0
    fi
    
    echo -e "${YELLOW}→${NC} Installing $package..."
    
    if [[ "$OS" == "macos" ]]; then
        brew install "$brew_name" &> /dev/null
    else
        $SUDO apt-get install -y "$apt_name" &> /dev/null
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $package installed successfully"
    else
        echo -e "${RED}✗${NC} Failed to install $package"
    fi
}

# Update package manager
echo -e "${CYAN}=== Updating Package Manager ===${NC}"
if [[ "$OS" == "macos" ]]; then
    brew update &> /dev/null
else
    $SUDO apt-get update &> /dev/null
fi
echo -e "${GREEN}✓${NC} Package manager updated"
echo ""

# Network Scanning & Enumeration
echo -e "${CYAN}=== Network Scanning & Enumeration ===${NC}"
install_package "nmap" "nmap" "nmap"
install_package "netcat" "netcat" "netcat-traditional"
install_package "masscan" "masscan" "masscan"
if [[ "$OS" == "linux" ]]; then
    install_package "ifconfig" "net-tools" "net-tools"
fi
echo ""

# Network Analysis
echo -e "${CYAN}=== Network Analysis ===${NC}"
install_package "tshark" "wireshark" "tshark"
if [[ "$OS" == "macos" ]]; then
    install_package "wireshark" "wireshark" "wireshark"
else
    echo -e "${YELLOW}→${NC} Wireshark GUI (requires manual setup on Linux)"
    echo "  Install with: sudo apt-get install wireshark"
fi
install_package "tcpdump" "tcpdump" "tcpdump"
install_package "ettercap" "ettercap" "ettercap-text-only"
echo ""

# Web Application Testing
echo -e "${CYAN}=== Web Application Testing ===${NC}"
install_package "nikto" "nikto" "nikto"
install_package "sqlmap" "sqlmap" "sqlmap"
install_package "gobuster" "gobuster" "gobuster"
install_package "dirb" "dirb" "dirb"
install_package "wfuzz" "wfuzz" "wfuzz"
echo ""

# Password Attacks
echo -e "${CYAN}=== Password Attacks ===${NC}"
install_package "john" "john" "john"
install_package "hashcat" "hashcat" "hashcat"
install_package "hydra" "hydra" "hydra"
echo ""

# Exploitation Framework
echo -e "${CYAN}=== Exploitation Tools ===${NC}"
if [[ "$OS" == "macos" ]]; then
    echo -e "${YELLOW}→${NC} Metasploit Framework..."
    if ! command -v msfconsole &> /dev/null; then
        brew install metasploit &> /dev/null
        echo -e "${GREEN}✓${NC} Metasploit installed"
    else
        echo -e "${GREEN}✓${NC} Metasploit already installed"
    fi
else
    echo -e "${YELLOW}→${NC} Metasploit Framework (manual install recommended)"
    echo "  Install with: curl https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > msfinstall && chmod 755 msfinstall && ./msfinstall"
fi
install_package "exploitdb" "exploitdb" "exploitdb"
echo ""

# Forensics
echo -e "${CYAN}=== Forensics Tools ===${NC}"
install_package "binwalk" "binwalk" "binwalk"
install_package "foremost" "foremost" "foremost"
install_package "exiftool" "exiftool" "libimage-exiftool-perl"
install_package "steghide" "steghide" "steghide"
if [[ "$OS" == "macos" ]]; then
    echo -e "${YELLOW}→${NC} Volatility (Python-based, install via pip3)"
    echo "  pip3 install volatility3"
else
    echo -e "${YELLOW}→${NC} Volatility (Python-based, install via pip3)"
    echo "  pip3 install volatility3"
fi
echo ""

# Reverse Engineering
echo -e "${CYAN}=== Reverse Engineering ===${NC}"
install_package "radare2" "radare2" "radare2"
install_package "gdb" "gdb" "gdb"
if [[ "$OS" == "macos" ]]; then
    echo -e "${YELLOW}→${NC} Ghidra (requires manual download)"
    echo "  Download from: https://ghidra-sre.org/"
else
    echo -e "${YELLOW}→${NC} Ghidra (download from NSA)"
    echo "  Download from: https://ghidra-sre.org/"
fi
echo ""

# Wireless Tools (Linux only)
if [[ "$OS" == "linux" ]]; then
    echo -e "${CYAN}=== Wireless Tools ===${NC}"
    install_package "aircrack-ng" "aircrack-ng" "aircrack-ng"
    install_package "reaver" "reaver" "reaver"
    echo ""
fi

# Additional Utilities
echo -e "${CYAN}=== Additional Utilities ===${NC}"
install_package "git" "git" "git"
install_package "wget" "wget" "wget"
install_package "curl" "curl" "curl"
install_package "whois" "whois" "whois"
install_package "dnsutils" "bind" "dnsutils"
echo ""

# Python Security Libraries
echo -e "${CYAN}=== Python Security Libraries ===${NC}"
echo -e "${YELLOW}→${NC} Installing Python security libraries..."
pip3 install --quiet requests scapy pwntools 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Python libraries installed (requests, scapy, pwntools)"
else
    echo -e "${YELLOW}!${NC} Some Python libraries may have failed (run 'pip3 install requests scapy pwntools')"
fi
echo ""

echo -e "${GREEN}=== Installation Complete ===${NC}"
echo ""
echo "Tools installed successfully! You now have a Kali-style toolkit."
echo ""
echo "Additional recommendations:"
echo "  - Burp Suite Community: https://portswigger.net/burp/communitydownload"
echo "  - Ghidra: https://ghidra-sre.org/"
echo "  - OWASP ZAP: https://www.zaproxy.org/download/"
echo ""
