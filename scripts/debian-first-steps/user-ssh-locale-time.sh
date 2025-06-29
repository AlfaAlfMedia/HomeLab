#!/bin/bash

# === Globale Variablen und Konfiguration ===
# BENUTZERNAME wird unten abgefragt.
# SSH_PUBLIC_KEYS Array wird unten gefüllt.

# === Hilfsfunktionen ===

# Funktion, um einen bestimmten Wert in der sshd_config sicherzustellen
# Argumente: $1 = Schlüssel, $2 = Wert, $3 = Konfigurationsdatei
ensure_ssh_config_value() {
    local key="$1"
    local value="$2"
    local config_file="$3"
    
    echo "    Sicherstellen: $key $value"
    
    if grep -qE "^\s*$key\s+$value\s*$" "$config_file"; then
        echo "      => Bereits korrekt gesetzt."
        return 0
    fi
    if grep -qE "^\s*$key\s+.*" "$config_file"; then
        sed -i -E "s/^\s*($key\s+).*$/\1$value/" "$config_file"
        echo "      => Aktiven Wert von '$key' auf '$value' geändert."
    elif grep -qE "^\s*#\s*$key\s+.*" "$config_file"; then
        sed -i -E "s/^\s*#\s*($key\s+).*$/\1$value/" "$config_file"
        echo "      => '$key' entkommentiert und auf '$value' gesetzt."
    else
        echo "$key $value" >> "$config_file"
        echo "      => '$key $value' hinzugefügt."
    fi
}

# Funktion zum Konfigurieren der System-Locale
configure_system_locale() {
    echo ""
    echo "--- Schritt 6: System-Locale auf de_DE.UTF-8 setzen ---"
    if [ "$(id -u)" -ne 0 ]; then
        echo "[FEHLER] Dieser Teil des Skripts (Locale-Setup) muss als root ausgeführt werden." >&2
        echo "         Überspringe Locale-Setup."
        return 1
    fi

    local DESIRED_LOCALE="de_DE.UTF-8"
    local LOCALE_GEN_FILE="/etc/locale.gen"
    local DEFAULT_LOCALE_FILE="/etc/default/locale"
    local EXPECTED_LINE_IN_LOCALE_GEN="${DESIRED_LOCALE} UTF-8"

    echo "[INFO] Prüfe aktuelle Locale-Einstellungen..."
    local current_lang
    current_lang=$(grep -oP '^LANG=\K.*' "$DEFAULT_LOCALE_FILE" 2>/dev/null)

    local has_localectl
    has_localectl=$(command -v localectl)
    if [ -n "$has_localectl" ] && localectl status | grep -q "LANG=${DESIRED_LOCALE}"; then
        if grep -qP "^\s*${EXPECTED_LINE_IN_LOCALE_GEN}" "$LOCALE_GEN_FILE"; then # Prüft auch, ob es in locale.gen aktiv ist
            echo "[INFO] System-Locale ist bereits vollständig auf '$DESIRED_LOCALE' gesetzt."
            return 0
        fi
    elif [ -z "$has_localectl" ] && [ "$current_lang" == "$DESIRED_LOCALE" ]; then
         if grep -qP "^\s*${EXPECTED_LINE_IN_LOCALE_GEN}" "$LOCALE_GEN_FILE"; then
            echo "[INFO] System-Locale ist bereits auf '$DESIRED_LOCALE' gesetzt (via $DEFAULT_LOCALE_FILE)."
            return 0
        fi
    fi
    echo "[INFO] Aktuelle LANG-Einstellung: '${current_lang:-Nicht gesetzt oder Datei nicht lesbar}'. Ziel: '$DESIRED_LOCALE'."
    
    echo "[AKTION] Konfiguriere System-Locale auf '$DESIRED_LOCALE'..."

    echo "[INFO] Stelle sicher, dass das 'locales' Paket installiert ist..."
    if ! dpkg -s locales &> /dev/null; then
        echo "[INFO] 'locales' Paket nicht gefunden. Installiere es..."
        apt update || { echo "[FEHLER] apt update fehlgeschlagen." >&2; return 1; }
        apt install -y locales || { echo "[FEHLER] Installation von 'locales' fehlgeschlagen." >&2; return 1; }
    else
        echo "[INFO] 'locales' Paket ist bereits installiert."
    fi

    echo "[INFO] Prüfe $LOCALE_GEN_FILE auf '$EXPECTED_LINE_IN_LOCALE_GEN'..."
    if ! grep -qP "^\s*#?\s*${EXPECTED_LINE_IN_LOCALE_GEN}" "$LOCALE_GEN_FILE"; then
        echo "[INFO] Zeile '$EXPECTED_LINE_IN_LOCALE_GEN' nicht in $LOCALE_GEN_FILE gefunden. Füge sie hinzu."
        echo "$EXPECTED_LINE_IN_LOCALE_GEN" >> "$LOCALE_GEN_FILE"
    else
        echo "[INFO] Zeile gefunden. Stelle sicher, dass sie aktiviert ist (kein '#' davor)..."
        sed -i -E "s/^\s*#+\s*(${EXPECTED_LINE_IN_LOCALE_GEN}.*)/\1/g" "$LOCALE_GEN_FILE"
    fi

    echo "[AKTION] Generiere Locales neu..."
    if locale-gen "$DESIRED_LOCALE"; then 
        echo "[INFO] Locale '$DESIRED_LOCALE' erfolgreich generiert."
    elif locale-gen; then 
        echo "[INFO] Alle aktivierten Locales erfolgreich generiert."
    else
        echo "[FEHLER] locale-gen ist fehlgeschlagen." >&2
    fi

    echo "[AKTION] Setze Standard-System-Locale auf '$DESIRED_LOCALE'..."
    if [ -n "$has_localectl" ]; then
        echo "[INFO] Verwende 'localectl' zum Setzen der Locale."
        if localectl set-locale LANG="$DESIRED_LOCALE"; then
            echo "[INFO] Locale erfolgreich mit localectl gesetzt."
        else
            echo "[FEHLER] 'localectl set-locale' fehlgeschlagen." >&2
            return 1
        fi
    else
        echo "[INFO] 'localectl' nicht gefunden. Verwende 'update-locale'."
        if update-locale LANG="$DESIRED_LOCALE"; then
            echo "[INFO] Locale erfolgreich mit update-locale gesetzt."
        else
            echo "[FEHLER] 'update-locale' fehlgeschlagen." >&2
            return 1
        fi
    fi
    return 0
}

