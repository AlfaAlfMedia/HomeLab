# Hetzner Let's Encrypt Certificate Manager (Venv Edition)

Dieses Repository enthält ein robustes Bash-Skript zur vollautomatischen Anforderung von Let's Encrypt Zertifikaten. Da das offizielle `certbot-dns-hetzner` Plugin nicht in den Standard-Repositories von Debian 12 enthalten ist, verfolgt dieses Skript den professionellen Ansatz, Certbot und seine Plugins in einer isolierten **Python Virtual Environment (venv)** zu verwalten.

Dieser Ansatz garantiert eine funktionierende Installation, ohne das Host-System mit systemweiten `pip`-Paketen zu verändern.

## Features

* **Venv-Basiert:** Installiert Certbot und Plugins sicher in einer isolierten Umgebung (`/opt/certbot-venv`), um Konflikte zu vermeiden und die Stabilität des Host-Systems zu gewährleisten.
* **Vollautomatisiert:** Ein einziges Skript, das die `venv` einrichtet, Abhängigkeiten installiert, Zertifikate abruft **und die automatische Erneuerung einrichtet**.
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
Das Skript wird die `venv` unter `/opt/certbot-venv` erstellen (falls noch nicht vorhanden) und anschließend das Zertifikat anfordern.

### Schritt 5: Wechsel von Staging zu Produktion (Wichtig!)

Wenn der Testlauf mit `STAGING=1` erfolgreich war, hast du nun ein Test-Zertifikat. Um dieses **durch ein echtes Produktions-Zertifikat zu ersetzen**, musst du eine Erneuerung erzwingen.

1.  Setze `STAGING=0` in deiner `/etc/hetzner-cert-manager/config.conf`.
2.  Führe das Skript mit dem `--force-renewal` Flag aus:

```bash
sudo /usr/local/sbin/hetzner-cert-manager.sh --force-renewal
```
Dieses Flag wird normalerweise nur dieses eine Mal benötigt.

### Schritt 6: Automatische Erneuerung einrichten

Nachdem du dein erstes Produktions-Zertifikat erhalten hast, kannst du mit einem einzigen Befehl die automatische Erneuerung einrichten.

```bash
sudo /usr/local/sbin/hetzner-cert-manager.sh --setup-renewal
```
Dieser Befehl erledigt alles Notwendige:
* Erstellt einen `systemd`-Service, der den `certbot renew` Befehl aus der `venv` aufruft.
* Erstellt einen `systemd`-Timer, der den Service zweimal täglich startet.
* Aktiviert den Timer und bereinigt eventuell vorhandene, konfliktreiche Standard-Timer von `certbot`.

Du kannst den Status des Timers jederzeit mit `sudo systemctl list-timers | grep certbot` überprüfen.

### Schritt 7: Logging einrichten (Optional, empfohlen)

Kopiere die `logrotate`-Konfiguration, um zu verhindern, dass die Log-Datei unendlich wächst.
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
