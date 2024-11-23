#!/bin/bash

# Farben für schönen Output
GREEN="\033[1;32m"
RED="\033[1;31m"
BLUE="\033[1;34m"
RESET="\033[0m"

# Hilfsfunktionen
success_msg() { echo -e "${GREEN}✔ $1${RESET}"; }
error_exit() { echo -e "${RED}✖ $1${RESET}"; exit 1; }
step_msg() { echo -e "${BLUE}==> $1${RESET}"; }

# Konfigurationsdatei einlesen
CONFIG_FILE="config.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    error_exit "Konfigurationsdatei $CONFIG_FILE wurde nicht gefunden!"
fi
source "$CONFIG_FILE"

# Passwort sicher abfragen
get_password() {
    read -sp "Gib das Passwort für Benutzer $USERNAME und root ein: " PASSWORD
    echo
    read -sp "Bestätige das Passwort: " PASSWORD_CONFIRM
    echo
    if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
        error_exit "Die Passwörter stimmen nicht überein. Bitte erneut ausführen."
    fi
    success_msg "Passwort erfolgreich gesetzt."
}

# Spiegelserver aktualisieren
update_mirrorlist() {
    step_msg "Aktualisiere die Pacman-Spiegelserver für Deutschland (HTTPS)..."
    reflector --country Germany --protocol https --latest 5 --sort rate --save /etc/pacman.d/mirrorlist || error_exit "Fehler beim Aktualisieren der Spiegelserver."
    success_msg "Pacman-Spiegelserver aktualisiert."
}

# Partitionieren und formatieren
partition_disk() {
    step_msg "Partitioniere Festplatte $DISK..."
    wipefs -a "$DISK" || error_exit "Fehler beim Löschen der alten Partitionstabelle."
    parted "$DISK" --script mklabel gpt || error_exit "Fehler beim Erstellen der GPT-Partitionstabelle."
    parted "$DISK" --script mkpart ESP fat32 1MiB 512MiB || error_exit "Fehler beim Erstellen der EFI-Partition."
    parted "$DISK" --script set 1 esp on || error_exit "Fehler beim Setzen der ESP-Markierung."
    parted "$DISK" --script mkpart primary 512MiB 100% || error_exit "Fehler beim Erstellen der Root-Partition."
    success_msg "Partitionierung abgeschlossen."

    if [[ "$DISK" == *nvme* ]]; then
        EFI_PART="${DISK}p1"
        ROOT_PART="${DISK}p2"
    else
        EFI_PART="${DISK}1"
        ROOT_PART="${DISK}2"
    fi

    step_msg "Formatiere Partitionen..."
    mkfs.fat -F32 "$EFI_PART" || error_exit "Fehler beim Formatieren der EFI-Partition."
    if [ "$FILESYSTEM" == "btrfs" ]; then
        mkfs.btrfs -f "$ROOT_PART" || error_exit "Fehler beim Formatieren der Root-Partition als Btrfs."
        success_msg "Root-Partition als Btrfs formatiert."
    else
        mkfs.ext4 "$ROOT_PART" || error_exit "Fehler beim Formatieren der Root-Partition als ext4."
        success_msg "Root-Partition als ext4 formatiert."
    fi
}

# Btrfs-Subvolumes erstellen und mounten
setup_btrfs() {
    if [ "$FILESYSTEM" == "btrfs" ]; then
        step_msg "Erstelle Btrfs-Subvolumes..."
        mount "$ROOT_PART" /mnt || error_exit "Fehler beim Mounten der Root-Partition."
        btrfs subvolume create /mnt/@ || error_exit "Fehler beim Erstellen des @-Subvolumes."
        btrfs subvolume create /mnt/@home || error_exit "Fehler beim Erstellen des @home-Subvolumes."
        btrfs subvolume create /mnt/@snapshots || error_exit "Fehler beim Erstellen des @snapshots-Subvolumes."
        btrfs subvolume create /mnt/@var_log || error_exit "Fehler beim Erstellen des @var_log-Subvolumes."
        umount /mnt

        step_msg "Mount Subvolumes..."
        mount -o noatime,compress=zstd,subvol=@ "$ROOT_PART" /mnt
        mkdir -p /mnt/{boot,home,.snapshots,var/log}
        mount -o noatime,compress=zstd,subvol=@home "$ROOT_PART" /mnt/home
        mount -o noatime,compress=zstd,subvol=@snapshots "$ROOT_PART" /mnt/.snapshots
        mount -o noatime,compress=zstd,subvol=@var_log "$ROOT_PART" /mnt/var/log
        mount "$EFI_PART" /mnt/boot || error_exit "Fehler beim Mounten der EFI-Partition."
        success_msg "Subvolumes gemountet."
    fi
}

# Basissystem installieren
install_base_system() {
    step_msg "Installiere Basissystem und grundlegende Pakete..."
    pacstrap /mnt base linux linux-firmware networkmanager btrfs-progs sudo openssh vim base-devel git || error_exit "Fehler beim Installieren des Basissystems."
    genfstab -U /mnt >> /mnt/etc/fstab || error_exit "Fehler beim Generieren der fstab."
    success_msg "Basissystem und grundlegende Pakete installiert."
}

# Bootloader installieren
install_grub() {
    step_msg "Installiere GRUB-Bootloader..."
    arch-chroot /mnt pacman -S --noconfirm grub efibootmgr intel-ucode amd-ucode || error_exit "Fehler beim Installieren von GRUB und Microcode."
    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB || error_exit "Fehler beim Installieren des GRUB-Bootloaders."
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg || error_exit "Fehler beim Erstellen der GRUB-Konfigurationsdatei."
    success_msg "GRUB-Bootloader erfolgreich installiert."
}

# Grundlegende Systemkonfiguration
configure_system() {
    step_msg "Wechsle ins neue System und führe grundlegende Konfiguration durch..."
    arch-chroot /mnt /bin/bash <<EOF
        ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
        hwclock --systohc
        echo "KEYMAP=de-latin1" > /etc/vconsole.conf
        echo "$HOSTNAME" > /etc/hostname
        echo -e "127.0.0.1   localhost\n::1         localhost\n127.0.1.1   $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts
        sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
        useradd -m -G wheel -s /bin/bash "$USERNAME"
        echo "$USERNAME:$PASSWORD" | chpasswd
        echo "root:$PASSWORD" | chpasswd
        systemctl enable NetworkManager
        systemctl enable sshd
EOF
    success_msg "Systemkonfiguration abgeschlossen."
}

# Hauptfunktion
main() {
    echo -e "${GREEN}Starte automatisierte Arch Linux Installation...${RESET}"
    get_password
    update_mirrorlist
    partition_disk
    if [ "$FILESYSTEM" == "btrfs" ]; then
        setup_btrfs
    fi
    install_base_system
    configure_system
    install_grub
    success_msg "Installation abgeschlossen. Starte das System neu, um das Post-Installationsskript auszuführen."
}

main
