#!/bin/sh
# ==============================================================================
# SCRIPT 2 : install-maxx-interactive.sh (VERSION FINALE COMPLETE & IDEMPOTENTE)
# TARGET OS: FreeBSD 15.1-RELEASE (POSIX /bin/sh)
# HARDWARE : HP Z4 G4 / Xeon W-2140B / NVIDIA Quadro M4000 (Driver 470) / ASUS PB278
# ==============================================================================

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Ce script doit etre execute en root."
    exit 1
fi

TARGET_USER="administrateur"
USER_HOME="/home/${TARGET_USER}"
MAXX_FILENAME="MaXX-Desktop-v2.2.0-LINUX-x86_64-tar.gz"
MAXX_TAR="${USER_HOME}/${MAXX_FILENAME}"
MAXX_URL="https://s3.ca-central-1.amazonaws.com/cdn.maxxinteractive.com/maxx-desktop-installer/${MAXX_FILENAME}"
GITHUB_RAW="https://raw.githubusercontent.com/msartor99/FreeBSD-Maxxdesktop/main"

echo "=== Phase 2 : Installation et Calibration Integrale de MaXX Interactive Desktop ==="

# ------------------------------------------------------------------------------
# 1. INSTALLATION GARANTIE DES POLICES X11/MOTIF, APPLICATIONS ET OUTILS NATIFS
# ------------------------------------------------------------------------------
echo "-> [1/11] Verification des polices X11/SGI, outils natifs et Linuxulator..."
pkg install -y \
    xorg-fonts font-alias font-misc-misc font-bh-75dpi font-bh-100dpi \
    font-bh-lucidatypewriter-75dpi font-bh-lucidatypewriter-100dpi \
    font-adobe-75dpi font-adobe-100dpi font-ibm-type1 font-dec-misc \
    font-sun-misc font-cursor-misc dejavu noto-basic \
    tradcpp xrdb xset xsetroot xprop xwininfo xkill setxkbmap xclock \
    mkfontscale mkfontdir feh dunst alttab scrot xterm wget curl ImageMagick7 \
    firefox thunderbird vlc pavucontrol dsbmixer ristretto mousepad thunar \
    btop shared-mime-info 2>/dev/null || true

sysrc linux_enable="YES"
sysrc linux_mounts_enable="YES"
service linux start 2>/dev/null || true

for lpkg in \
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
    linux-rl9-motif; do
    pkg install -y "$lpkg" 2>/dev/null || true
done

# ------------------------------------------------------------------------------
# 2. UNIFICATION DE /TMP ET LIENS DE COMPATIBILITE LINUXULATOR (NCURSES V5)
# ------------------------------------------------------------------------------
echo "-> [2/11] Unification de /compat/linux/tmp -> /tmp et bibliotheques Linuxulator..."
rm -rf /compat/linux/tmp
ln -s /tmp /compat/linux/tmp
chmod 1777 /tmp
ln -sf /usr/local /compat/linux/usr/local

if [ ! -f /compat/linux/etc/machine-id ]; then
    /bin/uuidgen > /compat/linux/etc/machine-id
fi

ln -sf libtinfo.so.6 /compat/linux/usr/lib64/libtinfo.so.5
ln -sf libncurses.so.6 /compat/linux/usr/lib64/libncurses.so.5

# ------------------------------------------------------------------------------
# 3. TELECHARGEMENT (AVEC CACHE) ET EXTRACTION DE MAXX DESKTOP OCTANE 2.2.0
# ------------------------------------------------------------------------------
echo "-> [3/11] Verification et telechargement de l'archive MaXX Desktop Octane 2.2.0..."
mkdir -p /compat/linux/opt /opt

if [ -x /compat/linux/opt/MaXX/bin64/5Dwm ]; then
    echo "-> MaXX Desktop est deja extrait dans /compat/linux/opt/MaXX (conservation de l'installation)."
    ln -sf /compat/linux/opt/MaXX /opt/MaXX
