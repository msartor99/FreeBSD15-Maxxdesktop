#!/bin/sh
# ==============================================================================
# UNIFIED SCRIPT : install-freebsd-maxx.sh (COMPLETE, RESILIENT & IDEMPOTENT)
# TARGET OS      : FreeBSD 15.1-RELEASE (POSIX /bin/sh)
# PURPOSE        : Base Workstation, X11, GPU, SDDM & MaXX Interactive Desktop 2.2
# REPO           : https://github.com/msartor99/FreeBSD15-Maxxdesktop
# ==============================================================================

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Root privileges required. Please execute this script as root."
    exit 1
fi

BACKTITLE="MaXX Desktop SGI - FreeBSD 15.1 Workstation Installer"

# Resilient atomic package installer (prevents bulk pkg transaction rollbacks)
install_pkgs() {
    for pkg_name in "$@"; do
        if pkg info -e "$pkg_name" >/dev/null 2>&1; then
            echo "   [OK] $pkg_name is already installed."
        else
            printf "   [+] Installing %s... " "$pkg_name"
            if env ASSUME_ALWAYS_YES=YES pkg install -y "$pkg_name" >/dev/null 2>&1; then
                echo "OK"
            else
                echo "SKIPPED (not available in repository)"
            fi
        fi
    done
}

# ==============================================================================
# 0. AUTO-DETECTION & INTERACTIVE WIZARD (BSDDIALOG)
# ==============================================================================
SYS_KBD=$(sysrc -n keymap 2>/dev/null | grep -Eo '^[a-z]{2}' || echo "ch")
DEFAULT_LANG="fr_CH.UTF-8"
DEFAULT_X11_KBD="ch-fr"

case "$SYS_KBD" in
    fr) DEFAULT_LANG="fr_FR.UTF-8"; DEFAULT_X11_KBD="fr" ;;
    ch) DEFAULT_LANG="fr_CH.UTF-8"; DEFAULT_X11_KBD="ch-fr" ;;
    de) DEFAULT_LANG="de_DE.UTF-8"; DEFAULT_X11_KBD="de" ;;
    uk|gb) DEFAULT_LANG="en_GB.UTF-8"; DEFAULT_X11_KBD="gb" ;;
    es) DEFAULT_LANG="es_ES.UTF-8"; DEFAULT_X11_KBD="es" ;;
    it) DEFAULT_LANG="it_IT.UTF-8"; DEFAULT_X11_KBD="it" ;;
    us) DEFAULT_LANG="en_US.UTF-8"; DEFAULT_X11_KBD="us" ;;
esac

MSG_DISCLAIMER="LEGAL DISCLAIMER\n\nThis script deeply configures your FreeBSD 15.1 system (Kernel, X11, GPU, Linuxulator, SDDM, and MaXX Interactive Desktop v2.2.0).\nIt is 100% idempotent and provided 'as is', without any warranty.\n\nDo you accept to proceed?"
if ! bsddialog --backtitle "$BACKTITLE" --title "Warning" --yesno "$MSG_DISCLAIMER" 13 75; then
    clear
    echo "Installation cancelled by user."
    exit 1
fi

USER_LOCALE=$(bsddialog --backtitle "$BACKTITLE" --title "Language & Region" --default-item "$DEFAULT_LANG" --menu "Select your system language and region:" 15 65 6 \
    "en_US.UTF-8" "English (US)" \
    "en_GB.UTF-8" "English (UK)" \
    "fr_CH.UTF-8" "French (Switzerland)" \
    "fr_FR.UTF-8" "French (France)" \
    "de_DE.UTF-8" "German (Germany)" \
    "de_CH.UTF-8" "German (Switzerland)" 3>&1 1>&2 2>&3) || { clear; exit 1; }

X11_KBD=$(bsddialog --backtitle "$BACKTITLE" --title "Keyboard Layout" --default-item "$DEFAULT_X11_KBD" --menu "Select your X11 Keyboard Layout:" 14 65 5 \
    "us"    "US English (QWERTY)" \
    "ch-fr" "Swiss French (QWERTZ)" \
    "ch-de" "Swiss German (QWERTZ)" \
    "fr"    "French (AZERTY)" \
    "de"    "German (QWERTZ)" 3>&1 1>&2 2>&3) || { clear; exit 1; }

case "$X11_KBD" in
    *-*) XKBLAYOUT="${X11_KBD%%-*}"; XKBVARIANT="${X11_KBD##*-}" ;;
    *)   XKBLAYOUT="$X11_KBD"; XKBVARIANT="" ;;
esac

while true; do
    TARGET_USER=$(bsddialog --backtitle "$BACKTITLE" --title "Target User" --inputbox "Enter the target username (who will use MaXX Desktop):" 10 65 "administrateur" 3>&1 1>&2 2>&3) || { clear; exit 1; }
    if [ -n "$TARGET_USER" ] && id "$TARGET_USER" >/dev/null 2>&1; then
        break
    else
        bsddialog --backtitle "$BACKTITLE" --title "Error" --msgbox "User '$TARGET_USER' does not exist. Please create the user first." 8 55
    fi
done

USER_HOME=$(pw usershow "$TARGET_USER" | awk -F: '{print $9}')
[ -z "$USER_HOME" ] && USER_HOME="/home/${TARGET_USER}"

CPU_CHOICE=$(bsddialog --backtitle "$BACKTITLE" --title "CPU Microcode" --default-item "2" --menu "Select your processor vendor:" 11 55 2 \
    "1" "AMD" \
    "2" "Intel (Xeon / Core)" 3>&1 1>&2 2>&3) || { clear; exit 1; }

GPU_CHOICE=$(bsddialog --backtitle "$BACKTITLE" --title "GPU Selection" --default-item "2" --menu "Select your graphics card vendor:" 12 55 3 \
    "1" "AMD (amdgpu)" \
    "2" "NVIDIA (Proprietary)" \
    "3" "Intel (i915kms)" 3>&1 1>&2 2>&3) || { clear; exit 1; }

NV_VER="3"
if [ "$GPU_CHOICE" = "2" ]; then
    NV_VER=$(bsddialog --backtitle "$BACKTITLE" --title "NVIDIA Driver Version" --default-item "3" --menu "Select the NVIDIA driver branch:" 12 65 3 \
        "1" "Latest Production Driver" \
        "2" "Legacy 580 Series" \
        "3" "Legacy 470 Series (Quadro M4000 / Maxwell / Kepler)" 3>&1 1>&2 2>&3) || { clear; exit 1; }
fi

SPLASH_RES=$(bsddialog --backtitle "$BACKTITLE" --title "Monitor Resolution" --default-item "2560x1440" --menu "Select your monitor's native resolution:" 14 65 4 \
    "1920x1080" "Full HD (16:9)" \
    "1920x1200" "WUXGA (16:10)" \
    "2560x1440" "QHD / 2K (16:9 - 27 inch)" \
    "3840x2160" "4K UHD (16:9)" 3>&1 1>&2 2>&3) || SPLASH_RES="2560x1440"

clear
echo "=============================================================================="
echo " FULL DEPLOYMENT : BASE WORKSTATION & MAXX INTERACTIVE DESKTOP v2.2.0"
echo " Target User : $TARGET_USER | Locale : $USER_LOCALE | Keyboard : $XKBLAYOUT $XKBVARIANT"
echo "=============================================================================="

# ==============================================================================
# 1. SYSTEM DAEMONS, PKG REPOSITORIES & XORG / SDDM FAIL-SAFE
# ==============================================================================
echo "-> [1/15] Enabling system daemons and syncing pkg repositories..."
sysrc dbus_enable="YES"
sysrc sddm_enable="YES"
sysrc linux_enable="YES"
sysrc linux_mounts_enable="YES"
sysrc rpcbind_enable="YES"
sysrc smartd_enable="YES"
sysrc cupsd_enable="YES"

env ASSUME_ALWAYS_YES=YES pkg bootstrap -f
env ASSUME_ALWAYS_YES=YES pkg update -f

echo "-> [2/15] Installing critical X11 core, SDDM, and XFCE (Fallback)..."
install_pkgs xorg xprop xorg-apps dbus sddm xfce xfce4-goodies

