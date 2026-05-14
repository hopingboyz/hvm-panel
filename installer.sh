#!/usr/bin/env bash

# =========================================================
# HVM PANEL V8 ULTRA INSTALLER
# FILE NAME: install.sh
# PANEL FILE: hvm.bin
# PORT: 5000
# USERNAME: admin
# PASSWORD: admin
# =========================================================

set -euo pipefail

# =========================================================
# COLORS
# =========================================================

RED="\e[1;31m"
GREEN="\e[1;32m"
YELLOW="\e[1;33m"
BLUE="\e[1;34m"
CYAN="\e[1;36m"
MAGENTA="\e[1;35m"
WHITE="\e[1;37m"
NC="\e[0m"

# =========================================================
# VARIABLES
# =========================================================

HVM_URL="https://download1583.mediafire.com/3z0i8stqa1zgNI9x-OrcdR3dS3wM6AkEYnMmXHY2VrRZBN6dbEuq_J3Oa6wutLTh4UGBff0rJnl3JhdyQENZ2uXaVrmelj0MlleWWFNxArn6hBPM0KqDOCoxKH0tag6Vw3UlH5T8troqXIJLzh5_f859eDspOwo4tbSihZwVdRbrtg/b51c1b41scg3ev7/hvm.bin"

INSTALL_DIR="/opt/hvm"
SERVICE_NAME="hvm"
PANEL_PORT="5000"
BIN_FILE="${INSTALL_DIR}/hvm.bin"
LOG_FILE="/var/log/hvm.log"

# =========================================================
# UI FUNCTIONS
# =========================================================

line() {
    echo -e "${MAGENTA}============================================================${NC}"
}

info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

spinner() {
    local pid=$1
    local delay=0.08
    local spin='⠋⠙⠸⠴⠦⠇'

    while ps -p $pid > /dev/null 2>&1; do
        for i in $(seq 0 5); do
            printf "\r${CYAN}%s${NC} " "${spin:$i:1}"
            sleep $delay
        done
    done

    printf "\r"
}

# =========================================================
# LOGO
# =========================================================

clear

echo -e "${CYAN}"