# Funktion zum Konfigurieren des Zeitservers (NTP)
configure_ntp_client() {
    echo ""
    echo "--- Schritt 7: Zeitserver (NTP) mit systemd-timesyncd konfigurieren ---"
    if [ "$(id -u)" -ne 0 ]; then
        echo "[FEHLER] Dieser Teil des Skripts (NTP-Setup) muss als root ausgeführt werden." >&2
        echo "         Überspringe NTP-Setup."
        return 1
    fi
    
    if ! command -v timedatectl &> /dev/null; then
        echo "[INFO] 'timedatectl' (Teil von systemd) nicht gefunden."
        if ! dpkg -s systemd &> /dev/null && ! dpkg -s systemd-timesyncd &> /dev/null ; then
             echo "[INFO] Versuche systemd zu installieren..."
             apt update || { echo "[FEHLER] apt update fehlgeschlagen." >&2; return 1; }
             apt install -y systemd || { echo "[FEHLER] Installation von systemd fehlgeschlagen." >&2; return 1; }
        fi
        if ! command -v timedatectl &> /dev/null; then 
            echo "[FEHLER] Konnte systemd-timesyncd nicht verfügbar machen. Überspringe NTP-Setup." >&2
            return 1
        fi
    fi
    
    local timesyncd_conf_dir="/etc/systemd/timesyncd.conf.d"
    local custom_ntp_conf_file="${timesyncd_conf_dir}/10-custom-ntp.conf"
    local gateway_ip

    read -p "Bitte geben Sie die IP-Adresse Ihres Gateways (primärer NTP-Server) ein (leer lassen für Standard): " gateway_ip

    if [ -z "$gateway_ip" ]; then
        echo "[INFO] Keine Gateway-IP für NTP-Server angegeben. Entferne ggf. alte benutzerdefinierte Konfiguration."
        if [ -f "$custom_ntp_conf_file" ]; then
            rm -f "$custom_ntp_conf_file"
            echo "[INFO] Datei '$custom_ntp_conf_file' entfernt, um systemd-timesyncd Standard zu verwenden."
        else
            echo "[INFO] Keine benutzerdefinierte NTP-Konfiguration unter '$custom_ntp_conf_file' gefunden."
        fi
        echo "[INFO] systemd-timesyncd wird versuchen, Standard-NTP-Server zu verwenden."
    else
        echo "[AKTION] Konfiguriere '$gateway_ip' als primären NTP-Server für systemd-timesyncd."
        
        if [ ! -d "$timesyncd_conf_dir" ]; then
            mkdir -p "$timesyncd_conf_dir"
            echo "[INFO] Verzeichnis '$timesyncd_conf_dir' erstellt."
        fi

        local fallback_ntp_servers="0.de.pool.ntp.org 1.de.pool.ntp.org 2.de.pool.ntp.org 3.de.pool.ntp.org"
        echo "[INFO] Schreibe Konfiguration nach '$custom_ntp_conf_file'..."
        cat > "$custom_ntp_conf_file" << EOF
[Time]
NTP=${gateway_ip}
FallbackNTP=${fallback_ntp_servers}
EOF
        if [ $? -eq 0 ]; then
            echo "[INFO] NTP-Konfiguration erfolgreich geschrieben."
        else
            echo "[FEHLER] Konnte NTP-Konfiguration nicht nach '$custom_ntp_conf_file' schreiben." >&2
            return 1
        fi
    fi

    echo "[AKTION] Aktiviere und starte systemd-timesyncd neu..."
    if [[ "$(systemctl is-enabled systemd-timesyncd 2>/dev/null)" == "masked" ]]; then
        systemctl unmask systemd-timesyncd || echo "[WARNUNG] Konnte systemd-timesyncd nicht demaskieren."
    fi
    systemctl enable systemd-timesyncd || echo "[WARNUNG] Konnte systemd-timesyncd nicht aktivieren."
    systemctl restart systemd-timesyncd
    
    echo "[INFO] Warte 5 Sekunden auf die Synchronisation..."
    sleep 5 
    if systemctl is-active --quiet systemd-timesyncd; then
        echo "[INFO] systemd-timesyncd ist aktiv."
        echo "[INFO] Aktueller Zeitstatus (nach NTP-Konfiguration):"
        timedatectl status
    else
        echo "[WARNUNG] systemd-timesyncd konnte nicht gestartet werden oder ist nicht aktiv."
        echo "[INFO] Status von systemd-timesyncd:"
        systemctl status systemd-timesyncd --no-pager -l
        echo "[INFO] Bitte überprüfen Sie auch 'journalctl -u systemd-timesyncd'."
    fi
    return 0
}

