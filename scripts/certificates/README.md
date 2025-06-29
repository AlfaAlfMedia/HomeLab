# Hetzner Let's Encrypt Certificate Manager

Dieses Repository enthält ein robustes Bash-Skript zur vollautomatischen Anforderung von Let's Encrypt Zertifikaten (inkl. Wildcards). Es dient als professioneller Wrapper um das offizielle `certbot-dns-hetzner` Plugin und ist für den sicheren, stabilen Einsatz auf Debian-basierten Systemen konzipiert.

## Features

* **Plugin-Basiert:** Nutzt das offizielle `certbot-dns-hetzner` Plugin für maximale Stabilität und vermeidet fehleranfällige manuelle Hooks.
* **Sicher & GitHub-Ready:** Vollständige Trennung von Code, Konfiguration und Zugangsdaten. Eine `.gitignore`-Datei verhindert das versehentliche Committen von sensiblen Informationen.
* **Vollautomatisiert:** Ein einziges Skript, das alle notwendigen Schritte von der Abhängigkeitsprüfung bis zum Zertifikatsabruf durchführt.
* **Flexibel Konfigurierbar:** Alle Parameter (Domains, E-Mail, Pfade, Flags) werden in einer separaten Konfigurationsdatei verwaltet.
* **Transparentes Logging:** Alle Ausgaben werden sowohl auf der Konsole angezeigt als auch in eine Log-Datei geschrieben, die für `logrotate` vorbereitet ist.
* **Zukunftssicher:** Baut auf dem Standard-Erneuerungsmechanismus von Certbot (via `systemd timer`) auf.

## Funktionsweise

Das Skript `hetzner-cert-manager.sh` ist ein "Wrapper". Es liest seine Konfigurationsdatei (`config.conf`), um zu wissen, *was* es tun soll (z.B. welche Domains zu sichern sind). Anschließend ruft es `certbot` mit dem `--dns-hetzner` Plugin auf.

Das Plugin selbst ist ein eigenständiges Werkzeug und liest seine eigene, minimale Konfigurationsdatei (`credentials.ini`), um den für die API-Authentifizierung benötigten Token zu erhalten. Diese Trennung sorgt für erhöhte Sicherheit und Modularität.

## Dateien in diesem Repository

* `hetzner-cert-manager.sh`: Das ausführbare Hauptskript.
* `config.conf.example`: Eine Vorlage für die Skript-Konfiguration.
* `credentials.ini.example`: Eine Vorlage für die Zugangsdaten des Hetzner-Plugins.
* `hetzner-cert-manager`: Eine Vorlage für /etc/logrotate.d/
* `.gitignore`: Verhindert das Committen der lokalen Konfigurationsdateien.
* `README.md`: Diese Anleitung.

## Installation und Konfiguration

Folge diesen Schritten, um den Manager auf deinem Server einzurichten.

### Schritt 1: Dateien auf den Server bringen

Klone dieses Repository oder erstelle die vier oben genannten Dateien manuell in einem Arbeitsverzeichnis.

```bash
git clone <deine-repository-url>
cd <dein-repository-name>
```

### Schritt 2: Skript installieren

Wir platzieren das Skript an den systemweiten, standardkonformen Speicherort.

```bash
# Skript nach /usr/local/sbin verschieben
sudo mv ./hetzner-cert-manager.sh /usr/local/sbin/

# Skript ausführbar machen
sudo chmod +x /usr/local/sbin/hetzner-cert-manager.sh
```

### Schritt 3: Konfiguration einrichten

Die Konfiguration wird in zwei separaten Schritten durchgeführt.

**Teil A: Die Manager-Konfiguration (`config.conf`)**

```bash
# Verzeichnis für die Konfiguration erstellen
sudo mkdir -p /etc/hetzner-cert-manager

# Konfigurationsvorlage kopieren
sudo cp ./config.conf.example /etc/hetzner-cert-manager/config.conf

# Konfigurationsdatei bearbeiten und an deine Bedürfnisse anpassen
sudo nano /etc/hetzner-cert-manager/config.conf
```
*Passe in dieser Datei die Werte für `EMAIL`, `DOMAINS` etc. an.*

**Teil B: Die Hetzner-Plugin-Zugangsdaten (`credentials.ini`)**

Das Plugin selbst benötigt seine eigene Datei nur mit dem API-Token.

```bash
# Pfad aus der config.conf entnehmen (Standard: /etc/letsencrypt/hetzner)
# Verzeichnis erstellen (falls noch nicht vorhanden)
sudo mkdir -p /etc/letsencrypt/hetzner

# Vorlage für die Zugangsdaten kopieren
sudo cp ./credentials.ini.example /etc/letsencrypt/hetzner/credentials.ini

# Datei mit dem echten API-Token befüllen
sudo nano /etc/letsencrypt/hetzner/credentials.ini
```

**WICHTIG: Setze für beide Dateien strikte Berechtigungen!**

```bash
# Schützt die Manager-Konfiguration
sudo chmod 644 /etc/hetzner-cert-manager/config.conf

# Schützt die Datei mit dem geheimen API-Token!
sudo chmod 600 /etc/letsencrypt/hetzner/credentials.ini
```

### Schritt 4: Logging einrichten (Empfohlen)

Richte `logrotate` ein, damit die Log-Datei nicht unendlich wächst.

```bash
sudo nano /etc/logrotate.d/hetzner-cert-manager
```

Füge folgenden Inhalt ein:

```
/var/log/hetzner-cert-manager.log {
    monthly
    rotate 12
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
```

## Benutzung

Nachdem alles konfiguriert ist, kannst du den Zertifikatsabruf mit einem einzigen Befehl starten:

```bash
sudo /usr/local/sbin/hetzner-cert-manager.sh
```

Das Skript kümmert sich um alles Weitere, inklusive der Installation fehlender Abhängigkeiten (falls in `config.conf` aktiviert).

## Automatische Erneuerung

Du musst **keinen eigenen Cronjob** einrichten. Das offizielle `certbot`-Paket installiert einen `systemd timer`, der den Befehl `certbot renew` ausführt. Dieser Befehl findet deine Zertifikate und erneuert sie automatisch mit der hinterlegten Plugin-Konfiguration.

Überprüfe den Timer mit: `sudo systemctl list-timers | grep certbot`

## Lizenz

Dieses Projekt steht unter der MIT-Lizenz.

