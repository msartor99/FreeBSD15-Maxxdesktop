#!/bin/sh
# ==============================================================================
# SCRIPT 1 : install-base-system.sh (VERSION FINALE COMPLETE & IDEMPOTENTE)
# TARGET OS: FreeBSD 15.1-RELEASE (POSIX /bin/sh)
# HARDWARE : HP Z4 G4 / Xeon W-2140B / NVIDIA Quadro M4000 (Driver 470) / ASUS PB278
# REPO     : https://github.com/msartor99/FreeBSD-Maxxdesktop
# ==============================================================================

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Ce script doit etre execute en root."
    exit 1
fi

TARGET_USER="administrateur"
USER_HOME="/home/${TARGET_USER}"
GITHUB_RAW="https://raw.githubusercontent.com/msartor99/FreeBSD-Maxxdesktop/main"

echo "=== Phase 1 : Configuration du Systeme de Base FreeBSD 15.1-RELEASE (HP Z4 G4) ==="

# ------------------------------------------------------------------------------
# 1. CONFIGURATION DES DEPOTS PKG (BRANCHE LATEST) ET MISE A JOUR DU CATALOGUE
# ------------------------------------------------------------------------------
echo "-> [1/11] Configuration des depots FreeBSD en mode 'latest'..."
mkdir -p /usr/local/etc/pkg/repos
cat > /usr/local/etc/pkg/repos/FreeBSD.conf << 'EOF'
FreeBSD: {
  url: "pkg+http://pkg.FreeBSD.org/${ABI}/latest",
  mirror_type: "srv",
  signature_type: "fingerprints",
  fingerprints: "/usr/share/keys/pkg",
  enabled: yes
}
EOF

env ASSUME_ALWAYS_YES=yes pkg bootstrap -f
pkg update -f
pkg upgrade -y

# ------------------------------------------------------------------------------
# 2. INSTALLATION DES PAQUETS DE BASE, XORG, PILOTE NVIDIA 470, SDDM ET AUDIO
# ------------------------------------------------------------------------------
echo "-> [2/11] Installation de Xorg, NVIDIA Driver 470 (Quadro M4000), SDDM et utilitaires..."
pkg install -y \
    sudo bash git curl wget nano vim-console htop btop \
    pciutils usbutils dmidecode lsof tree zip unzip tar \
    xorg-server xorg-drivers xinit xauth xrandr xdpyinfo \
    xrdb xset xsetroot xprop xwininfo xkill setxkbmap xclock xterm \
    nvidia-driver-470 nvidia-settings-470 nvidia-xconfig mesa-demos \
    linux-nvidia-libs-470 \
    sddm qt5-graphicaleffects qt5-quickcontrols2 \
    ImageMagick7 feh scrot dunst alttab tradcpp \
    alsa-lib alsa-utils pulseaudio pavucontrol dsbmixer \
    dbus consolekit2 polkit hal 2>/dev/null || true

# ------------------------------------------------------------------------------
# 3. VERIFICATION DU COMPTE UTILISATEUR 'administrateur' ET DROITS SUDO
# ------------------------------------------------------------------------------
echo "-> [3/11] Verification de l'utilisateur ${TARGET_USER} (wheel, operator, video)..."
if ! id "${TARGET_USER}" >/dev/null 2>&1; then
    pw useradd -n "${TARGET_USER}" -m -s /bin/sh -G wheel,operator,video
else
    pw groupmod wheel -m "${TARGET_USER}"
    pw groupmod operator -m "${TARGET_USER}"
    pw groupmod video -m "${TARGET_USER}"
fi

mkdir -p /usr/local/etc/sudoers.d
cat > /usr/local/etc/sudoers.d/administrateur << EOF
%wheel ALL=(ALL:ALL) NOPASSWD: ALL
${TARGET_USER} ALL=(ALL:ALL) NOPASSWD: ALL
EOF
chmod 440 /usr/local/etc/sudoers.d/administrateur

