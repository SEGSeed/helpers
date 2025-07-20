#!/bin/bash

# Color definitions
red='\033[0;31m'
green='\033[0;32m'
blue='\033[0;34m'
yellow='\033[0;33m'
plain='\033[0m'

# Must run as root
[[ $EUID -ne 0 ]] && echo -e "${red}Fatal error:${plain} Please run this script as root." && exit 1

# Detect OS
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
else
    echo -e "${red}Could not detect OS.${plain} Exiting." && exit 1
fi

# Detect CPU architecture
arch() {
    case "$(uname -m)" in
        x86_64 | x64 | amd64) echo 'amd64' ;;
        i*86 | x86) echo '386' ;;
        armv8* | armv8 | arm64 | aarch64) echo 'arm64' ;;
        armv7* | armv7 | arm) echo 'armv7' ;;
        *) echo -e "${red}Unsupported CPU architecture!${plain}" && exit 1 ;;
    esac
}

ARCH=$(arch)
echo -e "${green}Detected architecture: ${ARCH}${plain}"

# Check glibc version
check_glibc_version() {
    glibc_version=$(ldd --version | head -n1 | awk '{print $NF}')
    required_version="2.32"
    if [[ "$(printf '%s\n' "$required_version" "$glibc_version" | sort -V | head -n1)" != "$required_version" ]]; then
        echo -e "${red}GLIBC version $glibc_version is too old! Required: 2.32 or higher.${plain}"
        exit 1
    fi
}
check_glibc_version

# Install base packages
install_base() {
    case "${release}" in
        ubuntu | debian)
            apt update && apt install -y wget curl tar tzdata
            ;;
        centos | rhel | almalinux | rocky)
            yum update -y && yum install -y wget curl tar tzdata
            ;;
        fedora)
            dnf update -y && dnf install -y wget curl tar tzdata
            ;;
        arch)
            pacman -Syu --noconfirm wget curl tar tzdata
            ;;
        *)
            apt update && apt install -y wget curl tar tzdata
            ;;
    esac
}
install_base

# Install x-ui v2.4.5
XUI_VERSION="v2.4.5"
DOWNLOAD_URL="https://github.com/MHSanaei/3x-ui/releases/download/${XUI_VERSION}/x-ui-linux-${ARCH}.tar.gz"

cd /usr/local/
echo -e "${yellow}Downloading x-ui ${XUI_VERSION}...${plain}"
wget -O x-ui.tar.gz "${DOWNLOAD_URL}"
if [[ $? -ne 0 ]]; then
    echo -e "${red}Download failed. Check your internet or GitHub access.${plain}" && exit 1
fi

# Clean previous x-ui installation
systemctl stop x-ui >/dev/null 2>&1
rm -rf /usr/local/x-ui
tar zxvf x-ui.tar.gz && rm -f x-ui.tar.gz
cd x-ui
chmod +x x-ui bin/*

# Install service
cp -f x-ui.service /etc/systemd/system/
wget -O /usr/bin/x-ui https://raw.githubusercontent.com/MHSanaei/3x-ui/main/x-ui.sh
chmod +x /usr/bin/x-ui
chmod +x /usr/local/x-ui/x-ui.sh

# Enable and start service
systemctl daemon-reload
systemctl enable x-ui
systemctl start x-ui

# Custom Configuration from environment variables
USERNAME="${USERNAME:-}"
PASSWORD="${PASSWORD:-}"
PORT="${PORT:-}"
WEBPATH="${WEBPATH:-}"

/usr/local/x-ui/x-ui setting -username "${USERNAME}" -password "${PASSWORD}" -port "${PORT}" -webBasePath "${WEBPATH}"
/usr/local/x-ui/x-ui migrate

SERVER_IP=$(curl -s https://api.ipify.org)

# Output
echo -e "${green}x-ui ${XUI_VERSION} installed with custom credentials!${plain}"
echo -e "###############################################"
echo -e "${green}Username: ${USERNAME}${plain}"
echo -e "${green}Password: ${PASSWORD}${plain}"
echo -e "${green}Port: ${PORT}${plain}"
echo -e "${green}WebBasePath: ${WEBPATH:-(empty)}${plain}"
echo -e "${green}Access URL: http://${SERVER_IP}:${PORT}/${WEBPATH}${plain}"
echo -e "###############################################"

# Help
echo -e "
┌───────────────────────────────────────────────────────┐
│  ${blue}x-ui control commands:${plain}
│
│  x-ui              - Admin panel script
│  x-ui start        - Start service
│  x-ui stop         - Stop service
│  x-ui restart      - Restart service
│  x-ui status       - Check status
│  x-ui log          - View logs
│  x-ui setting      - Show current settings
│  x-ui update       - Update x-ui
│  x-ui uninstall    - Uninstall x-ui
└───────────────────────────────────────────────────────┘
"