if ! pkg info -e sddm >/dev/null 2>&1; then
    echo "CRITICAL ERROR: Xorg or SDDM failed to install. Aborting to prevent black screen."
    exit 1
fi

mkdir -p /usr/local/share/xsessions
cat << 'EOF' > /usr/local/share/xsessions/xfce.desktop
[Desktop Entry]
Name=XFCE (Fallback)
Comment=Fallback XFCE4 Desktop Environment
Exec=/usr/local/bin/startxfce4
Type=Application
EOF

# ==============================================================================
# 2. X11/SGI FONTS, SYSTEM UTILITIES & TOOLCHEST APPLICATIONS (ISOLATED)
# ==============================================================================
echo "-> [3/15] Installing X11/Motif fonts, system utilities, and desktop applications..."

# 2.1 X11, SGI & UTF-8 Fonts
install_pkgs \
    xorg-fonts font-alias font-misc-misc font-bh-75dpi font-bh-100dpi \
    font-bh-lucidatypewriter-75dpi font-bh-lucidatypewriter-100dpi \
    font-adobe-75dpi font-adobe-100dpi font-ibm-type1 font-dec-misc \
    font-sun-misc font-cursor-misc dejavu noto-basic noto-sans

# 2.2 X11 Tools, tradcpp preprocessor, and hardware/system utilities
install_pkgs \
    tradcpp xrdb xset xsetroot xwininfo xkill setxkbmap xhost xclock xfontsel xcalc \
    mkfontscale mkfontdir feh dunst alttab scrot xterm xscreensaver \
    wget curl bash sudo unzip libzip git htop btop python3 smartmontools \
    mesa-demos dmidecode pciutils usbutils shared-mime-info

if ! pkg info -e ImageMagick7 >/dev/null 2>&1 && ! pkg info -e ImageMagick6 >/dev/null 2>&1; then
    pkg install -y ImageMagick7 || pkg install -y ImageMagick6 || true
fi

# 2.3 Desktop, Office, Web, Multimedia, Printing & System Applications
install_pkgs \
    firefox thunderbird vlc pavucontrol dsbmixer ristretto mousepad thunar xfe \
    gnome-system-monitor xpdf atril-lite atril gimp inkscape dia libreoffice \
    galculator gucharmap catfish gnome-screenshot xfce4-screenshooter-plugin \
    filezilla octopkg system-config-printer cups cups-filters print-manager

service dbus restart 2>/dev/null || service dbus start 2>/dev/null || true
service cupsd restart 2>/dev/null || service cupsd start 2>/dev/null || true

# ==============================================================================
# 3. CPU MICROCODE, GPU DRIVERS & LINUXULATOR (ROCKY LINUX 9)
# ==============================================================================
echo "-> [4/15] Configuring CPU microcode, GPU drivers, and Linuxulator..."
if [ "$CPU_CHOICE" = "1" ]; then
    install_pkgs cpu-microcode-amd
    sysrc -f /boot/loader.conf cpu_microcode_load="YES"
    sysrc -f /boot/loader.conf cpu_microcode_name="/boot/firmware/amd-ucode.bin"
else
    install_pkgs cpu-microcode-intel
    sysrc -f /boot/loader.conf cpu_microcode_load="YES"
    sysrc -f /boot/loader.conf cpu_microcode_name="/boot/firmware/intel-ucode.bin"
fi
sysrc microcode_update_enable="YES"

# Idempotent fstab mounts for Linuxulator and /tmp
add_fstab() {
    grep -qE "[[:space:]]$2[[:space:]]" /etc/fstab || printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$1" "$2" "$3" "$4" "$5" "$6" >> /etc/fstab
}
add_fstab "tmpfs"      "/tmp"                 "tmpfs"     "rw,mode=1777" "0" "0"
add_fstab "fdescfs"    "/dev/fd"              "fdescfs"   "rw"           "0" "0"
add_fstab "procfs"     "/proc"                "procfs"    "rw"           "0" "0"
add_fstab "linprocfs"  "/compat/linux/proc"   "linprocfs" "rw,late"      "0" "0"
add_fstab "linsysfs"   "/compat/linux/sys"    "linsysfs"  "rw,late"      "0" "0"
add_fstab "devfs"      "/compat/linux/dev"    "devfs"     "rw,late"      "0" "0"

kldload -n linux 2>/dev/null || true
kldload -n linux64 2>/dev/null || true
service linux start 2>/dev/null || true
mount -a 2>/dev/null || true

NV_LIN=""
case "$GPU_CHOICE" in
    2)
        KMOD_DRIVER="nvidia-modeset"
        case "$NV_VER" in
            2) NV_BASE="nvidia-driver-580"; NV_LIN="linux-nvidia-libs-580" ;;
            3) NV_BASE="nvidia-driver-470"; NV_LIN="linux-nvidia-libs-470" ;;
            *) NV_BASE="nvidia-driver";     NV_LIN="linux-nvidia-libs" ;;
        esac
        install_pkgs "$NV_BASE" nvidia-settings nvidia-xconfig
        [ -x /usr/local/bin/nvidia-xconfig ] && /usr/local/bin/nvidia-xconfig >/dev/null 2>&1 || true
        ;;
    3)
        KMOD_DRIVER="i915kms"
        install_pkgs drm-kmod libva-intel-driver
        ;;
    *)
        KMOD_DRIVER="amdgpu"
        install_pkgs drm-kmod
        ;;
esac

CURRENT_KMODS=$(sysrc -n kld_list 2>/dev/null || echo "")
case " $CURRENT_KMODS " in
    *" $KMOD_DRIVER "*) ;;
    *) sysrc kld_list+="$KMOD_DRIVER" ;;
esac

install_pkgs \
    linux_base-rl9 \
    linux-rl9-xorg-libs \
    linux-rl9-libjpeg-turbo \
    linux-rl9-libpng \
    linux-rl9-freetype \
    linux-rl9-fontconfig \
    linux-rl9-gtk2 \
    linux-rl9-gtk3 \
    linux-rl9-gdk-pixbuf2 \
    linux-rl9-pango \
    linux-rl9-cairo \
    linux-rl9-harfbuzz \
    linux-rl9-atk \
    linux-rl9-alsa-lib \
    linux-rl9-dbus-libs \
    linux-rl9-libGLU \
    linux-rl9-libglvnd \
    linux-rl9-motif

[ -n "$NV_LIN" ] && install_pkgs "$NV_LIN"

# ==============================================================================
# 4. KERNEL TUNING, X11 KEYBOARD, USER GROUPS & SUDO PRIVILEGES
# ==============================================================================
echo "-> [5/15] Tuning kernel sysctl parameters, X11 keyboard, and user privileges..."
sysrc -f /boot/loader.conf aio_load="YES"
sysrc rc_startmsgs="NO"

if ! grep -q " > /dev/null" /etc/rc; then
    sed -i '' 's/run_rc_script ${_rc_elem} ${_boot}/run_rc_script ${_rc_elem} ${_boot} > \/dev\/null/g' /etc/rc
fi

add_sysctl() {
    if grep -q "^$1=" /etc/sysctl.conf; then
        sed -i '' "s|^$1=.*|$1=$2|" /etc/sysctl.conf
    else
        echo "$1=$2" >> /etc/sysctl.conf
    fi
    sysctl "$1=$2" >/dev/null 2>&1 || true
}
add_sysctl "kern.sched.preempt_thresh" "224"
add_sysctl "kern.ipc.shm_allow_removed" "1"
add_sysctl "net.local.stream.recvspace" "65536"
add_sysctl "net.local.stream.sendspace" "65536"

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
if [ -f "$XSETUP" ]; then
    sed -i '' '/setxkbmap/d' "$XSETUP"
    if [ -n "$XKBVARIANT" ]; then
        echo "/usr/local/bin/setxkbmap -layout $XKBLAYOUT -variant $XKBVARIANT" >> "$XSETUP"
    else
        echo "/usr/local/bin/setxkbmap -layout $XKBLAYOUT" >> "$XSETUP"
    fi
fi

pw groupmod video -m sddm 2>/dev/null || true
pw groupmod video -m "$TARGET_USER" 2>/dev/null || true
pw groupmod operator -m "$TARGET_USER" 2>/dev/null || true
pw groupmod wheel -m "$TARGET_USER" 2>/dev/null || true
pw groupmod cups -m "$TARGET_USER" 2>/dev/null || true

