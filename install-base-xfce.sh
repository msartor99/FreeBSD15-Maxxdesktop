#!/bin/sh
# ==============================================================================
# SCRIPT 1: install-base-system.sh
# TARGET OS: FreeBSD 15.0-RELEASE (or later)
# AUTHOR: msartor99
# PURPOSE: Core System Tuning, X11, Graphics, Localization & Boot Aesthetics
# ==============================================================================

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Root privileges required. Please execute this script as root."
    exit 1
fi

BACKTITLE="MaXX Desktop SGI - FreeBSD 15 Workstation Installer"

# --- AUTO-DETECT SYSTEM DEFAULTS ---
SYS_KBD=$(sysrc -n keymap 2>/dev/null | grep -Eo '^[a-z]{2}' || echo "us")
DEFAULT_LANG="en_US.UTF-8"
DEFAULT_X11_KBD="us"

case "$SYS_KBD" in
    fr) DEFAULT_LANG="fr_FR.UTF-8"; DEFAULT_X11_KBD="fr" ;;
    ch) DEFAULT_LANG="fr_CH.UTF-8"; DEFAULT_X11_KBD="ch-fr" ;;
    de) DEFAULT_LANG="de_DE.UTF-8"; DEFAULT_X11_KBD="de" ;;
    uk|gb) DEFAULT_LANG="en_GB.UTF-8"; DEFAULT_X11_KBD="gb" ;;
    es) DEFAULT_LANG="es_ES.UTF-8"; DEFAULT_X11_KBD="es" ;;
    it) DEFAULT_LANG="it_IT.UTF-8"; DEFAULT_X11_KBD="it" ;;
esac

# --- INTERACTIVE INTERFACE (bsddialog) ---
# Disclaimer
MSG_DISCLAIMER="LEGAL DISCLAIMER\n\nThis script deeply modifies your FreeBSD system configuration.\nIt is provided 'as is', without any warranty.\n\nACKNOWLEDGEMENTS\n\nThanks to the Silicon Graphics fandom community for the public domain resources used to enhance the visual boot theme.\n\nDo you accept to proceed?"
if ! bsddialog --backtitle "$BACKTITLE" --title "Warning & Credits" --yesno "$MSG_DISCLAIMER" 16 75; then
    clear; echo "Installation cancelled by user."; exit 1
fi

# 1. Language Selection
USER_LOCALE=$(bsddialog --backtitle "$BACKTITLE" --title "Language & Region" --default-item "$DEFAULT_LANG" --menu "Select your system language and region:" 15 60 8 \
    "en_US.UTF-8" "English (US)" \
    "en_GB.UTF-8" "English (UK)" \
    "fr_FR.UTF-8" "French (France)" \
    "fr_CH.UTF-8" "French (Switzerland)" \
    "de_DE.UTF-8" "German (Germany)" \
    "de_CH.UTF-8" "German (Switzerland)" \
    "es_ES.UTF-8" "Spanish (Spain)" \
    "it_IT.UTF-8" "Italian (Italy)" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then clear; echo "Installation cancelled."; exit 1; fi

# 2. Keyboard Selection
X11_KBD=$(bsddialog --backtitle "$BACKTITLE" --title "Keyboard Layout" --default-item "$DEFAULT_X11_KBD" --menu "Select your X11 Keyboard Layout:" 15 60 8 \
    "us" "US English" \
    "gb" "UK English" \
    "fr" "French (AZERTY)" \
    "ch-fr" "Swiss French (QWERTZ)" \
    "ch-de" "Swiss German (QWERTZ)" \
    "de" "German (QWERTZ)" \
    "es" "Spanish (QWERTY)" \
    "it" "Italian (QWERTY)" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then clear; echo "Installation cancelled."; exit 1; fi

case "$X11_KBD" in
    *-*) XKBLAYOUT="${X11_KBD%%-*}"; XKBVARIANT="${X11_KBD##*-}" ;;
    *)   XKBLAYOUT="$X11_KBD"; XKBVARIANT="" ;;
esac

# 3. Target User Setup
while true; do
    TARGET_USER=$(bsddialog --backtitle "$BACKTITLE" --title "Target User" --inputbox "Enter the target username (who will use MaXX):" 10 60 "administrateur" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ] || [ -z "$TARGET_USER" ]; then clear; echo "Installation cancelled."; exit 1; fi
    if id "$TARGET_USER" >/dev/null 2>&1; then break;
    else bsddialog --backtitle "$BACKTITLE" --title "Error" --msgbox "User '$TARGET_USER' does not exist. Please create the user first." 8 50; fi
done

