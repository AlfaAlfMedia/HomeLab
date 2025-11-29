# Technitium DNS Auto-PTR Generator

Automatische Erstellung von Reverse-DNS (PTR) Records in Technitium DNS Server aus vorhandenen A und AAAA Records.

## 🎯 Problem

Die manuelle Pflege von Reverse-DNS (PTR Records) ist mühsam und fehleranfällig, besonders wenn man Dutzende oder Hunderte von Forward-DNS-Einträgen hat. Dieses Skript automatisiert den gesamten Prozess.

## ✨ Features

- ✅ Verarbeitet automatisch alle A und AAAA Records einer Zone
- ✅ Berechnet korrekte Reverse-Zonen für IPv4 und IPv6
- ✅ Erstellt fehlende Reverse-Zonen automatisch
- ✅ Unterstützt mehrere IP-Netze in einer einzigen Forward-Zone
- ✅ Dry-Run-Modus zum Testen ohne Änderungen
- ✅ Übersichtliche Fortschrittsanzeige
- ✅ Fehlerbehandlung und Validierung

## 📋 Voraussetzungen

- Python 3.6 oder höher
- Technitium DNS Server mit aktivierter API
- `requests` Bibliothek (wird automatisch installiert)

## 🚀 Installation

### Methode 1: Direkt ausführen (empfohlen für einmalige Nutzung)

```bash
# Skript herunterladen
wget https://raw.githubusercontent.com/AlfaAlfMedia/HomeLab/main/scripts/technitium/technitium-auto-ptr.py

# Ausführbar machen
chmod +x technitium-auto-ptr.py

# Mit pipx ausführen (installiert Abhängigkeiten automatisch)
pipx run --spec requests technitium-auto-ptr.py
```

### Methode 2: Mit Virtual Environment (sauberste Methode)

```bash
# Skript herunterladen
wget https://raw.githubusercontent.com/AlfaAlfMedia/HomeLab/main/scripts/technitium/technitium-auto-ptr.py

# Virtual Environment erstellen
python3 -m venv technitium-env

# Virtual Environment aktivieren
source technitium-env/bin/activate

# Abhängigkeiten installieren
pip install requests

# Skript ausführen
python3 technitium-auto-ptr.py

# Nach der Nutzung: Virtual Environment deaktivieren
deactivate
```

### Methode 3: Systemweite Installation (nicht empfohlen)

```bash
# Skript herunterladen
wget https://raw.githubusercontent.com/AlfaAlfMedia/HomeLab/main/scripts/technitium/technitium-auto-ptr.py

# Abhängigkeiten installieren
pip3 install requests

# Skript ausführen
python3 technitium-auto-ptr.py
```

## 🖥️ Python Installation

### Linux (Debian/Ubuntu)

```bash
# Python und pip installieren
sudo apt update
sudo apt install python3 python3-pip python3-venv

# Optional: pipx für isolierte Skript-Ausführung
sudo apt install pipx
pipx ensurepath
```

### Linux (RHEL/CentOS/Fedora)

```bash
# Python und pip installieren
sudo dnf install python3 python3-pip

# Optional: pipx
sudo dnf install pipx
pipx ensurepath
```

### macOS

```bash
# Mit Homebrew
brew install python3

# Optional: pipx
brew install pipx
pipx ensurepath
```

### Windows