# Funktion zum Konfigurieren der System-Zeitzone
configure_system_timezone() {
    echo ""
    echo "--- Schritt 8: System-Zeitzone auf Europe/Berlin setzen ---"
    if [ "$(id -u)" -ne 0 ]; then
        echo "[FEHLER] Dieser Teil des Skripts (Zeitzonen-Setup) muss als root ausgeführt werden." >&2
        echo "         Überspringe Zeitzonen-Setup."
        return 1
    fi

    local DESIRED_TIMEZONE="Europe/Berlin"

    if ! command -v timedatectl &> /dev/null; then
        echo "[FEHLER] 'timedatectl' Befehl nicht gefunden. Kann Zeitzone nicht setzen." >&2
        return 1
    fi

    current_timezone=$(timedatectl status | grep "Time zone" | awk '{print $3}')
    echo "[INFO] Aktuelle Zeitzone: $current_timezone"

    if [ "$current_timezone" == "$DESIRED_TIMEZONE" ]; then
        echo "[INFO] System-Zeitzone ist bereits auf '$DESIRED_TIMEZONE' gesetzt."
        return 0
    fi

    echo "[AKTION] Setze System-Zeitzone auf '$DESIRED_TIMEZONE'..."
    if timedatectl set-timezone "$DESIRED_TIMEZONE"; then
        echo "[INFO] System-Zeitzone erfolgreich auf '$DESIRED_TIMEZONE' gesetzt."
    else
        echo "[FEHLER] Konnte System-Zeitzone nicht auf '$DESIRED_TIMEZONE' setzen." >&2
        return 1
    fi
    return 0
}


