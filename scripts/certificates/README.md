# Let's Encrypt Wildcard-Zertifikate mit Hetzner DNS

Dieses Repository enthält ein Bash-Skript zur vollautomatischen Anforderung von Let's Encrypt Wildcard-Zertifikaten. Es nutzt die DNS-01-Challenge und interagiert direkt mit der Hetzner DNS API, um die benötigten TXT-Einträge zu erstellen und zu löschen.

Dieses Projekt entstand, um einen robusten, sicheren und standardkonformen Weg für die Zertifikatsautomatisierung auf Debian-basierten Systemen zu bieten, bei dem Code und Konfiguration sauber getrennt sind.

## Features

* **Vollautomatisch:** Fordert Wildcard- (*.example.com) und Standardzertifikate an.
* **Sicher:** Trennt den ausführbaren Code von der Konfigurationsdatei, die geheime API-Tokens enthält.
* **Standardkonform:** Orientiert sich am Filesystem Hierarchy Standard (FHS) für die Ablage von Skripten und Konfigurationen.
* **Robust:** Prüft auf notwendige Abhängigkeiten (`curl`, `jq`, `certbot`) und bietet deren automatische Installation an.
* **Flexibel:** Alle wichtigen Parameter (Domains, E-Mail, Token) werden in einer separaten Konfigurationsdatei verwaltet.
* **Transparent:** Schreibt detaillierte Logs in eine eigene Log-Datei mit integrierter Unterstützung für `logrotate`.
* **Zukunftssicher:** Kompatibel mit dem automatischen Erneuerungsprozess von Certbot via `systemd timer`.

## Funktionsweise

Das Skript dient als `manual-auth-hook` und `manual-cleanup-hook` für Certbot. Wenn `certbot` ein Zertifikat anfordert oder erneuert, ruft es dieses Skript auf:
1.  **Auth-Hook:** Das Skript empfängt den Challenge-Token von Certbot und erstellt über die Hetzner DNS API den geforderten `_acme-challenge` TXT-Eintrag.
2.  **Cleanup-Hook:** Nachdem Let's Encrypt den DNS-Eintrag erfolgreich validiert hat, ruft Certbot das Skript erneut auf, um den temporären TXT-Eintrag wieder zu löschen und die DNS-Zone sauber zu halten.

## Voraussetzungen

Das Skript ist für Debian-basierte Systeme (wie Debian, Ubuntu) optimiert. Folgende Pakete werden benötigt und bei Bedarf automatisch installiert:
* `certbot`
* `curl`
* `jq`

## Installation und Konfiguration

Folge diesen Schritten, um das Skript auf deinem Server einzurichten.

### 1. Repository klonen (Optional)

Wenn du dieses Projekt von GitHub beziehst, klone es. Ansonsten erstelle die Dateien manuell.
```bash
git clone <deine-repository-url>
cd <dein-repository-name>
```

### 2. Skript installieren

Wir platzieren das Skript an den systemweiten, standardkonformen Speicherort.

```bash
# Skript nach /usr/local/sbin verschieben
sudo mv ./hetzner-dns-certificate.sh /usr/local/sbin/

# Skript ausführbar machen
sudo chmod +x /usr/local/sbin/hetzner-dns-certificate.sh
```

### 3. Konfiguration einrichten

Die Konfigurationsdatei enthält alle deine persönlichen Daten und wird sicher in `/etc` abgelegt.

```bash
# Verzeichnis für die Konfiguration erstellen
sudo mkdir -p /etc/hetzner-dns

# Konfigurationsvorlage kopieren
sudo cp ./hetzner-dns.conf.example /etc/hetzner-dns/hetzner-dns.conf

# Konfigurationsdatei bearbeiten
sudo nano /etc/hetzner-dns/hetzner-dns.conf
```

Fülle in dieser Datei mindestens die folgenden Variablen aus:
* `HETZNER_DNS_TOKEN`
* `EMAIL`
* `DOMAINS`

**WICHTIG: Setze strikte Berechtigungen**, damit nur `root` die Datei mit deinem API-Token lesen kann:

```bash
sudo chmod 600 /etc/hetzner-dns/hetzner-dns.conf
```

### 4. Logging einrichten (Empfohlen)

Das Skript loggt standardmäßig nach `/var/log/hetzner-cert.log`. Um zu verhindern, dass diese Datei unendlich wächst, richte `logrotate` ein.

Erstelle die `logrotate`-Konfigurationsdatei:
```bash
sudo nano /etc/logrotate.d/hetzner-cert
```
Füge folgenden Inhalt ein:
```
/var/log/hetzner-cert.log {
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

Nachdem alles konfiguriert ist, kannst du den ersten Zertifikatsabruf starten.

```bash
sudo /usr/local/sbin/hetzner-dns-certificate.sh
```
Das Skript prüft die Abhängigkeiten und startet dann Certbot. Folge den Anweisungen auf dem Bildschirm.

## Automatische Erneuerung

Du musst **keinen eigenen Cronjob** einrichten. Das offizielle `certbot`-Paket installiert einen `systemd timer`, der zweimal täglich prüft, ob Zertifikate erneuert werden müssen. Wenn eine Erneuerung ansteht, ruft Certbot automatisch dein Skript als Werkzeug auf.

Du kannst den Status des Timers überprüfen mit:
```bash
sudo systemctl list-timers | grep certbot
```

## Lizenz

Dieses Projekt steht unter der MIT-Lizenz.