cat << "EOF"

  _    _  __      __  __  __              _____               _   _   ______   _      
 | |  | | \ \    / / |  \/  |            |  __ \      /\     | \ | | |  ____| | |     
 | |__| |  \ \  / /  | \  / |   ______   | |__) |    /  \    |  \| | | |__    | |     
 |  __  |   \ \/ /   | |\/| |  |______|  |  ___/    / /\ \   | . ` | |  __|   | |     
 | |  | |    \  /    | |  | |            | |       / ____ \  | |\  | | |____  | |____ 
 |_|  |_|     \/     |_|  |_|            |_|      /_/    \_\ |_| \_| |______| |______|
                                                                                      
                                                                                      

        HVM PANEL V8 ULTRA INSTALLER

EOF

echo -e "${NC}"

line

# =========================================================
# ROOT CHECK
# =========================================================

if [[ "$EUID" -ne 0 ]]; then
    error "Please run this installer as root."
    exit 1
fi

# =========================================================
# OS DETECTION
# =========================================================

if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    DISTRO=$ID
    VERSION=$VERSION_ID
else
    error "Unable to detect operating system."
    exit 1
fi

ARCH=$(uname -m)

info "Detected OS: ${PRETTY_NAME}"
info "Architecture: ${ARCH}"

line

# =========================================================
# PACKAGE INSTALL
# =========================================================

install_packages() {

    info "Installing required dependencies..."

    if command -v apt >/dev/null 2>&1; then

        export DEBIAN_FRONTEND=noninteractive

        apt update -y >/dev/null 2>&1

        apt install -y \
        wget curl unzip tar sudo nano \
        python3 python3-pip \
        net-tools lsof ca-certificates \
        gnupg software-properties-common \
        >/dev/null 2>&1

    elif command -v dnf >/dev/null 2>&1; then

        dnf install -y \
        wget curl unzip tar sudo nano \
        python3 python3-pip \
        net-tools lsof ca-certificates \
        >/dev/null 2>&1

    elif command -v yum >/dev/null 2>&1; then

        yum install -y epel-release >/dev/null 2>&1

        yum install -y \
        wget curl unzip tar sudo nano \
        python3 python3-pip \
        net-tools lsof ca-certificates \
        >/dev/null 2>&1

    elif command -v pacman >/dev/null 2>&1; then

        pacman -Sy --noconfirm \
        wget curl unzip tar sudo nano \
        python python-pip \
        net-tools lsof ca-certificates \
        >/dev/null 2>&1

    elif command -v apk >/dev/null 2>&1; then

        apk update >/dev/null 2>&1

        apk add \
        wget curl unzip tar sudo nano \
        python3 py3-pip \
        net-tools lsof ca-certificates \
        >/dev/null 2>&1

    elif command -v zypper >/dev/null 2>&1; then

        zypper refresh >/dev/null 2>&1

        zypper install -y \
        wget curl unzip tar sudo nano \
        python3 python3-pip \
        net-tools lsof ca-certificates \
        >/dev/null 2>&1

    else
        error "Unsupported Linux distribution."
        exit 1
    fi

    ok "Dependencies installed successfully."
}

install_packages

line

# =========================================================
# CHECK PORT
# =========================================================

if lsof -Pi :${PANEL_PORT} -sTCP:LISTEN -t >/dev/null 2>&1; then
    warn "Port ${PANEL_PORT} is already in use."

    echo
    lsof -i:${PANEL_PORT}
    echo

    read -rp "Continue installation anyway? (y/n): " PORT_CONFIRM

    if [[ "$PORT_CONFIRM" != "y" ]]; then
        error "Installation cancelled."
        exit 1
    fi
fi

# =========================================================
# CREATE INSTALL DIRECTORY
# =========================================================

info "Preparing installation directory..."

mkdir -p "${INSTALL_DIR}"

cd "${INSTALL_DIR}"

ok "Directory ready."

line

# =========================================================
# DOWNLOAD HVM
# =========================================================

info "Downloading hvm.bin..."

rm -f hvm.bin

(
wget -q --show-progress -O hvm.bin "${HVM_URL}"
) &

spinner $!

echo

if [[ ! -f hvm.bin ]]; then
    error "Download failed."
    exit 1
fi

if [[ ! -s hvm.bin ]]; then
    error "Downloaded file is empty."
    exit 1
fi

chmod +x hvm.bin

ok "hvm.bin downloaded successfully."

line

# =========================================================
# FIREWALL
# =========================================================

info "Configuring firewall rules..."

if command -v ufw >/dev/null 2>&1; then
    ufw allow ${PANEL_PORT}/tcp >/dev/null 2>&1 || true
fi

if command -v firewall-cmd >/dev/null 2>&1; then
    firewall-cmd --permanent --add-port=${PANEL_PORT}/tcp >/dev/null 2>&1 || true
    firewall-cmd --reload >/dev/null 2>&1 || true
fi

if command -v iptables >/dev/null 2>&1; then
    iptables -C INPUT -p tcp --dport ${PANEL_PORT} -j ACCEPT >/dev/null 2>&1 || \
    iptables -I INPUT -p tcp --dport ${PANEL_PORT} -j ACCEPT >/dev/null 2>&1 || true
fi

ok "Firewall configured."

line

# =========================================================
# SYSTEMD SERVICE
# =========================================================

if command -v systemctl >/dev/null 2>&1; then

    info "Creating systemd service..."

cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=HVM Panel V8
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${INSTALL_DIR}
ExecStart=${BIN_FILE}
Restart=always
RestartSec=5
LimitNOFILE=1048576
User=root
StandardOutput=append:${LOG_FILE}
StandardError=append:${LOG_FILE}

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable ${SERVICE_NAME} >/dev/null 2>&1
    systemctl restart ${SERVICE_NAME}

    sleep 5

    if systemctl is-active --quiet ${SERVICE_NAME}; then
        ok "HVM service started successfully."
    else
        error "Service failed to start."
        echo
        systemctl status ${SERVICE_NAME} --no-pager
        echo
        exit 1
    fi

else

    warn "Systemd not found. Running manually..."

    nohup ${BIN_FILE} >> ${LOG_FILE} 2>&1 &

    sleep 3

fi

line

# =========================================================
# PANEL STATUS
# =========================================================

if lsof -Pi :${PANEL_PORT} -sTCP:LISTEN -t >/dev/null 2>&1; then
    PANEL_STATUS="${GREEN}ONLINE${NC}"
else
    PANEL_STATUS="${RED}OFFLINE${NC}"
fi

# =========================================================
# PUBLIC IP
# =========================================================

PUBLIC_IP=$(curl -4 -s --max-time 10 ifconfig.me || true)

if [[ -z "${PUBLIC_IP}" ]]; then
    PUBLIC_IP=$(hostname -I | awk '{print $1}')
fi

if [[ -z "${PUBLIC_IP}" ]]; then
    PUBLIC_IP="YOUR_SERVER_IP"
fi

# =========================================================
# FINISH
# =========================================================

clear

echo -e "${GREEN}"

cat << EOF

╔══════════════════════════════════════════════════════╗
║              HVM PANEL V8 INSTALLED                 ║
╚══════════════════════════════════════════════════════╝

STATUS            : ${PANEL_STATUS}

PANEL URL         : http://${PUBLIC_IP}:${PANEL_PORT}

DEFAULT USERNAME  : admin
DEFAULT PASSWORD  : admin

INSTALL DIRECTORY : ${INSTALL_DIR}

BINARY FILE       : ${BIN_FILE}

LOG FILE          : ${LOG_FILE}

SERVICE NAME      : ${SERVICE_NAME}

════════════════════════════════════════════════════════

SERVICE COMMANDS

systemctl start ${SERVICE_NAME}
systemctl stop ${SERVICE_NAME}
systemctl restart ${SERVICE_NAME}
systemctl status ${SERVICE_NAME}

════════════════════════════════════════════════════════

VIEW LIVE LOGS

journalctl -u ${SERVICE_NAME} -f

════════════════════════════════════════════════════════

EOF

echo -e "${NC}"
