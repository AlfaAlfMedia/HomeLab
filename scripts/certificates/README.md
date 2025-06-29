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

## Benutzung

### Schritt 4: Erster Zertifikatsabruf

Führe das Skript zum ersten Mal aus. Es wird empfohlen, den ersten Lauf im Staging-Modus (`STAGING=1` in `config.conf`) durchzuführen, um die Rate-Limits von Let's Encrypt nicht zu gefährden.

```bash
sudo /usr/local/sbin/hetzner-cert-manager.sh
```
Das Skript wird die `venv` unter `/opt/certbot-venv` erstellen, die notwendigen Python-Pakete installieren und anschließend das Zertifikat anfordern.

### Schritt 5: Wechsel von Staging zu Produktion (Wichtig!)

Wenn der Testlauf mit `STAGING=1` erfolgreich war, hast du nun ein Test-Zertifikat. Wenn du jetzt einfach `STAGING=0` setzt und das Skript erneut ausführst, wird Certbot sagen, dass eine Erneuerung nicht notwendig ist.

Um das **Test-Zertifikat durch ein echtes Produktions-Zertifikat zu ersetzen**, musst du eine Erneuerung erzwingen.

1.  Setze `STAGING=0` in deiner `/etc/hetzner-cert-manager/config.conf`.
2.  Führe das Skript mit dem `--force-renewal` Flag aus:

```bash
sudo /usr/local/sbin/hetzner-cert-manager.sh --force-renewal
```
Dieses Flag wird normalerweise nur dieses eine Mal benötigt.

### Schritt 6: Automatische Erneuerung einrichten

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

**Teil C: Unseren Timer aktivieren**
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now certbot-renew.timer
```

**Teil D: Konflikte mit dem Standard-Certbot-Timer bereinigen (Wichtig!)**

Auf manchen Systemen kann durch eine frühere `apt`-Installation ein standardmäßiger `certbot.timer` existieren. Dieser würde fehlschlagen, da er die Certbot-Version in unserer `venv` nicht kennt. Wir müssen sicherstellen, dass nur unser eigener Timer aktiv ist.

1.  Überprüfe, ob ein konfliktreicher Timer existiert:
    ```bash
    sudo systemctl list-timers | grep 'certbot.timer'
    ```

2.  Wenn der obige Befehl eine Ausgabe liefert, deaktiviere den Standard-Timer:
    ```bash
    sudo systemctl disable --now certbot.timer
    ```

Nach diesem Schritt sollte nur noch unser `certbot-renew.timer` übrig sein, was du mit `sudo systemctl list-timers | grep certbot` überprüfen kannst.

### Schritt 7: Logging einrichten (Optional, empfohlen)

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
