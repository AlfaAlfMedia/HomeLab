# Hetzner DNS-Challenge Wildcard Zertifikat

Dieses Skript ermöglicht die automatische Anforderung von Wildcard-Zertifikaten für Domains, die bei Hetzner verwaltet werden – mittels Let's Encrypt und der DNS-Challenge.

## Vorbereitung

### 1. `.env` konfigurieren
- Kopiere die Datei `.env.example` in eine neue Datei namens `.env`:
  ```bash
  cp .env.example .env
  ```
- Öffne die `.env`-Datei und trage deine Daten ein:
  - `EMAIL`: Deine E-Mail-Adresse  
  - `DOMAIN`: Deine Domain (z. B. `example.com`)  
  - `STAGING`: `1` für Testzertifikate (Staging), `0` für Produktion  
  - `HETZNER_DNS_TOKEN`: Dein Hetzner DNS-API-Token

### 2. Benötigte Programme installieren
Stelle sicher, dass folgende Programme installiert sind:
- `sudo`
- `jq` (z. B. `sudo apt install jq`)
- `curl`
- `certbot` (z. B. `sudo apt install certbot`)

Falls eines der Programme fehlt, kannst du sie mit folgendem Befehl installieren:
```bash
sudo apt update && sudo apt install sudo jq curl certbot
```
Dein Benutzer muss zudem über ausreichende `sudo`-Rechte verfügen.

## Nutzung

### 1. Repository klonen
```bash
git clone git@github.com:AlfaAlfMedia/HomeLab.git
```

### 2. In das Skriptverzeichnis wechseln
```bash
cd HomeLab/scripts/certificates
```

### 3. Skript ausführen
```bash
./hetzner-dns-challenge.sh
```

### 4. Zertifikate finden
Nach erfolgreicher Ausführung findest du die Zertifikate in den Standardverzeichnissen von Let's Encrypt:
```bash
/etc/letsencrypt/live/example.com/
```

## Hinweise

### Staging vs. Produktion
Setze in der `.env`:
- `STAGING=1`, um ein Testzertifikat zu erstellen (empfohlen für den ersten Test).
- `STAGING=0`, um ein gültiges Zertifikat für den produktiven Einsatz zu erhalten.

### Wildcard-Unterstützung
Das Skript fordert automatisch Zertifikate für die Basis-Domain und alle Subdomains an, z. B.:
- `example.com`
- `*.example.com`

---

**Viel Erfolg!**
