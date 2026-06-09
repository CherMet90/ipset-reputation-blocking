# Репутационная блокировка IP с помощью ipset + iptables

Простой и переносимый набор для защиты открытых портов (например, 443) с использованием готовых репутационных списков.

- **Три надёжных источника**: blocklist.de, Spamhaus DROP, Emerging Threats.
- **Атомарное обновление** ipset без разрывов.
- **Логирование** только новых соединений с ограничением частоты.

## Быстрый старт

```bash
cd ~
git clone https://github.com/CherMet90/ipset-reputation-blocking.git
cd ipset-reputation-blocking
chmod +x install.sh
sudo ./install.sh
```

При первом запуске `install.sh` скопирует `config.env.example` → `config.env` и попросит отредактировать его под себя (порты, белый список IP). Откройте и настройте:

```bash
sudo nano config.env
# или: sudo vi config.env
```

После правок запустите `install.sh` ещё раз:

```bash
sudo ./install.sh
```

Далее — примените правила iptables (см. раздел «Интеграция iptables»).

## Интеграция iptables

Цепочка логгирования дропов (создаётся один раз)
```
sudo iptables -N BLOCKLIST_LOG_DROP
sudo iptables -A BLOCKLIST_LOG_DROP -m conntrack --ctstate NEW -m limit --limit 1/min --limit-burst 5 -j LOG --log-prefix "IPTABLES-REPBLOCK: " --log-level 4
sudo iptables -A BLOCKLIST_LOG_DROP -j DROP
```

Правила INPUT
Пример для порта 443:
```
sudo iptables -A INPUT -m set --match-set whitelist src -j ACCEPT
sudo iptables -A INPUT -m set --match-set reputation_blocklist src -j BLOCKLIST_LOG_DROP
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
```

## Логирование

Заблокированные соединения пишутся в `/var/log/iptables-repblock.log` (ротация по logrotate по умолчанию).

Просмотр в реальном времени:

```bash
sudo tail -f /var/log/iptables-repblock.log
```

## Проверка работы

- Посмотреть размер набора: `sudo ipset list reputation_blocklist | head`
- Статистика iptables: `sudo iptables -L INPUT -n -v`
- Протестировать блокировку (добавьте свой IP в набор, стукните по порту, удалите):

```bash
sudo ipset add reputation_blocklist <YOUR_IP>
# попробуйте подключиться к вашему серверу на защищённый порт
sudo ipset del reputation_blocklist <YOUR_IP>
sudo cat /var/log/iptables-repblock.log
```

- проверить крон

```
ls -la /etc/cron.daily/update-blocklist
```

## Обновление списков

По умолчанию — ежедневно через `/etc/cron.daily/update-blocklist`.

Принудительное обновление:

```bash
sudo /usr/local/sbin/update-blocklist.sh
```

Скрипт обновления **атомарен**: создаёт временный набор, загружает в него данные, затем меняет местами с основным. Блокировка работает непрерывно.

## Удаление

```bash
sudo ./uninstall.sh
```

Удаляет ipset‑наборы, скрипты, cron, конфиги в `/etc/reputation-block/`. Правила iptables удалите вручную (или оставьте — они просто перестанут срабатывать без ipset).

## Ограничения

- Защищает только от IP из репутационных списков (~26 000). Не защищает от DDoS с «чистых» адресов.
- Не заменяет полноценную IDS/IPS.
- Логируются только первые пакеты новых соединений (защита от переполнения логов).

---

**Источники списков:**

- [blocklist.de](https://www.blocklist.de/en/api.html)
- [Spamhaus DROP](https://www.spamhaus.org/drop/)
- [Emerging Threats compromised IPs](https://rules.emergingthreats.net/blockrules/compromised-ips.txt)