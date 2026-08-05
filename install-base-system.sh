#!/bin/sh
# ==============================================================================
# SCRIPT 1: install-base-system.sh (CORRIGÉ POUR FREEBSD 15.1)
# TARGET OS: FreeBSD 15.1-RELEASE (or later)
# PURPOSE: Core System Tuning, X11, Graphics, Localization & Boot Aesthetics
# ==============================================================================

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Root privileges required. Please execute this script as root."
    exit 1
fi

BACKTITLE="MaXX Desktop SGI - FreeBSD 15.1 Workstation Installer"

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

# --- INTERACTIVE INTERFACE ---
MSG_DISCLAIMER="LEGAL DISCLAIMER\n\nThis script deeply modifies your FreeBSD system configuration.\nIt is provided 'as is', without any warranty.\n\nDo you accept to proceed?"
if ! bsddialog --backtitle "$BACKTITLE" --title "Warning" --yesno "$MSG_DISCLAIMER" 12 75; then
    clear; echo "Installation cancelled by user."; exit 1
fi

USER_LOCALE=$(bsddialog --backtitle "$BACKTITLE" --title "Language & Region" --default-item "$DEFAULT_LANG" --menu "Select your system language and region:" 15 60 8 \
    "en_US.UTF-8" "English (US)" \
    "en_GB.UTF-8" "English (UK)" \
    "fr_FR.UTF-8" "French (France)" \
    "fr_CH.UTF-8" "French (Switzerland)" \
    "de_DE.UTF-8" "German (Germany)" \
    "de_CH.UTF-8" "German (Switzerland)" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then clear; exit 1; fi

X11_KBD=$(bsddialog --backtitle "$BACKTITLE" --title "Keyboard Layout" --default-item "$DEFAULT_X11_KBD" --menu "Select your X11 Keyboard Layout:" 15 60 8 \
    "us" "US English" \
    "fr" "French (AZERTY)" \
    "ch-fr" "Swiss French (QWERTZ)" \
    "ch-de" "Swiss German (QWERTZ)" \
    "de" "German (QWERTZ)" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then clear; exit 1; fi

case "$X11_KBD" in
    *-*) XKBLAYOUT="${X11_KBD%%-*}"; XKBVARIANT="${X11_KBD##*-}" ;;
    *)   XKBLAYOUT="$X11_KBD"; XKBVARIANT="" ;;
esac

while true; do
    TARGET_USER=$(bsddialog --backtitle "$BACKTITLE" --title "Target User" --inputbox "Enter the target username (who will use MaXX):" 10 60 "administrateur" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ] || [ -z "$TARGET_USER" ]; then clear; exit 1; fi
    if id "$TARGET_USER" >/dev/null 2>&1; then break;
    else bsddialog --backtitle "$BACKTITLE" --title "Error" --msgbox "User '$TARGET_USER' does not exist. Please create the user first." 8 50; fi
done

