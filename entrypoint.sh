#!/bin/bash
# run a command in an X session via vnc server

APP_COMMAND="$*" # take all args as part of command
if [ -z "$APP_COMMAND" ]; then
  echo "Error: missing command!"
  exit 1
fi

# log everything
set -x

############## Environment variables ##################
WINDOW_WIDTH="${WINDOW_WIDTH:-800}"  # Window Width
WINDOW_HEIGHT="${WINDOW_HEIGHT:-600}"  # Window Height
VNC_PASSWORD="${VNC_PASSWORD:-badpass}"  # vnc password
VNC_PORT="${VNC_PORT:-5900}"  # vnc port
EXTRA_VNC_ARGS="${EXTRA_VNC_ARGS:-}"  # additional arguments for x11vnc
EXTRA_X_ARGS="${EXTRA_X_ARGS:-}"  # additional arguments for X server
PUID="${PUID:-1000}"  # User ID
PGID="${PGID:-1000}"  # Group ID
VIRTUAL_VRAM="${VIRTUAL_VRAM:-192000}"  # need more vram for higher resolutions
REFRESH_RATE="${WINDOW_REFRESH:-60}"  # hz, refresh rate, probably should stick with 60
RUNAS_ROOT="${RUNAS_ROOT:-false}"  # override to "true" to run as root user intead of the non-root user

############## Functions ##################

function kill_pids() {
  # kill -TERM, then wait, for a list of pids in the order given
  for THIS_PID in "$@"; do
    if [ -n "$THIS_PID" ]; then
      echo "killing process: ${THIS_PID}..." >&2
      kill -TERM "$THIS_PID" && wait "$THIS_PID"
    fi
  done
}

function _kill_procs() {
  # handler for killing things off when signal is caught
  #   TODO we should also do the xdotool thing like firefox_wrapper does, to cleanly stop the app
  echo "signal caught, cleaning up processes" >&2
  kill_pids "$PID_APP" "$PID_VNC" "$PID_WM" "$PID_X"
  echo "done with cleanup" >&2
  exit 0
}

function create_user() {
  # create user (name, id, gid)
  local U_NAME="$1"
  local U_ID="$2"
  local G_ID="$3"
  echo "creating user: $U_NAME" >&2
  addgroup -gid "${G_ID}" "$U_NAME"  # create a group with users name and given id
  adduser --system --uid "${U_ID}" --gid "${G_ID}" --disabled-password --home /config --shell /bin/bash -q "$U_NAME"  # create the user with given ids
  addgroup "$U_NAME" tty  # add user to tty group
  chown -R "${U_NAME}":"${U_NAME}" "/config"  # chown the users home folder
}

function create_xorg_conf() {
  # generate a barebones xorg.conf (w, h r, vram, xorg.conf)
  local W_WIDTH="${1:-1024}"  # width in pixels
  local W_HEIGHT="${2:-768}"  # height in pixels
  local W_REFRESH="${3:-60}"  # hz, refresh rate
  local VRAM="${4:-192000}" # need more vram for higher resolutions
  local XORG_CONF_PATH="${5:-/etc/X11/xorg.conf}"
  local NEW_MODENAME="${W_WIDTH}x${W_HEIGHT}"
  local W_DEPTH="24"  # bit depth of display
  echo "generating $XORG_CONF_PATH for resolution: $NEW_MODENAME" >&2
  local NEW_MODELINE
  NEW_MODELINE=$(cvt "$W_WIDTH" "$W_HEIGHT" "$W_REFRESH" | tail -n1 | awk '{print $3 " " $4 " " $5 " " $6 " " $7 " " $8 " " $9 " " $10 " " $11 " " $12 " " $13}' )
  cat << EOF_XORG > "$XORG_CONF_PATH"
  Section "Device"
    Identifier "dummy_videocard"
    Driver "dummy"
    Option "ConstantDPI" "true"
    VideoRam $VRAM
  EndSection

  Section "Monitor"
    Identifier "dummy_monitor"
    HorizSync   5.0 - 1000.0
    VertRefresh 5.0 - 200.0
    Modeline "$NEW_MODENAME" $NEW_MODELINE
  EndSection

  Section "Screen"
    Identifier "dummy_screen"
    Device "dummy_videocard"
    Monitor "dummy_monitor"
    DefaultDepth $W_DEPTH
    SubSection "Display"
      Viewport 0 0
      Depth $W_DEPTH
      Modes "$NEW_MODENAME"
      Virtual $W_WIDTH $W_HEIGHT
    EndSubSection
  EndSection

EOF_XORG
}

function start_dbus() {
  # start dbus, which X needs
  echo "starting dbus" >&2
  eval "$(dbus-launch --sh-syntax)"
}

function keep_screen_awake() {
  # prevent screen from sleeping (start X first)
  echo "making sure X doesnt try to sleep or blank the screen" >&2
  xset s off
  xset s noblank
}


############## Actual startup begins here ##################

# trap signals and call our handler to clean things up
#   usage: trap <callback function> <signals>
trap _kill_procs SIGTERM SIGINT

# create user
DESKTOP_USER="desktopuser"  # to avoid running as root, we will create a new non-root user
create_user "$DESKTOP_USER" "$PUID" "$PGID"

# create xorg.conf
create_xorg_conf "$WINDOW_WIDTH" "$WINDOW_HEIGHT" "$REFRESH_RATE" "$VIRTUAL_VRAM" "/xorg-dummy.conf"

# X needs dbus
start_dbus

# now lets build our virtual framebuffer
echo "starting X"
DISPLAY=":99" # X will create a virtual display with this identifier
# shellcheck disable=SC2086 # ignore unquoted vars (thats how we need it)
X $DISPLAY $EXTRA_X_ARGS -config /xorg-dummy.conf & PID_X=$!  
export DISPLAY

keep_screen_awake

echo "starting vnc server with size: ${WINDOW_WIDTH}x${WINDOW_HEIGHT}"
# shellcheck disable=SC2086 # ignore unquoted vars (thats how we need it)
/usr/bin/x11vnc -rfbport "$VNC_PORT" -safer -passwd "$VNC_PASSWORD" -forever -quiet -scale 1 -display "$DISPLAY" -notruecolor -shared -geometry "${WINDOW_WIDTH}x${WINDOW_HEIGHT}" $EXTRA_VNC_ARGS & PID_VNC=$!

echo "starting matchbox window manager"
/usr/bin/matchbox-window-manager -use_titlebar no -use_cursor no & PID_WM=$!




echo "running command: $APP_COMMAND"

if [ "$RUNAS_ROOT" == "true" ]; then
  # run it as root, skip the non-root user
  $APP_COMMAND & PID_APP=$!
else
  # run as the non-root user we just created
  # preserve environment to keep all the env vars, including DISPLAY
  #   but that means we need to set USER, HOME, SHELL ourselves
  su --preserve-environment -c "export HOME=/config; USER=$DESKTOP_USER; SHELL=/bin/bash; $APP_COMMAND" "$DESKTOP_USER" & PID_APP=$!
fi

# let everything print for a second 
sleep 1
echo "######## app has been started  #########"

wait $PID_APP
echo "######## app exited  #########"
sleep 1
_kill_procs