mkdir -p /usr/local/etc/sudoers.d
echo "%wheel ALL=(ALL) ALL" > /usr/local/etc/sudoers.d/wheel
cat > /usr/local/etc/sudoers.d/power_and_maxx << 'EOF'
%wheel ALL=(ALL) NOPASSWD: /sbin/reboot, /sbin/poweroff, /sbin/shutdown, /usr/local/bin/octopkg, /usr/local/bin/system-config-printer
EOF
chmod 0440 /usr/local/etc/sudoers.d/wheel /usr/local/etc/sudoers.d/power_and_maxx

CLASS_NAME="custom_${USER_LOCALE%%.*}"
sed -i '' "/^${CLASS_NAME}|/,/:tc=default:/d" /etc/login.conf 2>/dev/null || true
printf "%s|Custom User Class:\n\t:charset=UTF-8:\n\t:lang=%s:\n\t:tc=default:\n" "$CLASS_NAME" "$USER_LOCALE" >> /etc/login.conf
cap_mkdb /etc/login.conf
echo "defaultclass=$CLASS_NAME" > /etc/adduser.conf
pw usermod "$TARGET_USER" -L "$CLASS_NAME" 2>/dev/null || true

# ==============================================================================
# 5. UNIFYING /TMP & LINUXULATOR COMPATIBILITY LINKS (NCURSES V5)
# ==============================================================================
echo "-> [6/15] Unifying /compat/linux/tmp, /usr/tmp -> /tmp, and ncurses symlinks..."
rm -rf /compat/linux/tmp /compat/linux/usr/tmp /usr/tmp
ln -shf /tmp /compat/linux/tmp
ln -shf /tmp /compat/linux/usr/tmp
ln -shf /tmp /usr/tmp
chmod 1777 /tmp
ln -shf /usr/local /compat/linux/usr/local

if [ ! -s /compat/linux/etc/machine-id ]; then
    /bin/uuidgen > /compat/linux/etc/machine-id
fi

ln -sf libtinfo.so.6 /compat/linux/usr/lib64/libtinfo.so.5
ln -sf libncurses.so.6 /compat/linux/usr/lib64/libncurses.so.5

# ==============================================================================
# 6. DOWNLOADING (WITH CACHE) & EXTRACTING MAXX DESKTOP OCTANE 2.2.0
# ==============================================================================
echo "-> [7/15] Verifying and extracting MaXX Desktop Octane 2.2.0..."
MAXX_FILENAME="MaXX-Desktop-v2.2.0-LINUX-x86_64-tar.gz"
MAXX_TAR="${USER_HOME}/${MAXX_FILENAME}"
MAXX_URL="https://s3.ca-central-1.amazonaws.com/cdn.maxxinteractive.com/maxx-desktop-installer/${MAXX_FILENAME}"

mkdir -p /compat/linux/opt /opt

if [ -f "/root/${MAXX_FILENAME}" ] && [ ! -f "$MAXX_TAR" ]; then
    cp -f "/root/${MAXX_FILENAME}" "$MAXX_TAR"
fi

if [ -f "$MAXX_TAR" ] && [ ! -s "$MAXX_TAR" ]; then
    rm -f "$MAXX_TAR"
fi

if [ ! -f "$MAXX_TAR" ]; then
    echo "   Downloading ${MAXX_FILENAME} (233 MB)..."
    wget -c -O "$MAXX_TAR" "$MAXX_URL" || fetch -o "$MAXX_TAR" "$MAXX_URL"
    chown "${TARGET_USER}:${TARGET_USER}" "$MAXX_TAR"
fi

if [ ! -x /compat/linux/opt/MaXX/bin64/5Dwm ]; then
    echo "   Extracting MaXX Desktop into /compat/linux/opt/MaXX..."
    rm -rf /compat/linux/opt/MaXX /opt/MaXX
    tar -xzf "$MAXX_TAR" -C /compat/linux/opt
fi
ln -shf /compat/linux/opt/MaXX /opt/MaXX

# ==============================================================================
# 7. SGI SPLASH SCREENS (UEFI BOOT, SGILOGO, SDDM THEME & DESKTOP WALLPAPER)
# ==============================================================================
echo "-> [8/15] Calibrating SGI visuals (UEFI Boot, sgilogo.png, SDDM, and Wallpaper at ${SPLASH_RES})..."
IMG_DIR="/boot/images"
GITHUB_RAW_15="https://raw.githubusercontent.com/msartor99/FreeBSD15-Maxxdesktop/main"
GITHUB_RAW_LEGACY="https://raw.githubusercontent.com/msartor99/FreeBSD-Maxxdesktop/main"
mkdir -p "$IMG_DIR"

# Idempotent backup of original freebsd-logo-rev.png (executed only once)
if [ -f "$IMG_DIR/freebsd-logo-rev.png" ] && [ ! -f "$IMG_DIR/freebsd-logo-rev.png.bak" ]; then
    cp -p "$IMG_DIR/freebsd-logo-rev.png" "$IMG_DIR/freebsd-logo-rev.png.bak"
fi

for repo_api in \
    "https://api.github.com/repos/msartor99/FreeBSD15-Maxxdesktop/contents" \
    "https://api.github.com/repos/msartor99/FreeBSD-Maxxdesktop/contents"; do
    curl -s "$repo_api" | grep '"download_url"' | cut -d'"' -f4 | grep -iE "\.jpg|\.png" | while read -r img_url; do
        fname=$(basename "$img_url")
        [ ! -s "$IMG_DIR/$fname" ] && fetch -q -o "$IMG_DIR/$fname" "$img_url" 2>/dev/null || true
    done
done

# Explicit download of sgilogo.png from GitHub
if [ ! -s "$IMG_DIR/sgilogo.png" ]; then
    fetch -q -o "$IMG_DIR/sgilogo.png" "${GITHUB_RAW_15}/sgilogo.png" 2>/dev/null || \
    fetch -q -o "$IMG_DIR/sgilogo.png" "${GITHUB_RAW_LEGACY}/sgilogo.png" 2>/dev/null || \
    wget -q -O "$IMG_DIR/sgilogo.png" "${GITHUB_RAW_15}/sgilogo.png" 2>/dev/null || true
fi

if [ ! -s "$IMG_DIR/SGI_splash.jpg" ]; then
    fetch -q -o "$IMG_DIR/SGI_splash.jpg" "${GITHUB_RAW_15}/SGI_splash.jpg" 2>/dev/null || \
    fetch -q -o "$IMG_DIR/SGI_splash.jpg" "${GITHUB_RAW_LEGACY}/SGI_splash.jpg" 2>/dev/null || \
    fetch -q -o "$IMG_DIR/SGI_splash.jpg" "https://raw.githubusercontent.com/msartor99/FreeBSD15-Maxxdesktop/6dbb056de534d22de825e1876c3e66ae406d723f/SGI_splash.jpg" 2>/dev/null || true
fi

if [ ! -s "$IMG_DIR/sgi_desktop_orig.jpg" ]; then
    if [ -s "$IMG_DIR/sgi_desktop.jpg" ]; then
        cp -f "$IMG_DIR/sgi_desktop.jpg" "$IMG_DIR/sgi_desktop_orig.jpg"
    else
        fetch -q -o "$IMG_DIR/sgi_desktop_orig.jpg" "${GITHUB_RAW_15}/sgi_desktop.jpg" 2>/dev/null || \
        fetch -q -o "$IMG_DIR/sgi_desktop_orig.jpg" "${GITHUB_RAW_LEGACY}/sgi_desktop.jpg" 2>/dev/null || true
    fi
fi

IM_CMD=""
if [ -x /usr/local/bin/magick ]; then
    IM_CMD="/usr/local/bin/magick"
elif [ -x /usr/local/bin/convert ]; then
    IM_CMD="/usr/local/bin/convert"
fi