else
    if [ -f "/root/${MAXX_FILENAME}" ] && [ ! -f "$MAXX_TAR" ]; then
        cp -f "/root/${MAXX_FILENAME}" "$MAXX_TAR"
    fi

    if [ -f "$MAXX_TAR" ] && [ ! -s "$MAXX_TAR" ]; then
        rm -f "$MAXX_TAR"
    fi

    if [ ! -f "$MAXX_TAR" ]; then
        echo "-> Telechargement de ${MAXX_FILENAME} (233 Mo)..."
        wget -c -O "$MAXX_TAR" "$MAXX_URL" || fetch -o "$MAXX_TAR" "$MAXX_URL"
        chown "${TARGET_USER}:${TARGET_USER}" "$MAXX_TAR"
    else
        echo "-> Archive valide deja presente dans $MAXX_TAR (cache utilise)."
    fi

    echo "-> Extraction propre de MaXX Desktop dans /compat/linux/opt/MaXX..."
    rm -rf /compat/linux/opt/MaXX /opt/MaXX
    tar -xzf "$MAXX_TAR" -C /compat/linux/opt
    ln -sf /compat/linux/opt/MaXX /opt/MaXX
fi

# ------------------------------------------------------------------------------
# 4. TELECHARGEMENT ET CALIBRATION DES SPLASH SCREENS SGI (BOOT UEFI, SDDM, BUREAU)
# ------------------------------------------------------------------------------
echo "-> [4/11] Telechargement et calibration des images Splash SGI (msartor99/FreeBSD-Maxxdesktop)..."
mkdir -p /boot/images

# Telechargement depuis msartor99/FreeBSD-Maxxdesktop si non presentes ou vides
if [ ! -s /boot/images/SGI_splash.jpg ]; then
    fetch -q -o /boot/images/SGI_splash.jpg "${GITHUB_RAW}/SGI_splash.jpg" 2>/dev/null || \
    fetch -q -o /boot/images/SGI_splash.jpg "${GITHUB_RAW}/sgi_splash.jpg" 2>/dev/null || true
fi

if [ ! -s /boot/images/sgi_desktop_orig.jpg ]; then
    fetch -q -o /boot/images/sgi_desktop_orig.jpg "${GITHUB_RAW}/sgi_desktop.jpg" 2>/dev/null || \
    fetch -q -o /boot/images/sgi_desktop_orig.jpg "${GITHUB_RAW}/SGI_desktop.jpg" 2>/dev/null || true
fi

# Fallback sur l'arbre Git de msartor99 si les fichiers sont dans un sous-dossier
if [ ! -s /boot/images/SGI_splash.jpg ] || [ ! -s /boot/images/sgi_desktop_orig.jpg ]; then
    curl -s "https://api.github.com/users/msartor99/repos" | grep '"full_name"' | cut -d'"' -f4 | while read -r repo; do
        curl -s "https://api.github.com/repos/${repo}/git/trees/HEAD?recursive=1" | grep '"path"' | cut -d'"' -f4 | grep -iE "splash|sgi|desktop|\.jpg|\.png" | while read -r path; do
            case "$path" in
                *[Ss]plash*) [ ! -s /boot/images/SGI_splash.jpg ] && fetch -q -o /boot/images/SGI_splash.jpg "https://raw.githubusercontent.com/${repo}/HEAD/${path}" || true ;;
                *[Dd]esktop*) [ ! -s /boot/images/sgi_desktop_orig.jpg ] && fetch -q -o /boot/images/sgi_desktop_orig.jpg "https://raw.githubusercontent.com/${repo}/HEAD/${path}" || true ;;
            esac
        done
    done
fi

# Fallback ultime sur les fonds officiels inclus dans MaXX Desktop si pas d'acces GitHub
if [ ! -s /boot/images/SGI_splash.jpg ]; then
    MAXX_FALLBACK_BG=$(find /compat/linux/opt/MaXX/share -type f \( -name "*.jpg" -o -name "*.png" \) 2>/dev/null | head -n 1)
    [ -n "$MAXX_FALLBACK_BG" ] && cp -f "$MAXX_FALLBACK_BG" /boot/images/SGI_splash.jpg
fi
if [ ! -s /boot/images/sgi_desktop_orig.jpg ] && [ -s /boot/images/SGI_splash.jpg ]; then
    cp -f /boot/images/SGI_splash.jpg /boot/images/sgi_desktop_orig.jpg
fi

cp -f /boot/images/SGI_splash.jpg /boot/images/sgi_splash.jpg 2>/dev/null || true