# 4. GPU Detection
GPU_CHOICE=$(bsddialog --backtitle "$BACKTITLE" --title "GPU Selection" --menu "Select your graphics card vendor:" 12 50 3 \
    1 "AMD" \
    2 "NVIDIA" \
    3 "Intel" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then clear; echo "Installation cancelled."; exit 1; fi

if [ "$GPU_CHOICE" = "2" ]; then
    NV_VER=$(bsddialog --backtitle "$BACKTITLE" --title "NVIDIA Driver Version" --menu "Select the NVIDIA driver branch for FreeBSD 15:" 12 60 3 \
        1 "Latest Production Driver" \
        2 "Legacy 580 Series" \
        3 "Legacy 470 Series (Kepler)" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then clear; echo "Installation cancelled."; exit 1; fi
fi

clear
echo "=========================================================="
echo " Phase 1: Deploying Base Workstation Environment"
echo "=========================================================="

# --- 1. BOOTSTRAP PKG & SERVICES ---
echo "[+] Enabling system daemons..."
sysrc dbus_enable="YES"
sysrc sddm_enable="YES"
sysrc linux_enable="YES"
sysrc rpcbind_enable="YES"
sysrc smartd_enable="YES"

echo "[+] Syncing repository catalogs..."
env ASSUME_ALWAYS_YES=YES pkg bootstrap -f
env ASSUME_ALWAYS_YES=YES pkg update -f

echo "[+] Installing X11 Display Server and Core utilities..."
pkg install -y xorg xprop xorg-apps dbus sddm xfce xfce4-goodies wget bash sudo unzip libzip git htop python3 bashtop smartmontools ImageMagick7 feh

echo "[+] Installing Toolchest Native Utilities..."
pkg install -y xterm xscreensaver xkill xprop xwininfo gnome-system-monitor gnome-screenshot firefox thunderbird vlc xfe

# --- 2. GPU HARDWARE CONFIGURATION ---
echo "[+] Provisioning Graphics Stack..."
case $GPU_CHOICE in
    2)
        KMOD_DRIVER="nvidia-modeset"
        case $NV_VER in
            2) NV_BASE="nvidia-driver-580"; NV_LIN="linux-nvidia-libs-580" ;;
            3) NV_BASE="nvidia-driver-470"; NV_LIN="linux-nvidia-libs-470" ;;
            *) NV_BASE="nvidia-driver"; NV_LIN="linux-nvidia-libs" ;;
        esac
        # Split installs to ensure the main driver succeeds even if optional libs fail
        echo "[+] Installing main NVIDIA driver..."
        pkg install -y "$NV_BASE"
        echo "[+] Installing Linux compatibility libraries and tools (optional)..."
        pkg install -y "$NV_LIN" 2>/dev/null || echo "Warning: $NV_LIN unavailable, skipping."
        pkg install -y nvidia-xconfig 2>/dev/null || echo "Warning: nvidia-xconfig unavailable, skipping."
        
        [ -f /usr/local/bin/nvidia-xconfig ] && nvidia-xconfig
        ;;
    3)
        KMOD_DRIVER="i915kms"
        pkg install -y drm-kmod libva-intel-driver
        ;;
    *)
        KMOD_DRIVER="amdgpu"
        pkg install -y drm-kmod
        ;;
esac

CURRENT_KMODS=$(sysrc -n kld_list)
case "$CURRENT_KMODS" in
    *"$KMOD_DRIVER"*) ;;
    *) sysrc kld_list+="$KMOD_DRIVER" ;;
esac

