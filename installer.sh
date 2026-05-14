#!/usr/bin/env bash

# =========================================================
# HVM PANEL V8 UNIVERSAL INSTALLER
# FILE NAME: install.sh
# PANEL BINARY: hvm.bin
# PORT: 5000
# USERNAME: admin
# PASSWORD: admin
# =========================================================

clear

# =========================================================
# COLORS
# =========================================================

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# =========================================================
# VARIABLES
# =========================================================

HVM_URL="https://download1583.mediafire.com/3z0i8stqa1zgNI9x-OrcdR3dS3wM6AkEYnMmXHY2VrRZBN6dbEuq_J3Oa6wutLTh4UGBff0rJnl3JhdyQENZ2uXaVrmelj0MlleWWFNxArn6hBPM0KqDOCoxKH0tag6Vw3UlH5T8troqXIJLzh5_f859eDspOwo4tbSihZwVdRbrtg/b51c1b41scg3ev7/hvm.bin"

INSTALL_DIR="/opt/hvm"
SERVICE_NAME="hvm"
PANEL_PORT="5000"

# =========================================================
# LOGO
# =========================================================

echo -e "${CYAN}"

cat << "EOF"

██╗  ██╗██╗   ██╗███╗   ███╗
██║  ██║██║   ██║████╗ ████║
███████║██║   ██║██╔████╔██║
██╔══██║╚██╗ ██╔╝██║╚██╔╝██║
██║  ██║ ╚████╔╝ ██║ ╚═╝ ██║
╚═╝  ╚═╝  ╚═══╝  ╚═╝     ╚═╝

        HVM PANEL V8 UNIVERSAL INSTALLER

EOF

echo -e "${NC}"

sleep 2

# =========================================================
# ROOT CHECK
# =========================================================

if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}[ERROR] Please run this installer as root.${NC}"
    exit 1
fi

# =========================================================
# ARCH CHECK
# =========================================================

ARCH=$(uname -m)

echo -e "${BLUE}[INFO] Detected Architecture:${NC} $ARCH"

# =========================================================
# OS DETECTION
# =========================================================

if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
    VERSION=$VERSION_ID
else
    echo -e "${RED}[ERROR] Cannot detect operating system.${NC}"
    exit 1
fi

echo -e "${BLUE}[INFO] Detected OS:${NC} $PRETTY_NAME"

# =========================================================
# PACKAGE MANAGER DETECTION
# =========================================================

install_deps() {

    echo -e "${CYAN}[INFO] Installing required packages...${NC}"

    if command -v apt >/dev/null 2>&1; then

        apt update -y
        apt install -y \
        wget curl unzip tar sudo nano \
        python3 python3-pip \
        net-tools lsof ca-certificates

    elif command -v dnf >/dev/null 2>&1; then

        dnf update -y
        dnf install -y \
        wget curl unzip tar sudo nano \
        python3 python3-pip \
        net-tools lsof ca-certificates

    elif command -v yum >/dev/null 2>&1; then

        yum update -y
        yum install -y epel-release
        yum install -y \
        wget curl unzip tar sudo nano \
        python3 python3-pip \
        net-tools lsof ca-certificates

    elif command -v apk >/dev/null 2>&1; then

        apk update
        apk add \
        wget curl unzip tar sudo nano \
        python3 py3-pip \
        net-tools lsof ca-certificates

    elif command -v pacman >/dev/null 2>&1; then

        pacman -Sy --noconfirm \
        wget curl unzip tar sudo nano \
        python python-pip \
        net-tools lsof ca-certificates

    elif command -v zypper >/dev/null 2>&1; then

        zypper refresh
        zypper install -y \
        wget curl unzip tar sudo nano \
        python3 python3-pip \
        net-tools lsof ca-certificates

    else
        echo -e "${RED}[ERROR] Unsupported package manager.${NC}"
        exit 1
    fi

    echo -e "${GREEN}[OK] Dependencies installed.${NC}"
}

install_deps

# =========================================================
# CREATE INSTALL DIRECTORY
# =========================================================

echo -e "${CYAN}[INFO] Creating HVM directory...${NC}"

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || exit 1

# =========================================================
# DOWNLOAD HVM BINARY
# =========================================================

echo -e "${CYAN}[INFO] Downloading hvm.bin...${NC}"

rm -f hvm.bin

wget --progress=bar:force -O hvm.bin "$HVM_URL"

if [ ! -f hvm.bin ]; then
    echo -e "${RED}[ERROR] Failed to download hvm.bin${NC}"
    exit 1
fi

chmod +x hvm.bin

echo -e "${GREEN}[OK] hvm.bin downloaded successfully.${NC}"

# =========================================================
# FIREWALL CONFIG
# =========================================================

echo -e "${CYAN}[INFO] Configuring firewall...${NC}"

if command -v ufw >/dev/null 2>&1; then
    ufw allow ${PANEL_PORT}/tcp >/dev/null 2>&1
fi

if command -v firewall-cmd >/dev/null 2>&1; then
    firewall-cmd --permanent --add-port=${PANEL_PORT}/tcp >/dev/null 2>&1
    firewall-cmd --reload >/dev/null 2>&1
fi

if command -v iptables >/dev/null 2>&1; then
    iptables -I INPUT -p tcp --dport ${PANEL_PORT} -j ACCEPT >/dev/null 2>&1
fi

echo -e "${GREEN}[OK] Firewall configured.${NC}"

# =========================================================
# SYSTEMD SERVICE
# =========================================================

if command -v systemctl >/dev/null 2>&1; then

echo -e "${CYAN}[INFO] Creating systemd service...${NC}"

cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=HVM Panel V8
After=network.target

[Service]
Type=simple
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/hvm.bin
Restart=always
RestartSec=3
LimitNOFILE=999999
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ${SERVICE_NAME} >/dev/null 2>&1
systemctl restart ${SERVICE_NAME}

echo -e "${GREEN}[OK] Systemd service created.${NC}"

else

echo -e "${YELLOW}[WARNING] systemd not detected.${NC}"
echo -e "${YELLOW}[WARNING] Starting HVM manually in background...${NC}"

nohup ${INSTALL_DIR}/hvm.bin > /dev/null 2>&1 &

fi

# =========================================================
# CHECK PORT
# =========================================================

sleep 3

PORT_CHECK=$(lsof -i:${PANEL_PORT} | grep LISTEN)

if [ -n "$PORT_CHECK" ]; then
    PANEL_STATUS="${GREEN}RUNNING${NC}"
else
    PANEL_STATUS="${RED}OFFLINE${NC}"
fi

# =========================================================
# GET SERVER IP
# =========================================================

PUBLIC_IP=$(curl -4 -s ifconfig.me)

if [ -z "$PUBLIC_IP" ]; then
    PUBLIC_IP=$(hostname -I | awk '{print $1}')
fi

# =========================================================
# FINISH
# =========================================================

clear

echo -e "${GREEN}"

cat << EOF

===========================================================
                HVM PANEL V8 INSTALLED
===========================================================

STATUS            : $PANEL_STATUS

PANEL URL         : http://${PUBLIC_IP}:${PANEL_PORT}

USERNAME          : admin
PASSWORD          : admin

INSTALL DIRECTORY : ${INSTALL_DIR}

BINARY FILE       : ${INSTALL_DIR}/hvm.bin

SERVICE NAME      : ${SERVICE_NAME}

===========================================================

MANAGEMENT COMMANDS

systemctl start hvm
systemctl stop hvm
systemctl restart hvm
systemctl status hvm

===========================================================

EOF

echo -e "${NC}"