1. Python von [python.org](https://www.python.org/downloads/) herunterladen
2. Installer ausführen und **"Add Python to PATH"** anhaken
3. PowerShell oder CMD öffnen:

```powershell
# Prüfen ob Python installiert ist
python --version

# pipx installieren (optional)
pip install pipx
pipx ensurepath
```

**Wichtig für Windows:** Nach der Installation Terminal neu starten!

## ⚙️ Konfiguration

1. **API-Token von Technitium holen:**
   - Technitium Web-Oberfläche öffnen
   - Zu **Settings** → **API** gehen
   - API-Token kopieren

2. **Skript bearbeiten:**

```bash
# Mit einem Text-Editor öffnen
nano technitium-auto-ptr.py
```

3. **Diese Werte anpassen:**

```python
API_URL = "http://localhost:5380"  # Standard Technitium API URL
API_TOKEN = "DEIN_API_TOKEN_HIER"  # API-Token hier einfügen
ZONE_NAME = "beispiel.de"          # Deine Forward-DNS-Zone
DRY_RUN = False                    # Auf True setzen zum Testen
```

## 🎮 Verwendung

### Testlauf (empfohlen beim ersten Mal)

```python
# Im Skript einstellen:
DRY_RUN = True
```

```bash
python3 technitium-auto-ptr.py
```

Das Skript zeigt an, was es tun würde, ohne tatsächlich Änderungen vorzunehmen.

### Tatsächliche Ausführung

```python
# Im Skript einstellen:
DRY_RUN = False
```

```bash
python3 technitium-auto-ptr.py
```

## 📖 Beispiel-Ausgabe

```
======================================================================
Technitium DNS Auto-PTR Generator
======================================================================

🔌 Verbinde zu Technitium auf http://localhost:5380
📋 Lade Records aus Zone: alfaalf-media.com

✅ 75 A-Records und 15 AAAA-Records gefunden

🔍 Prüfe Reverse-Zonen...

  ✅ 1.168.192.in-addr.arpa - existiert
  ⚠️  5.10.172.in-addr.arpa - existiert nicht
      Erstelle Zone: 5.10.172.in-addr.arpa
      ✅ Zone erfolgreich erstellt

======================================================================
Erstelle PTR Records...
======================================================================

📝 server.alfaalf-media.com (A) -> 192.168.1.10
   PTR: 10.1.168.192.in-addr.arpa -> server.alfaalf-media.com
   ✅ Erstellt

📝 nas.alfaalf-media.com (A) -> 172.10.5.20
   PTR: 20.5.10.172.in-addr.arpa -> nas.alfaalf-media.com
   ✅ Erstellt

...

======================================================================
Zusammenfassung
======================================================================
✅ Erfolgreich erstellt: 90
```

## 🔧 So funktioniert es

1. **Lädt alle A und AAAA Records** aus der angegebenen Zone via Technitium API
2. **Berechnet Reverse-Zonen:**
   - IPv4: Nutzt /24-Netze (z.B. `192.168.1.x` → `1.168.192.in-addr.arpa`)
   - IPv6: Nutzt /64-Netze (z.B. `2001:db8::/64` → entsprechende IP6.ARPA Zone)
3. **Erstellt fehlende Reverse-Zonen** automatisch als Primary-Zonen
4. **Fügt PTR Records hinzu** für jeden Forward-Record

## 🏗️ Reverse-Zone-Erstellung

Das Skript ermittelt automatisch, welche Reverse-Zonen benötigt werden, basierend auf deinen IP-Adressen:

**IPv4 Beispiel:**
- Forward: `server.beispiel.de` → `192.168.1.10`
- Erstellt Zone: `1.168.192.in-addr.arpa`
- Fügt PTR hinzu: `10.1.168.192.in-addr.arpa` → `server.beispiel.de`

**IPv6 Beispiel:**
- Forward: `server.beispiel.de` → `2001:db8::1`
- Erstellt Zone: `[entsprechende ip6.arpa Zone]`
- Fügt PTR hinzu: `[vollständige Reverse-Notation]` → `server.beispiel.de`

## 🛡️ Sicherheitsfeatures

- **Dry-Run-Modus**: Skript testen ohne Änderungen vorzunehmen
- **API-Validierung**: Prüft API-Verbindung vor der Verarbeitung
- **Zonen-Verifizierung**: Bestätigt Existenz der Reverse-Zonen vor dem Hinzufügen von Records
- **Fehlerbehandlung**: Behandelt API-Fehler und ungültige IPs sauber
- **Fortschrittsanzeige**: Klares Feedback über den aktuellen Status

## ⚠️ Wichtige Hinweise

- Das Skript nutzt die **Technitium REST API** - stelle sicher, dass der API-Zugriff aktiviert ist
- PTR Records werden standardmäßig mit einer **TTL von 3600 Sekunden (1 Stunde)** erstellt
- Bei mehrfacher Ausführung können doppelte PTR Records entstehen (Technitium erlaubt mehrere PTR Records pro IP)
- Für IPv4 verwendet das Skript **/24-Netze** für Reverse-Zonen
- Für IPv6 verwendet das Skript **/64-Netze** für Reverse-Zonen

## 🌍 Plattform-Kompatibilität

Das Skript läuft auf allen Plattformen mit Python 3.6+:

- ✅ **Linux** (Debian, Ubuntu, RHEL, CentOS, Fedora, Arch, etc.)
- ✅ **macOS** (Intel und Apple Silicon)
- ✅ **Windows** (10, 11, Server)
- ✅ **BSD** (FreeBSD, OpenBSD)
- ✅ **Raspberry Pi** (Raspberry Pi OS)

## 🤝 Beiträge

Verbesserungen und Pull Requests sind willkommen!

## 📄 Lizenz

MIT License - Frei verwendbar und anpassbar.

## 🙏 Credits

Teil der [AlfaAlfMedia HomeLab](https://github.com/AlfaAlfMedia/HomeLab) Skript-Sammlung.

## 📚 Weiterführende Links

- [AlfaAlfMedia HomeLab Repository](https://github.com/AlfaAlfMedia/HomeLab)
- [Technitium DNS Server](https://technitium.com/dns/)
- [Technitium API Dokumentation](https://github.com/TechnitiumSoftware/DnsServer/blob/master/APIDOCS.md)
- [RFC 1035 - Domain Names](https://www.rfc-editor.org/rfc/rfc1035)
- [RFC 3596 - DNS Extensions für IPv6](https://www.rfc-editor.org/rfc/rfc3596)

## ❓ Fehlerbehebung

**"API Error: Connection refused"**
- Prüfe, ob Technitium läuft
- Überprüfe die API_URL (Standard: `http://localhost:5380`)

**"Please configure your API_TOKEN"**
- Du musst deinen tatsächlichen API-Token aus Technitium Settings → API eintragen

**"No A or AAAA records found"**
- Prüfe, ob ZONE_NAME korrekt ist
- Stelle sicher, dass die Zone existiert und Records enthält

**PTR Records werden nicht aufgelöst**
- Stelle sicher, dass deine DNS-Clients deinen Technitium-Server verwenden
- Prüfe, ob Reverse-Zonen korrekt delegiert sind (bei öffentlichen IPs)

**Python-Fehler unter Windows**
- Stelle sicher, dass Python während der Installation zu PATH hinzugefügt wurde
- Versuche `py` statt `python3` zu verwenden
- Terminal nach der Installation neu starten

**"ModuleNotFoundError: No module named 'requests'"**
- Virtual Environment aktivieren (`source technitium-env/bin/activate`)
- Oder `pip install requests` ausführen
- Oder `pipx run --spec requests technitium-auto-ptr.py` verwenden
