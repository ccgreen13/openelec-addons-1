openelec-wine
=============

This repository contains stuff to build Wine as a package for OpenELEC. It is in a very early stage but I will improve it. This repo includes Wine, some tools (joy2key, xwininfo, xdotool, xev) and a script to launch wine (launchwine.sh). The script launches applications/games and does some more. It can start joy2key using a game-specific configuration file, it can kill XBMC or hide the window for optimal sound output/performance (if music is playing in XBMC in the background with visualization), it takes care of resetting the screen resolution to the original values when the game exits and it feeds OpenELEC's watchdog if it needs to.
Additionally there are two "example launchers" included to start games from XBMC's "Programs" menu.

Everything is only tested on x86 OpenELEC installations.

The thread on openelec.tv can be found here: http://openelec.tv/forum/128-addons/62660-wine-for-x86#64622
