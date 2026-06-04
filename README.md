# Репутационная блокировка IP с помощью ipset + iptables

Простой и переносимый набор для защиты открытых портов (например, 443) с использованием готовых репутационных списков.

- **Три надёжных источника**: blocklist.de, Spamhaus DROP, Emerging Threats.
- **Атомарное обновление** ipset без разрывов.
- **Логирование** только новых соединений с ограничением частоты.

## Быстрый старт

```bash
git clone https://github.com/CherMet90/ipset-reputation-block.git
cd ipset-reputation-block
# Отредактируйте config.env под себя (порты, белый список)
sudo ./install.sh
# После установки примените правила iptables (см. раздел "Интеграция iptables")
```

**Важно:** `install.sh` **не изменяет iptables**. Он только устанавливает пакеты, создаёт ipset‑наборы, копирует скрипт обновления и прописывает cron. Правила вы добавляете вручную из файла `rules.v4` или адаптируете под свой текущий файрвол.

## Что в проекте

| Файл | Назначение |
|------|------------|
| `config.env` | Настройки: порты, белый список, размер ipset |
| `update-blocklist.sh` | Загружает списки и атомарно подменяет ipset (основная логика) |
| `rules.v4` | Эталонный блок правил iptables для ручной вставки |
| `install.sh` | Установка пакетов, ipset, cron |
| `uninstall.sh` | Полное удаление всего, что поставил `install.sh` (iptables не трогает) |

## Настройка

Перед установкой отредактируйте `config.env`:

```bash
PORTS="443"                     # Какие порты защищать
WHITELIST="1.2.3.4 10.0.0.0/8"  # IP/подсети, которые никогда не блокируются
MAXELEM=65536                   # Максимум записей в ipset
```

Если белый список не нужен, оставьте `WHITELIST=""`.

## Установка

```bash
sudo ./install.sh
```

Что он делает (и только это):

- Устанавливает пакеты `ipset` и `curl`.
- Создаёт ipset‑набор `reputation_blocklist` (и опционально `whitelist`).
- Копирует `update-blocklist.sh` в `/usr/local/sbin/` и прописывает симлинк в `/etc/cron.daily/`.
- Запускает первичное наполнение списков (~26 000 записей).
- **Не трогает** iptables‑правила.

После установки все файлы живут в `/etc/reputation-block/`.

## Интеграция iptables

### Если у вас пустой iptables

Примените готовый шаблон:

```bash
sudo iptables-restore < rules.v4
sudo netfilter-persistent save
```

### Если у вас уже есть правила

Вставьте блок из `rules.v4` в нужное место вручную.

Суть правил (порядок критичен):

1. **Белый список** — пропускаем сразу.
2. **Блокировка** — дропаем с логгированием только новых соединений.
3. **Остальные** — ACCEPT.

Для каждого порта:

```
-A INPUT -p tcp --dport <PORT> -m set --match-set whitelist src -j ACCEPT
-A INPUT -p tcp --dport <PORT> -m set --match-set reputation_blocklist src -j BLOCKLIST_LOG_DROP
-A INPUT -p tcp --dport <PORT> -j ACCEPT
```

Цепочка `BLOCKLIST_LOG_DROP` (создаётся один раз):

```
-A BLOCKLIST_LOG_DROP -m conntrack --ctstate NEW -m limit --limit 1/min --limit-burst 5 -j LOG --log-prefix "IPTABLES-REPBLOCK: "
-A BLOCKLIST_LOG_DROP -j DROP
```

Не забудьте сохранить:

```bash
sudo netfilter-persistent save
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