#!/bin/bash
# install.sh — устанавливает только базовые зависимости и ipset
# iptables правила НЕ трогает — используйте rules.v4 вручную.
set -e
[[ $EUID -ne 0 ]] && { echo "Run as root"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/config.env"

IPSET_NAME="${IPSET_NAME:-reputation_blocklist}"
MAXELEM="${MAXELEM:-65536}"
HASHSIZE="${HASHSIZE:-16384}"
INSTALL_DIR="/etc/reputation-block"
BIN_DIR="/usr/local/sbin"

echo ">>> Installing packages..."
apt update -qq && apt install -y -qq ipset curl

echo ">>> Copying config and script..."
mkdir -p "$INSTALL_DIR"
cp -n "${SCRIPT_DIR}/config.env" "${INSTALL_DIR}/config.env" 2>/dev/null || true
cp "${SCRIPT_DIR}/update-blocklist.sh" "${BIN_DIR}/update-blocklist.sh"
chmod +x "${BIN_DIR}/update-blocklist.sh"

echo ">>> Creating ipset (if not exists)..."
ipset create "$IPSET_NAME" hash:net hashsize "$HASHSIZE" maxelem "$MAXELEM" 2>/dev/null || true
if [[ -n "$WHITELIST" ]]; then
    ipset create whitelist hash:net 2>/dev/null || true
    for ip in $WHITELIST; do
        ipset add whitelist "$ip" 2>/dev/null || true
    done
fi

echo ">>> Setting up daily cron..."
ln -sf "${BIN_DIR}/update-blocklist.sh" /etc/cron.daily/update-blocklist

echo ">>> Initial blocklist fill..."
"${BIN_DIR}/update-blocklist.sh"

echo "Done. Now manually configure iptables using rules.v4 template."