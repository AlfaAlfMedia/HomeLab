# Technitium DNS Auto-PTR Generator

Automatische Erstellung von Reverse-DNS (PTR) Records in Technitium DNS Server aus vorhandenen A und AAAA Records.

## 🎯 Warum dieses Skript?

Die manuelle Pflege von Reverse-DNS (PTR Records) ist mühsam und fehleranfällig, besonders wenn man Dutzende oder Hunderte von Forward-DNS-Einträgen hat. Dieses Skript automatisiert den gesamten Prozess - einmal ausführen und alle PTR Records sind erstellt.

## 🚀 Schnellstart

### Schritt 1: Skript herunterladen

**Linux / macOS:**
```bash
wget https://raw.githubusercontent.com/AlfaAlfMedia/HomeLab/main/scripts/technitium/technitium-auto-ptr.py
```

**Windows (PowerShell):**
```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/AlfaAlfMedia/HomeLab/main/scripts/technitium/technitium-auto-ptr.py" -OutFile "technitium-auto-ptr.py"
```

### Schritt 2: Python installieren (falls noch nicht vorhanden)

**Prüfen ob Python bereits installiert ist:**
```bash
python3 --version
```

Falls Python nicht installiert ist:

<details>
<summary><b>Linux (Debian/Ubuntu)</b></summary>

```bash
sudo apt update
sudo apt install python3 python3-requests
```
</details>

<details>
<summary><b>Linux (RHEL/CentOS/Fedora)</b></summary>

```bash
sudo dnf install python3 python3-requests
```
</details>

<details>
<summary><b>macOS</b></summary>

```bash
# Mit Homebrew
brew install python3

# requests installieren
pip3 install requests
```
</details>

<details>
<summary><b>Windows</b></summary>

