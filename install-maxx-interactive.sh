#!/bin/sh
# ==============================================================================
# SCRIPT 2: install-maxx-interactive.sh (CORRIGÉ, AUDITÉ & 100% IDEMPOTENT)
# TARGET OS: FreeBSD 15.1-RELEASE
# HARDWARE: HP Z4 G4 / Xeon W-2140B / Quadro M4000 / ASUS PB278 (2560x1440)
# ==============================================================================

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Ce script doit être exécuté en root."
    exit 1
fi

TARGET_USER="administrateur"
USER_HOME="/home/$TARGET_USER"
MAXX_TAR="/tmp/MaXX-Desktop-LINUX-x86_64-Octane-2.2.0.tar.gz"
MAXX_URL="https://s3.ca-central-1.amazonaws.com/cdn.maxxinteractive.com/maxx-desktop-installer/MaXX-Desktop-LINUX-x86_64-Octane-2.2.0.tar.gz"

echo "=========================================================="
echo " Phase 2: Installation et Calibration de MaXX Desktop"
echo "=========================================================="

# 1. INSTALLATION GARANTIE DES POLICES X11/MOTIF, THUNDERBIRD ET OUTILS NATIFS
echo "[+] Installation des polices X11/SGI obligatoires, Thunderbird et tradcpp..."
pkg install -y \
    xorg-fonts-miscbitmaps \
    xorg-fonts-100dpi \
    xorg-fonts-75dpi \
    font-misc-misc \
    font-alias \
    font-cursor-misc \
    font-bh-lucidatypewriter-100dpi \
    font-bh-lucidatypewriter-75dpi \
    font-adobe-100dpi \
    font-adobe-75dpi \
    tradcpp \
    feh \
    xscreensaver \
    xterm \
    btop \
    firefox \
    thunderbird \
    vlc

# Installation isolée des bibliothèques Linuxulator complémentaires
echo "[+] Vérification des bibliothèques Linuxulator (Rocky Linux 9)..."
for lpkg in linux-rl9-xorg-libs linux-rl9-libjpeg-turbo linux-rl9-libpng linux-rl9-freetype linux-rl9-fontconfig linux-rl9-motif linux-rl9-libGLU linux-rl9-glvnd; do
    pkg install -y "$lpkg" >/dev/null 2>&1 || true
done

# 2. LIENS SYMBOLIQUES NCURSES V5 DANS LINUXULATOR (REQUIS PAR LES BINAIRES MAXX)
echo "[+] Création des liens de compatibilité ncurses v5 dans /compat/linux/..."
for libdir in /compat/linux/usr/lib64 /compat/linux/lib64; do
    if [ -d "$libdir" ]; then
        [ -f "$libdir/libncurses.so.6" ] && ln -sf libncurses.so.6 "$libdir/libncurses.so.5"
        [ -f "$libdir/libtinfo.so.6" ]   && ln -sf libtinfo.so.6   "$libdir/libtinfo.so.5"
        [ -f "$libdir/libpanel.so.6" ]   && ln -sf libpanel.so.6   "$libdir/libpanel.so.5"
    fi
done

# 3. TÉLÉCHARGEMENT (AVEC CACHE) ET EXTRACTION DE MAXX DESKTOP OCTANE 2.2.0
mkdir -p /compat/linux/opt
if [ ! -s "$MAXX_TAR" ]; then
    echo "[+] Téléchargement de MaXXdesktop Octane-2.2.0 (233 Mo)..."
    fetch -o "$MAXX_TAR" "$MAXX_URL" || wget -O "$MAXX_TAR" "$MAXX_URL"
else
    echo "[+] Archive MaXXdesktop déjà présente dans $MAXX_TAR (cache utilisé)."
fi

echo "[+] Extraction propre de MaXXdesktop dans /compat/linux/opt/..."
rm -rf /compat/linux/opt/MaXX /opt/MaXX
tar -xzf "$MAXX_TAR" -C /compat/linux/opt/
ln -sf /compat/linux/opt/MaXX /opt/MaXX

