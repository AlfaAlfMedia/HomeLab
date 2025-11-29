#!/bin/bash
# ====================
# ZSH Installation & Konfiguration
# ====================
# Skript installiert zsh mit Plugins und richtet eine vorkonfigurierte .zshrc ein
# Autor: https://github.com/AlfaAlfMedia
# Lizenz: MIT

set -e  # Bei Fehler abbrechen

echo "==================================="
echo "ZSH Installation & Konfiguration"
echo "==================================="
echo ""

# Prüfen ob als root ausgeführt
if [ "$EUID" -ne 0 ]; then 
    echo "Bitte als root ausführen (sudo ./install-zsh.sh)"
    exit 1
fi

# Zielbenutzername erfragen (optional)
read -p "Für welchen Benutzer soll zsh konfiguriert werden? (Enter für aktuellen User): " TARGET_USER
if [ -z "$TARGET_USER" ]; then
    if [ -n "$SUDO_USER" ]; then
        TARGET_USER=$SUDO_USER
    else
        TARGET_USER=$(whoami)
    fi
fi

# Prüfen ob User existiert
if ! id "$TARGET_USER" &>/dev/null; then
    echo "Fehler: Benutzer '$TARGET_USER' existiert nicht!"
    exit 1
fi

USER_HOME=$(eval echo ~$TARGET_USER)

echo "Installation für Benutzer: $TARGET_USER"
echo "Home-Verzeichnis: $USER_HOME"
echo ""

# 1. ZSH installieren
echo "[1/5] Installiere zsh..."
apt update
apt install -y zsh

# 2. Plugins installieren
echo "[2/5] Installiere zsh-Plugins..."
apt install -y zsh-syntax-highlighting zsh-autosuggestions

# 3. .zshrc erstellen
echo "[3/5] Erstelle .zshrc Konfiguration..."
cat > "$USER_HOME/.zshrc" << 'EOF'
# ====================
# ZSH Konfiguration
# ====================

# ---- History-Einstellungen ----
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY              # History zwischen Sessions teilen
setopt HIST_IGNORE_DUPS           # Keine doppelten Einträge
setopt HIST_FIND_NO_DUPS          # Keine Duplikate beim Suchen
setopt HIST_IGNORE_SPACE          # Befehle mit führendem Leerzeichen nicht speichern

# ---- Completion System ----
autoload -Uz compinit
compinit

# Erweiterte Completion-Optionen
setopt COMPLETE_IN_WORD           # Completion auch in der Mitte des Wortes
setopt ALWAYS_TO_END              # Cursor nach Completion ans Ende
setopt AUTO_MENU                  # Completion-Menu bei mehreren Matches
setopt AUTO_LIST                  # Automatisch alle Möglichkeiten auflisten

# Completion-Styling
zstyle ':completion:*' menu select                          # Menü mit Auswahl
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'  # Case-insensitive
zstyle ':completion:*' list-colors ''                       # Farben in Listings
zstyle ':completion:*' verbose yes
zstyle ':completion:*:descriptions' format '%B%d%b'
zstyle ':completion:*:messages' format '%d'
zstyle ':completion:*:warnings' format 'Keine Matches für: %d'
zstyle ':completion:*' group-name ''

# Completion für Befehls-Optionen
zstyle ':completion:*:options' description 'yes'
zstyle ':completion:*:options' auto-description '%d'

# ---- Verzeichnis-Navigation ----
setopt AUTO_CD                    # cd automatisch bei Verzeichnis-Namen
setopt AUTO_PUSHD                 # Verzeichnisse automatisch auf Stack
setopt PUSHD_IGNORE_DUPS          # Keine Duplikate im Stack
setopt PUSHD_SILENT               # Kein Output bei pushd/popd

# ---- Prompt mit vollständigem Pfad (zweizeilig) ----
# Farben aktivieren
autoload -U colors && colors

# Prompt aufbauen
PROMPT='
%T >> %B%F{green}%n%f@%F{yellow}%m%f:%b%F{cyan}%~%f
%# '

# Optional: Rechtsseitiger Prompt mit Uhrzeit
# RPROMPT='%F{gray}%*%f'

# ---- Nützliche Aliase ----
alias ls='ls --color=auto'
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'

# ---- Keybindings ----
# Emacs-Style (für Ctrl+A, Ctrl+E etc.)
bindkey -e
bindkey "^[[H"    beginning-of-line   # Pos1
bindkey "^[[F"    end-of-line         # Ende
bindkey "^[[3~"   delete-char         # Entf
bindkey "^[[1;5C" forward-word        # Ctrl+Pfeil rechts
bindkey "^[[1;5D" backward-word       # Ctrl+Pfeil links

# Pfeiltasten für History-Suche (mit bereits getipptem Präfix)
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search    # Pfeil hoch
bindkey "^[[B" down-line-or-beginning-search  # Pfeil runter

# ---- Plugins ----
# Syntax Highlighting aktivieren
if [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# Autosuggestions aktivieren
if [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi
EOF

# Besitzer setzen
chown $TARGET_USER:$TARGET_USER "$USER_HOME/.zshrc"
chmod 644 "$USER_HOME/.zshrc"

# 4. ZSH als Standard-Shell setzen
echo "[4/5] Setze zsh als Standard-Shell für $TARGET_USER..."
chsh -s $(which zsh) $TARGET_USER

# 5. Fertig
echo "[5/5] Installation abgeschlossen!"
echo ""
echo "==================================="
echo "ZSH wurde erfolgreich installiert!"
echo "==================================="
echo ""
echo "WICHTIG: Bitte ab- und wieder anmelden, damit die Änderungen wirksam werden!"
echo ""
echo "Features:"
echo "  ✓ Syntax Highlighting (grün/rot bei Befehlen)"
echo "  ✓ Autosuggestions (graue Vorschläge aus History)"
echo "  ✓ Erweiterte Tab-Completion mit Menü"
echo "  ✓ History-basierte Suche mit Pfeiltasten"
echo "  ✓ Zweizeiliger Prompt mit Uhrzeit und vollständigem Pfad"
echo ""
echo "Konfigurationsdatei: $USER_HOME/.zshrc"
echo ""