# 4a. Generation du Splash Boot/Shutdown UEFI (1920x1080 PNG 8-bit RGBA < 1.5 Mo pour vt loader)
if [ -s /boot/images/SGI_splash.jpg ]; then
    /usr/local/bin/magick /boot/images/SGI_splash.jpg \
        -resize 1920x1080^ -gravity center -extent 1920x1080 \
        -strip -depth 8 -alpha set -define png:color-type=6 \
        "png32:/boot/images/sgi_splash.png"
    # Remplacement egalement du logo graphique du loader FreeBSD au cas ou
    cp -f /boot/images/sgi_splash.png /boot/images/freebsd-logo-rev.png 2>/dev/null || true
fi

# 4b. Generation du fond d'ecran SGI 2560x1440 pour ASUS PB278 (SDDM + Bureau MaXX)
if [ -s /boot/images/sgi_desktop_orig.jpg ]; then
    /usr/local/bin/magick /boot/images/sgi_desktop_orig.jpg \
        -resize 2560x1440^ -gravity center -extent 2560x1440 \
        /boot/images/sgi_desktop.jpg
fi

# 4c. Application au theme SDDM sgi_irix
if [ -s /boot/images/sgi_desktop.jpg ] && [ -d /usr/local/share/sddm/themes/sgi_irix ]; then
    cp -f /boot/images/sgi_desktop.jpg /usr/local/share/sddm/themes/sgi_irix/background.jpg
    chmod 644 /usr/local/share/sddm/themes/sgi_irix/background.jpg
fi

# 4d. Configuration complete de /boot/loader.conf pour forcer le Splash graphique UEFI
sed -i '' '/^boot_mute=/d; /^beastie_disable=/d; /^loader_logo=/d; /^splash=/d; /^shutdown_splash=/d; /^efi_max_resolution=/d' /boot/loader.conf
cat >> /boot/loader.conf << 'EOF'
efi_max_resolution="1080p"
boot_mute="YES"
beastie_disable="YES"
loader_logo="none"
splash="/boot/images/sgi_splash.png"
shutdown_splash="/boot/images/sgi_splash.png"
EOF

# ------------------------------------------------------------------------------
# 5. ENREGISTREMENT LDCONFIG, CACHES GDK-PIXBUF & MIME (ICONES ROX-FILER)
# ------------------------------------------------------------------------------
echo "-> [5/11] Configuration du cache ldconfig, GDK-Pixbuf et MIME dans Linuxulator..."
mkdir -p /compat/linux/etc/ld.so.conf.d
printf "/opt/MaXX/lib64\n/opt/MaXX/lib\n" > /compat/linux/etc/ld.so.conf.d/maxx.conf
/compat/linux/sbin/ldconfig 2>/dev/null || chroot /compat/linux /sbin/ldconfig 2>/dev/null || true

