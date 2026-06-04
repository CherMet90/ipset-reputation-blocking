#!/bin/bash
# uninstall.sh — удаление репутационной блокировки
# Убирает ТОЛЬКО то, что поставил install.sh.
# iptables-правила НЕ трогает (вы добавляли их вручную — вам и удалять).
set -e

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (sudo ./uninstall.sh)" >&2
   exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "${SCRIPT_DIR}/config.env" ]]; then
    source "${SCRIPT_DIR}/config.env"
fi

IPSET_NAME="${IPSET_NAME:-reputation_blocklist}"
INSTALL_DIR="/etc/reputation-block"
BIN_SCRIPT="/usr/local/sbin/update-blocklist.sh"
CRON_DAILY="/etc/cron.daily/update-blocklist"

echo "=== Uninstalling ipset-reputation-block ==="

echo "Removing cron task..."
rm -f "$CRON_DAILY"

echo "Removing ipset collections..."
ipset destroy whitelist 2>/dev/null || true
ipset destroy "${IPSET_NAME}" 2>/dev/null || true

echo "Removing script..."
rm -f "$BIN_SCRIPT"

echo "Removing config directory..."
rm -rf "$INSTALL_DIR"

echo "=== Done ==="
echo ""
echo "iptables rules were NOT removed. If you applied rules.v4, remove them manually, e.g.:"
echo "  sudo iptables -L INPUT -n --line-numbers | grep -E 'whitelist|${IPSET_NAME}|BLOCKLIST_LOG_DROP'"
echo "  sudo iptables -D INPUT <number>  (for each matching rule, starting from highest number)"
echo "  sudo iptables -F BLOCKLIST_LOG_DROP && sudo iptables -X BLOCKLIST_LOG_DROP"
echo "  sudo netfilter-persistent save"