if [ -n "$IM_CMD" ]; then
    if [ -s "$IMG_DIR/SGI_splash.jpg" ]; then
        "$IM_CMD" "$IMG_DIR/SGI_splash.jpg" \
            -resize "${SPLASH_RES}^" -gravity center -extent "${SPLASH_RES}" \
            -strip -depth 8 -alpha set -define png:color-type=6 \
            "png32:$IMG_DIR/sgi_splash.png"
        cp -f "$IMG_DIR/sgi_splash.png" "$IMG_DIR/SGI_splash.png"
    fi

    if [ -s "$IMG_DIR/sgi_desktop_orig.jpg" ]; then
        "$IM_CMD" "$IMG_DIR/sgi_desktop_orig.jpg" \
            -resize "${SPLASH_RES}^" -gravity center -extent "${SPLASH_RES}" \
            "$IMG_DIR/sgi_desktop.jpg"
    elif [ -s "$IMG_DIR/SGI_splash.jpg" ]; then
        "$IM_CMD" "$IMG_DIR/SGI_splash.jpg" \
            -resize "${SPLASH_RES}^" -gravity center -extent "${SPLASH_RES}" \
            "$IMG_DIR/sgi_desktop.jpg"
    fi
fi

# Replace freebsd-logo-rev.png with sgilogo.png (fallback to sgi_splash.png)
if [ -s "$IMG_DIR/sgilogo.png" ]; then
    cp -f "$IMG_DIR/sgilogo.png" "$IMG_DIR/freebsd-logo-rev.png"
    chmod 644 "$IMG_DIR/freebsd-logo-rev.png"
elif [ -s "$IMG_DIR/sgi_splash.png" ]; then
    cp -f "$IMG_DIR/sgi_splash.png" "$IMG_DIR/freebsd-logo-rev.png"
    chmod 644 "$IMG_DIR/freebsd-logo-rev.png"
fi

# Configure SDDM Theme SGI_IRIX
if [ -s "$IMG_DIR/sgi_desktop.jpg" ]; then
    SDDM_BASE="/usr/local/share/sddm/themes"
    if [ -d "$SDDM_BASE/maldives" ]; then
        rm -rf "$SDDM_BASE/sgi_irix"
        cp -R "$SDDM_BASE/maldives" "$SDDM_BASE/sgi_irix"
        cp -f "$IMG_DIR/sgi_desktop.jpg" "$SDDM_BASE/sgi_irix/sgi_desktop.jpg"
        cp -f "$IMG_DIR/sgi_desktop.jpg" "$SDDM_BASE/sgi_irix/background.jpg"
        chmod 644 "$SDDM_BASE/sgi_irix/sgi_desktop.jpg" "$SDDM_BASE/sgi_irix/background.jpg"
        sed -i '' -E "s/^[bB]ackground[[:space:]]*=.*/background=sgi_desktop.jpg/" "$SDDM_BASE/sgi_irix/theme.conf"

        mkdir -p /usr/local/etc/sddm.conf.d
        cat > /usr/local/etc/sddm.conf.d/10-theme.conf << 'EOF'
[Theme]
Current=sgi_irix
EOF
    fi
fi

# Idempotent cleanup and setup of /boot/loader.conf
for old_var in splash_bmp_load bitmap_load bitmap_name bitmap_type splash_image efi_max_resolution autoboot_delay; do
    sysrc -f /boot/loader.conf -x "$old_var" 2>/dev/null || true
done
sed -i '' '/kern.vt.fb.default_mode/d' /boot/loader.conf 2>/dev/null || true

sysrc -f /boot/loader.conf boot_mute="YES"
sysrc -f /boot/loader.conf boot_verbose="NO"
sysrc -f /boot/loader.conf beastie_disable="YES"
sysrc -f /boot/loader.conf loader_logo="none"
sysrc -f /boot/loader.conf splash="/boot/images/sgi_splash.png"
sysrc -f /boot/loader.conf shutdown_splash="/boot/images/sgi_splash.png"
sysrc splash_changer_enable="YES"

# ==============================================================================
# 8. LDCONFIG, GDK-PIXBUF, MIME CACHES & ELF BRANDING (BRANDELF LINUX)
# ==============================================================================
echo "-> [9/15] Configuring ldconfig, GDK-Pixbuf, MIME caches, and Linux ELF branding..."
mkdir -p /compat/linux/etc/ld.so.conf.d
printf "/opt/MaXX/lib64\n/opt/MaXX/lib\n" > /compat/linux/etc/ld.so.conf.d/maxx.conf
/compat/linux/sbin/ldconfig 2>/dev/null || chroot /compat/linux /sbin/ldconfig 2>/dev/null || true

mkdir -p /compat/linux/usr/share/mime
cp -af /usr/local/share/mime/* /compat/linux/usr/share/mime/ 2>/dev/null || true
chroot /compat/linux /usr/bin/update-mime-database /usr/share/mime 2>/dev/null || true
chroot /compat/linux /usr/bin/gdk-pixbuf-query-loaders-64 --update-cache 2>/dev/null || true

find /compat/linux/opt/MaXX/bin64 /compat/linux/opt/MaXX/bin /compat/linux/opt/MaXX/lib64 \
    -type f ! -name "*.sh" ! -name "*.py" ! -name "*.pl" ! -name "*.conf" ! -name "*.ad" 2>/dev/null | while read -r f; do
    if file -b "$f" 2>/dev/null | grep -q "^ELF "; then
        brandelf -t Linux "$f" 2>/dev/null || true
    fi
done

# ==============================================================================
# 9. SYSTEM BRIDGES, HINV HARDWARE PROBES, SGI FONTS & TRADCPP
# ==============================================================================
echo "-> [10/15] Creating system bridges, SGI hardware probes, and tradcpp links..."
mkdir -p /compat/linux/usr/bin /compat/linux/usr/sbin /compat/linux/bin /compat/linux/lib

chflags noschg /usr/bin/cpp 2>/dev/null || true
if [ -f /usr/bin/cpp ] && [ ! -L /usr/bin/cpp ]; then
    mv -f /usr/bin/cpp /usr/bin/cpp.clang.bak 2>/dev/null || true
fi
ln -sf /usr/local/bin/tradcpp /usr/bin/cpp
ln -sf /usr/local/bin/tradcpp /lib/cpp
rm -f /compat/linux/lib/cpp /compat/linux/usr/bin/cpp /compat/linux/bin/cpp
ln -sf /usr/local/bin/tradcpp /compat/linux/lib/cpp
ln -sf /usr/local/bin/tradcpp /compat/linux/usr/bin/cpp
ln -sf /usr/local/bin/tradcpp /compat/linux/bin/cpp

for xtool in xrdb xset xsetroot xprop xwininfo xkill setxkbmap xhost feh; do
    rm -f "/compat/linux/usr/bin/$xtool" "/compat/linux/bin/$xtool"
    if [ -x "/usr/local/bin/$xtool" ]; then
        ln -sf "/usr/local/bin/$xtool" "/compat/linux/usr/bin/$xtool"
    fi
done

ln -sf /compat/linux/bin/bash      /bin/bash
ln -sf /usr/bin/killall            /compat/linux/usr/bin/killall
ln -sf /usr/bin/which              /compat/linux/usr/bin/which
ln -sf /usr/local/bin/nvidia-smi   /usr/bin/nvidia-smi
ln -sf /usr/local/bin/nvidia-smi   /compat/linux/usr/bin/nvidia-smi
ln -sf /usr/local/sbin/dmidecode   /compat/linux/usr/sbin/dmidecode
ln -sf /usr/local/sbin/dmidecode   /compat/linux/usr/bin/dmidecode
ln -sf /usr/local/bin/lspci        /compat/linux/usr/bin/lspci
ln -sf /usr/local/sbin/lsusb       /compat/linux/usr/bin/lsusb
ln -sf /compat/linux/opt/MaXX/bin64/xosview2 /xosview2
ln -sf /compat/linux/opt/MaXX/bin64/xconfirm /xconfirm

for mbin in background iconcatalog fm; do
    if [ -x "/compat/linux/opt/MaXX/bin64/$mbin" ]; then
        ln -sf "/compat/linux/opt/MaXX/bin64/$mbin" "/$mbin"
        ln -sf "/compat/linux/opt/MaXX/bin64/$mbin" "/usr/local/bin/$mbin"
    fi
done

mkdir -p /compat/linux/usr/share/fonts
ln -shf /usr/local/share/fonts/dejavu /compat/linux/usr/share/fonts/dejavu
ln -shf /usr/local/share/fonts/noto   /compat/linux/usr/share/fonts/noto
if [ -d /compat/linux/opt/MaXX/share/fonts ]; then
    for fdir in /compat/linux/opt/MaXX/share/fonts/*; do
        if [ -d "$fdir" ]; then
            /usr/local/bin/mkfontscale "$fdir" 2>/dev/null || true
            /usr/local/bin/mkfontdir "$fdir" 2>/dev/null || true
        fi
    done
fi

# ==============================================================================
# 10. SGI RED CURSOR (redSGI) & PRE-COMPILING INDIGOMAGIC THEME
# ==============================================================================
echo "-> [11/15] Installing redSGI cursor theme and pre-compiling IndigoMagic resources..."
mkdir -p /usr/local/share/icons /usr/local/share/icons/default /usr/local/share/themes
mkdir -p /compat/linux/usr/share/icons /compat/linux/usr/share/themes

if [ -d /compat/linux/opt/MaXX/share/icons ]; then
    cp -af /compat/linux/opt/MaXX/share/icons/* /usr/local/share/icons/ 2>/dev/null || true
    cp -af /compat/linux/opt/MaXX/share/icons/* /compat/linux/usr/share/icons/ 2>/dev/null || true
fi
if [ -d /compat/linux/opt/MaXX/share/themes ]; then
    cp -af /compat/linux/opt/MaXX/share/themes/* /usr/local/share/themes/ 2>/dev/null || true
    cp -af /compat/linux/opt/MaXX/share/themes/* /compat/linux/usr/share/themes/ 2>/dev/null || true
fi

printf "[Icon Theme]\nName=Default\nComment=Default SGI Cursor Theme\nInherits=redSGI\n" > /usr/local/share/icons/default/index.theme

sed -i '' 's/\*darkScheme:.*/\*darkScheme: FALSE/g' /compat/linux/opt/MaXX/etc/Xdefaults.d/* "${USER_HOME}/.maxxdesktop/Xdefaults.d/"* 2>/dev/null || true

