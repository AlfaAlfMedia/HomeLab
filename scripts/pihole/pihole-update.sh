#!/bin/bash

# Dieses Skript aktualisiert Debian/Pi-hole, loggt die Ausgaben und sendet
# NTFY-Benachrichtigungen bei Fehlern oder wichtigen Ereignissen.
# Konfiguration wird aus einer externen Datei geladen.

# --- Konfigurationsdatei ---
CONFIG_FILE="/root/.config/update_script" # Pfad zur Konfigurationsdatei

# --- Standardeinstellungen (Defaults) ---
# Werden verwendet, wenn in der Config-Datei nicht anders angegeben
DEFAULT_SYSTEM_NAME="Pihole Updater"
DEFAULT_NTFY_TAGS="warning,zap"
DEFAULT_NTFY_PRIORITY="4"
DEFAULT_NTFY_DELIVERY_TIME="9am" # Standard: Zustellung um 9 Uhr planen
DEFAULT_LOG_DIR="/var/log/cron-update"
DEFAULT_SCHEDULE_NTFY="true" # Standardmäßig Benachrichtigungen planen, wenn Zeit gesetzt

# --- Konfiguration laden ---
# Frühe Prüfung, ob Datei existiert. Fehlermeldung nach stderr.
if [ ! -f "$CONFIG_FILE" ]; then
    echo "[FEHLER] $(date +'%Y-%m-%d %H:%M:%S') Konfigurationsdatei $CONFIG_FILE nicht gefunden!" >&2
    exit 1
fi

# Konfigurationsdatei sourcen (Variablen werden hier gesetzt)
# shellcheck source=/dev/null
source "$CONFIG_FILE"

# --- Variablen validieren und Defaults anwenden ---
# Pflichtfelder prüfen
if [ -z "$NTFY_URL" ] || [ -z "$NTFY_ACCESS_TOKEN" ]; then
    # Loggt nach stderr, da Logdatei noch nicht sicher initialisiert ist
    echo "[FEHLER] $(date +'%Y-%m-%d %H:%M:%S') NTFY_URL oder NTFY_ACCESS_TOKEN sind in $CONFIG_FILE nicht gesetzt oder leer!" >&2
    # Optional: Sende unauthentifizierte NTFY-Nachricht als letzte Warnung
    curl -s -H "Title: Kritischer Konfig-Fehler" -H "Tags: critical,skull" -H "Priority: max" -d "FEHLER: NTFY_URL oder NTFY_ACCESS_TOKEN in $CONFIG_FILE nicht gesetzt!" "${NTFY_URL:-https://ntfy.sh/}" # Fallback URL
    exit 1
fi

# Optionale Felder mit Defaults füllen
SYSTEM_NAME="${SYSTEM_NAME:-$DEFAULT_SYSTEM_NAME}"
NTFY_TAGS="${NTFY_TAGS:-$DEFAULT_NTFY_TAGS}"
NTFY_PRIORITY="${NTFY_PRIORITY:-$DEFAULT_NTFY_PRIORITY}"
NTFY_DELIVERY_TIME="${NTFY_DELIVERY_TIME:-$DEFAULT_NTFY_DELIVERY_TIME}"
LOG_DIR="${LOG_DIR:-$DEFAULT_LOG_DIR}"

# Entscheidung über Planung: Nur wenn Zeit gesetzt ist UND Default es vorsieht
SCHEDULE_NTFY=$DEFAULT_SCHEDULE_NTFY
if [ -z "$NTFY_DELIVERY_TIME" ]; then
    SCHEDULE_NTFY="false"
fi

# --- Befehlspfade (Anpassen bei Bedarf) ---
APT_GET="/usr/bin/apt-get"
PIHOLE_CMD="/usr/local/bin/pihole" # Sicherstellen, dass der Pfad stimmt (which pihole)
REBOOT_CMD="/sbin/reboot"
DATE_CMD="/bin/date"
CURL_CMD="/usr/bin/curl"
TEE_CMD="/usr/bin/tee"
MKDIR_CMD="/bin/mkdir"
CHMOD_CMD="/bin/chmod"
CHOWN_CMD="/bin/chown"