# === Hauptskript ===
echo "=== Container Setup Skript Start ==="
echo "Dieses Skript führt eine Basiskonfiguration für einen neuen Debian/Ubuntu-basierten Container durch."
echo "Es muss mit root-Rechten ausgeführt werden."
echo "===================================="
echo "Aktuelles Datum und Uhrzeit zu Beginn: $(date)"

# --- Benutzereingaben am Anfang sammeln ---
read -p "Bitte geben Sie den gewünschten Benutzernamen ein: " BENUTZERNAME
if [ -z "$BENUTZERNAME" ]; then
    echo "[FEHLER] Es wurde kein Benutzername eingegeben. Skript wird beendet."
    exit 1
fi
echo "Zielbenutzer wird sein: $BENUTZERNAME"

# SSH-Schlüssel abfragen
SSH_PUBLIC_KEYS=() # Array für die Schlüssel initialisieren
add_keys_response=""
while [[ ! "$add_keys_response" =~ ^[jJnN]$ ]]; do
    read -p "Möchten Sie öffentliche SSH-Schlüssel für den Benutzer '$BENUTZERNAME' hinzufügen? (j/N): " add_keys_response
    add_keys_response=${add_keys_response:-N} # Standard ist Nein
done

if [[ "$add_keys_response" =~ ^[jJ]$ ]]; then
    num_keys_str=""
    while ! [[ "$num_keys_str" =~ ^[0-9]+$ ]]; do
        read -p "Wie viele öffentliche SSH-Schlüssel möchten Sie hinzufügen? (Zahl eingeben): " num_keys_str
    done
    num_keys=$((num_keys_str)) # In Zahl umwandeln

    if [ "$num_keys" -gt 0 ]; then
        echo "Bitte geben Sie nun die öffentlichen SSH-Schlüssel ein."
        for (( i=1; i<=num_keys; i++ )); do
            current_key=""
            while [ -z "$current_key" ]; do # Solange keine Eingabe erfolgte
                read -p "Schlüssel $i/$num_keys: " current_key
                # Einfache Validierung (kann erweitert werden)
                if [[ -n "$current_key" && ! ( "$current_key" =~ ^ssh-(rsa|dss|ed25519|ecdsa) ) ]]; then
                    echo "[WARNUNG] Die Eingabe sieht nicht wie ein gültiger öffentlicher SSH-Schlüssel aus. Bitte erneut versuchen."
                    current_key="" # Eingabe verwerfen
                elif [ -n "$current_key" ]; then
                    SSH_PUBLIC_KEYS+=("$current_key")
                fi
            done
        done
        echo "[INFO] ${#SSH_PUBLIC_KEYS[@]} SSH-Schlüssel wurden erfasst."
    else
        echo "[INFO] Keine SSH-Schlüssel werden hinzugefügt."
    fi
else
    echo "[INFO] Es werden keine SSH-Schlüssel interaktiv hinzugefügt."
fi


# --- Schritt 1: Neuen Benutzer erstellen ---
echo ""
echo "--- Schritt 1: Erstelle Benutzer $BENUTZERNAME ---"
if id "$BENUTZERNAME" &>/dev/null; then
    echo "Benutzer $BENUTZERNAME existiert bereits."
