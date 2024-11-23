#!/bin/bash

# Überprüfen, ob das Skript als root ausgeführt wird
if [ "$(id -u)" -ne 0 ]; then
    echo "Das Skript benötigt root-Berechtigungen. Starte es mit sudo neu..."
    exec sudo "$0" "$@"
    exit 0
fi

# Überprüfen, ob dialog installiert ist
if ! command -v dialog &>/dev/null; then
    echo "Das Paket 'dialog' ist nicht installiert. Installiere es zuerst mit 'pacman -S dialog'."
    exit 1
fi

# Hilfsfunktionen für Dialoge
get_input() {
    dialog --title "$1" --inputbox "$2" 10 60 "$3" 2>&1 >/dev/tty
}

get_password() {
    dialog --title "$1" --passwordbox "$2" 10 60 2>&1 >/dev/tty
}

get_choice() {
    local title="$1"
    shift
    local options=("$@")
    local menu=()
    for i in "${!options[@]}"; do
        menu+=("$i" "${options[i]}")
    done
    dialog --title "$title" --menu "Wähle eine Option:" 15 60 8 "${menu[@]}" 2>&1 >/dev/tty
}

get_yes_no() {
    dialog --title "$1" --yesno "$2" 10 60
}

# Zeitzonenauswahl
select_timezone() {
    local timezones=("Europe/Berlin" "America/New_York" "Asia/Tokyo" "UTC")
    local index
    index=$(get_choice "Zeitzonenauswahl" "${timezones[@]}") || exit 1
    echo "${timezones[index]}"
}

# Locale-Auswahl
select_locale() {
    local locales=("de_DE.UTF-8" "en_US.UTF-8")
    local index
    index=$(get_choice "Locale-Auswahl" "${locales[@]}") || exit 1
    echo "${locales[index]}"
}

# Festplattenauswahl (nur Hauptplatten, keine Partitionen)
select_disk() {
    local disks=($(lsblk -dn -o NAME,TYPE | awk '$2 == "disk" {print $1}'))
    local menu=()
    for disk in "${disks[@]}"; do
        size=$(lsblk -dn -o SIZE "/dev/$disk")
        menu+=("$disk" "$disk ($size)")
    done
    get_choice "Festplattenauswahl" "${menu[@]}"
}

# WLAN-SSID auswählen
select_wlan() {
    iwctl station wlan0 scan >/dev/null 2>&1
    sleep 2

    # SSIDs erfassen und filtern
    local ssids=($(iwctl station wlan0 get-networks | awk -F '  +' '/[^\s]/ {if (NR>3) print $1}' | sort -u | sed '/^\s*$/d'))
    if [ ${#ssids[@]} -eq 0 ]; then
        dialog --title "WLAN-Auswahl" --msgbox "Keine WLAN-Netzwerke gefunden." 10 60
        return 1
    fi

    # Erstelle ein Menü mit nummerierten Optionen
    local menu=()
    for ssid in "${ssids[@]}"; do
        menu+=("$ssid" "$ssid")
    done

    get_choice "WLAN-Netzwerk auswählen" "${menu[@]}"
}

# Konfigurationsdatei erstellen
create_config() {
    CONFIG_FILE="config.conf"

    # Benutzerinformationen
    HOSTNAME=$(get_input "Hostname" "Gib den Hostnamen ein:" "archlinux") || exit 1
    USERNAME=$(get_input "Benutzername" "Gib den Benutzernamen ein:" "user") || exit 1

    # Zeitzone und Locale
    TIMEZONE=$(select_timezone)
    LOCALE=$(select_locale)

    # Festplatte
    DISK=$(select_disk)

    # Dateisystem
    local filesystems=("Btrfs" "ext4" "xfs")
    FILESYSTEM=${filesystems[$(get_choice "Dateisystem-Auswahl" "${filesystems[@]}")]} || exit 1

    # WLAN
    if get_yes_no "WLAN-Konfiguration" "Soll WLAN konfiguriert werden?"; then
        SSID=$(select_wlan) || exit 1
        WLAN_PASSWORD=$(get_password "WLAN-Passwort" "Gib das Passwort für $SSID ein:") || exit 1
    else
        SSID=""
        WLAN_PASSWORD=""
    fi

    # Desktop-Umgebung
    local desktop_envs=("GNOME" "KDE" "XFCE" "MATE" "Keine")
    DESKTOP_ENV=${desktop_envs[$(get_choice "Desktop-Umgebung" "${desktop_envs[@]}")]} || exit 1

    # NVIDIA-Treiber
    if get_yes_no "NVIDIA-Treiber" "Soll der NVIDIA-Treiber installiert werden?"; then
        INSTALL_NVIDIA=true
        if get_yes_no "Intel GPU deaktivieren" "Soll die Intel-GPU deaktiviert werden?"; then
            DISABLE_INTEL=true
        else
            DISABLE_INTEL=false
        fi
    else
        INSTALL_NVIDIA=false
        DISABLE_INTEL=false
    fi

    # GitHub-Repository
    GITHUB_REPO_URL=$(get_input "GitHub-Repository" "Gib die URL deines privaten GitHub-Repositories ein:" "https://github.com/<DEIN_USERNAME>/arch-install-scripts.git") || exit 1

    # Konfigurationsdatei schreiben
    cat <<EOF > $CONFIG_FILE
# config.conf - Automatisch generierte Konfigurationsdatei

# Allgemeine Einstellungen
HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME"
TIMEZONE="$TIMEZONE"
LOCALE="$LOCALE"
DISK="/dev/$DISK"
FILESYSTEM="$FILESYSTEM"

# WLAN-Optionen
SSID="$SSID"
WLAN_PASSWORD="$WLAN_PASSWORD"

# Desktop-Einstellungen
DESKTOP_ENV="$DESKTOP_ENV"

# Grafiktreiber
INSTALL_NVIDIA=$INSTALL_NVIDIA
DISABLE_INTEL=$DISABLE_INTEL

# Repository
GITHUB_REPO_URL="$GITHUB_REPO_URL"
EOF

    dialog --title "Konfiguration abgeschlossen" --msgbox "Die Konfigurationsdatei wurde erfolgreich erstellt: $CONFIG_FILE" 10 60
}

# Hauptfunktion
main() {
    dialog --title "Arch Linux Installer" --msgbox "Willkommen beim Arch Linux Installer-Konfigurationsassistenten!" 10 60
    create_config
    dialog --title "Fertig" --msgbox "Die Konfiguration ist abgeschlossen! Du kannst jetzt mit der Installation fortfahren." 10 60
}

main
