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
#PROMPT='%B%F{green}%n@%m%f%b:%F{blue}%~%f
#%# '
PROMPT='
%T >> %B%F{green}%n%f@%F{yellow}%m%f:%b%F{grey}%~%f
%# '

# Optional: Rechtsseitiger Prompt mit Uhrzeit
# RPROMPT='%F{gray}%*%f'

# ---- Syntax Highlighting (manuell - siehe unten) ----
# Wird nachinstalliert, auskommentiert lassen bis Installation

# ---- Suggestions basierend auf History ----
# Wird nachinstalliert, auskommentiert lassen bis Installation

# ---- Nützliche Aliase ----
alias ls='ls --color=auto'
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'

# ---- Keybindings ----
# Emacs-Style (für Ctrl+A, Ctrl+E etc.)
bindkey -e

# Pfeiltasten für History-Suche (mit bereits getipptem Präfix)
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search    # Pfeil hoch
bindkey "^[[B" down-line-or-beginning-search  # Pfeil runter

# Syntax Highlighting aktivieren
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Autosuggestions aktivieren
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
