# MaXX Interactive Desktop on FreeBSD 15 🚀
*The legendary IRIX / Silicon Graphics experience, resurrected on modern UNIX.*

This repository provides two highly optimized, idempotent `bash` scripts to transform a fresh FreeBSD 15 installation into a fully functional, 3D-accelerated workstation featuring the **MaXX Interactive Desktop** (a modern clone of the SGI IRIX environment).

---

## 🌍 Overview / Présentation

These scripts handle the heavy lifting of bridging FreeBSD and Linux subsystems, correcting pathing errors, and configuring X11/Nvidia. 

Ces scripts s'occupent du travail complexe de liaison entre FreeBSD et le sous-système Linux (Linuxulator), corrigent les erreurs de chemins de l'installateur officiel, et configurent X11/Nvidia.

### Features
* **Script 1 (`install-base-xfce.sh`)**: Base system configuration, X11, Nvidia Drivers, SDDM (NASA theme), XFCE4 fallback, Audio (Pipewire), Printing, and USB support.
* **Script 2 (`install-maxx-interactive.sh`)**: Direct download of MaXX, smart extraction via Linuxulator, library integration (`ldconfig`), missing utilities, and desktop icon restorations.

---

## 🛠️ Usage / Utilisation

### Requirements
* A fresh installation of **FreeBSD 15.0-RELEASE** (or newer).
* An internet connection.
* An NVIDIA graphics card (configured for the `470` driver in the script, easily modifiable).

### Step 1: Base System
Run the first script as `root`. This will prepare your system and install the display manager.
```bash
doas ./install-base-xfce.sh

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

Created by msartor99.





# FreeBSD15-Maxxdesktop

Here is an installation script for Maxx Desktop Interactive on FreeBSD 15. This script was created with the help of Gemini AI, based on the original installation script for CentOS/Red Hat/Rocky Linux provided by Eric Masson. The work was long and difficult. The system installs linux-rl9 and all its dependencies, but this version is operational with some limitations.

Here's how to download and run it.

fetch -o install_maxx_desktop.sh https://raw.githubusercontent.com/msartor99/FreeBSD15-Maxxdesktop/main/install_maxx_desktop.sh && chmod +x install_maxx_desktop.sh && ./install_maxx_desktop.sh

Many thanks again to Eric Masson for his work and all his efforts.



Here is the link to the original web page.

https://docs.maxxinteractive.com/

Have fun!


