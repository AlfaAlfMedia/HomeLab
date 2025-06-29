#!/usr/bin/env bash
# =================================================================
#        Hetzner Let's Encrypt Certificate Manager
# =================================================================
#
# Version: 4.0 (Final)
# Zweck:   Ein robuster Wrapper zur Anforderung von Let's Encrypt
#          Zertifikaten über das offizielle certbot-dns-hetzner
#          Plugin, mit ausgelagerter Konfiguration für den
#          sicheren Einsatz und die Veröffentlichung auf GitHub.
#
# =================================================================

# Stoppt das Skript sofort bei Fehlern
set -e
set -o pipefail

# --- Initialisierung & Konfiguration ---

# Fester Pfad zur Haupt-Konfigurationsdatei
CONFIG_FILE="/etc/hetzner-cert-manager/config.conf"

# Funktion zum Laden der Konfiguration
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
        echo "!! FEHLER: Konfigurationsdatei nicht gefunden!    !!" >&2
        echo "!! Erwartet: $CONFIG_FILE  !!" >&2
        echo "!! Bitte die Installationsanleitung in der README.md befolgen. !!" >&2
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
}

# Lade Konfiguration, um LOG_FILE-Variable zu erhalten
load_config

# Setze Standard-Logpfad, falls nicht in der Config definiert
LOG_FILE="${LOG_FILE:-/var/log/hetzner-cert-manager.log}"

# Stelle sicher, dass die Log-Datei existiert und für root schreibbar ist
if [ "$(id -u)" -eq 0 ]; then
    sudo touch "$LOG_FILE"
    sudo chown root:root "$LOG_FILE"
fi

# Leite alle Ausgaben (stdout und stderr) in die Log-Datei um
# UND zeige sie gleichzeitig auf dem Bildschirm an.
exec &> >(tee -a "$LOG_FILE")

# Funktion für formatierte Log-Ausgaben mit Zeitstempel
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] => $1"
}

# --- Prüffunktionen ---

# Überprüfen, ob das Skript als root ausgeführt wird
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
      log "FEHLER: Dieses Skript muss mit sudo oder als root ausgeführt werden." >&2
      exit 1
    fi
}

# Funktion zur Überprüfung der Abhängigkeiten
check_dependencies() {
    log "Prüfe Abhängigkeiten..."
    REQUIRED_PACKAGES=("certbot" "python3-certbot-dns-hetzner")
    MISSING_PACKAGES=()

    for PACKAGE in "${REQUIRED_PACKAGES[@]}"; do
        if ! dpkg -s "$PACKAGE" >/dev/null 2>&1; then
            MISSING_PACKAGES+=("$PACKAGE")
        fi
    done

    if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
        log "WARNUNG: Folgende Pakete fehlen: ${MISSING_PACKAGES[*]}"
        if [[ "$AUTO_INSTALL_DEPS" == "TRUE" ]]; then
            log "AUTO_INSTALL_DEPS=TRUE: Installiere fehlende Pakete automatisch."
            apt-get update
            apt-get install -y "${MISSING_PACKAGES[@]}"
        else
            log "Bitte installieren Sie die fehlenden Pakete manuell oder setzen Sie AUTO_INSTALL_DEPS auf TRUE."
            exit 1
        fi
    else
        log "Alle Abhängigkeiten sind erfüllt."
    fi
}

# Funktion zur Überprüfung der Hetzner-Zugangsdaten-Datei
check_credentials() {
    log "Prüfe Hetzner-Zugangsdaten-Datei..."
    if [ ! -f "$HETZNER_CREDENTIALS_PATH" ]; then
        log "FEHLER: Hetzner Zugangsdaten-Datei nicht gefunden unter '$HETZNER_CREDENTIALS_PATH'" >&2
        log "Bitte erstellen Sie die Datei gemäß der README-Anleitung." >&2
        exit 1
    fi
    log "Hetzner-Zugangsdaten-Datei gefunden."
}

# --- Hauptprozess ---

# Führe alle Schritte aus
check_root
log "Starte den Zertifikats-Manager..."
check_dependencies
check_credentials

# Staging-Option zusammenbauen
staging_option=""
if [ "$STAGING" -eq 1 ]; then
    staging_option="--staging"
    log "STAGING-Modus ist aktiviert."
else
    log "PRODUKTIV-Modus ist aktiviert."
fi

# Domain-Optionen für den Certbot-Befehl zusammenbauen
domain_flags=()
for d in "${DOMAINS[@]}"; do
    domain_flags+=(-d "$d")
done

log "Rufe Certbot mit dem Hetzner-DNS-Plugin auf für die Domains: ${DOMAINS[*]}"
certbot certonly \
  --dns-hetzner \
  --dns-hetzner-credentials "$HETZNER_CREDENTIALS_PATH" \
  --non-interactive \
  --agree-tos \
  -m "$EMAIL" \
  "${domain_flags[@]}" \
  $staging_option

log "-------------------------------------------"
log "Zertifikatsprozess erfolgreich abgeschlossen!"
log "Die automatische Erneuerung über den Certbot-Dienst ist nun aktiv."
log "-------------------------------------------"
