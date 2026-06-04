#!/bin/bash
# update-blocklist.sh — загрузка репутационных списков и атомарная подмена ipset
set -e

# ── Конфигурация ────────────────────────────────────────────────────────────
CONFIG_FILE="/etc/reputation-block/config.env"
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
else
  echo "ERROR: config file not found: $CONFIG_FILE" >&2
  exit 1
fi

IPSET_NAME="${IPSET_NAME:-reputation_blocklist}"
MAXELEM="${MAXELEM:-65536}"
HASHSIZE="${HASHSIZE:-16384}"

TMP_LIST="/tmp/blocklist_$$.tmp"
RESTORE_FILE="/tmp/blocklist_restore_$$.txt"

# Очистка leftover от предыдущего неудачного запуска
sudo ipset destroy "${IPSET_NAME}_new" 2>/dev/null || true

> "$TMP_LIST"

# ── Проверенные источники (формат подтверждён на 2026-06-04) ────────────────
# Если формат изменится — обновим этот скрипт. Не парсим из конфига.
echo "Fetching from blocklist.de..."
curl -sf https://lists.blocklist.de/lists/all.txt | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' >> "$TMP_LIST"

echo "Fetching from Spamhaus DROP..."
curl -sf https://www.spamhaus.org/drop/drop.txt | sed -n 's/^\([0-9.]\+\/[0-9]\+\).*/\1/p' >> "$TMP_LIST"

echo "Fetching from Emerging Threats..."
curl -sf https://rules.emergingthreats.net/blockrules/compromised-ips.txt | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' >> "$TMP_LIST"

UNIQUE_COUNT=$(sort -u "$TMP_LIST" | wc -l)
echo "Total unique IPs/CIDRs: $UNIQUE_COUNT"

# ── Атомарная подмена ───────────────────────────────────────────────────────
sudo ipset create "${IPSET_NAME}_new" hash:net hashsize "$HASHSIZE" maxelem "$MAXELEM"

sort -u "$TMP_LIST" | awk '{print "add '"${IPSET_NAME}_new"' " $0}' > "$RESTORE_FILE"
sudo ipset restore -! < "$RESTORE_FILE"

sudo ipset swap "${IPSET_NAME}" "${IPSET_NAME}_new"
sudo ipset destroy "${IPSET_NAME}_new"

# ── Сохранение для восстановления после ребута ──────────────────────────────
sudo ipset save "${IPSET_NAME}" > /etc/reputation-block/ipset-save

rm -f "$TMP_LIST" "$RESTORE_FILE"

FINAL_COUNT=$(sudo ipset list "${IPSET_NAME}" | grep -oP 'Number of entries: \K\d+')
logger -t "update-blocklist" "Updated ipset ${IPSET_NAME}: ${FINAL_COUNT} entries"
echo "Done. Final entries in ${IPSET_NAME}: ${FINAL_COUNT}"