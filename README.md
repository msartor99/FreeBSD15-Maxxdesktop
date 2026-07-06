# MaXX Interactive Desktop on FreeBSD 15 🚀

# july 6 2026 : some adjustment

correction : splash image size, refine start Linux program from MaXX


# june 27 2026 : new version
*The legendary IRIX / Silicon Graphics experience, resurrected on modern UNIX.*

This repository provides two highly optimized, idempotent `bash` scripts to transform a fresh FreeBSD 15 installation into a fully functional, 3D-accelerated workstation featuring the **MaXX Interactive Desktop** (a modern clone of the SGI IRIX environment).

---

## 🌍 Overview / Présentation

These scripts handle the heavy lifting of bridging FreeBSD and Linux subsystems, correcting pathing errors, and configuring X11/Nvidia. 

Ces scripts s'occupent du travail complexe de liaison entre FreeBSD et le sous-système Linux (Linuxulator), corrigent les erreurs de chemins de l'installateur officiel, et configurent X11/Nvidia.

### Features
* **Script 1 (`install-base-system.sh`)**: Base system configuration, X11, Nvidia Drivers, SDDM (IRIX theme), XFCE4 fallback, Audio (Pipewire), Printing, and USB support.
* **Script 2 (`install-maxx-interactive.sh`)**: Direct download of MaXX, smart extraction via Linuxulator, library integration (`ldconfig`), missing utilities, and desktop icon restorations.

---

## 🛠️ Usage / Utilisation

### Requirements
* A fresh installation of **FreeBSD 15.0-RELEASE** (or newer).
* An internet connection.
* An NVIDIA graphics card (configured for the `470` driver in the script, easily modifiable).
* my way to use the script, make install directly on the computer with a USB key, add new user and set member to wheel operator video, run freebsd-update fetch install
* use second computer with WinXX to run putty and connect by ssh,
*  use winSCP to copy install script on the FreeBSD, a run by putty like sh install-base-system.sh and sh install-maxx-interactive.sh

### Step 1: Base System
Run the first script as `root`. This will prepare your system and install the display manager.

doas ./install-base-system.sh

Reboot your machine once the script finishes. You should be greeted by the SDDM login screen.
Step 2: MaXX Environment

Once the base system is running, switch to a TTY (or SSH) and run the second script as root. It is completely idempotent and will safely apply all necessary fixes for MaXX.
Bash

doas ./install-maxx-interactive.sh

Step 3: Enjoy IRIX

Log out or restart the display manager. Select MaXX Interactive Desktop from the SDDM session menu.
🐛 Known Fixes Applied (Script 2)

The official MaXX installer struggles on FreeBSD. This script automatically fixes:
   Bypasses the broken arch dependency by downloading and extracting the .tar.gz manually.
   Creates the missing bin32 symlink required by Xsession.dt.
   Hooks MaXX's SGI Motif and Scheme libraries directly into the Linuxulator via ld.so.conf.d to prevent xset segfaults.
   Restores ROX-Filer visual fidelity by forcing GTK cache updates and setting XDG_DATA_DIRS.


Created by msartor99 and Gemini

have fun!







