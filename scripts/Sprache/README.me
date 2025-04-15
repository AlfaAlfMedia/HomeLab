# Linux System Locale Konfigurations-Skript (UTF-8)

Ein Bash-Skript zur einfachen Einstellung der System-Locale auf UTF-8 (z.B. `de_DE.UTF-8`) auf Debian-basierten Systemen, um Darstellungsprobleme von Sonderzeichen in Terminals und SSH-Clients zu beheben.

---

## 🤔 Problembeschreibung

Werden Sonderzeichen wie deutsche Umlaute (ä, ö, ü) oder andere internationale Zeichen in deiner SSH-Sitzung (MobaXterm, PuTTY etc.) oder auf der Linux-Konsole nicht korrekt angezeigt? Sie erscheinen vielleicht als Fragezeichen, Leerzeichen oder seltsame Symbole.

Das liegt fast immer an inkonsistenten Zeichenkodierungs-Einstellungen zwischen dem Server (Linux) und deinem SSH-Client. Für eine korrekte Darstellung müssen **beide** Seiten dieselbe Kodierung verwenden – heutzutage ist **UTF-8** der universelle Standard.

Dieses Skript kümmert sich um die **Serverseite**. Die notwendigen Einstellungen im **SSH-Client** musst du danach selbst vornehmen (siehe unten).

---

## ✨ Features & Was das Skript tut

* **Prüft Bestehendes:** Stellt fest, ob die gewünschte UTF-8 Locale bereits korrekt konfiguriert ist und beendet sich dann ohne Änderungen (Idempotent).
* **Installiert Abhängigkeiten:** Sorgt dafür, dass das notwendige `locales`-Paket installiert ist.
* **Konfiguriert Locales:** Aktiviert die gewünschte Locale in `/etc/locale.gen`.
* **Generiert Locales:** Führt `locale-gen` aus, um die Locale-Dateien zu erstellen.
* **Setzt System-Standard:** Macht die gewünschte Locale zum systemweiten Standard (`localectl` oder `update-locale`).
* **Flexibel:** Die gewünschte Locale (z.B. `de_DE.UTF-8`) kann einfach am Anfang des Skripts geändert werden.

---

## ⚙️ Anforderungen

* Ein Debian-basiertes System (Debian, Ubuntu, Raspberry Pi OS, etc.).
* Root-Berechtigungen zur Ausführung.
* Standard-Tools wie `bash`, `grep`, `sed`, `apt-get`, `wget`.
* Internetzugang für `wget` und `apt-get`.

---

## 🚀 Anwendung des Skripts

1.  **Herunterladen / Erstellen:**
    Lade das Skript direkt von GitHub herunter oder erstelle es manuell auf deinem Server, z.B. in `/usr/local/sbin/`.

    * **Mit `wget` herunterladen:**
        ```bash
        sudo wget -O /usr/local/sbin/set_system_locale.sh [https://raw.githubusercontent.com/AlfaAlfMedia/HomeLab/main/scripts/Sprache/set_german_locale.sh](https://raw.githubusercontent.com/AlfaAlfMedia/HomeLab/main/scripts/Sprache/set_german_locale.sh)
        ```
    * **ODER manuell erstellen:**
        ```bash
        sudo nano /usr/local/sbin/set_system_locale.sh
        # Kopiere den Skript-Inhalt von GitHub hier hinein und speichere.
        ```

2.  **Anpassen (Optional):**
    Bearbeite das Skript, falls du eine andere Locale als `de_DE.UTF-8` verwenden möchtest. Ändere die Variable `DESIRED_LOCALE` am Anfang der Datei.
    ```bash
    sudo nano /usr/local/sbin/set_system_locale.sh
    ```

3.  **Ausführbar machen:**
    ```bash
    sudo chmod +x /usr/local/sbin/set_system_locale.sh
    ```

4.  **Als Root ausführen:**
    ```bash
    sudo /usr/local/sbin/set_system_locale.sh
    ```
    Beachte die Ausgaben des Skripts.

5.  **‼️ WICHTIG: Server neu starten oder neu anmelden!**
    Die Änderungen werden erst nach einem **Neustart des Servers** (`sudo reboot`) oder einem **vollständigen Ab- und erneuten Anmelden** per SSH wirksam!

---

## 💻 Wichtig: Konfiguration des SSH-Clients!

Nachdem der Server korrekt konfiguriert ist, muss auch dein SSH-Client auf deinem Computer UTF-8 verwenden.

### Beispiel: MobaXterm

1.  Öffne MobaXterm.
2.  Gehe zu **Settings** -> **Configuration**.
3.  Wähle den Reiter **Terminal**.
4.  Stelle sicher, dass **"Terminal characters set"** auf **`UTF-8`** steht.
5.  Gehe zum Reiter **SSH**.
6.  Stelle sicher, dass **"Use UTF-8 encoding for SSH connections"** **aktiviert** ist.
7.  Klicke **OK**.
8.  **Schließe die bestehende SSH-Sitzung** und öffne sie **neu**.

### Beispiel: PuTTY

1.  Starte PuTTY.
2.  Lade deine gespeicherte Sitzung oder wähle "Default Settings".
3.  Gehe links zu **Window** -> **Translation**.
4.  Wähle bei **"Remote character set"** die Option **`UTF-8`**.
5.  *Empfohlen:* Gehe zurück zu **Session**, wähle die Sitzung erneut aus und klicke **Save**, um die Einstellung zu speichern.
6.  Öffne die Verbindung. Falls sie bereits offen war, **schließe sie und öffne sie neu**.

---

## ✅ Testen

Wenn Server **und** Client konfiguriert sind und die SSH-Sitzung neu gestartet wurde:

1.  Verbinde dich per SSH.
2.  Gib ein: `echo "Test: Äpfel Öffnen Übermut - äöü ÄÖÜ ß €"`
3.  Die Ausgabe sollte nun korrekt sein.

---

*Disclaimer: Dieses Skript ändert Systemkonfigurationen. Benutzung auf eigene Gefahr.*