CPU_CHOICE=$(bsddialog --backtitle "$BACKTITLE" --title "CPU Microcode" --menu "Select your processor vendor:" 12 50 2 \
    1 "AMD" \
    2 "Intel" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then clear; exit 1; fi

GPU_CHOICE=$(bsddialog --backtitle "$BACKTITLE" --title "GPU Selection" --menu "Select your graphics card vendor:" 12 50 3 \
    1 "AMD" \
    2 "NVIDIA" \
    3 "Intel" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then clear; exit 1; fi

if [ "$GPU_CHOICE" = "2" ]; then
    NV_VER=$(bsddialog --backtitle "$BACKTITLE" --title "NVIDIA Driver Version" --menu "Select the NVIDIA driver branch:" 12 60 3 \
        1 "Latest Production Driver" \
        2 "Legacy 580 Series" \
        3 "Legacy 470 Series (Kepler)" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then clear; exit 1; fi
fi

SPLASH_RES=$(bsddialog --backtitle "$BACKTITLE" --title "Splash Screen Resolution" --default-item "2560x1440" --menu "Select your monitor's resolution:" 15 60 4 \
    "1920x1080" "Full HD (16:9)" \
    "1920x1200" "WUXGA (16:10)" \
    "2560x1440" "QHD / 2K (16:9) - 27 pouces" \
    "3840x2160" "4K UHD (16:9)" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then SPLASH_RES="1920x1080"; fi

clear
echo "=========================================================="
echo " Phase 1: Deploying Base Workstation Environment"
echo "=========================================================="

echo "[+] Enabling system daemons..."
sysrc dbus_enable="YES"
sysrc sddm_enable="YES"
sysrc linux_enable="YES"
sysrc rpcbind_enable="YES"
sysrc smartd_enable="YES"

echo "[+] Syncing repository catalogs..."
env ASSUME_ALWAYS_YES=YES pkg bootstrap -f
env ASSUME_ALWAYS_YES=YES pkg update -f

# --- SÉCURITÉ TOUT-OU-RIEN : ISOLEMENT DES PAQUETS CRITIQUES ---
echo "[+] 1/3 Installing X11 Core and SDDM (Critical)..."
pkg install -y xorg xprop xorg-apps dbus sddm xfce xfce4-goodies

# COUPE-CIRCUIT : Vérification absolue de la présence de SDDM
if ! pkg info -e sddm >/dev/null 2>&1; then
    echo ""
    echo "====================================================================="
    echo "CRITICAL ERROR: Xorg or SDDM failed to install."
    echo "Script aborted to prevent unbootable black screen."
    echo "====================================================================="
    exit 1
fi

echo "[+] 2/3 Installing Core Utilities and Subsystems..."
pkg install -y wget bash sudo unzip libzip git htop python3 smartmontools feh linux_base-rl9 xterm xscreensaver xkill xwininfo gnome-system-monitor gnome-screenshot firefox thunderbird vlc xfe

echo "[+] 3/3 Installing Variable Utilities..."
pkg install -y ImageMagick7 || pkg install -y ImageMagick6 || true
pkg install -y bashtop || pkg install -y btop || true

echo "[+] Granting video node access..."
pw groupmod video -m sddm
pw groupmod video -m "$TARGET_USER"
pw groupmod operator -m "$TARGET_USER"
pw groupmod wheel -m "$TARGET_USER"

echo "[+] Forcing XFCE Registration for SDDM..."
mkdir -p /usr/local/share/xsessions
cat << 'EOF' > /usr/local/share/xsessions/xfce.desktop
[Desktop Entry]
Name=XFCE (Fallback)
Comment=Environnement de bureau XFCE4 de secours
Exec=/usr/local/bin/startxfce4
Type=Application
EOF

# --- 1.5 CPU MICROCODE ---
echo "[+] Installing CPU microcodes..."
if [ "$CPU_CHOICE" = "1" ]; then
    pkg install -y devcpu-data-amd
    sysrc -f /boot/loader.conf cpu_microcode_load="YES"
    sysrc -f /boot/loader.conf cpu_microcode_name="/boot/firmware/amd-ucode.bin"
else
    pkg install -y devcpu-data-intel
    sysrc -f /boot/loader.conf cpu_microcode_load="YES"
    sysrc -f /boot/loader.conf cpu_microcode_name="/boot/firmware/intel-ucode.bin"
fi
sysrc microcode_update_enable="YES"

# --- 2. GPU CONFIGURATION ---
echo "[+] Provisioning Graphics Stack..."
case $GPU_CHOICE in
    2)
        KMOD_DRIVER="nvidia-modeset"
        case $NV_VER in
            2) NV_BASE="nvidia-driver-580"; NV_LIN="linux-nvidia-libs-580" ;;
            3) NV_BASE="nvidia-driver-470"; NV_LIN="linux-nvidia-libs-470" ;;
            *) NV_BASE="nvidia-driver"; NV_LIN="linux-nvidia-libs" ;;
        esac
        
        kldload -n linux 2>/dev/null
        kldload -n linux64 2>/dev/null
        service linux start >/dev/null 2>&1
        
        pkg install -y "$NV_BASE"
        pkg install -y "$NV_LIN" || true
        pkg install -y nvidia-xconfig
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

