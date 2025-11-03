# Certbot Hetzner Cloud DNS Setup Script

Automatisches Setup-Skript für Let's Encrypt SSL-Zertifikate mit der **neuen Hetzner Cloud DNS API** in einer isolierten Python Virtual Environment.

## ⚠️ Wichtig: Neue Hetzner Cloud API

Dieses Skript verwendet das **neue** `certbot-dns-hetzner-cloud` Plugin für die Hetzner Cloud DNS API. Wenn deine Domain noch in der alten DNS Console (dns.hetzner.com) ist, musst du sie zuerst zur [Hetzner Console](https://console.hetzner.cloud) migrieren.

**Nicht kompatibel mit:** Alter DNS Console (wird Mai 2026 abgeschaltet)  
**Kompatibel mit:** Neue Hetzner Cloud DNS API

## 🎯 Features

- ✅ Vollautomatische Einrichtung von Certbot mit Hetzner Cloud DNS Plugin
- ✅ Isolierte Python Virtual Environment (keine Systemkonflikte)
- ✅ Wildcard-Zertifikate (`*.domain.de`)
- ✅ ECDSA-Schlüssel für bessere Performance
- ✅ Automatische Erneuerung via systemd Timer
- ✅ Backup bestehender Zertifikate
- ✅ Automatisches Neuladen des Webservers nach Erneuerung
- ✅ Farbige Konsolen-Ausgabe für bessere Übersicht

## 📋 Voraussetzungen

- Ubuntu/Debian Linux Server mit root-Zugriff
- Domain in der neuen Hetzner Console migriert
- Hetzner Cloud API Token ([Anleitung](#hetzner-cloud-api-token-erstellen))
- Nginx oder Apache2 Webserver

## 🚀 Installation

### 1. Skript herunterladen

```bash
wget https://raw.githubusercontent.com/DEIN-USERNAME/DEIN-REPO/main/certbot-hetzner-setup.sh
# oder
curl -O https://raw.githubusercontent.com/DEIN-USERNAME/DEIN-REPO/main/certbot-hetzner-setup.sh
```

### 2. Skript konfigurieren

Öffne das Skript und passe die Variablen am Anfang an:

```bash
nano certbot-hetzner-setup.sh
```

Ändere folgende Zeilen:

```bash
DOMAIN="alfaalf-media.de"           # Deine Domain
EMAIL="deine@email.de"              # Deine E-Mail für Let's Encrypt
HETZNER_API_TOKEN="DEIN_TOKEN_HIER" # Dein Hetzner DNS API Token
WEBSERVER="nginx"                   # "nginx" oder "apache2"
```

### 3. Skript ausführbar machen

```bash
chmod +x certbot-hetzner-setup.sh
```

### 4. Skript ausführen

```bash
sudo ./certbot-hetzner-setup.sh
```

Das Skript führt nun automatisch folgende Schritte aus:

1. Stoppt alte Certbot-Dienste
2. Installiert Python3 und venv (falls nötig)
3. Erstellt Virtual Environment unter `/opt/certbot/certbot-venv`
4. Installiert Certbot und certbot-dns-hetzner Plugin
5. Erstellt Hetzner API Credentials
6. Sichert bestehende Zertifikate
7. Erstellt neues Let's Encrypt Zertifikat (inkl. Wildcard)
8. Richtet systemd Service und Timer für automatische Erneuerung ein
9. Lädt den Webserver neu

## 🔑 Hetzner API Token erstellen

1. Logge dich in die [Hetzner DNS Console](https://dns.hetzner.com/) ein
2. Gehe zu **API Tokens** im Menü
3. Klicke auf **Create access token**
4. Gib einen Namen ein (z.B. "Certbot")
5. Wähle die Berechtigung **Read & Write**
6. Kopiere den generierten Token (wird nur einmal angezeigt!)

## 📂 Verzeichnisstruktur

Nach der Installation sieht die Struktur so aus:

```
/opt/certbot/
├── certbot-venv/              # Python Virtual Environment
│   ├── bin/
│   │   └── certbot           # Certbot Binary
│   └── lib/
│       └── python3.x/
│           └── site-packages/

/etc/letsencrypt/
├── live/
│   └── domain.de/
│       ├── cert.pem
│       ├── chain.pem
│       ├── fullchain.pem
│       └── privkey.pem
├── hetzner/
│   └── credentials.ini       # Hetzner API Token (chmod 600)
└── renewal/
    └── domain.de.conf

/etc/systemd/system/
├── certbot-renew.service     # Renewal Service
└── certbot-renew.timer       # Täglicher Timer

/var/log/certbot/             # Log-Verzeichnis
```

## 🔄 Automatische Erneuerung

Das Skript richtet einen systemd Timer ein, der **täglich** (zu einer zufälligen Zeit innerhalb von 12 Stunden) prüft, ob das Zertifikat erneuert werden muss.

### Timer-Status prüfen

```bash
# Timer-Status anzeigen
sudo systemctl status certbot-renew.timer

# Nächste Ausführungszeit anzeigen
sudo systemctl list-timers certbot-renew.timer

# Manuelle Erneuerung testen (Dry-Run)
sudo /opt/certbot/certbot-venv/bin/certbot renew --dry-run

# Manuelle Erneuerung durchführen
sudo /opt/certbot/certbot-venv/bin/certbot renew
```

### Timer neu starten

```bash
sudo systemctl restart certbot-renew.timer
```

### Timer deaktivieren

```bash
sudo systemctl stop certbot-renew.timer
sudo systemctl disable certbot-renew.timer
```

## 🔍 Zertifikat überprüfen

```bash
# Alle Zertifikate anzeigen
sudo /opt/certbot/certbot-venv/bin/certbot certificates

# Zertifikat-Details
sudo openssl x509 -in /etc/letsencrypt/live/domain.de/cert.pem -text -noout

# Ablaufdatum prüfen
sudo openssl x509 -in /etc/letsencrypt/live/domain.de/cert.pem -noout -dates
```

## 🛠️ Webserver-Konfiguration

### Nginx

```nginx
server {
    listen 443 ssl http2;
    server_name domain.de *.domain.de;

    ssl_certificate /etc/letsencrypt/live/domain.de/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/domain.de/privkey.pem;
    
    # Empfohlene SSL-Einstellungen
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    # HSTS (optional)
    add_header Strict-Transport-Security "max-age=31536000" always;
    
    # Weitere Konfiguration...
}
```

Nginx neu laden:
```bash
sudo nginx -t  # Konfiguration testen
sudo systemctl reload nginx
```

### Apache2

```apache
<VirtualHost *:443>
    ServerName domain.de
    ServerAlias *.domain.de

    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/domain.de/cert.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/domain.de/privkey.pem
    SSLCertificateChainFile /etc/letsencrypt/live/domain.de/chain.pem

    # Empfohlene SSL-Einstellungen
    SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite HIGH:!aNULL:!MD5
    SSLHonorCipherOrder on
    
    # Weitere Konfiguration...
</VirtualHost>
```

Apache neu laden:
```bash
sudo apache2ctl configtest  # Konfiguration testen
sudo systemctl reload apache2
```

## 🐛 Troubleshooting

### Fehler: "ambiguous option: --dns-hetzner"

Das Skript verwendet die korrekte Syntax `-a dns-hetzner`. Falls du manuell Certbot aufrufst, verwende:

```bash
sudo /opt/certbot/certbot-venv/bin/certbot certonly \
  -a dns-hetzner \
  --dns-hetzner-credentials /etc/letsencrypt/hetzner/credentials.ini \
  -d domain.de
```

**Nicht** verwenden: `--dns-hetzner` (führt zu Fehlern)

### Fehler: "DNS problem: NXDOMAIN"

- Prüfe, ob die Domain korrekt bei Hetzner DNS eingetragen ist
- Warte einige Minuten nach DNS-Änderungen
- Erhöhe `--dns-hetzner-propagation-seconds` im Skript (z.B. auf 120)

### Fehler: "Unauthorized"

- Überprüfe den Hetzner API Token
- Stelle sicher, dass der Token **Read & Write** Rechte hat
- Prüfe `/etc/letsencrypt/hetzner/credentials.ini`

### Logs anzeigen

```bash
# Certbot Logs
sudo /opt/certbot/certbot-venv/bin/certbot --logs

# Systemd Service Logs
sudo journalctl -u certbot-renew.service

# Letzte 50 Zeilen
sudo journalctl -u certbot-renew.service -n 50
```

### Manuelle Erneuerung mit Debug-Output

```bash
sudo /opt/certbot/certbot-venv/bin/certbot renew --dry-run -v
```

## 🔐 Sicherheit

- ✅ API Credentials sind nur für root lesbar (`chmod 600`)
- ✅ Virtual Environment isoliert Python-Pakete vom System
- ✅ ECDSA-Schlüssel für moderne Verschlüsselung
- ✅ Automatische Backups vor Zertifikatserstellung

### API Token schützen

```bash
# Berechtigungen prüfen
ls -la /etc/letsencrypt/hetzner/credentials.ini
# Sollte sein: -rw------- 1 root root

# Falls nicht, korrigieren:
sudo chmod 600 /etc/letsencrypt/hetzner/credentials.ini
sudo chown root:root /etc/letsencrypt/hetzner/credentials.ini
```

## 📝 Manuelle Installation (ohne Skript)

Falls du die Schritte einzeln durchführen möchtest, siehe die detaillierte Anleitung in den Kommentaren des Skripts.

## 🤝 Contributing

Contributions sind willkommen! Bitte öffne ein Issue oder Pull Request.

## 📜 Lizenz

MIT License

## 🙏 Credits

- [Certbot](https://certbot.eff.org/) - EFF's Let's Encrypt Client
- [certbot-dns-hetzner](https://github.com/ctrlaltcoop/certbot-dns-hetzner) - Hetzner DNS Plugin
- [Let's Encrypt](https://letsencrypt.org/) - Kostenlose SSL-Zertifikate

## ⚠️ Disclaimer

Dieses Skript wird "as-is" bereitgestellt. Teste es zuerst auf einem Test-System, bevor du es in Produktion verwendest.

## 📧 Support

Bei Fragen oder Problemen:
- Öffne ein Issue auf GitHub
- Siehe [Troubleshooting](#-troubleshooting) Sektion
- Offizielle Certbot Dokumentation: https://eff-certbot.readthedocs.io/

---

**Hinweis:** Ersetze `alfaalf-media.de` mit deiner eigenen Domain und `DEIN-USERNAME/DEIN-REPO` mit deinem GitHub Repository.