if [ ! -f /compat/linux/opt/MaXX/share/X11/schemes/Base/Base.orig ]; then
    cp -af /compat/linux/opt/MaXX/share/X11/schemes/Base/Base \
           /compat/linux/opt/MaXX/share/X11/schemes/Base/Base.orig
fi

cat > /tmp/compile_base.xrm << 'EOF'
#define GAMMA_1_7
#define USE_COLORS
#define USE_SPACING
#define USE_FONTS
#include "/opt/MaXX/share/X11/schemes/Base/FontPalette"
#include "/opt/MaXX/share/X11/schemes/IndigoMagic/BaseColorPalette"
#include "/opt/MaXX/share/X11/schemes/Base/Base.orig"
EOF
/usr/local/bin/tradcpp -P /tmp/compile_base.xrm > /compat/linux/opt/MaXX/share/X11/schemes/Base/Base 2>/dev/null || true
rm -f /tmp/compile_base.xrm

mkdir -p /compat/linux/opt/MaXX/share/X11/app-defaults
cat > /tmp/build_sgi_theme.xrm << 'EOF'
#define GAMMA_1_7
#define USE_COLORS
#define USE_SPACING
#define USE_FONTS
#include "/opt/MaXX/share/X11/schemes/Base/FontPalette"
#include "/opt/MaXX/share/X11/schemes/IndigoMagic/BaseColorPalette"
#include "/opt/MaXX/share/X11/schemes/Base/Base.orig"
#include "/opt/MaXX/etc/Xdefaults.d/Xdefaults.init"
#include "/opt/MaXX/etc/Xdefaults.d/Xdefaults.classic"
#include "/opt/MaXX/etc/Xdefaults.d/Xdefaults.bitmapFont"
#include "/opt/MaXX/etc/Xdefaults.d/Xdefaults.5dwm"
#include "/opt/MaXX/etc/Xdefaults.d/Xdefaults.toolchest"
EOF
/usr/local/bin/tradcpp -P /tmp/build_sgi_theme.xrm > /compat/linux/opt/MaXX/share/X11/app-defaults/SgiIndigoMagic.ad 2>/dev/null || true
rm -f /tmp/build_sgi_theme.xrm

cat >> /compat/linux/opt/MaXX/share/X11/app-defaults/SgiIndigoMagic.ad << 'EOF'
*scheme: IndigoMagic
*darkScheme: FALSE
*chest_orientation: XmVERTICAL
*modernLookandFeel: false
*desktopStyle: Classic
*smoothText: false
5Dwm*keyboardFocusPolicy: pointer
*background: #c1c1c1
*foreground: #000000
*basicBackground: #c1c1c1
*textForeground: #000000
*textBackground: #8e8e8e
*buttonBackground: #999999
*scrollBarTroughColor: #999999
*scrollBarControlBackground: #999999
*topShadowColor: #e1e1e1
*bottomShadowColor: #4c4c4c
*selectColor: #8e8e8e
*highlightColor: #c1c1c1
*armColor: #8e8e8e
*troughColor: #8e8e8e
Toolchest*background: #c1c1c1
Toolchest*foreground: #000000
Toolchest*XmPushButton*background: #c1c1c1
Toolchest*XmPushButton*foreground: #000000
Toolchest*XmCascadeButton*background: #c1c1c1
Toolchest*XmCascadeButton*foreground: #000000
Toolchest*XmLabel*background: #c1c1c1
Toolchest*XmLabel*foreground: #000000
Toolchest*XmRowColumn*background: #c1c1c1
Toolchest*XmRowColumn*foreground: #000000
Toolchest*XmSeparator*background: #c1c1c1
5Dwm*background: #c1c1c1
5Dwm*foreground: #000000
5Dwm*topShadowColor: #e1e1e1
5Dwm*bottomShadowColor: #4c4c4c
5Dwm*selectColor: #8e8e8e
5Dwm*menu*background: #c1c1c1
5Dwm*menu*foreground: #000000
5Dwm*menu*topShadowColor: #e1e1e1
5Dwm*menu*bottomShadowColor: #4c4c4c
5Dwm*menu*XmPushButton*background: #c1c1c1
5Dwm*menu*XmPushButton*foreground: #000000
5Dwm*menu*XmCascadeButton*background: #c1c1c1
5Dwm*menu*XmCascadeButton*foreground: #000000
5Dwm*menu*XmLabel*background: #c1c1c1
5Dwm*menu*XmLabel*foreground: #000000
5Dwm*menu*XmSeparator*background: #c1c1c1
5Dwm*feedback*background: #c1c1c1
5Dwm*feedback*foreground: #000000
5Dwm*icon*background: #c1c1c1
5Dwm*icon*foreground: #000000
5DWm*background: #c1c1c1
5DWm*foreground: #000000
5DWm*menu*background: #c1c1c1
5DWm*menu*foreground: #000000
Mwm*background: #c1c1c1
Mwm*foreground: #000000
Mwm*menu*background: #c1c1c1
Mwm*menu*foreground: #000000
xconfirm*background: #c1c1c1
xconfirm*foreground: #000000
xconfirm*topShadowColor: #e1e1e1
xconfirm*bottomShadowColor: #4c4c4c
xconfirm*XmForm*background: #c1c1c1
xconfirm*XmForm*foreground: #000000
xconfirm*XmLabel*background: #c1c1c1
xconfirm*XmLabel*foreground: #000000
xconfirm*XmPushButton*background: #999999
xconfirm*XmPushButton*foreground: #000000
xconfirm*XmText*background: #c1c1c1
xconfirm*XmText*foreground: #000000
xconfirm*XmTextField*background: #c1c1c1
xconfirm*XmTextField*foreground: #000000
Xconfirm*background: #c1c1c1
Xconfirm*foreground: #000000
*XmDialogShell*background: #c1c1c1
*XmDialogShell*foreground: #000000
*XmMessageBox*background: #c1c1c1
*XmMessageBox*foreground: #000000
Toolchest*fontList: -*-helvetica-bold-o-normal-*-14-*-*-*-*-*-iso8859-1
*fontList: -*-helvetica-medium-r-normal-*-12-*-*-*-*-*-iso8859-1
EOF