# ------------------------------------------------------------------------------
# 4. LOCALISATION FRANCAISE (UTF-8) ET CLAVIER SUISSE ROMAND (FR_CH / CH FR)
# ------------------------------------------------------------------------------
echo "-> [4/11] Configuration de la langue fr_FR.UTF-8 et du clavier Suisse Romand..."
sysrc keymap="ch.fr.kbd"
kbdcontrol -l ch.fr.kbd 2>/dev/null || true

cat > /etc/profile.d/locale_sgi.sh << 'EOF'
export LANG="fr_FR.UTF-8"
export LC_ALL="fr_FR.UTF-8"
export MM_CHARSET="UTF-8"
EOF
chmod +x /etc/profile.d/locale_sgi.sh

for prof in "${USER_HOME}/.profile" "${USER_HOME}/.shrc" "/root/.profile"; do
    if [ -f "$prof" ]; then
        grep -q 'LANG=fr_FR.UTF-8' "$prof" || cat >> "$prof" << 'EOF'
export LANG="fr_FR.UTF-8"
export MM_CHARSET="UTF-8"
EOF
    fi
done

# ------------------------------------------------------------------------------
# 5. OPTIMISATION DU CHARGEUR DE DEMARRAGE (/BOOT/LOADER.CONF) & NOYAU
# ------------------------------------------------------------------------------
echo "-> [5/11] Configuration de /boot/loader.conf (UEFI 1080p, NVIDIA, Son, Temp Xeon)..."
touch /boot/loader.conf
sed -i '' '/^kern.vty=/d; /^efi_max_resolution=/d; /^coretemp_load=/d; /^snd_hda_load=/d; /^linux_load=/d; /^linux64_load=/d; /^boot_mute=/d; /^beastie_disable=/d; /^loader_logo=/d; /^splash=/d; /^shutdown_splash=/d' /boot/loader.conf

cat >> /boot/loader.conf << 'EOF'
kern.vty="vt"
efi_max_resolution="1080p"
coretemp_load="YES"
snd_hda_load="YES"
linux_load="YES"
linux64_load="YES"
boot_mute="YES"
beastie_disable="YES"
loader_logo="none"
splash="/boot/images/sgi_splash.png"
shutdown_splash="/boot/images/sgi_splash.png"
EOF

# ------------------------------------------------------------------------------
# 6.OPTIMISATION SYSCTL (/ETC/SYSCTL.CONF) POUR STATION GRAPHIQUE X11 / MOTIF
# ------------------------------------------------------------------------------
echo "-> [6/11] Optimisation des parametres noyau dans /etc/sysctl.conf..."
touch /etc/sysctl.conf
sed -i '' '/^kern.ipc.shmmax=/d; /^kern.ipc.shmall=/d; /^kern.ipc.shm_allow_removed=/d; /^compat.linux.osrelease=/d; /^kern.sched.preempt_thresh=/d; /^hw.snd.default_auto=/d' /etc/sysctl.conf

cat >> /etc/sysctl.conf << 'EOF'
# Memoire partagee X11 / Motif / OpenGL et compatibilite Linuxulator
kern.ipc.shmmax=2147483648
kern.ipc.shmall=524288
kern.ipc.shm_allow_removed=1
kern.sched.preempt_thresh=224
hw.snd.default_auto=1
EOF
service sysctl reload 2>/dev/null || true

# ------------------------------------------------------------------------------
# 7. CONFIGURATION DU LINUXULATOR ET POINTS DE MONTAGE (/ETC/FSTAB)
# ------------------------------------------------------------------------------
echo "-> [7/11] Configuration de /etc/fstab pour Linuxulator (linprocfs, linsysfs, tmpfs)..."
mkdir -p /compat/linux/proc /compat/linux/sys /compat/linux/dev/shm /compat/linux/dev/fd

