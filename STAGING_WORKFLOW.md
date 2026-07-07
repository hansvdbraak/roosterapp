# Staging Workflow — Roosterapp

## Overzicht

| | Productie | Staging |
|---|---|---|
| **URL** | `https://rooster.4ub2b.com` | `http://staging.4ub2b.com` |
| **Database** | `roosterapp` (user: `roosterapp`) | `roosterapp_staging` (user: `roosterapp_staging`) |
| **Systemd service** | `rooster-server` | `rooster-staging` |
| **Logs** | `/var/log/rooster_server.log` | `/var/log/rooster_staging.log` |
| **Config** | `config/production.yaml` | `config/staging.yaml` |
| **Web bestanden** | `/var/www/roosterapp` | `/var/www/roosterapp_staging` |

---

## Werken in staging-mode

### Flutter app bouwen en deployen naar staging

```bash
# Stap 1: build
flutter build web --dart-define=ENV=staging

# Stap 2: deploy naar VPS
scp -r build/web/* root@91.99.141.133:/var/www/roosterapp_staging/
```

### Flutter lokaal draaien tegen staging server

```bash
flutter run --dart-define=ENV=staging
```

### Server code deployen naar staging

```bash
scp -r /Users/hansvandebraak/IdeaProjects/rooster/rooster_server/* root@91.99.141.133:/opt/rooster_server/
ssh root@91.99.141.133 "systemctl restart rooster-staging"
ssh root@91.99.141.133 "tail -f /var/log/rooster_staging.log"
```

### Database migraties op staging

Migraties worden automatisch toegepast bij herstart (`--apply-migrations` staat in de systemd unit):

```bash
ssh root@91.99.141.133 "systemctl restart rooster-staging"
```

---

## Promotie staging → productie

### Stap 1: Backup productie (altijd doen!)

```bash
# Backup web build
ssh root@91.99.141.133 "cp -r /var/www/roosterapp /var/www/roosterapp_backup_$(date +%Y%m%d)"

# Backup database (bij schema-wijzigingen)
ssh root@91.99.141.133 "sudo -u postgres pg_dump roosterapp > /root/roosterapp_backup_$(date +%Y%m%d).sql"
```

### Stap 2: Flutter web bouwen en deployen naar productie

```bash
flutter build web
scp -r build/web/* root@91.99.141.133:/var/www/roosterapp/
```

### Stap 3: Server code deployen (als server-code gewijzigd)

```bash
scp -r /Users/hansvandebraak/IdeaProjects/rooster/rooster_server/* root@91.99.141.133:/opt/rooster_server/
ssh root@91.99.141.133 "systemctl restart rooster-server"
```

### Stap 4: Database migraties op productie (alleen bij schema-wijzigingen)

```bash
ssh root@91.99.141.133 "systemctl stop rooster-server"
ssh root@91.99.141.133 "cd /opt/rooster_server && dart bin/main.dart --mode production --apply-migrations &"
# Wacht tot migraties klaar zijn (check logs), dan:
ssh root@91.99.141.133 "systemctl start rooster-server"
```

---

## Rollback productie

### Web app rollback (direct, seconden)

```bash
ssh root@91.99.141.133 "rm -rf /var/www/roosterapp && cp -r /var/www/roosterapp_backup_YYYYMMDD /var/www/roosterapp"
```

### Server code rollback (via git)

```bash
# Bekijk versies
ssh root@91.99.141.133 "cd /opt/rooster_server && git log --oneline -5"

# Terug naar vorige versie
ssh root@91.99.141.133 "cd /opt/rooster_server && git checkout <commit-hash>"
ssh root@91.99.141.133 "systemctl restart rooster-server"
```

### Database rollback

```bash
# Herstel database uit backup
ssh root@91.99.141.133 "systemctl stop rooster-server"
ssh root@91.99.141.133 "sudo -u postgres psql -c 'DROP DATABASE roosterapp;'"
ssh root@91.99.141.133 "sudo -u postgres psql -c 'CREATE DATABASE roosterapp OWNER roosterapp;'"
ssh root@91.99.141.133 "sudo -u postgres psql roosterapp < /root/roosterapp_backup_YYYYMMDD.sql"
ssh root@91.99.141.133 "systemctl start rooster-server"
```

### Rollback staging

```bash
ssh root@91.99.141.133 "systemctl restart rooster-staging"
# Of web build herstellen:
ssh root@91.99.141.133 "rm -rf /var/www/roosterapp_staging/*"
# En opnieuw deployen met vorige build
```

---

## Handige SSH commando's

```bash
# Status beide services
ssh root@91.99.141.133 "systemctl status rooster-server rooster-staging"

# Live logs
ssh root@91.99.141.133 "tail -f /var/log/rooster_server.log"
ssh root@91.99.141.133 "tail -f /var/log/rooster_staging.log"

# Herstart services
ssh root@91.99.141.133 "systemctl restart rooster-server"
ssh root@91.99.141.133 "systemctl restart rooster-staging"

# Beschikbare DB backups
ssh root@91.99.141.133 "ls -lh /root/roosterapp_backup*"
```

---

## Omgeving herkennen in de app

`AppConfig.environment` geeft `'production'`, `'staging'` of `'local'` terug.
Kan gebruikt worden om bijv. een banner te tonen in staging builds.