# ==============================================================================
# 11. NATIVE FREEBSD APPLICATION WRAPPERS & SGI SYSTEM TOOLS
# ==============================================================================
echo "-> [12/15] Generating unconditional FreeBSD application wrappers and SGI tools..."

for su_gui in qt-sudo gksu gksudo kdesu pkexec; do
    if [ -x "/usr/local/bin/$su_gui" ] && [ ! -f "/usr/local/bin/${su_gui}.orig" ]; then
        mv -f "/usr/local/bin/$su_gui" "/usr/local/bin/${su_gui}.orig"
    fi
    cat > "/usr/local/bin/$su_gui" << 'EOF'
#!/bin/sh
while [ $# -gt 0 ]; do
    case "$1" in
        -d|-u|--user|--description|-m|--message) shift 2 ;;
        -*) shift ;;
        *) break ;;
    esac
done
exec /usr/local/bin/sudo -E "$@"
EOF
    chmod +x "/usr/local/bin/$su_gui"
done

create_wrapper() {
    NAME="$1"
    TARGET_CMD="$2"
    rm -f "/compat/linux/opt/MaXX/bin64/$NAME" "/compat/linux/usr/bin/$NAME" "/usr/local/bin/$NAME" "/$NAME" 2>/dev/null || true
    cat > "/compat/linux/opt/MaXX/bin64/$NAME" << EOF
#!/bin/sh
unset LD_LIBRARY_PATH
unset LD_PRELOAD
unset GIO_MODULE_DIR
unset GTK_PATH
unset GDK_PIXBUF_MODULE_FILE
unset GDK_PIXBUF_MODULEDIR
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin"
exec $TARGET_CMD "\$@" >/dev/null 2>&1 &
EOF
    chmod +x "/compat/linux/opt/MaXX/bin64/$NAME"
    ln -sf "/compat/linux/opt/MaXX/bin64/$NAME" "/compat/linux/usr/bin/$NAME"
    ln -sf "/compat/linux/opt/MaXX/bin64/$NAME" "/$NAME"
}

XPDF_BIN="/usr/local/bin/xpdf"
[ ! -x "$XPDF_BIN" ] && [ -x /usr/local/libexec/xpdf/xpdf ] && XPDF_BIN="/usr/local/libexec/xpdf/xpdf"
[ ! -x "$XPDF_BIN" ] && XPDF_BIN="/usr/local/bin/atril"

if [ -x /usr/local/bin/xfce4-screenshooter ]; then
    SCREENSHOT_CMD="/usr/local/bin/xfce4-screenshooter"
elif [ -x /usr/local/bin/gnome-screenshot ]; then
    SCREENSHOT_CMD="/usr/local/bin/gnome-screenshot -i"
else
    SCREENSHOT_CMD="/usr/local/bin/scrot -s"
fi

create_wrapper "WEBBROWSER"       "/usr/local/bin/firefox"
create_wrapper "EMAILCLIENT"      "/usr/local/bin/thunderbird"
create_wrapper "MAIL"             "/usr/local/bin/thunderbird"
create_wrapper "gnome-calendar"   "/usr/local/bin/thunderbird -calendar"
create_wrapper "MEDIAVIEWER"      "/usr/local/bin/vlc"
create_wrapper "AUDIOPLAYER"      "/usr/local/bin/vlc"
create_wrapper "FILEBROWSER"      "/usr/local/bin/thunar"
create_wrapper "TEXTEDITOR"       "/usr/local/bin/mousepad"
create_wrapper "IMGVIEWER"        "/usr/local/bin/ristretto"
create_wrapper "IMAGEEDITOR"      "/usr/local/bin/gimp"
create_wrapper "IMGEDITOR"        "/usr/local/bin/gimp"
create_wrapper "VECTOREDITOR"     "/usr/local/bin/inkscape"
create_wrapper "PDFVIEWER"        "$XPDF_BIN"
create_wrapper "screenshot"       "$SCREENSHOT_CMD"
create_wrapper "gnome-screenshot" "$SCREENSHOT_CMD"
create_wrapper "gftp"             "/usr/local/bin/filezilla"
create_wrapper "pavucontrol"      "/usr/local/bin/dsbmixer"
create_wrapper "xmmix"            "/usr/local/bin/dsbmixer"
create_wrapper "gvu"              "/usr/local/bin/pavucontrol"
create_wrapper "grecord"          "/usr/local/bin/pavucontrol"
create_wrapper "Restart"          "/usr/local/bin/sudo /sbin/reboot"
create_wrapper "Shutdown"         "/usr/local/bin/sudo /sbin/poweroff"

# Unconditional wrappers for binaries invoked directly by system.chestrc
for bin_app in xclock xfontsel dia thunderbird firefox vlc gimp inkscape; do
    rm -f "/compat/linux/usr/bin/$bin_app" "/compat/linux/opt/MaXX/bin64/$bin_app"
    cat > "/compat/linux/opt/MaXX/bin64/$bin_app" << EOF
#!/bin/sh
unset LD_LIBRARY_PATH
unset LD_PRELOAD
unset GIO_MODULE_DIR
unset GTK_PATH
unset GDK_PIXBUF_MODULE_FILE
unset GDK_PIXBUF_MODULEDIR
export PATH="/usr/local/bin:/usr/bin:/bin"
exec /usr/local/bin/$bin_app "\$@" >/dev/null 2>&1 &
EOF
    chmod +x "/compat/linux/opt/MaXX/bin64/$bin_app"
    ln -sf "/compat/linux/opt/MaXX/bin64/$bin_app" "/compat/linux/usr/bin/$bin_app"
done

LO_BIN="/usr/local/bin/libreoffice"
[ ! -x "$LO_BIN" ] && [ -x /usr/local/lib/libreoffice/program/soffice ] && LO_BIN="/usr/local/lib/libreoffice/program/soffice"
rm -f /compat/linux/usr/bin/libreoffice /compat/linux/opt/MaXX/bin64/libreoffice
cat > /compat/linux/opt/MaXX/bin64/libreoffice << EOF
#!/bin/sh
unset LD_LIBRARY_PATH
unset LD_PRELOAD
unset GIO_MODULE_DIR
unset GTK_PATH
unset GDK_PIXBUF_MODULE_FILE
unset GDK_PIXBUF_MODULEDIR
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin"
export HOME="\${HOME:-${USER_HOME}}"
export SAL_USE_VCLPLUGIN="gen"
exec $LO_BIN "\$@" >/dev/null 2>&1 &
EOF
chmod +x /compat/linux/opt/MaXX/bin64/libreoffice
ln -sf /compat/linux/opt/MaXX/bin64/libreoffice /compat/linux/usr/bin/libreoffice
ln -sf /compat/linux/opt/MaXX/bin64/libreoffice /libreoffice

cat > /compat/linux/opt/MaXX/bin64/launch_gnome_app << 'EOF'
#!/bin/sh
unset LD_LIBRARY_PATH
unset LD_PRELOAD
unset GIO_MODULE_DIR
unset GTK_PATH
unset GDK_PIXBUF_MODULE_FILE
unset GDK_PIXBUF_MODULEDIR
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin"

/usr/local/bin/xhost +SI:localuser:root >/dev/null 2>&1 || true

APP="$1"
shift