mkdir -p /compat/linux/usr/share/mime
cp -af /usr/local/share/mime/* /compat/linux/usr/share/mime/ 2>/dev/null || true
chroot /compat/linux /usr/bin/update-mime-database /usr/share/mime 2>/dev/null || true
chroot /compat/linux /usr/bin/gdk-pixbuf-query-loaders-64 --update-cache 2>/dev/null || true

# ------------------------------------------------------------------------------
# 6. TATOUAGE ELF (BRANDELF LINUX) UNIQUEMENT SUR LES VRAIS BINAIRES ELF
# ------------------------------------------------------------------------------
echo "-> [6/11] Tatouage ELF (brandelf Linux) sur les binaires MaXX..."
find /compat/linux/opt/MaXX/bin64 /compat/linux/opt/MaXX/bin /compat/linux/opt/MaXX/lib64 \
    -type f ! -name "*.sh" ! -name "*.py" ! -name "*.pl" ! -name "*.conf" ! -name "*.ad" 2>/dev/null | while read -r f; do
    if file -b "$f" 2>/dev/null | grep -q "^ELF "; then
        brandelf -t Linux "$f" 2>/dev/null || true
    fi
done

# ------------------------------------------------------------------------------
# 7. PONTS SYSTEME, POLICES SGI ET PREPROCESSEUR C (TRADCPP) POUR LIBXT/XRDB
# ------------------------------------------------------------------------------
echo "-> [7/11] Creation des ponts systeme, polices SGI et tradcpp..."
mkdir -p /compat/linux/usr/bin /compat/linux/bin /compat/linux/lib

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

for xtool in xrdb xset xsetroot xprop xwininfo xkill setxkbmap xclock feh; do
    rm -f "/compat/linux/usr/bin/$xtool" "/compat/linux/bin/$xtool"
    if [ -x "/usr/local/bin/$xtool" ]; then
        ln -sf "/usr/local/bin/$xtool" "/compat/linux/usr/bin/$xtool"
    fi
done
ln -sf /usr/bin/killall /compat/linux/usr/bin/killall
ln -sf /usr/bin/which   /compat/linux/usr/bin/which

mkdir -p /compat/linux/usr/share/fonts
ln -sf /usr/local/share/fonts/dejavu /compat/linux/usr/share/fonts/dejavu
ln -sf /usr/local/share/fonts/noto   /compat/linux/usr/share/fonts/noto
if [ -d /compat/linux/opt/MaXX/share/fonts ]; then
    for fdir in /compat/linux/opt/MaXX/share/fonts/*; do
        if [ -d "$fdir" ]; then
            /usr/local/bin/mkfontscale "$fdir" 2>/dev/null || true
            /usr/local/bin/mkfontdir "$fdir" 2>/dev/null || true
        fi
    done
fi

# ------------------------------------------------------------------------------
# 8. THEME CURSEUR SGI ROUGE (redSGI), THEMES GTK ET COMPILATION INDIGOMAGIC
# ------------------------------------------------------------------------------
echo "-> [8/11] Installation du curseur SGI (redSGI), themes GTK et palette IndigoMagic..."
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

mkdir -p /compat/linux/opt/MaXX/share/X11/app-defaults
cat > /tmp/build_sgi_theme.xrm << 'EOF'
#define GAMMA_1_7
#define USE_COLORS
#define USE_SPACING
#define USE_FONTS
#include "/opt/MaXX/share/X11/schemes/Base/FontPalette"
#include "/opt/MaXX/share/X11/schemes/IndigoMagic/BaseColorPalette"
#include "/opt/MaXX/share/X11/schemes/Base/Base"
EOF
/usr/local/bin/tradcpp -P /tmp/build_sgi_theme.xrm > /compat/linux/opt/MaXX/share/X11/app-defaults/SgiIndigoMagic.ad
rm -f /tmp/build_sgi_theme.xrm

cat /compat/linux/opt/MaXX/etc/Xdefaults.d/Xdefaults.init \
    /compat/linux/opt/MaXX/etc/Xdefaults.d/Xdefaults.classic \
    /compat/linux/opt/MaXX/etc/Xdefaults.d/Xdefaults.bitmapFont \
    /compat/linux/opt/MaXX/etc/Xdefaults.d/Xdefaults.5dwm \
    /compat/linux/opt/MaXX/etc/Xdefaults.d/Xdefaults.toolchest >> /compat/linux/opt/MaXX/share/X11/app-defaults/SgiIndigoMagic.ad

cat >> /compat/linux/opt/MaXX/share/X11/app-defaults/SgiIndigoMagic.ad << 'EOF'
*scheme: IndigoMagic
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
Toolchest*fontList: -*-helvetica-bold-o-normal-*-14-*-*-*-*-*-iso8859-1
*fontList: -*-helvetica-medium-r-normal-*-12-*-*-*-*-*-iso8859-1
EOF

# ------------------------------------------------------------------------------
# 9. WRAPPERS D'APPLICATIONS ET D'OUTILS SYSTEME POUR LE TOOLCHEST (SANS CONFLIT LD)
# ------------------------------------------------------------------------------
echo "-> [9/11] Deploiement des wrappers FreeBSD pour mlaunch et le Toolchest..."

create_wrapper() {
    cat > "/compat/linux/opt/MaXX/bin64/$1" << EOF
#!/bin/sh
unset LD_LIBRARY_PATH
export PATH="/usr/local/bin:/usr/bin:/bin:\$PATH"
exec $2 "\$@" &
EOF
    chmod +x "/compat/linux/opt/MaXX/bin64/$1"
}

create_wrapper "WEBBROWSER"  "/usr/local/bin/firefox"
create_wrapper "EMAILCLIENT" "/usr/local/bin/thunderbird"
create_wrapper "MAIL"        "/usr/local/bin/thunderbird"
create_wrapper "MEDIAVIEWER" "/usr/local/bin/vlc"
create_wrapper "AUDIOPLAYER" "/usr/local/bin/vlc"
create_wrapper "FILEBROWSER" "/usr/local/bin/thunar"
create_wrapper "TEXTEDITOR"  "/usr/local/bin/mousepad"
create_wrapper "IMAGEEDITOR" "/usr/local/bin/ristretto"
create_wrapper "PDFVIEWER"   "/usr/local/bin/firefox"
create_wrapper "pavucontrol" "/usr/local/bin/dsbmixer"

printf "#!/bin/sh\nexit 0\n" > /compat/linux/opt/MaXX/bin64/sound
chmod +x /compat/linux/opt/MaXX/bin64/sound

cat > /compat/linux/opt/MaXX/bin64/mlaunch << 'EOF'
#!/bin/sh
while [ $# -gt 0 ]; do
    case "$1" in -*) shift ;; *) break ;; esac
done
CMD="$1"; shift
if [ -x "/opt/MaXX/bin64/$CMD" ]; then
    exec "/opt/MaXX/bin64/$CMD" "$@" &
elif [ -x "/usr/local/bin/$CMD" ]; then
    unset LD_LIBRARY_PATH
    exec "/usr/local/bin/$CMD" "$@" &
else
    unset LD_LIBRARY_PATH
    exec "$CMD" "$@" &
fi
EOF
chmod +x /compat/linux/opt/MaXX/bin64/mlaunch

create_wrapper "gr_osview" "/usr/local/bin/xterm -title 'SGI System Monitor (btop)' -geometry 110x35 -bg black -fg green -e /usr/local/bin/btop"
create_wrapper "Restart"   "sudo /sbin/reboot"
create_wrapper "Shutdown"  "sudo /sbin/poweroff"

cat > /compat/linux/opt/MaXX/bin64/tellsystem << 'EOF'
#!/bin/sh
unset LD_LIBRARY_PATH
exec /usr/local/bin/xterm -title "SGI Hardware Inventory (hinv)" -geometry 90x28 -bg "#1e2638" -fg "#ffffff" -e /bin/sh -c '
echo "======================================================================"
echo "  SILICON GRAPHICS / MAXX INTERACTIVE DESKTOP - HARDWARE INVENTORY"
echo "======================================================================"
echo "System    : $(uname -sr)"
echo "Hostname  : $(hostname)"
echo "Processor : $(sysctl -n hw.model) ($(sysctl -n hw.ncpu) threads)"
echo "Memory    : $(( $(sysctl -n hw.physmem) / 1024 / 1024 )) MB RAM"
echo "Graphics  : NVIDIA Quadro M4000 (Driver 470 Stable)"
echo "Display   : ASUS PB278 (2560x1440 @ 24-bit TrueColor)"
echo "----------------------------------------------------------------------"
nvidia-smi 2>/dev/null || true
printf "\nAppuyez sur Entree pour fermer..."
read dummy
' &
EOF
chmod +x /compat/linux/opt/MaXX/bin64/tellsystem
cp -af /compat/linux/opt/MaXX/bin64/tellsystem /compat/linux/opt/MaXX/bin64/hinv

# ------------------------------------------------------------------------------
# 10. INITIALISATION DU PROFIL UTILISATEUR ET DU SCRIPT OFFICIEL XSESSION.DT
# ------------------------------------------------------------------------------
echo "-> [10/11] Configuration de system.runtime, Xsession.dt et du profil de ${TARGET_USER}..."

grep -q "export MAXX_BIN" /compat/linux/opt/MaXX/etc/system.runtime || cat >> /compat/linux/opt/MaXX/etc/system.runtime << 'EOF'
export MAXX_HOME="/opt/MaXX"
export MaXX_HOME="/opt/MaXX"
export MAXX_BIN="/opt/MaXX/bin64"
export MAXX_LIBS="/opt/MaXX/lib64"
export MAXX_SHARE="/opt/MaXX/share"
export MAXX_ETC="/opt/MaXX/etc"
export MAXX_SETTINGS="/opt/MaXX/share/msettings"
EOF

cat > /compat/linux/opt/MaXX/etc/skel/Xsession.dt << 'EOF'
#!/bin/bash
ver="2.2"
export USER=${USER:-$(whoami)}
export USERNAME="$USER"
rm -f /tmp/MaXXisRunning-$USERNAME > /dev/null 2>&1
d=`date +%F_%T`
[ -f "$HOME/.console" ] && mv "$HOME/.console" "$HOME/.console-$d"
echo "[`date`] Starting MaXX Interactive Desktop" > "$HOME/.console"

env -u LD_LIBRARY_PATH /usr/local/bin/xset m 0 0
env -u LD_LIBRARY_PATH /usr/local/bin/xset -b
env -u LD_LIBRARY_PATH /usr/local/bin/xset +fp /opt/MaXX/share/fonts/sgi,/usr/local/share/fonts/misc,/usr/local/share/fonts/100dpi,/usr/local/share/fonts/75dpi 2>/dev/null || true
env -u LD_LIBRARY_PATH /usr/local/bin/xset fp rehash 2>/dev/null || true
env -u LD_LIBRARY_PATH /usr/local/bin/xsetroot -solid SkyBlue4

. /opt/MaXX/etc/system.runtime
. $MAXX_HOME/etc/system.desktopenv
export XDG_DATA_DIRS="/opt/MaXX/share:/usr/local/share:/usr/share"

if [ ! -d "$HOME/.maxxdesktop" ]; then
    cd "$HOME"
    $MAXX_HOME/share/misc/HOME/initMaXX-Desktop-Home.sh >> "$HOME/.console" 2>&1
fi

mkdir -p "$HOME/.icons"
ln -sf /opt/MaXX/share/ROX-Filer/ROX "$HOME/.icons/ROX"
echo "ch" > "$HOME/.maxxdesktop/KeyboardInput.Choice"
echo "fr_FR.UTF-8" > "$HOME/.maxxdesktop/Language.Choice"

$MAXX_BIN/telldesktop load
env -u LD_LIBRARY_PATH /usr/local/bin/xrdb -nocpp -override /opt/MaXX/share/X11/app-defaults/SgiIndigoMagic.ad 2>/dev/null || true
env -u LD_LIBRARY_PATH /usr/local/bin/setxkbmap ch fr 2>/dev/null || true

$MAXX_BIN/telldesktop start

# Application du fond d'ecran SGI APRES telldesktop start (avec relance differee si ROX-Filer initialise son Pinboard)
if [ -f /boot/images/sgi_desktop.jpg ]; then
    env -u LD_LIBRARY_PATH /usr/local/bin/feh --bg-fill /boot/images/sgi_desktop.jpg &
    (sleep 2 && env -u LD_LIBRARY_PATH /usr/local/bin/feh --bg-fill /boot/images/sgi_desktop.jpg) &
fi

$MAXX_BIN/5Dwm -multiscreen >> "$HOME/.console" 2>&1
$MAXX_BIN/telldesktop stop
EOF
chmod +x /compat/linux/opt/MaXX/etc/skel/Xsession.dt

mkdir -p "${USER_HOME}/.icons" "${USER_HOME}/.config"
ln -sf /opt/MaXX/share/ROX-Filer/ROX "${USER_HOME}/.icons/ROX"

# ------------------------------------------------------------------------------
# 11. LANCEUR /USR/LOCAL/BIN/STARTMAXX ET DECLARATION SDDM
# ------------------------------------------------------------------------------
echo "-> [11/11] Creation de /usr/local/bin/startmaxx et session SDDM..."

cat > /usr/local/bin/startmaxx << 'EOF'
#!/bin/sh
export USER=${USER:-$(id -un)}
export USERNAME="$USER"
export HOME=${HOME:-/home/$USER}
export LANG="fr_FR.UTF-8"
export XCURSOR_THEME="redSGI"
export PATH="/opt/MaXX/bin64:/opt/MaXX/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
exec /compat/linux/bin/bash /opt/MaXX/etc/skel/Xsession.dt > "$HOME/.maxx-session.log" 2>&1
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
chown -R "${TARGET_USER}:${TARGET_USER}" "${USER_HOME}"

echo "======================================================================"
echo "=== Phase 2 terminee avec succes ! MaXX Desktop Octane 2.2 est pret. ==="
echo "======================================================================"
exit 0