# --- 3. LINUXULATOR VIRTUAL FILE SYSTEMS ---
echo "[+] Stabilizing Linuxulator subsystem mounts (/etc/fstab)..."
add_fstab() { grep -q "$2" /etc/fstab || printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$1" "$2" "$3" "$4" "$5" "$6" >> /etc/fstab; }
add_fstab "tmpfs"     "/tmp"                 "tmpfs"    "rw,mode=1777" "0" "0"
add_fstab "fdescfs"   "/dev/fd"              "fdescfs"  "rw"           "0" "0"
add_fstab "procfs"    "/proc"                "procfs"   "rw"           "0" "0"
add_fstab "linprocfs" "/compat/linux/proc"   "linprocfs" "rw,late"     "0" "0"
add_fstab "linsysfs"  "/compat/linux/sys"    "linsysfs" "rw,late"      "0" "0"
add_fstab "devfs"     "/compat/linux/dev"    "devfs"    "rw,late"      "0" "0"
mount -a 2>/dev/null

# --- 4. KERNEL TUNING & SILENT BOOT ---
echo "[+] Tuning Kernel parameters and quiet startup sequence..."
sysrc -f /boot/loader.conf boot_mute="YES"
sysrc -f /boot/loader.conf autoboot_delay="3"
sysrc -f /boot/loader.conf tmpfs_load="YES"
sysrc -f /boot/loader.conf aio_load="YES"
sysrc rc_startmsgs="NO"

add_sysctl() { grep -q "^$1" /etc/sysctl.conf || echo "$1=$2" >> /etc/sysctl.conf; sysctl $1=$2 >/dev/null 2>&1; }
add_sysctl "kern.sched.preempt_thresh" "224"
add_sysctl "kern.ipc.shm_allow_removed" "1"
add_sysctl "net.local.stream.recvspace" "65536"
add_sysctl "net.local.stream.sendspace" "65536"

# --- 5. KEYBOARD MAPS GENERATION ---
echo "[+] Locking regional keyboard layouts for X11..."
mkdir -p /usr/local/etc/X11/xorg.conf.d
cat > /usr/local/etc/X11/xorg.conf.d/00-keyboard.conf << EOF
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "$XKBLAYOUT"
        Option "XkbVariant" "$XKBVARIANT"
EndSection
EOF

XSETUP="/usr/local/share/sddm/scripts/Xsetup"
if [ -f "$XSETUP" ] && ! grep -q "setxkbmap" "$XSETUP"; then
    if [ -n "$XKBVARIANT" ]; then
        echo "setxkbmap -layout $XKBLAYOUT -variant $XKBVARIANT" >> "$XSETUP"
    else
        echo "setxkbmap -layout $XKBLAYOUT" >> "$XSETUP"
    fi
fi

# --- 6. SECURITY & ACCOUNT LOCALIZATION ---
echo "[+] Hardening sudoers privileges and user environment classes..."
mkdir -p /usr/local/etc/sudoers.d
echo "%wheel ALL=(ALL) ALL" > /usr/local/etc/sudoers.d/wheel
echo "%wheel ALL=(ALL) NOPASSWD: /sbin/reboot, /sbin/poweroff, /sbin/shutdown" > /usr/local/etc/sudoers.d/power_management
chmod 0440 /usr/local/etc/sudoers.d/wheel /usr/local/etc/sudoers.d/power_management

CLASS_NAME="custom_${USER_LOCALE%%.*}"
sed -i '' "/^${CLASS_NAME}|/,/:tc=default:/d" /etc/login.conf 2>/dev/null
printf "%s|Custom User Class:\n\t:charset=UTF-8:\n\t:lang=%s:\n\t:tc=default:\n" "$CLASS_NAME" "$USER_LOCALE" >> /etc/login.conf
cap_mkdb /etc/login.conf
echo "defaultclass=$CLASS_NAME" > /etc/adduser.conf

pw usermod "$TARGET_USER" -G wheel,operator,video -L "$CLASS_NAME" 2>/dev/null

# --- 7. SGI VISUAL THEME INTEGRATION ---
echo "[+] Deploying SGI Retro Aesthetics (Splash screen and SDDM)..."
IMG_DIR="/boot/images"
mkdir -p "$IMG_DIR"
SGI_WALLPAPER_URL="https://raw.githubusercontent.com/msartor99/FreeBSD15-Maxxdesktop/main/sgi_desktop.jpg"
SGI_MENU_LOGO_URL="https://raw.githubusercontent.com/msartor99/FreeBSD15-Maxxdesktop/main/sgilogo.png"

wget -q -O "$IMG_DIR/sgi_menu_src.png" "$SGI_MENU_LOGO_URL" 2>/dev/null
if [ -f "$IMG_DIR/sgi_menu_src.png" ]; then
    cp "$IMG_DIR/sgi_menu_src.png" "/boot/images/freebsd-brand-rev.png"
    cp "$IMG_DIR/sgi_menu_src.png" "/boot/images/freebsd-brand.png"
fi

wget -q -O "$IMG_DIR/sgi_desktop.jpg" "$SGI_WALLPAPER_URL" 2>/dev/null
if [ -f "$IMG_DIR/sgi_desktop.jpg" ]; then
    /usr/local/bin/magick "$IMG_DIR/sgi_desktop.jpg" -resize 1920x1200^ -gravity center -extent 1920x1200 -alpha set -define png:color-type=6 "png32:$IMG_DIR/sgi_boot.png"
    if [ -f "$IMG_DIR/sgi_boot.png" ]; then
        sysrc -f /boot/loader.conf splash="/boot/images/sgi_boot.png"
    fi
    SDDM_BASE="/usr/local/share/sddm/themes"
    if [ -d "$SDDM_BASE/maldives" ]; then
        rm -rf "$SDDM_BASE/sgi_irix"
        cp -R "$SDDM_BASE/maldives" "$SDDM_BASE/sgi_irix"
        cp "$IMG_DIR/sgi_desktop.jpg" "$SDDM_BASE/sgi_irix/sgi_desktop.jpg"
        sed -i '' "s|^background=.*|background=sgi_desktop.jpg|" "$SDDM_BASE/sgi_irix/theme.conf"
        mkdir -p /usr/local/etc/sddm.conf.d
        cat > /usr/local/etc/sddm.conf.d/10-theme.conf << 'EOF'
[Theme]
Current=sgi_irix
EOF
    fi
fi

echo "=========================================================="
echo " Phase 1 Completed successfully!"
echo " A critical reboot is required to activate the graphics engine."
echo " Execute: 'reboot' and run Script 2 after logging back in."
echo "=========================================================="
