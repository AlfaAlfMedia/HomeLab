# Hetzner Let's Encrypt Certificate Manager (Venv Edition)

Dieses Repository enthält ein robustes Bash-Skript zur vollautomatischen Anforderung von Let's Encrypt Zertifikaten. Da das offizielle `certbot-dns-hetzner` Plugin nicht in den Standard-Repositories von Debian 12 enthalten ist, verfolgt dieses Skript den professionellen Ansatz, Certbot und seine Plugins in einer isolierten **Python Virtual Environment (venv)** zu verwalten.

Dieser Ansatz garantiert eine funktionierende Installation, ohne das Host-System mit systemweiten `pip`-Paketen zu verändern.

## Features

* **Venv-Basiert:** Installiert Certbot und Plugins sicher in einer isolierten Umgebung (`/opt/certbot-venv`), um Konflikte zu vermeiden und die Stabilität des Host-Systems zu gewährleisten.
* **Vollautomatisiert:** Ein einziges Skript, das die `venv` einrichtet, Abhängigkeiten installiert und den Zertifikatsabruf durchführt.
* **Sicher & GitHub-Ready:** Saubere Trennung von Logik, Konfiguration und sensiblen Zugangsdaten.
* **Transparentes Logging:** Alle Ausgaben werden auf der Konsole angezeigt und parallel in eine Log-Datei geschrieben.
* **Inklusive Erneuerung:** Die Anleitung enthält eine fertige `systemd`-Unit zur Einrichtung der vollautomatischen Zertifikatserneuerung.

## Dateien in diesem Repository

* `hetzner-cert-manager.sh`: Das Hauptskript, das die venv verwaltet und Certbot ausführt.
* `config.conf.example`: Eine Vorlage für die Skript-Konfiguration.
* `credentials.ini.example`: Eine Vorlage für die Zugangsdaten des Hetzner-Plugins.
* `hetzner-cert-manager.logrotate`: Eine Vorlage für `/etc/logrotate.d/`.
* `.gitignore`: Verhindert das Committen der lokalen Konfigurationsdateien.
* `README.md`: Diese Anleitung.

## Installation und Konfiguration

### Schritt 1: Dateien auf den Server bringen

Klone das Repository oder erstelle die notwendigen Dateien manuell in einem Arbeitsverzeichnis.

```bash
git clone <deine-repository-url>
cd <dein-repository-name>
```

### Schritt 2: Skript installieren

```bash
# Skript nach /usr/local/sbin verschieben
sudo mv ./hetzner-cert-manager.sh /usr/local/sbin/

# Skript ausführbar machen
sudo chmod +x /usr/local/sbin/hetzner-cert-manager.sh
```

### Schritt 3: Konfiguration einrichten

**Teil A: Die Manager-Konfiguration (`config.conf`)**

```bash
sudo mkdir -p /etc/hetzner-cert-manager
sudo cp ./config.conf.example /etc/hetzner-cert-manager/config.conf
sudo nano /etc/hetzner-cert-manager/config.conf
```
*Passe in dieser Datei die Werte an deine Bedürfnisse an.*

**Teil B: Die Hetzner-Plugin-Zugangsdaten (`credentials.ini`)**

```bash
sudo mkdir -p /etc/letsencrypt/hetzner
sudo cp ./credentials.ini.example /etc/letsencrypt/hetzner/credentials.ini
sudo nano /etc/letsencrypt/hetzner/credentials.ini
```
*Trage hier deinen echten Hetzner DNS API-Token ein.*

**WICHTIG: Setze strikte Berechtigungen!**
```bash
sudo chmod 644 /etc/hetzner-cert-manager/config.conf
sudo chmod 600 /etc/letsencrypt/hetzner/credentials.ini
```

### Schritt 4: Erster Zertifikatsabruf

Führe das Skript zum ersten Mal aus. Es wird die `venv` unter `/opt/certbot-venv` erstellen, die notwendigen Python-Pakete installieren und anschließend das Zertifikat anfordern.

```bash
sudo /usr/local/sbin/hetzner-cert-manager.sh
```

### Schritt 5: Automatische Erneuerung einrichten (Sehr wichtig!)

Da wir Certbot nicht über `apt` installiert haben, müssen wir den Erneuerungsprozess manuell einrichten. Wir verwenden dafür einen `systemd`-Timer.

**Teil A: Der `systemd`-Service**

Erstelle eine Service-Datei, die den `renew`-Befehl ausführt.
```bash
sudo nano /etc/systemd/system/certbot-renew.service
```
Füge folgenden Inhalt ein:
```ini
[Unit]
Description=Renew Let's Encrypt certificates using venv certbot

[Service]
Type=oneshot
ExecStart=/opt/certbot-venv/bin/certbot renew --quiet

```

**Teil B: Der `systemd`-Timer**

Erstelle eine Timer-Datei, die den Service zweimal täglich zu einer zufälligen Zeit startet.
```bash
sudo nano /etc/systemd/system/certbot-renew.timer
```
Füge folgenden Inhalt ein:
```ini
[Unit]
Description=Run certbot-renew.service twice daily

[Timer]
OnCalendar=*-*-* 00/12:00:00
RandomizedDelaySec=3600
Persistent=true

[Install]
WantedBy=timers.target
```

**Teil C: Timer aktivieren**
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now certbot-renew.timer
```

Du kannst den Status des Timers jederzeit mit `sudo systemctl list-timers | grep certbot` überprüfen.

### Schritt 6: Logging einrichten (Optional, empfohlen)

Kopiere die `logrotate`-Konfiguration.
```bash
# Die Datei heißt hier der Einfachheit halber `hetzner-cert-manager`, nicht `...logrotate`
sudo cp ./hetzner-cert-manager.logrotate /etc/logrotate.d/hetzner-cert-manager
```
Der Inhalt sollte sein:
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

## Lizenz

Dieses Projekt steht unter der MIT-Lizenz.
