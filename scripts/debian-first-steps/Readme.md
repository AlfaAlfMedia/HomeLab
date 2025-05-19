# Linux Container Basis-Setup Skript

Dieses Bash-Skript automatisiert die grundlegende Konfiguration eines neuen Debian- oder Ubuntu-basierten Linux-Containers (oder auch einer Minimal-Installation einer VM). Es führt typische erste Einrichtungsschritte durch, um das System sicherer und benutzerfreundlicher zu machen.

**Wichtiger Hinweis:** Das Skript ist dafür gedacht, mit Root-Rechten ausgeführt zu werden, da es Systemkonfigurationen ändert und Software installiert. Bitte überprüfe den Inhalt des Skripts, bevor du es auf einem System ausführst, um sicherzustellen, dass es deinen Anforderungen entspricht.

## 🚀 Hauptfunktionen

Das Skript führt die folgenden Aktionen aus:

1.  **Benutzererstellung:**
    * Fragt nach einem Benutzernamen.
    * Erstellt diesen Benutzer mit einem Home-Verzeichnis und `/bin/bash` als Shell.
    * Fordert zur interaktiven Passworteingabe für den neuen Benutzer auf.

2.  **Systemaktualisierung und Tool-Installation:**
    * Führt `apt update` und `apt full-upgrade` aus.
    * Installiert eine Auswahl nützlicher Basistools: `curl`, `sudo`, `wget`, `git`, `nano`, `htop`, `dnsutils`, `tcpdump`, `ufw`, `tree`, `net-tools`.

3.  **Gruppenmanagement und Benutzerberechtigungen:**
    * Erstellt die Gruppe `ssh`, falls sie nicht existiert.
    * Fügt den neu erstellten Benutzer den Gruppen `ssh` und `sudo` hinzu.

4.  **SSH-Schlüssel-Autorisierung:**
    * Fragt, ob öffentliche SSH-Schlüssel für den neuen Benutzer hinzugefügt werden sollen.
    * Fragt nach der Anzahl der Schlüssel und den Schlüsseln selbst.
    * Richtet das `~/.ssh`-Verzeichnis und die `authorized_keys`-Datei für den Benutzer ein, setzt die korrekten Berechtigungen und fügt die angegebenen Schlüssel hinzu.

5.  **SSH-Daemon-Konfiguration (`/etc/ssh/sshd_config`):**
    * Erstellt ein Backup der bestehenden `sshd_config`.
    * Stellt sicher, dass folgende Optionen gesetzt sind:
        * `Port 22`
        * `PermitRootLogin no`
        * `PubkeyAuthentication yes`
        * `PasswordAuthentication no` (Deaktiviert Passwort-Logins, SSH-Schlüssel werden vorausgesetzt!)
    * Fügt `AllowGroups ssh` hinzu, um SSH-Logins auf Mitglieder der `ssh`-Gruppe zu beschränken.
    * Überprüft die Syntax der `sshd_config` mit `sshd -t`.

6.  **System-Locale Konfiguration:**
    * Setzt die System-Locale auf `de_DE.UTF-8`.
    * Installiert das `locales`-Paket, falls notwendig.
    * Generiert die Locale und setzt sie als Standard.

7.  **Zeitserver (NTP) Konfiguration:**
    * Konfiguriert `systemd-timesyncd` als NTP-Client.
    * Fragt optional nach der IP-Adresse des Gateways, um diese als primären NTP-Server zu verwenden.
    * Verwendet deutsche Pool-Server (`de.pool.ntp.org`) als Fallback.
    * Startet den `systemd-timesyncd`-Dienst neu und zeigt den Status an.

8.  **System-Zeitzone Konfiguration:**
    * Setzt die System-Zeitzone auf `Europe/Berlin` mittels `timedatectl`.

## 📋 Voraussetzungen

* Ein Debian-basiertes System (z.B. Debian, Ubuntu).
* Ausführung des Skripts mit **Root-Rechten** (z.B. via `sudo`).
* Internetverbindung für Paket-Downloads und NTP-Synchronisation.

## ⚙️ Anwendung

1.  Lade das Skript (`user-ssh-locale-time.sh` - benenne es, wie du möchtest) manuell herunter.

2.  **Ausführbar machen:**
    ```bash
    chmod +x user-ssh-locale-time.sh
    ```

3.  **Als Root ausführen:**
    ```bash
    sudo ./user-ssh-locale-time.sh
    ```

4.  **Interaktive Eingaben:**
    Das Skript wird dich nach folgenden Informationen fragen:
    * Gewünschter Benutzername.
    * Ob SSH-Schlüssel hinzugefügt werden sollen, und falls ja, die Schlüssel selbst.
    * Optional die IP-Adresse deines Gateways für die NTP-Konfiguration.

## ⚠️ Wichtige Hinweise

* **Überprüfung:** Lies das Skript sorgfältig durch, bevor du es ausführst, um sicherzustellen, dass die durchgeführten Aktionen deinen Erwartungen entsprechen.
* **Root-Rechte:** Das Skript benötigt Root-Rechte für die meisten seiner Operationen.
* **SSH-Konfiguration:** Das Skript ändert die `sshd_config`. Es wird ein Backup (`/etc/ssh/sshd_config.backup_DATUM_ZEIT`) erstellt. Die wichtigste Änderung ist die Deaktivierung der Passwort-Authentifizierung (`PasswordAuthentication no`). **Stelle sicher, dass du SSH-Schlüssel für den Benutzer eingerichtet hast und diese funktionieren, bevor du dich ausloggst oder den SSH-Dienst neu startest, da du dich sonst möglicherweise nicht mehr per Passwort anmelden kannst!**
* **Neustart/Neuanmeldung:** Nach Abschluss des Skripts wird ein Neustart des Systems oder zumindest ein Neuladen der Konfiguration für einige Dienste (insbesondere SSH) und eine Neuanmeldung des Benutzers empfohlen, damit alle Änderungen (z.B. Gruppenmitgliedschaften, Locale) wirksam werden.
* **Firewall (UFW):** Das Skript installiert `ufw` (Uncomplicated Firewall), konfiguriert es aber nicht aktiv. Du solltest `ufw` manuell einrichten, um z.B. SSH-Zugriff zu erlauben:
    ```bash
    sudo ufw allow OpenSSH # oder sudo ufw allow 22/tcp
    sudo ufw enable
    sudo ufw status
    ```

## 🔧 Konfigurationsdetails

Das Skript modifiziert unter anderem folgende Dateien und Einstellungen:

* `/etc/passwd`, `/etc/shadow`, `/etc/group` (durch `useradd`, `passwd`, `usermod`)
* `/home/BENUTZERNAME/.ssh/authorized_keys`
* `/etc/ssh/sshd_config`
* `/etc/locale.gen`, `/etc/default/locale` (oder `localectl`-Einstellungen)
* `/etc/systemd/timesyncd.conf.d/10-custom-ntp.conf` (optional)
* Systemzeitzone via `timedatectl`

## 📄 Lizenz

Dieses Projekt steht unter der MIT-Lizenz. Siehe die Datei `LICENSE` für Details.

---

Anregungen und Verbesserungen sind willkommen!