grep -q '/compat/linux/proc' /etc/fstab || cat >> /etc/fstab << 'EOF'
linprocfs   /compat/linux/proc      linprocfs   rw                      0   0
linsysfs    /compat/linux/sys       linsysfs    rw                      0   0
devfs       /compat/linux/dev       devfs       rw,late                 0   0
fdescfs     /compat/linux/dev/fd    fdescfs     rw,late,linrdlnk        0   0
tmpfs       /compat/linux/dev/shm   tmpfs       rw,late,size=2g,mode=1777 0 0
EOF

# ------------------------------------------------------------------------------
# 8. ACTIVATION DES SERVICES DANS /ETC/RC.CONF (NVIDIA-MODESET, DBUS, SDDM, NTP)
# ------------------------------------------------------------------------------
echo "-> [8/11] Configuration des services dans /etc/rc.conf..."
sysrc kld_list="nvidia-modeset linux linux64 coretemp"
sysrc dbus_enable="YES"
sysrc linux_enable="YES"
sysrc linux_mounts_enable="YES"
sysrc sddm_enable="YES"
sysrc sddm_lang="fr_FR.UTF-8"
sysrc ntpd_enable="YES"
sysrc ntpd_sync_on_start="YES"
sysrc moused_enable="YES"
sysrc powerd_enable="YES"
sysrc powerd_flags="-a hiadaptive -b adaptive"

kldload nvidia-modeset 2>/dev/null || true
service linux start 2>/dev/null || true
mount -a 2>/dev/null || true

# ------------------------------------------------------------------------------
# 9. CONFIGURATION XORG POUR NVIDIA QUADRO M4000 + ECRAN ASUS PB278 (2560x1440)
# ------------------------------------------------------------------------------
echo "-> [9/11] Generation de la configuration Xorg (Quadro M4000 + Clavier Suisse Romand)..."
mkdir -p /usr/local/etc/X11/xorg.conf.d

cat > /usr/local/etc/X11/xorg.conf.d/10-nvidia-sgi.conf << 'EOF'
Section "Device"
    Identifier     "NVIDIA Quadro M4000"
    Driver         "nvidia"
    VendorName     "NVIDIA Corporation"
    BoardName      "Quadro M4000"
    Option         "NoLogo" "True"
    Option         "UseEDID" "True"
    Option         "ModeValidation" "AllowNonEdidModes"
EndSection

Section "Screen"
    Identifier     "SGI_Screen"
    Device         "NVIDIA Quadro M4000"
    DefaultDepth    24
    SubSection     "Display"
        Depth       24
        Modes      "2560x1440" "1920x1080"
    EndSubSection
EndSection
EOF

cat > /usr/local/etc/X11/xorg.conf.d/20-keyboard-ch-fr.conf << 'EOF'
Section "InputClass"
    Identifier      "Swiss French Keyboard"
    MatchIsKeyboard "on"
    Option          "XkbModel" "pc105"
    Option          "XkbLayout" "ch"
    Option          "XkbVariant" "fr"
EndSection
EOF

# ------------------------------------------------------------------------------
# 10. CREATION DU THEME SDDM 'sgi_irix' ET CONFIGURATION DE SDDM.CONF
# ------------------------------------------------------------------------------
echo "-> [10/11] Installation du theme SDDM SGI IRIX et configuration de /usr/local/etc/sddm.conf..."
THEME_DIR="/usr/local/share/sddm/themes/sgi_irix"
mkdir -p "$THEME_DIR"