case "$APP" in
    gnome-software)
        if [ -x /usr/local/bin/octopkg ]; then
            exec /usr/local/bin/octopkg "$@" >/dev/null 2>&1 &
        else
            exec /compat/linux/opt/MaXX/bin64/adminterm >/dev/null 2>&1 &
        fi
        ;;
    gnome-control-center)
        if [ "$1" = "printers" ]; then
            if [ -x /usr/local/bin/system-config-printer ]; then
                exec /usr/local/bin/system-config-printer >/dev/null 2>&1 &
            elif [ -x /usr/local/bin/firefox ]; then
                exec /usr/local/bin/firefox "http://localhost:631" >/dev/null 2>&1 &
            else
                exec /usr/local/bin/xdg-open "http://localhost:631" >/dev/null 2>&1 &
            fi
        else
            exec /usr/local/bin/nvidia-settings >/dev/null 2>&1 &
        fi
        ;;
    gnome-calculator)
        if [ -x /usr/local/bin/galculator ]; then
            exec /usr/local/bin/galculator "$@" >/dev/null 2>&1 &
        else
            exec /usr/local/bin/xcalc "$@" >/dev/null 2>&1 &
        fi
        ;;
    gnome-character-map)
        exec /usr/local/bin/gucharmap "$@" >/dev/null 2>&1 &
        ;;
    gnome-search-tool)
        exec /usr/local/bin/catfish "$@" >/dev/null 2>&1 &
        ;;
    gnome-system-log)
        exec /usr/local/bin/xterm \
            -name adminterm -class adminterm-color \
            -title "System Log (/var/log/messages)" \
            -geometry 110x32 -bg "#1e2638" -fg "#ffffff" \
            -sb -rightbar -sl 5000 \
            -fn "-*-lucidatypewriter-medium-r-normal-*-14-*-*-*-*-*-iso8859-1" \
            -e "/usr/bin/tail -n 200 -f /var/log/messages" &
        ;;
    *)
        exec "$APP" "$@" >/dev/null 2>&1 &
        ;;
esac
EOF
chmod +x /compat/linux/opt/MaXX/bin64/launch_gnome_app
ln -sf /compat/linux/opt/MaXX/bin64/launch_gnome_app /usr/local/bin/launch_gnome_app
ln -sf /compat/linux/opt/MaXX/bin64/launch_gnome_app /compat/linux/usr/bin/launch_gnome_app
ln -sf /compat/linux/opt/MaXX/bin64/launch_gnome_app /launch_gnome_app

printf "#!/bin/sh\nexit 0\n" > /compat/linux/opt/MaXX/bin64/sound
chmod +x /compat/linux/opt/MaXX/bin64/sound

cat > /compat/linux/opt/MaXX/bin64/winterm << EOF
#!/bin/sh
unset LD_LIBRARY_PATH
unset LD_PRELOAD
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:/opt/MaXX/bin64"
export LANG="${USER_LOCALE}"
exec /usr/local/bin/xterm \\
    -name winterm -class winterm-color \\
    -title "UNIX Shell (\$(whoami)@\$(hostname -s))" \\
    -geometry 100x32 \\
    -bg "#1e2638" -fg "#ffffff" -cr "#ff0000" \\
    -sb -rightbar -sl 5000 \\
    -fn "-*-lucidatypewriter-medium-r-normal-*-14-*-*-*-*-*-iso8859-1" &
EOF
chmod +x /compat/linux/opt/MaXX/bin64/winterm
cp -af /compat/linux/opt/MaXX/bin64/winterm /compat/linux/opt/MaXX/bin64/Console
cp -af /compat/linux/opt/MaXX/bin64/winterm /compat/linux/opt/MaXX/bin64/TERMINAL

cat > /compat/linux/opt/MaXX/bin64/adminterm << EOF
#!/bin/sh
unset LD_LIBRARY_PATH
unset LD_PRELOAD
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:/opt/MaXX/bin64"
export LANG="${USER_LOCALE}"
exec /usr/local/bin/xterm \\
    -name adminterm -class adminterm-color \\
    -title "ADMIN ROOT SHELL (root@\$(hostname -s))" \\
    -geometry 100x32 \\
    -bg "#4a151b" -fg "#ffffff" -cr "#ffff00" \\
    -sb -rightbar -sl 5000 \\
    -fn "-*-lucidatypewriter-medium-r-normal-*-14-*-*-*-*-*-iso8859-1" \\
    -e /usr/local/bin/sudo -i &
EOF
chmod +x /compat/linux/opt/MaXX/bin64/adminterm
cp -af /compat/linux/opt/MaXX/bin64/adminterm /compat/linux/opt/MaXX/bin64/RootConsole

for term_cmd in winterm Console TERMINAL adminterm RootConsole; do
    ln -sf "/compat/linux/opt/MaXX/bin64/$term_cmd" "/usr/local/bin/$term_cmd"
    ln -sf "/compat/linux/opt/MaXX/bin64/$term_cmd" "/$term_cmd"
done

cat > /compat/linux/opt/MaXX/bin64/tellsystem << 'EOF'
#!/compat/linux/bin/bash
export MAXX_BIN="/opt/MaXX/bin64"
export PATH="/opt/MaXX/bin64:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:$PATH"
HINV_OUT=$("$MAXX_BIN/hinv" 2>/dev/null)
"$MAXX_BIN/xconfirm" -c -icon info -t "$HINV_OUT" -header HINV >/dev/null 2>&1 &
EOF
chmod +x /compat/linux/opt/MaXX/bin64/tellsystem

cat > /compat/linux/opt/MaXX/bin64/tellversion << 'EOF'
#!/compat/linux/bin/bash
env -u LD_LIBRARY_PATH /usr/local/bin/xset b off 2>/dev/null || true
version=$(cat /opt/MaXX/etc/version 2>/dev/null || echo "Octane 2.2.0")
arch=$(/bin/uname -m)
fbsd_ver=$(/bin/freebsd-version -u 2>/dev/null || /usr/bin/uname -sr)
linux_ver=$(cat /compat/linux/etc/redhat-release 2>/dev/null || echo "Rocky Linux 9")

/opt/MaXX/bin64/xconfirm -icon info -c -C -t "Congratulations!

You are running MaXX Interactive Desktop
($arch / x86_64) Edition

Version: $version
Host OS: FreeBSD $fbsd_ver
Linuxulator: $linux_ver" -header "Tell version" >/dev/null 2>&1 &
EOF
chmod +x /compat/linux/opt/MaXX/bin64/tellversion

cat > /compat/linux/opt/MaXX/bin64/tellgpu << 'EOF'
#!/compat/linux/bin/bash
if [ -x /usr/local/bin/nvidia-smi ]; then
    GPU_OUT=$(env -u LD_LIBRARY_PATH /usr/local/bin/nvidia-smi --query --display=MEMORY,UTILIZATION,TEMPERATURE 2>/dev/null)
    /opt/MaXX/bin64/xconfirm -c -icon info -t "$GPU_OUT" -header "tell gpu" >/dev/null 2>&1 &
else
    /opt/MaXX/bin64/xconfirm -c -icon info -t "Unknown GPU - Not NVIDIA, sorry!" -header "tell gpu" >/dev/null 2>&1 &
fi
EOF
chmod +x /compat/linux/opt/MaXX/bin64/tellgpu

for cfg in \
    /compat/linux/opt/MaXX/etc/Xdefaults.d/Xdefaults.Gr_osview.dark \
    /compat/linux/opt/MaXX/etc/Xdefaults.d/Xdefaults.Gr_osview.light \
    "${USER_HOME}/.maxxdesktop/Xdefaults.d/Xdefaults.Gr_osview.dark" \
    "${USER_HOME}/.maxxdesktop/Xdefaults.d/Xdefaults.Gr_osview.light"; do
    if [ -f "$cfg" ]; then
        sed -i '' 's/xosview\*disk:[[:space:]]*True/xosview*disk: False/g' "$cfg"
        sed -i '' 's/xosview\*page:[[:space:]]*True/xosview*page: False/g' "$cfg"
        sed -i '' 's/xosview\*int:[[:space:]]*True/xosview*int: False/g' "$cfg"
        sed -i '' 's/xosview\*ints:[[:space:]]*True/xosview*ints: False/g' "$cfg"
        sed -i '' 's/xosview\*codecs:[[:space:]]*True/xosview*codecs: False/g' "$cfg"
        grep -q "xosview\*disk:" "$cfg" || echo "xosview*disk: False" >> "$cfg"
        grep -q "xosview\*page:" "$cfg" || echo "xosview*page: False" >> "$cfg"
        grep -q "xosview\*int:"  "$cfg" || echo "xosview*int: False" >> "$cfg"
        grep -q "xosview\*ints:" "$cfg" || echo "xosview*ints: False" >> "$cfg"
    fi
done

cat > /compat/linux/opt/MaXX/bin64/gr_osview2 << 'EOF'
#!/compat/linux/bin/bash
export MAXX_HOME="/opt/MaXX"
export MAXX_BIN="/opt/MaXX/bin64"
export PATH="/opt/MaXX/bin64:/usr/local/bin:/usr/bin:/bin:$PATH"