else
    echo "Erstelle Benutzer $BENUTZERNAME..."
    useradd -m -s /bin/bash "$BENUTZERNAME"
    if [ $? -ne 0 ]; then
        echo "[FEHLER] Benutzer $BENUTZERNAME konnte nicht erstellt werden."
        exit 1 
    else
        echo "Benutzer $BENUTZERNAME erfolgreich erstellt."
        echo "Bitte lege jetzt das Passwort für $BENUTZERNAME fest (wichtig für Konsolen-Login, falls SSH fehlschlägt):"
        passwd "$BENUTZERNAME"
        if [ $? -ne 0 ]; then
            echo "[WARNUNG] Passwort für $BENUTZERNAME konnte nicht interaktiv gesetzt werden oder wurde abgebrochen."
        fi
    fi
fi

# --- Schritt 2: System aktualisieren und Basistools installieren ---
echo ""
echo "--- Schritt 2: System aktualisieren und ausgewählte Tools installieren ---"
if [ "$(id -u)" -eq 0 ]; then
    echo "Führe Paketoperationen als root aus..."
    apt update && \
    apt full-upgrade -y && \
    apt install -y curl sudo wget git nano htop dnsutils tcpdump ufw tree net-tools
    if [ $? -ne 0 ]; then echo "[FEHLER] Während des Systemupdates oder der Tool-Installation."; else echo "System aktualisiert und Tools erfolgreich installiert."; fi
else
    echo "[WARNUNG] Skript nicht als root ausgeführt. Versuche Paketoperationen mit sudo..."
    if command -v sudo &> /dev/null; then
        sudo apt update && \
        sudo apt full-upgrade -y && \
        sudo apt install -y curl sudo wget git nano htop micro dnsutils tcpdump ufw tree net-tools
        if [ $? -ne 0 ]; then echo "[FEHLER] Während des Systemupdates oder der Tool-Installation mit sudo."; else echo "System aktualisiert und Tools mit sudo erfolgreich installiert."; fi
    else
        echo "[FEHLER] sudo ist nicht verfügbar und Skript nicht als root ausgeführt. Überspringe Paketoperationen."
    fi
fi

# --- Schritt 3: Gruppenmanagement und Benutzerberechtigungen ---
echo ""
echo "--- Schritt 3: Gruppenmanagement und Benutzerberechtigungen für $BENUTZERNAME ---"
if [ "$(id -u)" -eq 0 ]; then
    echo "Erstelle Gruppe 'ssh' (falls nicht existent)..."
    if grep -q -E "^ssh:" /etc/group; then
        echo "Gruppe 'ssh' existiert bereits."
    else
        groupadd ssh
        if [ $? -eq 0 ]; then echo "Gruppe 'ssh' erfolgreich erstellt."; else echo "[FEHLER] Gruppe 'ssh' konnte nicht erstellt werden."; fi
    fi

    if id "$BENUTZERNAME" &>/dev/null; then
        echo "Füge Benutzer $BENUTZERNAME zur Gruppe 'ssh' hinzu..."
        usermod -aG ssh "$BENUTZERNAME"
        if [ $? -eq 0 ]; then echo "Benutzer $BENUTZERNAME erfolgreich zur Gruppe 'ssh' hinzugefügt."; else echo "[FEHLER] $BENUTZERNAME konnte nicht zur Gruppe 'ssh' hinzugefügt werden."; fi
        
        if dpkg -s sudo &> /dev/null || command -v sudo &> /dev/null; then
            echo "Füge Benutzer $BENUTZERNAME zur Gruppe 'sudo' hinzu..."
            usermod -aG sudo "$BENUTZERNAME"
            if [ $? -eq 0 ]; then 
                echo "Benutzer $BENUTZERNAME erfolgreich zur Gruppe 'sudo' hinzugefügt."
                echo "Hinweis: $BENUTZERNAME muss sich möglicherweise neu anmelden, damit die sudo-Berechtigungen wirksam werden."
            else 
                echo "[FEHLER] $BENUTZERNAME konnte nicht zur Gruppe 'sudo' hinzugefügt werden."; 
            fi
        else
            echo "[WARNUNG] 'sudo' ist nicht installiert. $BENUTZERNAME kann nicht zur sudo-Gruppe hinzugefügt werden."
        fi
    else
        echo "[WARNUNG] Benutzer $BENUTZERNAME existiert nicht. Gruppenänderungen übersprungen."
    fi