# --- 3. LINUXULATOR MOUNTS ---
echo "[+] Stabilizing Linuxulator subsystem mounts..."
add_fstab() { grep -q "$2" /etc/fstab || printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$1" "$2" "$3" "$4" "$5" "$6" >> /etc/fstab; }
add_fstab "tmpfs"      "/tmp"                 "tmpfs"    "rw,mode=1777" "0" "0"
add_fstab "fdescfs"   "/dev/fd"              "fdescfs"  "rw"           "0" "0"
add_fstab "procfs"    "/proc"                "procfs"   "rw"           "0" "0"
add_fstab "linprocfs" "/compat/linux/proc"   "linprocfs" "rw,late"      "0" "0"
add_fstab "linsysfs"  "/compat/linux/sys"    "linsysfs" "rw,late"      "0" "0"
add_fstab "devfs"     "/compat/linux/dev"    "devfs"    "rw,late"      "0" "0"
mount -a 2>/dev/null

# --- 4. KERNEL TUNING & SILENT BOOT ---
echo "[+] Tuning Kernel parameters and quiet startup sequence..."
sysrc -f /boot/loader.conf -x beastie_disable 2>/dev/null || true
sysrc -f /boot/loader.conf -x autoboot_delay 2>/dev/null || true

sysrc -f /boot/loader.conf boot_mute="YES"
sysrc -f /boot/loader.conf boot_verbose="NO"
sysrc -f /boot/loader.conf aio_load="YES"
sysrc rc_startmsgs="NO"

if ! grep -q " > /dev/null" /etc/rc; then
    sed -i '' 's/run_rc_script ${_rc_elem} ${_boot}/run_rc_script ${_rc_elem} ${_boot} > \/dev\/null/g' /etc/rc
fi

add_sysctl() { grep -q "^$1" /etc/sysctl.conf || echo "$1=$2" >> /etc/sysctl.conf; sysctl $1=$2 >/dev/null 2>&1; }
add_sysctl "kern.sched.preempt_thresh" "224"
add_sysctl "kern.ipc.shm_allow_removed" "1"
add_sysctl "net.local.stream.recvspace" "65536"
add_sysctl "net.local.stream.sendspace" "65536"

# --- 5. KEYBOARD MAPS ---
echo "[+] Locking regional keyboard layouts for X11..."
mkdir -p /usr/local/etc/X11/xorg.conf.d
cat > /usr/local/etc/X11/xorg.conf.d/00-keyboard.conf << EOF
Section "ServerFlags"
        Option "DontZap" "false"
EndSection

Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "$XKBLAYOUT"
        Option "XkbVariant" "$XKBVARIANT"
        Option "XkbOptions" "terminate:ctrl_alt_bksp"
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

# --- 6. SECURITY & ACCOUNTS ---
echo "[+] Hardening privileges and classes..."
mkdir -p /usr/local/etc/sudoers.d
echo "%wheel ALL=(ALL) ALL" > /usr/local/etc/sudoers.d/wheel
echo "%wheel ALL=(ALL) NOPASSWD: /sbin/reboot, /sbin/poweroff, /sbin/shutdown" > /usr/local/etc/sudoers.d/power_management
chmod 0440 /usr/local/etc/sudoers.d/wheel /usr/local/etc/sudoers.d/power_management

CLASS_NAME="custom_${USER_LOCALE%%.*}"
sed -i '' "/^${CLASS_NAME}|/,/:tc=default:/d" /etc/login.conf 2>/dev/null
printf "%s|Custom User Class:\n\t:charset=UTF-8:\n\t:lang=%s:\n\t:tc=default:\n" "$CLASS_NAME" "$USER_LOCALE" >> /etc/login.conf
cap_mkdb /etc/login.conf
echo "defaultclass=$CLASS_NAME" > /etc/adduser.conf
pw usermod "$TARGET_USER" -L "$CLASS_NAME" 2>/dev/null

# --- 7. SGI VISUAL THEME INTEGRATION ---
echo "[+] Deploying SGI Retro Aesthetics (Splash screen and SDDM)..."
IMG_DIR="/boot/images"
mkdir -p "$IMG_DIR"

SGI_WALLPAPER_URL="https://raw.githubusercontent.com/msartor99/FreeBSD15-Maxxdesktop/main/sgi_desktop.jpg"
SGI_SPLASH_URL="https://raw.githubusercontent.com/msartor99/FreeBSD15-Maxxdesktop/6dbb056de534d22de825e1876c3e66ae406d723f/SGI_splash.jpg"

wget -q -O "$IMG_DIR/SGI_splash_src.jpg" "$SGI_SPLASH_URL" 2>/dev/null
wget -q -O "$IMG_DIR/sgi_desktop.jpg" "$SGI_WALLPAPER_URL" 2>/dev/null

# IDEMPOTENCE : Purge absolue des vieilles variables graphiques fautives
sysrc -f /boot/loader.conf -x splash_bmp_load 2>/dev/null || true
sysrc -f /boot/loader.conf -x bitmap_load 2>/dev/null || true
sysrc -f /boot/loader.conf -x bitmap_name 2>/dev/null || true
sysrc -f /boot/loader.conf -x bitmap_type 2>/dev/null || true
sysrc -f /boot/loader.conf -x splash_image 2>/dev/null || true
sysrc -f /boot/loader.conf -x efi_max_resolution 2>/dev/null || true
sed -i '' '/kern.vt.fb.default_mode/d' /boot/loader.conf 2>/dev/null || true

if command -v magick >/dev/null 2>&1 && [ -f "$IMG_DIR/SGI_splash_src.jpg" ]; then
    
    # 7.1 Splash Screen (généré une seule fois pour boot & shutdown)
    magick "$IMG_DIR/SGI_splash_src.jpg" -resize ${SPLASH_RES}^ -gravity center -extent ${SPLASH_RES} -alpha set -define png:color-type=6 "png32:$IMG_DIR/SGI_splash.png"
    
    # Configuration stricte pour FreeBSD 15.1
    sysrc -f /boot/loader.conf splash="/boot/images/SGI_splash.png"
    sysrc -f /boot/loader.conf shutdown_splash="/boot/images/SGI_splash.png"
    sysrc splash_changer_enable="YES"
fi

# 7.2 Image de fond pour SDDM
if [ -f "$IMG_DIR/sgi_desktop.jpg" ]; then
    SDDM_BASE="/usr/local/share/sddm/themes"
    
    if [ -d "$SDDM_BASE/maldives" ]; then
        rm -rf "$SDDM_BASE/sgi_irix"
        cp -R "$SDDM_BASE/maldives" "$SDDM_BASE/sgi_irix"
        cp "$IMG_DIR/sgi_desktop.jpg" "$SDDM_BASE/sgi_irix/sgi_desktop.jpg"
        
        sed -i '' -E "s/^[bB]ackground[[:space:]]*=.*/background=sgi_desktop.jpg/" "$SDDM_BASE/sgi_irix/theme.conf"
        
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