if [ -d /usr/local/share/sddm/themes/elarun ]; then
    cp -af /usr/local/share/sddm/themes/elarun/* "$THEME_DIR/" 2>/dev/null || true
elif [ -d /usr/local/share/sddm/themes/maldives ]; then
    cp -af /usr/local/share/sddm/themes/maldives/* "$THEME_DIR/" 2>/dev/null || true
fi

cat > "${THEME_DIR}/theme.conf" << 'EOF'
[General]
background=background.jpg
type=image
EOF

cat > /usr/local/etc/sddm.conf << 'EOF'
[General]
Numlock=on

[Theme]
Current=sgi_irix
CursorTheme=redSGI

[Users]
MaximumUid=65000
MinimumUid=1000
RememberLastUser=true
RememberLastSession=true

[X11]
ServerArguments=-nolisten tcp -dpi 96
EOF

# ------------------------------------------------------------------------------
# 11. TELECHARGEMENT ET CALIBRATION DES IMAGES SPLASH SGI (msartor99/FreeBSD-Maxxdesktop)
# ------------------------------------------------------------------------------
echo "-> [11/11] Telechargement et calibration des Splash Screens SGI depuis msartor99/FreeBSD-Maxxdesktop..."
mkdir -p /boot/images

curl -s "https://api.github.com/repos/msartor99/FreeBSD-Maxxdesktop/contents" | grep '"download_url"' | cut -d'"' -f4 | grep -iE "\.jpg|\.png" | while read -r img_url; do
    fname=$(basename "$img_url")
    fetch -q -o "/boot/images/$fname" "$img_url" 2>/dev/null || true
done

if [ ! -s /boot/images/SGI_splash.jpg ]; then
    fetch -q -o /boot/images/SGI_splash.jpg "${GITHUB_RAW}/SGI_splash.jpg" 2>/dev/null || \
    fetch -q -o /boot/images/SGI_splash.jpg "${GITHUB_RAW}/sgi_splash.jpg" 2>/dev/null || true
fi
if [ ! -s /boot/images/sgi_desktop.jpg ]; then
    fetch -q -o /boot/images/sgi_desktop_orig.jpg "${GITHUB_RAW}/sgi_desktop.jpg" 2>/dev/null || \
    fetch -q -o /boot/images/sgi_desktop_orig.jpg "${GITHUB_RAW}/SGI_desktop.jpg" 2>/dev/null || true
else
    cp -f /boot/images/sgi_desktop.jpg /boot/images/sgi_desktop_orig.jpg
fi

if [ -f /boot/images/SGI_splash.jpg ] && [ ! -f /boot/images/sgi_splash.jpg ]; then
    cp -f /boot/images/SGI_splash.jpg /boot/images/sgi_splash.jpg
elif [ -f /boot/images/sgi_splash.jpg ] && [ ! -f /boot/images/SGI_splash.jpg ]; then
    cp -f /boot/images/sgi_splash.jpg /boot/images/SGI_splash.jpg
fi

# Generation du Splash Boot/Shutdown UEFI (1920x1080 PNG 8-bit RGBA pour vt loader)
if [ -s /boot/images/SGI_splash.jpg ]; then
    /usr/local/bin/magick /boot/images/SGI_splash.jpg \
        -resize 1920x1080^ -gravity center -extent 1920x1080 \
        -strip -depth 8 -alpha set -define png:color-type=6 \
        "png32:/boot/images/sgi_splash.png"
    cp -f /boot/images/sgi_splash.png /boot/images/freebsd-logo-rev.png 2>/dev/null || true
fi

# Generation du fond d'ecran SGI en 2560x1440 (ASUS PB278) et application a SDDM
if [ -s /boot/images/sgi_desktop_orig.jpg ]; then
    /usr/local/bin/magick /boot/images/sgi_desktop_orig.jpg \
        -resize 2560x1440^ -gravity center -extent 2560x1440 \
        /boot/images/sgi_desktop.jpg
elif [ -s /boot/images/SGI_splash.jpg ]; then
    /usr/local/bin/magick /boot/images/SGI_splash.jpg \
        -resize 2560x1440^ -gravity center -extent 2560x1440 \
        /boot/images/sgi_desktop.jpg
fi

if [ -s /boot/images/sgi_desktop.jpg ]; then
    cp -f /boot/images/sgi_desktop.jpg "${THEME_DIR}/background.jpg"
    chmod 644 "${THEME_DIR}/background.jpg"
fi

chown -R "${TARGET_USER}:${TARGET_USER}" "${USER_HOME}"

echo "======================================================================"
echo "=== Phase 1 terminee avec succes ! Vous pouvez lancer le Script 2. ==="
echo "======================================================================"
exit 0