1. Python von [python.org](https://www.python.org/downloads/) herunterladen
2. Installer ausführen und **"Add Python to PATH"** anhaken
3. Terminal neu starten
4. Dann:
```powershell
pip install requests
```
</details>

### Schritt 3: API-Token erstellen

1. Technitium Web-Oberfläche öffnen (Standard: `http://server-ip:5380`)
2. Oben rechts auf deinen **Benutzernamen** klicken
3. **"Create API Token"** auswählen
4. Den angezeigten Token kopieren

### Schritt 4: Skript konfigurieren

Öffne die Datei `technitium-auto-ptr.py` mit einem Text-Editor:

**Linux / macOS:**
```bash
nano technitium-auto-ptr.py
```

**Windows:**
```powershell
notepad technitium-auto-ptr.py
```

Ändere diese Zeilen (ca. Zeile 25-27):

```python
API_TOKEN = "DEIN-API-TOKEN-HIER-EINFÜGEN"
ZONE_NAME = "deine-domain.de"
DRY_RUN = True  # Beim ersten Mal auf True lassen zum Testen!
```

Speichern und schließen.

### Schritt 5: Testlauf durchführen

**Wichtig:** Beim ersten Mal mit `DRY_RUN = True` testen!

```bash
python3 technitium-auto-ptr.py
```

Das Skript zeigt dir was es tun würde, **ohne** tatsächlich Änderungen vorzunehmen.

### Schritt 6: Tatsächlich ausführen

Wenn der Testlauf gut aussieht:

1. Skript nochmal öffnen
2. Ändern: `DRY_RUN = False`
3. Speichern
4. Nochmal ausführen:

```bash
python3 technitium-auto-ptr.py
```

**Fertig!** Alle PTR Records sind jetzt erstellt.

## 📖 Beispiel-Ausgabe

```
======================================================================
Technitium DNS Auto-PTR Generator
======================================================================

🔌 Verbinde zu Technitium auf http://localhost:5380
📋 Lade Records aus Zone: beispiel.de

✅ 75 A-Records und 15 AAAA-Records gefunden

🔍 Prüfe Reverse-Zonen...

  ✅ 1.168.192.in-addr.arpa - existiert
  ⚠️  5.10.172.in-addr.arpa - existiert nicht
      Erstelle Zone: 5.10.172.in-addr.arpa
      ✅ Zone erfolgreich erstellt

======================================================================
Erstelle PTR Records...
======================================================================

📝 server.beispiel.de (A) -> 192.168.1.10
   PTR: 10.1.168.192.in-addr.arpa -> server.beispiel.de
   ✅ Erstellt

📝 nas.beispiel.de (A) -> 172.10.5.20
   PTR: 20.5.10.172.in-addr.arpa -> nas.beispiel.de
   ✅ Erstellt

...

======================================================================
Zusammenfassung
======================================================================
✅ Erfolgreich erstellt: 90
```

## ⚙️ Konfigurationsoptionen

Im Skript kannst du folgende Werte anpassen:

```python
# Technitium API Einstellungen
API_URL = "http://localhost:5380"  # Ändere falls Technitium auf anderer IP/Port läuft
API_TOKEN = "dein-token"           # Dein API-Token
ZONE_NAME = "beispiel.de"          # Die Zone für die PTR Records erstellt werden sollen

# Test-Modus
DRY_RUN = False  # True = nur anzeigen, False = tatsächlich ausführen
```

## ✨ Features

- ✅ Verarbeitet automatisch alle A und AAAA Records einer Zone
- ✅ Berechnet korrekte Reverse-Zonen für IPv4 und IPv6
- ✅ Erstellt fehlende Reverse-Zonen automatisch
- ✅ Unterstützt mehrere IP-Netze in einer einzigen Forward-Zone
- ✅ Dry-Run-Modus zum sicheren Testen
- ✅ Übersichtliche Fortschrittsanzeige
- ✅ Läuft auf Linux, macOS, Windows, BSD, Raspberry Pi

## 🔧 So funktioniert es

1. **Lädt alle A und AAAA Records** aus der Zone via Technitium API
2. **Berechnet Reverse-Zonen:**
   - IPv4: `/24-Netze` (z.B. `192.168.1.x` → `1.168.192.in-addr.arpa`)
   - IPv6: `/64-Netze` (z.B. `2001:db8::/64` → entsprechende IP6.ARPA Zone)
3. **Erstellt fehlende Reverse-Zonen** automatisch als Primary-Zonen
4. **Fügt PTR Records hinzu** für jeden Forward-Record

**Beispiel:**
- Forward-Record: `server.beispiel.de` → `192.168.1.10` (A-Record)
- Skript erstellt: `10.1.168.192.in-addr.arpa` → `server.beispiel.de` (PTR-Record)

## ⚠️ Wichtige Hinweise

- PTR Records werden mit einer **TTL von 3600 Sekunden (1 Stunde)** erstellt
- Bei mehrfacher Ausführung können doppelte PTR Records entstehen (Technitium erlaubt mehrere PTR Records pro IP)
- Für IPv4 verwendet das Skript **/24-Netze** für Reverse-Zonen
- Für IPv6 verwendet das Skript **/64-Netze** für Reverse-Zonen
- Das Skript benötigt **API-Zugriff** - stelle sicher, dass dieser in Technitium aktiviert ist

## 🛡️ Sicherheit

- **Dry-Run-Modus**: Teste das Skript ohne tatsächliche Änderungen
- **API-Token**: Bewahre deinen Token sicher auf
- **Berechtigungen**: Der API-Token benötigt Schreibrechte auf Zonen

## ❓ Fehlerbehebung

<details>
<summary><b>"API Error: Connection refused"</b></summary>

- Prüfe ob Technitium läuft
- Überprüfe die `API_URL` (Standard: `http://localhost:5380`)
- Falls Technitium auf einem anderen Server läuft, nutze dessen IP
</details>

<details>
<summary><b>"Please configure your API_TOKEN"</b></summary>

- Du hast vergessen den API-Token einzutragen
- Erstelle einen Token: Benutzername → "Create API Token"
- Füge ihn im Skript bei `API_TOKEN =` ein
</details>

<details>
<summary><b>"No A or AAAA records found"</b></summary>

- Prüfe ob `ZONE_NAME` korrekt ist (Groß-/Kleinschreibung!)
- Stelle sicher, dass die Zone Records enthält
- Prüfe ob der API-Token die richtigen Berechtigungen hat
</details>

<details>
<summary><b>"externally-managed-environment" (Linux)</b></summary>

Debian/Ubuntu blockiert pip standardmäßig. Nutze stattdessen:

```bash
sudo apt install python3-requests
```
</details>

<details>
<summary><b>Windows: "python is not recognized"</b></summary>

- Python wurde nicht zu PATH hinzugefügt
- Installiere Python erneut und hake "Add Python to PATH" an
- Oder nutze `py` statt `python3`
</details>

<details>
<summary><b>PTR Records werden nicht aufgelöst</b></summary>

- Stelle sicher, dass deine DNS-Clients Technitium als DNS-Server nutzen
- Bei öffentlichen IPs: Reverse-Zonen müssen korrekt delegiert sein
</details>

## 🌍 Plattform-Kompatibilität

- ✅ Linux (Debian, Ubuntu, RHEL, CentOS, Fedora, Arch, etc.)
- ✅ macOS (Intel und Apple Silicon)
- ✅ Windows (10, 11, Server)
- ✅ BSD (FreeBSD, OpenBSD)
- ✅ Raspberry Pi (Raspberry Pi OS)

## 📋 Voraussetzungen

- Python 3.6 oder höher
- Technitium DNS Server mit aktivierter API
- `requests` Bibliothek (Python-Paket)

## 📄 Lizenz

MIT License - Frei verwendbar und anpassbar.

## 🙏 Credits

Teil der [AlfaAlfMedia HomeLab](https://github.com/AlfaAlfMedia/HomeLab) Skript-Sammlung.

## 📚 Weiterführende Links

- [AlfaAlfMedia HomeLab Repository](https://github.com/AlfaAlfMedia/HomeLab)
- [Technitium DNS Server](https://technitium.com/dns/)
- [Technitium API Dokumentation](https://github.com/TechnitiumSoftware/DnsServer/blob/master/APIDOCS.md)

## 🤝 Beiträge

Verbesserungen und Pull Requests sind willkommen!
