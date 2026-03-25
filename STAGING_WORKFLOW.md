# Staging Workflow — Roosterapp

## Overzicht

| | Productie | Staging |
|---|---|---|
| **Server** | `rooster.4ub2b.com` (poort 443, HTTPS) | `staging.4ub2b.com` (poort 8090, HTTP) |
| **Database** | `roosterapp` (user: `roosterapp`) | `roosterapp_staging` (user: `roosterapp_staging`) |
| **Systemd service** | `rooster-server` | `rooster-staging` |
| **Logs** | `/var/log/rooster_server.log` | `/var/log/rooster_staging.log` |
| **Config** | `config/production.yaml` | `config/staging.yaml` |

---

## Ontwikkelen op staging

### 1. Flutter app bouwen voor staging (web)

```bash
flutter build web --dart-define=ENV=staging
```

De app wijst dan automatisch naar `staging.4ub2b.com:8090`.

### 2. Flutter app draaien voor staging (lokaal testen)

```bash
flutter run --dart-define=ENV=staging
```

### 3. Flutter app bouwen voor productie (standaard, geen extra vlag nodig)

```bash
flutter build web
```

---

## Server code deployen naar staging

```bash
# Kopieer server code naar VPS
scp -r /Users/hansvandebraak/IdeaProjects/rooster/rooster_server/* root@91.99.141.133:/opt/rooster_server/

# Herstart staging service
ssh root@91.99.141.133 "systemctl restart rooster-staging"

# Check logs
ssh root@91.99.141.133 "tail -f /var/log/rooster_staging.log"
```

---

## Database migraties

### Nieuwe migratie aanmaken (lokaal)

```bash
cd /Users/hansvandebraak/IdeaProjects/rooster/rooster_server
dart pub global run serverpod_cli create-migration
```

### Migratie uitvoeren op staging

Migraties worden automatisch toegepast bij het (her)starten van de staging service (`--apply-migrations` flag staat in de systemd unit).

```bash
ssh root@91.99.141.133 "systemctl restart rooster-staging"
```

### Migratie uitvoeren op productie (na goedkeuring)

```bash
ssh root@91.99.141.133 "systemctl stop rooster-server"
ssh root@91.99.141.133 "cd /opt/rooster_server && dart bin/main.dart --mode production --apply-migrations &"
# Wacht tot migraties klaar zijn, dan:
ssh root@91.99.141.133 "systemctl start rooster-server"
```

---

## Promotie staging → productie

### Code promoveren

```bash
# Server is al op de VPS (zelfde map /opt/rooster_server)
# Alleen de mode verschilt. Herstart productie:
ssh root@91.99.141.133 "systemctl restart rooster-server"
```

### Flutter web build deployen naar productie

```bash
# Build productie versie
flutter build web

# Kopieer naar VPS
scp -r build/web/* root@91.99.141.133:/var/www/roosterapp/
```

---

## Handige SSH commando's

```bash
# Status services
ssh root@91.99.141.133 "systemctl status rooster-server rooster-staging"

# Staging herstarten
ssh root@91.99.141.133 "systemctl restart rooster-staging"

# Productie herstarten
ssh root@91.99.141.133 "systemctl restart rooster-server"

# Live staging logs
ssh root@91.99.141.133 "tail -f /var/log/rooster_staging.log"

# Live productie logs
ssh root@91.99.141.133 "tail -f /var/log/rooster_server.log"
```

---

## Staging service autostart inschakelen (optioneel)

```bash
ssh root@91.99.141.133 "systemctl enable rooster-staging"
```

---

## Omgeving herkennen in de app

`AppConfig.environment` geeft `'production'`, `'staging'` of `'local'` terug.
Kan gebruikt worden om bijv. een banner te tonen in staging builds.
