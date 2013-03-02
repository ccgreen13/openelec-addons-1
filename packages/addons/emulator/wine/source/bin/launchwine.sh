#!/bin/sh

# this script is a wrapper to start up an application using wine.
# to get help just run it without any parameters or see the code following
# this comment.. ;-)

#this comment is 80 chars width, just for orientation for the next string.......
HELP="This script makes starting up Wine on OpenELEC easy.
It needs some arguments:
  -f /path/to/executable: This argument is mandatory and has to be an absolute
      path. It is the path to the executable to be run by Wine.
  -k: If this argument is supplied, XBMC will be killed before starting Wine.
      This might be necessary to let Wine access the primary Alsa sound device
      which is otherwise used by XBMC. If you have two sound outputs and Wine
      detects that it cannot use the device configured with winecfg, Wine will
      select another device. In my setup, if I don't kill XBMC which uses the
      AV receiver output, Wine outputs audio to TV using the HDMI connection.
      If -k is not supplied, this script will hide the window of XBMC so that
      Wine gets maximum performance. This is helpful when XBMC is playing music
      with an active visualization in the background.
  -j: This argument specifies the configuration file for joy2key. Google it
      or ask for syntax of this file. If this parameter is supplied, this script
      will start joy2key with the configuration file and kill it when Wine
      exits.
  -t: This argument is mandatory if -j was supplied. It has to be the window
      title of the app started so that joy2key knows where to send keystrokes
      to. To find out the window title of the application which has the focus
      start the application without -j and -t switches, then do
      'xdotool getwindowfocus getwindowname' on the shell."

if [ "$1" == "" ] || [ "$1" == "-help" ] || [ "$1" == "--help" ];
then
    echo "$HELP"
    exit 0
fi

# Initialize/export variables
ADDON_DIR="$HOME/.xbmc/addons/emulator.wine"

export WINELOADER="$ADDON_DIR/bin/wine"
export WINESERVER="$ADDON_DIR/bin/wineserver"
export WINEDLLPATH="$ADDON_DIR/lib/wine:$WINEDLLPATH"
export JOYTOKEY="$ADDON_DIR/bin/joy2key"
export XWININFO="$ADDON_DIR/bin/xwininfo"

WATCHDOGPID=0
KILLXBMC=0
FILEPATH=""
JOYTOKEYRC=""
JOYTOKEYTITLE=""
JOYTOKEYPID=0

# Get some information from the X server
VIDEOOUT=($(xrandr | grep " connected" | tr " ")[1])
RESY="`xrandr -q | grep Screen | awk '{print $10}' | awk -F"," '{ print $1 }'`"
RESX="`xrandr -q | grep Screen | awk '{print $8}'`"

# Parse and validate options
while getopts ":kf:j:t:" opt; do
  case $opt in
    k)
        KILLXBMC=1
        ;;
    f)
        FILEPATH=$OPTARG
        if [ $FILEPATH != "winecfg" ] && [ $FILEPATH != "winecfg.exe" ];
        then
            if [ ! -e "$FILEPATH" ];
            then
                echo "-f: File '$FILEPATH' does not exist."
                exit 1
            fi
            if [ ${FILEPATH:0:1} != "/" ];
            then
                echo "-f: Path to file has to be an absoulte path."
                exit 1
            fi
        fi
        ;;
    t)
        JOYTOKEYTITLE=$OPTARG
        ;;
    j)
        JOYTOKEYRC=$OPTARG
        if [ ! -e "$JOYTOKEYRC" ];
        then
            echo "-j: File '$JOYTOKEYRC' does not exist."
            exit 1
        fi
        ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        exit 1
        ;;
    :)
        echo "Option -$OPTARG requires an argument." >&2
        exit 1
        ;;
  esac
done

# Validate some more options
if [ "$FILEPATH" == "" ];
then
    echo "-f: The filename to launch needs to be specified."
    exit 1
fi

if [ "$JOYTOKEYRC" != "" ] && [ "$JOYTOKEYTITLE" == "" ];
then
    echo "-j: -t needs to be specified, too."
    exit 1
fi

# Kill/hide XBMC
if [ $KILLXBMC -eq 1 ];
then
    /storage/.xbmc/addons/emulator.wine/bin/watchdog.sh &
    touch /var/lock/xbmc.disabled
    killall xbmc.bin

    if [ -e "/dev/watchdog" ];
    then
        (
            while true; do
                echo "." >/dev/watchdog
                sleep 1
            done
        ) &
        WATCHDOGPID=$!
    fi
else
    xdotool search --name "XBMC Media Center" windowunmap
fi

EXEPATH=$(dirname "$FILEPATH")
EXEFILE=$(basename "$FILEPATH")

# Joy2key stuff
if [ "$JOYTOKEYRC" != "" ];
then
    (
        # Wait for the window to appear
        set +e
        while [ 1 ];
        do
            "$XWININFO" -name "$JOYTOKEYTITLE" &>/dev/null
            if [ $? -eq 0 ];
            then
                break
            fi
            sleep 1
        done
        # Start joy2key
        while [ 1 ];
        do
            "$JOYTOKEY" "$JOYTOKEYTITLE" -rcfile "$JOYTOKEYRC" > /tmp/joy2key.log 2>&1
        done
    ) &
    JOYTOKEYPID=$!
fi



# Not needed since we look at the exit code, not the time elapsed
# to retry starting Wine
#STARTED=$(date +%s)
#ENDED=$(date +%s)
#let ELAPSED=$ENDED-$STARTED
#if [ $ELAPSED -lt 5 ];
#then
#    $WINELOADER "$FILEPATH" > /tmp/wine.log 2>&1
#fi



# Since wine does nothing and exits with code 1 on every first subsequent call
# (I have no clue why...) we restart it if it returned -1.
# We assume when Wine returns -1 Wine did exit without staring an application.
cd "$EXEPATH"
$WINELOADER "$FILEPATH" > /tmp/wine.log 2>&1
if [ $? -eq 1 ];
then
    $WINELOADER "$FILEPATH" > /tmp/wine.log 2>&1
fi



# If wine starts a subprocess this should wait for it to finish.
$WINESERVER -w

# this is obsolete if the line above works...
#while grep -q "wineserver" <<< "$(ps)";
#do
#    sleep 1
#done

if [ $JOYTOKEYPID -ne 0 ];
then
    kill -9 $JOYTOKEYPID > /dev/null 2>&1
    killall joy2key > /dev/null 2>&1
    killall xwininfo > /dev/null 2>&1
fi

if [ $WATCHDOGPID -ne 0 ];
then
    kill -9 $WATCHDOGPID > /dev/null 2>&1
fi

if [ $KILLXBMC -eq 0 ];
then
    xdotool search --name "XBMC Media Center" windowmap
fi

xrandr --output "$VIDEOOUT" --mode "$RESX"x"$RESY"

if [ -e "/var/lock/xbmc.disabled" ];
then
    rm /var/lock/xbmc.disabled
fi

