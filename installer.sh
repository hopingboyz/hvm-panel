#!/usr/bin/env bash

# =========================================================
# HVM PANEL V8 ULTRA INSTALLER
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

HVM_URL="https://files.catbox.moe/rr0uum.bin"

INSTALL_DIR="/opt/hvm"
SERVICE_NAME="hvm"
PANEL_PORT="5000"

BIN_FILE="${INSTALL_DIR}/hvm.bin"
LOG_FILE="/var/log/hvm.log"

MIN_FILE_SIZE_MB=30

# =========================================================
# FUNCTIONS
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

# =========================================================
# LOGO
# =========================================================

clear

echo -e "${CYAN}"

cat << "EOF"

██╗  ██╗██╗   ██╗███╗   ███╗
██║  ██║██║   ██║████╗ ████║
███████║██║   ██║██╔████╔██║
██╔══██║╚██╗ ██╔╝██║╚██╔╝██║
██║  ██║ ╚████╔╝ ██║ ╚═╝ ██║
╚═╝  ╚═╝  ╚═══╝  ╚═╝     ╚═╝

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
# INSTALL DEPENDENCIES
# =========================================================

info "Installing dependencies..."

if command -v apt >/dev/null 2>&1; then

    export DEBIAN_FRONTEND=noninteractive

    apt update -y

    apt install -y \
    curl wget lsof tar unzip sudo nano \
    python3 python3-pip ca-certificates

elif command -v dnf >/dev/null 2>&1; then

    dnf install -y \
    curl wget lsof tar unzip sudo nano \
    python3 python3-pip ca-certificates

elif command -v yum >/dev/null 2>&1; then

    yum install -y epel-release

    yum install -y \
    curl wget lsof tar unzip sudo nano \
    python3 python3-pip ca-certificates

elif command -v pacman >/dev/null 2>&1; then

    pacman -Sy --noconfirm \
    curl wget lsof tar unzip sudo nano \
    python python-pip ca-certificates

elif command -v apk >/dev/null 2>&1; then

    apk update

    apk add \
    curl wget lsof tar unzip sudo nano \
    python3 py3-pip ca-certificates

elif command -v zypper >/dev/null 2>&1; then

    zypper refresh

    zypper install -y \
    curl wget lsof tar unzip sudo nano \
    python3 python3-pip ca-certificates

else
    error "Unsupported Linux distribution."
    exit 1
fi

ok "Dependencies installed."

line

# =========================================================
# PORT CHECK
# =========================================================

if lsof -Pi :${PANEL_PORT} -sTCP:LISTEN -t >/dev/null 2>&1; then

    warn "Port ${PANEL_PORT} is already in use."

    echo
    lsof -i:${PANEL_PORT}
    echo

    read -rp "Continue anyway? (y/n): " confirm

    if [[ "$confirm" != "y" ]]; then
        error "Installation cancelled."
        exit 1
    fi
fi

line

# =========================================================
# CREATE INSTALL DIRECTORY
# =========================================================

info "Creating installation directory..."

mkdir -p "${INSTALL_DIR}"

cd "${INSTALL_DIR}"

ok "Directory created."

line

# =========================================================
# DOWNLOAD HVM BINARY
# =========================================================

info "Downloading hvm.bin..."

rm -f hvm.bin

curl -L \
--fail \
--retry 5 \
--retry-delay 3 \
--progress-bar \
-o hvm.bin "${HVM_URL}"

echo

# =========================================================
# VERIFY FILE
# =========================================================

if [[ ! -f hvm.bin ]]; then
    error "Download failed."
    exit 1
fi

if [[ ! -s hvm.bin ]]; then
    error "Downloaded file is empty."
    exit 1
fi

FILE_SIZE_MB=$(du -m hvm.bin | cut -f1)

info "Downloaded File Size: ${FILE_SIZE_MB}MB"

if [[ "${FILE_SIZE_MB}" -lt "${MIN_FILE_SIZE_MB}" ]]; then
    error "Invalid or corrupted hvm.bin detected."
    file hvm.bin || true
    exit 1
fi

if file hvm.bin | grep -qi "html"; then
    error "Downloaded HTML page instead of binary."
    exit 1
fi

chmod +x hvm.bin

ok "hvm.bin verified successfully."

line

# =========================================================
# FIREWALL CONFIG
# =========================================================

info "Configuring firewall..."

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
# CREATE SYSTEMD SERVICE
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
        error "HVM service failed to start."
        echo
        systemctl status ${SERVICE_NAME} --no-pager
        echo
        exit 1
    fi

else

    warn "systemd not detected."
    warn "Running HVM manually..."

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
# GET PUBLIC IP
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
║               HVM PANEL V8 INSTALLED                ║
╚══════════════════════════════════════════════════════╝

STATUS            : ${PANEL_STATUS}

PANEL URL         : http://${PUBLIC_IP}:${PANEL_PORT}

USERNAME          : admin
PASSWORD          : admin

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

ONE LINE INSTALLER

bash <(curl -fsSL https://raw.githubusercontent.com/hopingboyz/hvm-panel/main/installer.sh)

════════════════════════════════════════════════════════

EOF

echo -e "${NC}"
