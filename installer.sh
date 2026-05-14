#!/usr/bin/env bash

set -euo pipefail

# =========================================================
# HVM PANEL V8 INSTALLER
# =========================================================

RED="\e[1;31m"
GREEN="\e[1;32m"
YELLOW="\e[1;33m"
CYAN="\e[1;36m"
NC="\e[0m"

INSTALL_DIR="/opt/hvm"
BIN_FILE="${INSTALL_DIR}/hvm.bin"
SERVICE_NAME="hvm"
PORT="5000"

# =========================================================
# IMPORTANT:
# REPLACE THIS WITH REAL DIRECT DOWNLOAD URL
# =========================================================

HVM_URL="https://files.catbox.moe/l9wi44.bin"

MIN_SIZE_MB=38

clear

echo -e "${CYAN}"
echo "=================================================="
echo "              HVM PANEL V8 INSTALLER"
echo "=================================================="
echo -e "${NC}"

# =========================================================
# ROOT CHECK
# =========================================================

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR] Run as root${NC}"
    exit 1
fi

# =========================================================
# INSTALL DEPENDENCIES
# =========================================================

echo -e "${CYAN}[INFO] Installing dependencies...${NC}"

if command -v apt >/dev/null 2>&1; then
    apt update -y
    apt install -y curl wget lsof ca-certificates
elif command -v dnf >/dev/null 2>&1; then
    dnf install -y curl wget lsof ca-certificates
elif command -v yum >/dev/null 2>&1; then
    yum install -y curl wget lsof ca-certificates
elif command -v apk >/dev/null 2>&1; then
    apk add curl wget lsof ca-certificates
fi

# =========================================================
# CREATE DIRECTORY
# =========================================================

mkdir -p "${INSTALL_DIR}"
cd "${INSTALL_DIR}"

# =========================================================
# DOWNLOAD FILE
# =========================================================

echo -e "${CYAN}[INFO] Downloading hvm.bin...${NC}"

rm -f hvm.bin

curl -L --fail --retry 5 --retry-delay 3 \
-o hvm.bin "${HVM_URL}"

# =========================================================
# VERIFY FILE
# =========================================================

if [[ ! -f hvm.bin ]]; then
    echo -e "${RED}[ERROR] Download failed${NC}"
    exit 1
fi

FILE_SIZE_MB=$(du -m hvm.bin | cut -f1)

echo -e "${YELLOW}[INFO] Downloaded Size:${NC} ${FILE_SIZE_MB}MB"

if [[ "${FILE_SIZE_MB}" -lt "${MIN_SIZE_MB}" ]]; then
    echo -e "${RED}[ERROR] Invalid hvm.bin detected${NC}"
    echo -e "${RED}[ERROR] File too small or corrupted${NC}"
    echo
    file hvm.bin || true
    exit 1
fi

# =========================================================
# HTML CHECK
# =========================================================

if file hvm.bin | grep -qi "HTML"; then
    echo -e "${RED}[ERROR] MediaFire returned HTML page instead of binary${NC}"
    exit 1
fi

chmod +x hvm.bin

echo -e "${GREEN}[OK] hvm.bin verified successfully${NC}"

# =========================================================
# FIREWALL
# =========================================================

if command -v ufw >/dev/null 2>&1; then
    ufw allow ${PORT}/tcp >/dev/null 2>&1 || true
fi

# =========================================================
# SYSTEMD SERVICE
# =========================================================

if command -v systemctl >/dev/null 2>&1; then

cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=HVM Panel
After=network.target

[Service]
Type=simple
WorkingDirectory=${INSTALL_DIR}
ExecStart=${BIN_FILE}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ${SERVICE_NAME}
systemctl restart ${SERVICE_NAME}

fi

sleep 3

# =========================================================
# GET IP
# =========================================================

IP=$(curl -4 -s ifconfig.me || hostname -I | awk '{print $1}')

clear

echo -e "${GREEN}"
echo "=================================================="
echo "              HVM PANEL INSTALLED"
echo "=================================================="
echo
echo " PANEL URL : http://${IP}:${PORT}"
echo
echo " USERNAME  : admin"
echo " PASSWORD  : admin"
echo
echo " SERVICE   : ${SERVICE_NAME}"
echo " LOCATION  : ${INSTALL_DIR}"
echo
echo "=================================================="
echo -e "${NC}"
