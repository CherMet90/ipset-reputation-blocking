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
# Отредактируйте config.env под себя (порты, белый список)
chmod +x install.sh
sudo ./install.sh
# После установки примените правила iptables (см. раздел "Интеграция iptables")
```

**Важно:** `install.sh` **не изменяет iptables**. Он только устанавливает пакеты, создаёт ipset‑наборы, копирует скрипт обновления и прописывает cron. Правила вы добавляете вручную из файла `rules.v4` или адаптируете под свой текущий файрвол.

## Интеграция iptables

### Если у вас пустой iptables

Примените готовый шаблон:

```bash
sudo iptables-restore < rules.v4
sudo netfilter-persistent save
```

### Если у вас уже есть правила

Вставьте блок из `rules.v4` в нужное место вручную.

Посмотреть правила с номерами строк:

```bash
sudo iptables -L INPUT -n -v --line-numbers
sudo iptables -L BLOCKLIST_LOG_DROP -n -v --line-numbers
```

Заменить правило (например, отключить лимит для теста):

```bash
# синтаксис: -R <цепочка> <номер_строки> <новое правило>
sudo iptables -R BLOCKLIST_LOG_DROP 1 -m conntrack --ctstate NEW -j LOG --log-prefix "IPTABLES-REPBLOCK: "
```

Вставить правило на первое место:

```bash
sudo iptables -I BLOCKLIST_LOG_DROP 1 -j ... 
```

Удалить правило:

```bash
sudo iptables -D BLOCKLIST_LOG_DROP 1
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