# --- Logging initialisieren (NACHDEM LOG_DIR feststeht!) ---
# Verzeichnis erstellen (als root ausführen!)
"$MKDIR_CMD" -p "$LOG_DIR" || { echo "[FEHLER] $(date +'%Y-%m-%d %H:%M:%S') Konnte Log-Verzeichnis $LOG_DIR nicht erstellen." >&2; exit 1; }
# Berechtigungen ggf. anpassen (optional, meist ist root:root ok)
# "$CHOWN_CMD" root:adm "$LOG_DIR"
# "$CHMOD_CMD" 770 "$LOG_DIR"

# Logdatei definieren (Systemnamen für Dateinamen bereinigen)
SANITIZED_SYSTEM_NAME=$(echo "$SYSTEM_NAME" | tr -s ' /' '_')
LOG_FILE="$LOG_DIR/update_${SANITIZED_SYSTEM_NAME}_$($DATE_CMD +'%Y_%m_%d_%H%M%S').log"

# --- Funktionen ---
log_message() {
    # Schreibt Zeitstempel und Nachricht IMMER in die Logdatei
    echo "[$($DATE_CMD +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Jetzt kann das normale Logging in die Datei beginnen
log_message "===== Starte Update-Skript für $SYSTEM_NAME ====="
log_message "Konfiguration geladen aus $CONFIG_FILE."
log_message "Logdatei wird geschrieben nach: $LOG_FILE"
log_message "NTFY URL: $NTFY_URL"
log_message "NTFY Zustellung für Fehler geplant: $SCHEDULE_NTFY (Zielzeit: ${NTFY_DELIVERY_TIME:-sofort})"


send_ntfy_message() {
    local message="$1"
    # Nutze globale Konfigurationsvariablen oder übergebene Werte als Fallback/Override
    local use_prio="${2:-$NTFY_PRIORITY}"
    local use_tags="${3:-$NTFY_TAGS}"
    # Parameter 4 steuert explizit, ob diese Nachricht geplant werden soll
    local should_schedule_this_msg="${4:-$SCHEDULE_NTFY}" # Nutze globalen Standard, kann pro Aufruf überschrieben werden

    local at_header_arg=""
    local delivery_time_log=""

    # Planen nur wenn explizit für diese Nachricht gewünscht UND eine globale Zeit definiert ist
    if [[ "$should_schedule_this_msg" == "true" ]] && [[ -n "$NTFY_DELIVERY_TIME" ]]; then
        # Verwende die konfigurierte Zeit
        at_header_arg="-H \"At: $NTFY_DELIVERY_TIME\""
        delivery_time_log=" (geplant für $NTFY_DELIVERY_TIME)"
    else
        delivery_time_log=" (sofort)"
    fi

    log_message "Sende NTFY Nachricht$delivery_time_log (Prio: $use_prio, Tags: $use_tags): $message"

    # Baue curl Befehl als Array für Robustheit
    local curl_cmd_array=(
        "$CURL_CMD" -L -s
        -H "Authorization: Bearer $NTFY_ACCESS_TOKEN"
        -H "Title: Update Info $SYSTEM_NAME" # Nutzt $SYSTEM_NAME
        -H "Tags: $use_tags"                 # Nutzt $use_tags
        -H "Priority: $use_prio"             # Nutzt $use_prio
    )
    # Füge At-Header hinzu, wenn geplant
    if [[ "$should_schedule_this_msg" == "true" ]] && [[ -n "$NTFY_DELIVERY_TIME" ]]; then
         curl_cmd_array+=(-H "At: $NTFY_DELIVERY_TIME")
    fi
    # Füge Daten und URL hinzu
    curl_cmd_array+=(-d "$message" "$NTFY_URL") # Nutzt $NTFY_URL

    # Führe Befehl aus
    if ! "${curl_cmd_array[@]}"; then
         log_message "FEHLER: Konnte NTFY Nachricht nicht senden (Curl fehlgeschlagen für $NTFY_URL)."
         # Optional: Fallback OHNE Token (könnte fehlschlagen, wenn Topic Authentifizierung braucht)
         # "$CURL_CMD" -s -H "Title: Kritischer Fehler bei Update $SYSTEM_NAME" ... "$NTFY_URL"
    fi
}


update_pihole() {
    log_message "--- Starte Pi-hole Updates ---"
    local pihole_ok=true

    log_message "Aktualisiere Pi-hole Kernkomponenten ('$PIHOLE_CMD -up')..."
    # Leite stdout und stderr an tee weiter -> Logdatei UND Terminal (falls manuell)
    # Prüfung des Exit-Codes von pihole, nicht von tee
    if ! "$PIHOLE_CMD" -up 2>&1 | "$TEE_CMD" -a "$LOG_FILE"; then
        # Exit Code $? oder ${PIPESTATUS[0]} in Bash prüfen
        if [ "${PIPESTATUS[0]}" -ne 0 ]; then
            send_ntfy_message "Pi-hole Kern-Update fehlgeschlagen ('pihole -up'). Siehe Log: $LOG_FILE"
            log_message "FEHLER: '$PIHOLE_CMD -up' fehlgeschlagen (Exit Code: ${PIPESTATUS[0]})."
            pihole_ok=false
        fi
    else
        log_message "Pi-hole Kern-Update erfolgreich."
    fi

    log_message "Aktualisiere Pi-hole Gravity Datenbank ('$PIHOLE_CMD -g')..."
    if ! "$PIHOLE_CMD" -g 2>&1 | "$TEE_CMD" -a "$LOG_FILE"; then
         if [ "${PIPESTATUS[0]}" -ne 0 ]; then
            send_ntfy_message "Pi-hole Gravity Update fehlgeschlagen ('pihole -g'). Siehe Log: $LOG_FILE"
            log_message "FEHLER: '$PIHOLE_CMD -g' fehlgeschlagen (Exit Code: ${PIPESTATUS[0]})."
            pihole_ok=false
         fi
    else
        log_message "Pi-hole Gravity Update erfolgreich."
    fi

    log_message "--- Pi-hole Updates beendet ---"
    if $pihole_ok; then return 0; else return 1; fi
}

update_debian() {
    log_message "--- Starte Debian System Updates ---"
    local debian_ok=true

    log_message "Aktualisiere Paketlisten ('$APT_GET update')..."
    # DEBIAN_FRONTEND=noninteractive verhindert interaktive Dialoge
    if ! DEBIAN_FRONTEND=noninteractive "$APT_GET" update 2>&1 | "$TEE_CMD" -a "$LOG_FILE"; then
        if [ "${PIPESTATUS[0]}" -ne 0 ]; then
            # Fehler bei 'apt update' ist oft nicht kritisch für 'upgrade', aber melden
            send_ntfy_message "Debian Paketlisten-Update fehlgeschlagen ('apt-get update'). Upgrade wird trotzdem versucht. Siehe Log: $LOG_FILE"
            log_message "FEHLER: '$APT_GET update' fehlgeschlagen (Exit Code: ${PIPESTATUS[0]})."
            # Hier entscheiden: Skript abbrechen (debian_ok=false) oder weitermachen? Wir machen weiter.
            # debian_ok=false
        fi
    else
        log_message "Paketlisten-Update erfolgreich."
    fi

    log_message "Führe System-Upgrade durch ('$APT_GET full-upgrade')..."
    # Optionen -y (automatisch ja), force-confdef/confold (Konflikte bei Konfigdateien lösen)
    if ! DEBIAN_FRONTEND=noninteractive "$APT_GET" -y \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" \
        full-upgrade 2>&1 | "$TEE_CMD" -a "$LOG_FILE"; then
        if [ "${PIPESTATUS[0]}" -ne 0 ]; then
            send_ntfy_message "Debian System-Upgrade fehlgeschlagen ('apt-get full-upgrade'). Siehe Log: $LOG_FILE"
            log_message "FEHLER: '$APT_GET full-upgrade' fehlgeschlagen (Exit Code: ${PIPESTATUS[0]})."
            debian_ok=false
        fi
    else
        log_message "System-Upgrade erfolgreich."
        # Autoremove nur nach erfolgreichem Upgrade? Oder immer? Hier: danach
        log_message "Entferne nicht mehr benötigte Pakete ('$APT_GET autoremove')..."
        if ! DEBIAN_FRONTEND=noninteractive "$APT_GET" -y autoremove 2>&1 | "$TEE_CMD" -a "$LOG_FILE"; then
            if [ "${PIPESTATUS[0]}" -ne 0 ]; then
                # Fehler hier ist meist nicht kritisch
                log_message "WARNUNG: '$APT_GET autoremove' fehlgeschlagen (Exit Code: ${PIPESTATUS[0]})."
            fi
        else
            log_message "Nicht mehr benötigte Pakete entfernt."
        fi
    fi

    log_message "--- Debian System Updates beendet ---"
    if $debian_ok; then return 0; else return 1; fi
}

check_reboot() {
    log_message "Prüfe, ob Neustart erforderlich ist (/var/run/reboot-required)..."
    if [ -f /var/run/reboot-required ]; then
        log_message "Neustart erforderlich!"
        # Diese Nachricht SOFORT senden, nicht planen! (letzter Parameter 'false')
        send_ntfy_message "System $SYSTEM_NAME erfordert einen Neustart nach Updates. Reboot wird jetzt eingeleitet." "$NTFY_PRIORITY" "critical,reboot" "false"
        log_message "Leite Neustart in 5 Sekunden ein..."
        # Kurze Pause, damit Log/NTFY Zeit hat
        sleep 5
        # Führe Reboot aus - Ausgabe geht nur ins Log
        "$REBOOT_CMD" >> "$LOG_FILE" 2>&1
        # Das Skript sollte hier enden. Falls nicht:
        log_message "FEHLER: Reboot-Befehl wurde ausgeführt, aber Skript läuft weiter?"
        return 1 # Fehler oder unerwarteter Zustand
    else
        log_message "Kein Neustart erforderlich."
        return 0 # Erfolg
    fi
}

# --- Hauptausführung ---
main() {
    local pihole_exit_code=0
    local debian_exit_code=0
    local reboot_exit_code=0 # 0=kein Reboot, 1=Reboot eingeleitet/Fehler

    update_pihole
    pihole_exit_code=$?

    update_debian
    debian_exit_code=$?

    # Reboot-Check ausführen
    # Muss als letztes, da es das Skript beenden kann
    check_reboot
    reboot_exit_code=$?

    log_message "===== Update-Skript für $SYSTEM_NAME beendet ====="

    # Finaler Exit-Code für Cron etc.
    # Exit 1 wenn Pihole oder Debian Updates fehlgeschlagen sind
    if [ $pihole_exit_code -ne 0 ] || [ $debian_exit_code -ne 0 ]; then
        log_message "Skriptlauf mit Fehlern in Update-Schritten beendet (Pihole: $pihole_exit_code, Debian: $debian_exit_code)."
        exit 1
    elif [ $reboot_exit_code -ne 0 ]; then
        # Reboot wurde eingeleitet (oder ist fehlgeschlagen), was kein Fehler der Updates war
        log_message "Skriptlauf durch eingeleiteten Reboot beendet."
        exit 0 # Oder 1, je nachdem wie Cron das werten soll
    else
        log_message "Skriptlauf erfolgreich beendet."
        # Optional: Erfolgsmeldung senden?
        # send_ntfy_message "Updates für $SYSTEM_NAME erfolgreich abgeschlossen." "info" "checkmark" "true" # Planen
        exit 0
    fi
}

# Skript starten
main
