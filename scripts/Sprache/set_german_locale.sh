#!/bin/bash

# Skript zum Setzen der System-Locale auf de_DE.UTF-8
# Muss als root oder mit sudo ausgeführt werden!

# --- Konfiguration ---
DESIRED_LOCALE="de_DE.UTF-8"
LOCALE_GEN_FILE="/etc/locale.gen"
DEFAULT_LOCALE_FILE="/etc/default/locale" # Wird von update-locale verwaltet
# Zeile, wie sie in locale.gen aussehen sollte (ggf. mit # davor)
EXPECTED_LINE_IN_LOCALE_GEN="${DESIRED_LOCALE} UTF-8"

# --- Prüfungen ---
# 1. Prüfen, ob das Skript als root läuft
if [ "$(id -u)" -ne 0 ]; then
  echo "[FEHLER] Dieses Skript muss als root oder mit sudo ausgeführt werden." >&2
  exit 1
fi

# 2. Prüfen, ob die Locale bereits korrekt gesetzt ist
echo "[INFO] Prüfe aktuelle Locale-Einstellungen..."
current_lang=$(grep -oP '^LANG=\K.*' "$DEFAULT_LOCALE_FILE" 2>/dev/null) # Extrahiert den Wert von LANG

# Alternative Prüfung mit localectl (moderner)
has_localectl=$(command -v localectl)
if [ -n "$has_localectl" ]; then
    if localectl status | grep -q "LANG=${DESIRED_LOCALE}"; then
        echo "[INFO] System-Locale ist bereits auf '$DESIRED_LOCALE' gesetzt (via localectl)."
        exit 0
    fi
    # Fallback, falls localectl existiert, aber grep fehlschlägt oder LANG nicht die einzige Variable ist
    current_lang_localectl=$(localectl status | grep 'LANG=' | cut -d= -f2)
    if [ "$current_lang_localectl" == "$DESIRED_LOCALE" ]; then
         echo "[INFO] System-Locale ist bereits auf '$DESIRED_LOCALE' gesetzt (via localectl)."
         exit 0
    fi
fi

# Fallback-Prüfung der Datei /etc/default/locale
if [ "$current_lang" == "$DESIRED_LOCALE" ]; then
    echo "[INFO] System-Locale ist bereits auf '$DESIRED_LOCALE' gesetzt (via $DEFAULT_LOCALE_FILE)."
    exit 0
else
    echo "[INFO] Aktuelle LANG-Einstellung: '${current_lang:-Nicht gesetzt oder Datei nicht lesbar}'. Ziel: '$DESIRED_LOCALE'."
fi

# --- Aktionen ---
echo "[AKTION] Konfiguriere System-Locale auf '$DESIRED_LOCALE'..."

# 3. Sicherstellen, dass das 'locales' Paket installiert ist
echo "[INFO] Stelle sicher, dass das 'locales' Paket installiert ist..."
if ! dpkg -s locales &> /dev/null; then
    echo "[INFO] 'locales' Paket nicht gefunden. Installiere es..."
    apt-get update || { echo "[FEHLER] apt-get update fehlgeschlagen." >&2; exit 1; }
    apt-get install -y locales || { echo "[FEHLER] Installation von 'locales' fehlgeschlagen." >&2; exit 1; }
else
    echo "[INFO] 'locales' Paket ist bereits installiert."
fi

# 4. Sicherstellen, dass die gewünschte Locale in /etc/locale.gen aktiviert ist
echo "[INFO] Prüfe $LOCALE_GEN_FILE auf '$EXPECTED_LINE_IN_LOCALE_GEN'..."
# Prüfen, ob die Zeile existiert (egal ob auskommentiert oder nicht)
if ! grep -qP "^\s*#?\s*${EXPECTED_LINE_IN_LOCALE_GEN}" "$LOCALE_GEN_FILE"; then
    echo "[INFO] Zeile '$EXPECTED_LINE_IN_LOCALE_GEN' nicht in $LOCALE_GEN_FILE gefunden. Füge sie hinzu."
    # Füge die Zeile hinzu (bereits aktiviert)
    echo "$EXPECTED_LINE_IN_LOCALE_GEN" >> "$LOCALE_GEN_FILE"
else
    # Zeile existiert, stelle sicher, dass sie nicht auskommentiert ist
    echo "[INFO] Zeile gefunden. Stelle sicher, dass sie aktiviert ist (kein '#' davor)..."
    # Entferne führende '#' und Leerzeichen davor
    sed -i -E "s/^\s*#+\s*(${EXPECTED_LINE_IN_LOCALE_GEN}.*)/\1/g" "$LOCALE_GEN_FILE"
fi

# 5. Locales neu generieren
echo "[AKTION] Generiere Locales neu (locale-gen)..."
if locale-gen; then
    echo "[INFO] Locales erfolgreich generiert."
else
    echo "[FEHLER] locale-gen ist fehlgeschlagen." >&2
    # Nicht unbedingt abbrechen, update-locale könnte trotzdem funktionieren
fi

# 6. System-Locale setzen
echo "[AKTION] Setze Standard-System-Locale auf '$DESIRED_LOCALE'..."
if [ -n "$has_localectl" ]; then
    echo "[INFO] Verwende 'localectl' zum Setzen der Locale."
    if localectl set-locale LANG="$DESIRED_LOCALE"; then
        echo "[INFO] Locale erfolgreich mit localectl gesetzt."
    else
        echo "[FEHLER] 'localectl set-locale' fehlgeschlagen." >&2
        exit 1
    fi
else
    echo "[INFO] 'localectl' nicht gefunden. Verwende 'update-locale'."
    if update-locale LANG="$DESIRED_LOCALE"; then
        echo "[INFO] Locale erfolgreich mit update-locale gesetzt."
    else
        echo "[FEHLER] 'update-locale' fehlgeschlagen." >&2
        exit 1
    fi
fi

# --- Abschluss ---
echo ""
echo "[FERTIG] Die System-Locale wurde auf '$DESIRED_LOCALE' gesetzt."
echo "[WICHTIG] Damit die Änderungen systemweit für alle Dienste und neue Logins wirksam werden,"
echo "[WICHTIG] solltest du dich neu anmelden oder das System neu starten ('reboot')."
echo "[WICHTIG] Bestehende SSH-Sitzungen verwenden möglicherweise noch die alte Einstellung, bis sie neu gestartet werden."

exit 0
