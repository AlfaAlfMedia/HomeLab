# ZSH Installation & Konfiguration

Automatisches Installations-Skript für ZSH mit optimierter Konfiguration und Plugins für Debian/Ubuntu-Systeme.

## Features

- ✅ **Syntax Highlighting** - Befehle werden grün (gültig) oder rot (ungültig) hervorgehoben
- ✅ **Autosuggestions** - Intelligente Vorschläge basierend auf der Command-History
- ✅ **Erweiterte Tab-Completion** - Menü-basierte Vervollständigung mit Optionsbeschreibungen
- ✅ **History-basierte Suche** - Pfeiltasten durchsuchen History mit bereits getipptem Präfix
- ✅ **Übersichtlicher Prompt** - Zweizeiliges Design mit Uhrzeit, User, Host und vollständigem Pfad
- ✅ **Bash-kompatibel** - Die meisten Bash-Befehle und -Skripte funktionieren ohne Änderung

## Vorschau

```
14:23:45 >> user@hostname:/vollständiger/pfad/zum/verzeichnis
#
```

## Schnellinstallation

```bash
# Repository klonen
git clone https://github.com/yourusername/zsh-config.git
cd zsh-config

# Skript ausführbar machen
chmod +x install-zsh.sh

# Installation starten (als root)
sudo ./install-zsh.sh
```

Das Skript fragt nach dem Zielbenutzername. Nach der Installation **einmal ab- und wieder anmelden**, damit ZSH aktiv wird.

## Manuelle Installation

Falls du die Komponenten einzeln installieren möchtest:

### 1. ZSH installieren

```bash
sudo apt update
sudo apt install zsh
```

### 2. Plugins installieren

```bash
sudo apt install zsh-syntax-highlighting zsh-autosuggestions
```

### 3. Konfiguration einrichten

Kopiere den Inhalt der `.zshrc` aus diesem Repository in deine eigene `~/.zshrc`:

```bash
cp .zshrc ~/.zshrc
```

### 4. ZSH als Standard-Shell setzen

```bash
chsh -s $(which zsh)
```

Danach ab- und wieder anmelden.

## Anpassungen

### Prompt anpassen

Die Prompt-Konfiguration findest du in der `.zshrc` unter:

```bash
PROMPT='
%T >> %B%F{green}%n%f@%F{yellow}%m%f:%b%F{grey}%~%f
%# '
```

**Nützliche Variablen:**
- `%n` - Username
- `%m` - Hostname (kurz)
- `%M` - Hostname (vollständig)
- `%~` - Pfad mit ~ für Home
- `%/` - Vollständiger Pfad ohne ~
- `%c` - Nur aktuelles Verzeichnis
- `%T` - Zeit (HH:MM)
- `%*` - Zeit (HH:MM:SS)

**Farben:**
- `%F{farbe}` - Textfarbe: black, red, green, yellow, blue, magenta, cyan, white, grey
- `%f` - Farbe zurücksetzen

**Beispiele:**

```bash
# Einfacher einzeiliger Prompt:
PROMPT='%F{cyan}%n%f@%F{yellow}%m%f:%F{blue}%~%f %# '

# Nur aktuelles Verzeichnis statt vollständiger Pfad:
PROMPT='%F{green}%n@%m%f:%F{blue}%c%f %# '
```

### Weitere Aliase hinzufügen

In der `.zshrc` im Abschnitt "Nützliche Aliase":

```bash
alias update='sudo apt update && sudo apt upgrade'
alias ..='cd ..'
alias ...='cd ../..'
```

## Deinstallation

Zurück zu Bash wechseln:

```bash
chsh -s /bin/bash
```

Dann ab- und wieder anmelden.

## Kompatibilität

Getestet auf:
- Debian 11/12
- Ubuntu 20.04/22.04/24.04
- Proxmox LXC Container

## Unterschiede zu Bash

ZSH ist weitgehend Bash-kompatibel. Die wichtigsten Unterschiede:

- Array-Indizierung startet bei 1 (in Bash bei 0) - kann mit `setopt KSH_ARRAYS` angepasst werden
- Globbing ist erweitert (z.B. `**` für rekursive Suche)
- Erweiterte Completion und History-Funktionen

## Unterschiede zu Fish

Im Gegensatz zu Fish:
- ✅ Vollständig POSIX/Bash-kompatibel
- ✅ Bash-Skripte laufen ohne Änderung
- ✅ Alle Bash-Anleitungen funktionieren
- ✅ Gleiche Syntax für Variablen, Pipes, etc.

## Lizenz

MIT License - siehe LICENSE Datei

## Beitragen

Pull Requests sind willkommen! Für größere Änderungen bitte zuerst ein Issue öffnen.

## Support

Bei Problemen bitte ein Issue erstellen: https://github.com/yourusername/zsh-config/issues