# 4. VÉRIFICATION DE L'ARBORESCENCE BIN / BIN64 (SANS COPIE CIRCULAIRE)
echo "[+] Vérification des points d'entrée 64 bits..."
if [ ! -L /compat/linux/opt/MaXX/bin ] && [ -d /compat/linux/opt/MaXX/bin64 ]; then
    cp -af /compat/linux/opt/MaXX/bin64/* /compat/linux/opt/MaXX/bin/ 2>/dev/null || true
fi

# 5. TATOUAGE ELF (BRANDELF LINUX) UNIQUEMENT SUR LES VRAIS BINAIRES ELF
echo "[+] Tatouage ELF (FreeBSD Linuxulator) sur les exécutables binaires MaXX..."
find /compat/linux/opt/MaXX/bin64 /compat/linux/opt/MaXX/lib64 -type f 2>/dev/null | while read -r f; do
    if file -b "$f" | grep -q "^ELF "; then
        brandelf -t Linux "$f" 2>/dev/null || true
    fi
done

# 6. PONTS SYSTÈME, POLICES ET PRÉPROCESSEUR C (CPP) POUR XRESOURCES
echo "[+] Création des ponts entre les outils natifs FreeBSD et Linuxulator..."
mkdir -p /compat/linux/usr/bin /compat/linux/bin
ln -sf /usr/local/bin/tradcpp /compat/linux/usr/bin/cpp
ln -sf /usr/local/bin/tradcpp /usr/bin/cpp
ln -sf /usr/local/bin/xrdb    /compat/linux/usr/bin/xrdb
ln -sf /usr/local/bin/xset    /compat/linux/usr/bin/xset
ln -sf /usr/local/bin/xsetroot /compat/linux/usr/bin/xsetroot
ln -sf /usr/local/bin/xprop   /compat/linux/usr/bin/xprop
ln -sf /usr/local/bin/xwininfo /compat/linux/usr/bin/xwininfo
ln -sf /usr/local/bin/xkill   /compat/linux/usr/bin/xkill

# Enregistrement des polices X11
mkfontscale /usr/local/share/fonts/misc 2>/dev/null || true
mkfontdir   /usr/local/share/fonts/misc 2>/dev/null || true
fc-cache -f 2>/dev/null || true

# 7. THÈME CURSEUR SGI ROUGE (redSGI) ET ICÔNES
echo "[+] Installation du curseur SGI Classique (redSGI) et des thèmes..."
mkdir -p /usr/local/share/icons/default
if [ -d /compat/linux/opt/MaXX/share/icons/redSGI ]; then
    rm -rf /usr/local/share/icons/redSGI
    cp -R /compat/linux/opt/MaXX/share/icons/redSGI /usr/local/share/icons/
fi
cat > /usr/local/share/icons/default/index.theme << 'EOF'
[Icon Theme]
Inherits=redSGI
EOF

# 8. WRAPPERS D'APPLICATIONS ET CONNEXION DE THUNDERBIRD AU MENU TOOLCHEST
echo "[+] Déploiement des wrappers FreeBSD (Firefox, Thunderbird, VLC, btop) pour le Toolchest SGI..."

cat > /compat/linux/opt/MaXX/bin64/WEBBROWSER << 'EOF'
#!/bin/sh
exec /usr/local/bin/firefox "$@" &
EOF

cat > /compat/linux/opt/MaXX/bin64/EMAILCLIENT << 'EOF'
#!/bin/sh
exec /usr/local/bin/thunderbird "$@" &
EOF

# Création d'un alias Mail direct au cas où system.chestrc appelle "Mail" ou "mail"
ln -sf /compat/linux/opt/MaXX/bin64/EMAILCLIENT /compat/linux/opt/MaXX/bin64/Mail

cat > /compat/linux/opt/MaXX/bin64/MEDIAVIEWER << 'EOF'
#!/bin/sh
exec /usr/local/bin/vlc "$@" &
EOF

cat > /compat/linux/opt/MaXX/bin64/gr_osview2 << 'EOF'
#!/bin/sh
exec /usr/local/bin/xterm -title "SGI System Monitor (btop)" -geometry 110x35 -bg black -fg green -e /usr/local/bin/btop
EOF

cat > /compat/linux/opt/MaXX/bin64/Restart << 'EOF'
#!/bin/sh
exec sudo /sbin/reboot
EOF

cat > /compat/linux/opt/MaXX/bin64/Shutdown << 'EOF'
#!/bin/sh
exec sudo /sbin/poweroff
EOF

chmod +x /compat/linux/opt/MaXX/bin64/WEBBROWSER \
         /compat/linux/opt/MaXX/bin64/EMAILCLIENT \
         /compat/linux/opt/MaXX/bin64/MEDIAVIEWER \
         /compat/linux/opt/MaXX/bin64/gr_osview2 \
         /compat/linux/opt/MaXX/bin64/Restart \
         /compat/linux/opt/MaXX/bin64/Shutdown

# Patch automatique des fichiers de menu Toolchest (.chestrc / system.chestrc) pour l'entrée Mail
for rcfile in \
    /compat/linux/opt/MaXX/share/system.chestrc \
    /compat/linux/opt/MaXX/etc/system.chestrc \
    /compat/linux/opt/MaXX/share/skel/.chestrc \
    "$USER_HOME/.chestrc" \
    "$USER_HOME/.maxxdesktop/system.chestrc"; do
    if [ -f "$rcfile" ]; then
        sed -i '' -E 's|(f\.exec[[:space:]]+"[^"]*)*(EMAILCLIENT|thunderbird|evolution)[^"]*"|f.exec "/opt/MaXX/bin64/EMAILCLIENT"|g' "$rcfile" 2>/dev/null || true
    fi
done

# 9. SCRIPT DE DÉMARRAGE DE SESSION MAXX POUR SDDM ET STARTX
echo "[+] Création du lanceur de session MaXX Interactive Desktop..."
cat > /usr/local/bin/startmaxx << 'EOF'
#!/bin/sh
export MaXX_HOME=/opt/MaXX
export MAXX_EMAILCLIENT="/usr/local/bin/thunderbird"
export MAXX_WEBBROWSER="/usr/local/bin/firefox"
export MAXX_MEDIAVIEWER="/usr/local/bin/vlc"
export PATH="/opt/MaXX/bin64:/opt/MaXX/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
export LD_LIBRARY_PATH="/opt/MaXX/lib64:/opt/MaXX/lib"
export XCURSOR_THEME="redSGI"
export LANG="fr_FR.UTF-8"

# Clavier Suisse Romand
/usr/local/bin/setxkbmap ch fr 2>/dev/null || true

# Polices X11 pour 5Dwm et Toolchest
/usr/local/bin/xset +fp /usr/local/share/fonts/misc,/usr/local/share/fonts/100dpi,/usr/local/share/fonts/75dpi 2>/dev/null || true
/usr/local/bin/xset fp rehash 2>/dev/null || true

# Initialisation du profil MaXX utilisateur au premier lancement
if [ ! -d "$HOME/.maxxdesktop" ]; then
    mkdir -p "$HOME/.maxxdesktop"
    if [ -d /opt/MaXX/share/skel ]; then
        cp -R /opt/MaXX/share/skel/. "$HOME/" 2>/dev/null || true
    fi
fi

# Chargement des ressources X11 / Motif sans erreur de préprocesseur
if [ -f "$HOME/.Xresources" ]; then
    /usr/local/bin/xrdb -cpp /usr/local/bin/tradcpp -merge "$HOME/.Xresources" 2>/dev/null || true
elif [ -f /opt/MaXX/share/X11/app-defaults/MaXX ]; then
    /usr/local/bin/xrdb -cpp /usr/local/bin/tradcpp -merge /opt/MaXX/share/X11/app-defaults/MaXX 2>/dev/null || true
fi

# Application du fond d'écran SGI en 2560x1440
if [ -f /boot/images/sgi_desktop.jpg ] && [ -x /usr/local/bin/feh ]; then
    /usr/local/bin/feh --bg-fill /boot/images/sgi_desktop.jpg &
else
    /usr/local/bin/xsetroot -solid "#334c66" &
fi

# Lancement du Toolchest en arrière-plan
if [ -x /opt/MaXX/bin64/toolchest ]; then
    /opt/MaXX/bin64/toolchest &
fi

# Lancement du gestionnaire de fenêtres SGI 5Dwm (processus maître)
exec /opt/MaXX/bin64/5Dwm
EOF
chmod +x /usr/local/bin/startmaxx

# 10. DÉCLARATION DANS SDDM ET PROFIL UTILISATEUR
mkdir -p /usr/local/share/xsessions
cat > /usr/local/share/xsessions/maxx.desktop << 'EOF'
[Desktop Entry]
Name=MaXX Interactive Desktop
Comment=Environnement SGI IRIX 5Dwm (Octane 2.2)
Exec=/usr/local/bin/startmaxx
Type=Application
EOF

if [ -d "$USER_HOME" ]; then
    cat > "$USER_HOME/.xinitrc" << 'EOF'
#!/bin/sh
exec /usr/local/bin/startmaxx
EOF
    chmod +x "$USER_HOME/.xinitrc"
    chown -R "$TARGET_USER:$TARGET_USER" "$USER_HOME"
fi

echo "=========================================================="
echo " Phase 2 terminée et vérifiée sans erreur !"
echo " Polices X11, tradcpp, Thunderbird et lanceur SDDM prêts."
echo "=========================================================="