font_size=$(cat "$HOME/.maxxdesktop/SmallFontSize" 2>/dev/null || echo "10")
font_name=$(cat "$HOME/.maxxdesktop/SmallFontName" 2>/dev/null || echo "Sans")
font_face="${font_name}:weight=200:slant=italic:size=${font_size}"

isDark=$(env -u LD_LIBRARY_PATH /usr/local/bin/xrdb -q 2>/dev/null | grep darkScheme | cut -d ':' -f2 | awk '{print $1}')
if [ "$isDark" = "FALSE" ]; then
    CFG="$HOME/.maxxdesktop/Xdefaults.d/Xdefaults.Gr_osview.light"
else
    CFG="$HOME/.maxxdesktop/Xdefaults.d/Xdefaults.Gr_osview.dark"
fi
[ ! -f "$CFG" ] && CFG="/opt/MaXX/etc/Xdefaults.d/Xdefaults.Gr_osview.dark"

env -u LD_LIBRARY_PATH /usr/local/bin/xrdb -nocpp -merge "$CFG" 2>/dev/null || true
exec "$MAXX_BIN/xosview2" --config "$CFG" -font "$font_face" "$@" >/dev/null 2>&1 &
EOF
chmod +x /compat/linux/opt/MaXX/bin64/gr_osview2
cp -af /compat/linux/opt/MaXX/bin64/gr_osview2 /compat/linux/opt/MaXX/bin64/gr_osview

# ==============================================================================
# 12. CONFIGURING SYSTEM.RUNTIME, XSESSION.DT & USER PROFILE
# ==============================================================================
echo "-> [13/15] Configuring system.runtime, Xsession.dt, and user profile for ${TARGET_USER}..."

grep -q "export MAXX_BIN" /compat/linux/opt/MaXX/etc/system.runtime || cat >> /compat/linux/opt/MaXX/etc/system.runtime << 'EOF'
export MAXX_HOME="/opt/MaXX"
export MaXX_HOME="/opt/MaXX"
export MAXX_BIN="/opt/MaXX/bin64"
export MAXX_LIBS="/opt/MaXX/lib64"
export MAXX_SHARE="/opt/MaXX/share"
export MAXX_ETC="/opt/MaXX/etc"
export MAXX_SETTINGS="/opt/MaXX/share/msettings"
EOF

cat > /compat/linux/opt/MaXX/etc/skel/Xsession.dt << EOF
#!/bin/bash
ver="2.2"
export USER=\${USER:-\$(whoami)}
export USERNAME="\$USER"
rm -f /tmp/MaXXisRunning-\$USERNAME > /dev/null 2>&1
d=\`date +%F_%T\`
[ -f "\$HOME/.console" ] && mv "\$HOME/.console" "\$HOME/.console-\$d"
echo "[\`date\`] Starting MaXX Interactive Desktop" > "\$HOME/.console"

env -u LD_LIBRARY_PATH /usr/local/bin/xhost +SI:localuser:root >/dev/null 2>&1 || true
env -u LD_LIBRARY_PATH /usr/local/bin/xset m 0 0
env -u LD_LIBRARY_PATH /usr/local/bin/xset -b
env -u LD_LIBRARY_PATH /usr/local/bin/xset +fp /opt/MaXX/share/fonts/sgi,/usr/local/share/fonts/misc,/usr/local/share/fonts/100dpi,/usr/local/share/fonts/75dpi 2>/dev/null || true
env -u LD_LIBRARY_PATH /usr/local/bin/xset fp rehash 2>/dev/null || true
env -u LD_LIBRARY_PATH /usr/local/bin/xsetroot -solid SkyBlue4

. /opt/MaXX/etc/system.runtime
. \$MAXX_HOME/etc/system.desktopenv
export XDG_DATA_DIRS="/opt/MaXX/share:/usr/local/share:/usr/share"

if [ ! -d "\$HOME/.maxxdesktop" ]; then
    cd "\$HOME"
    \$MAXX_HOME/share/misc/HOME/initMaXX-Desktop-Home.sh >> "\$HOME/.console" 2>&1
    for cfg in "\$HOME/.maxxdesktop/Xdefaults.d/Xdefaults.Gr_osview."*; do
        if [ -f "\$cfg" ]; then
            sed -i '' 's/xosview\*disk:[[:space:]]*True/xosview*disk: False/g; s/xosview\*page:[[:space:]]*True/xosview*page: False/g; s/xosview\*codecs:[[:space:]]*True/xosview*codecs: False/g' "\$cfg" 2>/dev/null || true
        fi
    done
fi

mkdir -p "\$HOME/.icons"
ln -shf /opt/MaXX/share/ROX-Filer/ROX "\$HOME/.icons/ROX"
echo "${XKBLAYOUT}" > "\$HOME/.maxxdesktop/KeyboardInput.Choice"
echo "${USER_LOCALE}" > "\$HOME/.maxxdesktop/Language.Choice"

\$MAXX_BIN/telldesktop load
env -u LD_LIBRARY_PATH /usr/local/bin/xrdb -nocpp -load /opt/MaXX/share/X11/app-defaults/SgiIndigoMagic.ad 2>/dev/null || true
env -u LD_LIBRARY_PATH /usr/local/bin/setxkbmap ${XKBLAYOUT} ${XKBVARIANT} 2>/dev/null || true

\$MAXX_BIN/telldesktop start

if [ -f /boot/images/sgi_desktop.jpg ]; then
    env -u LD_LIBRARY_PATH /usr/local/bin/feh --bg-fill /boot/images/sgi_desktop.jpg &
    (sleep 2 && env -u LD_LIBRARY_PATH /usr/local/bin/feh --bg-fill /boot/images/sgi_desktop.jpg) &
fi

\$MAXX_BIN/5Dwm -multiscreen >> "\$HOME/.console" 2>&1
\$MAXX_BIN/telldesktop stop
EOF
chmod +x /compat/linux/opt/MaXX/etc/skel/Xsession.dt

mkdir -p "${USER_HOME}/.icons" "${USER_HOME}/.config"
ln -shf /opt/MaXX/share/ROX-Filer/ROX "${USER_HOME}/.icons/ROX"

# ==============================================================================
# 13. /USR/LOCAL/BIN/STARTMAXX LAUNCHER & SDDM SESSION REGISTRATION
# ==============================================================================
echo "-> [14/15] Creating /usr/local/bin/startmaxx and registering SDDM session..."

cat > /usr/local/bin/startmaxx << EOF
#!/bin/sh
export USER=\${USER:-\$(id -un)}
export USERNAME="\$USER"
export HOME=\${HOME:-/home/\$USER}
export LANG="${USER_LOCALE}"
export XCURSOR_THEME="redSGI"
export MAXX_HOME="/opt/MaXX"
export MAXX_BIN="/opt/MaXX/bin64"
export PATH="/opt/MaXX/bin64:/opt/MaXX/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:\$PATH"
exec /compat/linux/bin/bash /opt/MaXX/etc/skel/Xsession.dt > "\$HOME/.maxx-session.log" 2>&1
EOF
chmod +x /usr/local/bin/startmaxx

mkdir -p /usr/local/share/xsessions
cat > /usr/local/share/xsessions/maxx.desktop << 'EOF'
[Desktop Entry]
Name=MaXX Interactive Desktop (SGI IRIX)
Comment=Silicon Graphics IRIX Indigo Magic Desktop Environment (Octane 2.2)
Exec=/usr/local/bin/startmaxx
TryExec=/usr/local/bin/startmaxx
Type=Application
DesktopNames=MaXX
EOF

printf "#!/bin/sh\nexec /usr/local/bin/startmaxx\n" > "${USER_HOME}/.xinitrc"
chmod +x "${USER_HOME}/.xinitrc"

echo "-> [15/15] Verifying final ownership permissions on ${USER_HOME}..."
chown -R "${TARGET_USER}:${TARGET_USER}" "${USER_HOME}"

echo "=============================================================================="
echo " FULL INSTALLATION COMPLETED SUCCESSFULLY!"
echo " Base Workstation and MaXX Interactive Desktop v2.2.0 are ready."
echo " Run 'reboot' to start into the SGI IRIX login screen (SDDM)."
echo "=============================================================================="
exit 0