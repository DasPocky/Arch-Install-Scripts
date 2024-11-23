#!/bin/bash

# Farben für schöneren Output
GREEN="\033[1;32m"
RED="\033[1;31m"
BLUE="\033[1;34m"
RESET="\033[0m"

# Hilfsfunktionen
success_msg() { echo -e "${GREEN}✔ $1${RESET}"; }
error_exit() { echo -e "${RED}FEHLER: $1${RESET}"; exit 1; }
step_msg() { echo -e "${BLUE}==> $1${RESET}"; }

# Logging
LOG_FILE="/var/log/arch_post_install.log"
exec > >(tee -a $LOG_FILE) 2>&1

# Konfigurationsdatei einlesen
CONFIG_FILE="${CONFIG_FILE:-/root/arch-install-scripts/config.conf}"
if [ ! -f "$CONFIG_FILE" ]; then
    error_exit "Konfigurationsdatei $CONFIG_FILE wurde nicht gefunden!"
fi
source "$CONFIG_FILE"

# Pacman-Datenbank aktualisieren
update_pacman() {
    step_msg "Aktualisiere Pacman-Datenbank..."
    pacman -Syu --noconfirm || error_exit "Fehler beim Aktualisieren der Pacman-Datenbank. Bitte überprüfe deine Internetverbindung."
    success_msg "Pacman-Datenbank aktualisiert."
}

# NVIDIA-Treiber installieren
install_nvidia_drivers() {
    if [ "$INSTALL_NVIDIA" = true ]; then
        step_msg "Installiere NVIDIA-Treiber..."
        pacman -S --noconfirm nvidia-dkms nvidia-utils lib32-nvidia-utils || error_exit "Fehler beim Installieren der NVIDIA-Treiber."
        
        # Optionale Intel-Deaktivierung
        if [ "$DISABLE_INTEL" = true ]; then
            step_msg "Deaktiviere Intel GPU..."
            echo "blacklist i915" > /etc/modprobe.d/blacklist-intel.conf || error_exit "Fehler beim Blacklisten der Intel-Treiber."
        fi

        success_msg "NVIDIA-Treiber installiert."
    fi
}

# GNOME-Desktop installieren
install_gnome() {
    if [ "$INSTALL_DESKTOP" = true ] && [ "$DESKTOP_ENV" = "gnome" ]; then
        step_msg "Installiere GNOME-Desktop..."
        pacman -S --noconfirm gnome gdm xorg || error_exit "Fehler beim Installieren von GNOME."
        
        # Wayland deaktivieren, falls NVIDIA verwendet wird
        if [ "$INSTALL_NVIDIA" = true ]; then
            sed -i 's/#WaylandEnable=false/WaylandEnable=false/' /etc/gdm/custom.conf || error_exit "Fehler beim Konfigurieren von GDM."
        else
            sed -i 's/WaylandEnable=false/#WaylandEnable=false/' /etc/gdm/custom.conf || error_exit "Fehler beim Zurücksetzen von GDM."
        fi
        
        systemctl enable gdm || error_exit "Fehler beim Aktivieren von GDM."
        success_msg "GNOME-Desktop installiert und GDM aktiviert."
    fi
}

# Cleanup
cleanup() {
    step_msg "Entferne Post-Installationsskript und zugehörigen Service..."
    systemctl disable --now post-install.service || error_exit "Fehler beim Deaktivieren des Post-Installationsdienstes."
    rm -f /root/arch-install-scripts/post_install.sh
    rm -f /etc/systemd/system/post-install.service
    success_msg "Post-Installationsskript und Systemd-Service entfernt."
}

# Hauptfunktion
main() {
    echo -e "${GREEN}Starte Post-Installationsskript...${RESET}"
    update_pacman
    install_nvidia_drivers
    install_gnome
    cleanup
    success_msg "Post-Installation abgeschlossen! Bitte starte dein System neu."
}

main