else
    echo "[WARNUNG] Schritt 3 (Gruppenmanagement) erfordert root-Rechte. Übersprungen."
fi

# --- Schritt 4: SSH Key Autorisierung einrichten für $BENUTZERNAME ---
echo ""
echo "--- Schritt 4: SSH Key Autorisierung für $BENUTZERNAME ---"
if [ ${#SSH_PUBLIC_KEYS[@]} -gt 0 ]; then
    if [ "$(id -u)" -eq 0 ]; then
        if ! id "$BENUTZERNAME" &>/dev/null; then
            echo "[FEHLER] Benutzer $BENUTZERNAME existiert nicht. SSH-Konfiguration übersprungen."
        else
            USER_HOME_DIR=$(eval echo ~$BENUTZERNAME) 
            SSH_DIR="$USER_HOME_DIR/.ssh"
            AUTH_KEYS_FILE="$SSH_DIR/authorized_keys"
            
            if BENUTZER_GRUPPE=$(id -gn "$BENUTZERNAME" 2>/dev/null); then
                echo "Primäre Gruppe für $BENUTZERNAME ist '$BENUTZER_GRUPPE'."
            else
                BENUTZER_GRUPPE="$BENUTZERNAME" 
                echo "[WARNUNG] Konnte primäre Gruppe für $BENUTZERNAME nicht ermitteln, verwende '$BENUTZER_GRUPPE' als Gruppe."
            fi

            echo "Konfiguriere SSH-Zugriff für $BENUTZERNAME in '$USER_HOME_DIR'..."
            if [ ! -d "$USER_HOME_DIR" ]; then
                echo "[FEHLER] Home-Verzeichnis '$USER_HOME_DIR' nicht gefunden!"
            else
                if [ ! -d "$SSH_DIR" ]; then
                    mkdir -p "$SSH_DIR"
                    if [ $? -ne 0 ]; then echo "[FEHLER] Konnte das Verzeichnis '$SSH_DIR' nicht erstellen."; else echo "Verzeichnis '$SSH_DIR' erstellt."; fi
                fi
                
                chown "$BENUTZERNAME":"$BENUTZER_GRUPPE" "$SSH_DIR"
                chmod 700 "$SSH_DIR"
                touch "$AUTH_KEYS_FILE" # Erstellt Datei, falls nicht vorhanden, oder aktualisiert Zeitstempel

                if [ $? -ne 0 ]; then
                    echo "[FEHLER] Konnte die Datei '$AUTH_KEYS_FILE' nicht erstellen/anfassen."
                else
                    chown "$BENUTZERNAME":"$BENUTZER_GRUPPE" "$AUTH_KEYS_FILE"
                    chmod 600 "$AUTH_KEYS_FILE"
                    echo "Datei '$AUTH_KEYS_FILE' sichergestellt und Berechtigungen gesetzt."

                    KEYS_ADDED_COUNT=0
                    for CURRENT_KEY in "${SSH_PUBLIC_KEYS[@]}"; do
                        KEY_COMMENT=$(echo "$CURRENT_KEY" | awk '{print $3; exit}') 
                        if grep -q -F "$CURRENT_KEY" "$AUTH_KEYS_FILE"; then
                            echo "Schlüssel ($KEY_COMMENT) existiert bereits in '$AUTH_KEYS_FILE'."
                        else
                            echo "$CURRENT_KEY" >> "$AUTH_KEYS_FILE"
                            echo "Schlüssel ($KEY_COMMENT) wurde zu '$AUTH_KEYS_FILE' hinzugefügt."
                            KEYS_ADDED_COUNT=$((KEYS_ADDED_COUNT + 1))
                        fi
                    done
                    echo "$KEYS_ADDED_COUNT neue(r) Schlüssel effektiv zu '$AUTH_KEYS_FILE' hinzugefügt/überprüft."
                fi
                echo "SSH-Autorisierung für $BENUTZERNAME konfiguriert."
            fi
        fi
    else
        echo "[WARNUNG] Schritt 4 (SSH Key Autorisierung) erfordert root-Rechte. Übersprungen, da nicht als root ausgeführt."
    fi
else
    echo "[INFO] Keine SSH-Schlüssel zum Hinzufügen angegeben."
fi


# --- Schritt 5: SSH Daemon (sshd) Konfiguration anpassen ---
echo ""
echo "--- Schritt 5: SSH Daemon Konfiguration (/etc/ssh/sshd_config) anpassen ---"
if [ "$(id -u)" -eq 0 ]; then
    SSHD_CONFIG_FILE="/etc/ssh/sshd_config"
    if [ ! -f "$SSHD_CONFIG_FILE" ]; then
        echo "[FEHLER] $SSHD_CONFIG_FILE nicht gefunden. SSH-Konfiguration übersprungen."
    else
        SSHD_CONFIG_BACKUP="${SSHD_CONFIG_FILE}.backup_$(date +%Y-%m-%d_%H%M%S)"
        echo "  Erstelle Backup von '$SSHD_CONFIG_FILE' nach '$SSHD_CONFIG_BACKUP'..."
        cp "$SSHD_CONFIG_FILE" "$SSHD_CONFIG_BACKUP"
        if [ $? -ne 0 ]; then
            echo "  [FEHLER] Backup konnte nicht erstellt werden. Breche SSH-Konfiguration ab."
        else
            echo "  Backup erfolgreich erstellt: $SSHD_CONFIG_BACKUP"
            ensure_ssh_config_value "Port" "22" "$SSHD_CONFIG_FILE"
            ensure_ssh_config_value "PermitRootLogin" "no" "$SSHD_CONFIG_FILE"
            ensure_ssh_config_value "PubkeyAuthentication" "yes" "$SSHD_CONFIG_FILE"
            ensure_ssh_config_value "PasswordAuthentication" "no" "$SSHD_CONFIG_FILE"
            
            echo "  Prüfe/Füge 'AllowGroups ssh' hinzu..."
            if grep -qxF "AllowGroups ssh" "$SSHD_CONFIG_FILE"; then
                echo "      => 'AllowGroups ssh' ist bereits vorhanden."
            else
                echo "" >> "$SSHD_CONFIG_FILE" 
                echo "AllowGroups ssh" >> "$SSHD_CONFIG_FILE"
                echo "      => 'AllowGroups ssh' am Ende der Datei hinzugefügt."
            fi

            echo "  Überprüfe die SSHD-Konfigurationssyntax..."
            if command -v sshd &> /dev/null; then
                sshd -t
                if [ $? -eq 0 ]; then
                    echo "  SSHD Konfiguration ist VALIDE."
                    echo "  INFO: Der SSH-Dienst muss neu gestartet werden (z.B. 'sudo systemctl restart sshd')."
                else
                    echo "  [FEHLER] Die SSHD-Konfiguration ist nach den Änderungen INVALID!"
                    echo "  Bitte '$SSHD_CONFIG_FILE' manuell prüfen. Backup: '$SSHD_CONFIG_BACKUP'"
                fi
            else
                echo "[WARNUNG] sshd Befehl nicht gefunden. Konnte Konfiguration nicht testen."
            fi
        fi
    fi
else
    echo "[WARNUNG] Schritt 5 (SSHD Konfiguration) erfordert root-Rechte. Übersprungen."
fi

# --- Schritt 6: System-Locale konfigurieren ---
configure_system_locale

# --- Schritt 7: Zeitserver (NTP) konfigurieren ---
configure_ntp_client

# --- Schritt 8: System-Zeitzone konfigurieren ---
configure_system_timezone


echo ""
echo "=== Container Setup Skript Ende ==="
echo "Datum und Uhrzeit nach allen Änderungen: $(date)" 
echo "System-Zeitinformationen:"
if command -v timedatectl &> /dev/null; then
    timedatectl status
else
    echo "timedatectl nicht verfügbar."
fi
echo "==================================="
echo "[WICHTIG] Für einige Änderungen (insbesondere Locale für neue Shells und Dienste, sowie SSH-Dienst-Neustart) ist ein Systemneustart ('reboot') oder eine neue Anmeldung bzw. ein manueller Dienstneustart empfohlen."
