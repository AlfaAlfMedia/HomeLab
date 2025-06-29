#!/usr/bin/env bash
# =================================================================
#        Hetzner Let's Encrypt Certificate Manager (venv-Edition)
# =================================================================
#
# Version: 5.1 (Stabil & Venv-basiert, korrigierter Certbot-Aufruf)
# Zweck:   Ein robuster Wrapper zur Anforderung von Zertifikaten,
#          der Certbot und seine Plugins sicher in einer isolierten
#          Python Virtual Environment (venv) verwaltet.
#
# =================================================================

set -e
set -o pipefail

# --- Feste Pfade & Konfiguration ---
CONFIG_FILE="/etc/hetzner-cert-manager/config.conf"

# --- Funktionen ---
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "FEHLER: Konfigurationsdatei nicht gefunden: $CONFIG_FILE" >&2
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
}

setup_logging() {
    LOG_FILE="${LOG_FILE:-/var/log/hetzner-cert-manager.log}"
    if [ "$(id -u)" -eq 0 ]; then
        touch "$LOG_FILE" && chown root:root "$LOG_FILE"
    fi
    exec &> >(tee -a "$LOG_FILE")
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] => $1"
}

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
      log "FEHLER: Dieses Skript muss mit sudo oder als root ausgeführt werden." >&2
      exit 1
    fi
}

setup_venv() {
    log "Prüfe Python Virtual Environment (venv)..."
    VENV_PATH="${VENV_PATH:-/opt/certbot-venv}"
    CERTBOT_EXEC="$VENV_PATH/bin/certbot"

    # Prüfen, ob das venv-Tool installiert ist
    if ! dpkg -s python3-venv >/dev/null 2>&1; then
        log "Paket 'python3-venv' fehlt. Installiere es..."
        apt-get update
        apt-get install -y python3-venv
    fi

    # venv erstellen, falls es nicht existiert
    if [ ! -f "$CERTBOT_EXEC" ]; then
        log "Erstelle neue venv in '$VENV_PATH'..."
        python3 -m venv "$VENV_PATH"
        log "Installiere certbot und das Hetzner-Plugin in der venv (das kann einen Moment dauern)..."
        "$VENV_PATH/bin/pip" install --upgrade pip
        "$VENV_PATH/bin/pip" install certbot certbot-dns-hetzner
        log "Venv-Setup abgeschlossen."
    else
        log "Venv bereits vorhanden."
    fi
}

# --- Hauptprozess ---
load_config
setup_logging
check_root

log "Starte den Zertifikats-Manager..."
setup_venv # Stellt sicher, dass die venv existiert und Certbot installiert ist

# Prüfen, ob die Hetzner-Zugangsdaten existieren
if [ ! -f "$HETZNER_CREDENTIALS_PATH" ]; then
    log "FEHLER: Hetzner Zugangsdaten-Datei nicht gefunden unter '$HETZNER_CREDENTIALS_PATH'" >&2
    exit 1
fi
log "Hetzner-Zugangsdaten-Datei gefunden."

# Staging-Option
staging_option=""
if [ "$STAGING" -eq 1 ]; then
    staging_option="--staging"
    log "STAGING-Modus ist aktiviert."
fi

# Domain-Flags
domain_flags=()
for d in "${DOMAINS[@]}"; do
    domain_flags+=(-d "$d")
done

log "Rufe Certbot aus der venv auf für: ${DOMAINS[*]}"
"$CERTBOT_EXEC" certonly \
  --authenticator dns-hetzner \
  --dns-hetzner-credentials "$HETZNER_CREDENTIALS_PATH" \
  --non-interactive \
  --agree-tos \
  -m "$EMAIL" \
  "${domain_flags[@]}" \
  $staging_option

log "-------------------------------------------"
log "Zertifikatsprozess erfolgreich abgeschlossen!"
log "WICHTIG: Die automatische Erneuerung muss manuell eingerichtet werden (siehe README.md)."
log "-------------------------------------------"
