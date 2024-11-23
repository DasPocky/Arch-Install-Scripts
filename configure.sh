#!/bin/bash

# Farben für schönen Output
GREEN="\033[1;32m"
BLUE="\033[1;34m"
RED="\033[1;31m"
RESET="\033[0m"

# Hilfsfunktionen
success_msg() { echo -e "${GREEN}✔ $1${RESET}"; }
error_msg() { echo -e "${RED}✖ $1${RESET}"; }
prompt_msg() { echo -e "${BLUE}$1${RESET}"; }

# Verfügbare Laufwerke anzeigen und auswählen lassen
select_disk() {
    prompt_msg "Verfügbare Laufwerke:"
    lsblk -d -o NAME,SIZE,TYPE | grep "disk"

    local disk_options=($(lsblk -d -o NAME | grep -v "NAME"))
    local default_disk=${disk_options[0]}

    echo -e "\nWähle ein Laufwerk aus der obigen Liste (Standard: $default_disk):"
    read -rp "Eingabe (z. B. $default_disk): " DISK
    DISK=${DISK:-$default_disk}

    if [[ ! " ${disk_options[@]} " =~ " ${DISK} " ]]; then
        error_msg "Ungültige Auswahl. Bitte erneut ausführen."
        exit 1
    fi
    success_msg "Ausgewähltes Laufwerk: $DISK"
}

# Konfigurationsdatei erstellen
create_config() {
    prompt_msg "Willkommen! Wir erstellen jetzt deine Konfigurationsdatei für die automatisierte Arch Linux Installation."
    echo -e "\nBitte gib die folgenden Informationen ein (Drücke Enter, um den Standardwert zu akzeptieren):\n"

    # Allgemeine Einstellungen
    read -rp "Hostname (Standard: archlinux): " HOSTNAME
    HOSTNAME=${HOSTNAME:-archlinux}

    read -rp "Benutzername (Standard: user): " USERNAME
    USERNAME=${USERNAME:-user}

    read -rp "Zeitzone (Standard: Europe/Berlin): " TIMEZONE
    TIMEZONE=${TIMEZONE:-Europe/Berlin}

    read -rp "Locale (Standard: en_US.UTF-8): " LOCALE
    LOCALE=${LOCALE:-en_US.UTF-8}

    # Festplattenauswahl
    select_disk

    # Dateisystem
    echo -e "\nWähle das Dateisystem für die Installation:"
    select FS in "Btrfs" "ext4"; do
        case $FS in
            Btrfs) FILESYSTEM="btrfs"; break ;;
            ext4) FILESYSTEM="ext4"; break ;;
            *) error_msg "Ungültige Auswahl! Bitte erneut versuchen." ;;
        esac
    done

    # Desktop-Umgebung
    echo -e "\nSoll eine Desktop-Umgebung installiert werden?"
    select DESKTOP_CHOICE in "Ja" "Nein"; do
        case $DESKTOP_CHOICE in
            Ja) INSTALL_DESKTOP=true; break ;;
            Nein) INSTALL_DESKTOP=false; break ;;
            *) error_msg "Ungültige Auswahl! Bitte erneut versuchen." ;;
        esac
    done

    if [ "$INSTALL_DESKTOP" = true ]; then
        echo -e "\nWähle die Desktop-Umgebung:"
        select DE in "GNOME" "KDE" "XFCE"; do
            case $DE in
                GNOME) DESKTOP_ENV="gnome"; break ;;
                KDE) DESKTOP_ENV="kde"; break ;;
                XFCE) DESKTOP_ENV="xfce"; break ;;
                *) error_msg "Ungültige Auswahl! Bitte erneut versuchen." ;;
            esac
        done
    fi

    # Grafiktreiber
    echo -e "\nSoll der NVIDIA-Treiber installiert werden?"
    select NVIDIA_CHOICE in "Ja" "Nein"; do
        case $NVIDIA_CHOICE in
            Ja) INSTALL_NVIDIA=true; break ;;
            Nein) INSTALL_NVIDIA=false; break ;;
            *) error_msg "Ungültige Auswahl! Bitte erneut versuchen." ;;
        esac
    done

    if [ "$INSTALL_NVIDIA" = true ]; then
        echo -e "\nSoll die Intel-GPU deaktiviert werden?"
        select INTEL_CHOICE in "Ja" "Nein"; do
            case $INTEL_CHOICE in
                Ja) DISABLE_INTEL=true; break ;;
                Nein) DISABLE_INTEL=false; break ;;
                *) error_msg "Ungültige Auswahl! Bitte erneut versuchen." ;;
            esac
        done
    fi

    # Repository-URL
    echo -e "\nGib die URL deines privaten GitHub-Repositories ein:"
    read -rp "(Standard: https://github.com/<DEIN_USERNAME>/arch-install-scripts.git): " GITHUB_REPO_URL
    GITHUB_REPO_URL=${GITHUB_REPO_URL:-https://github.com/<DEIN_USERNAME>/arch-install-scripts.git}

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

# Desktop-Einstellungen
INSTALL_DESKTOP=$INSTALL_DESKTOP
DESKTOP_ENV="$DESKTOP_ENV"

# Grafiktreiber
INSTALL_NVIDIA=$INSTALL_NVIDIA
DISABLE_INTEL=$DISABLE_INTEL

# Repository
GITHUB_REPO_URL="$GITHUB_REPO_URL"
EOF

    success_msg "Konfigurationsdatei $CONFIG_FILE wurde erfolgreich erstellt!"
}

# Hauptfunktion
main() {
    echo -e "${GREEN}Start des Konfigurationsassistenten...${RESET}"
    create_config
    echo -e "\nDu kannst die Datei $CONFIG_FILE bei Bedarf manuell bearbeiten."
    success_msg "Die Konfiguration ist abgeschlossen! Fahre mit dem Installationsskript fort."
}

main
