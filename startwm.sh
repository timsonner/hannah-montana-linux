#!/bin/sh
# X11 + xrdp session — not Wayland (classic xrdp is X11)
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR
export XDG_SESSION_TYPE=x11
export DESKTOP_SESSION=plasma
export XDG_CURRENT_DESKTOP=KDE
# xorgxrdp has no usable GL — OpenGL/QPainter compose make kwin_x11 exit
# immediately (no titlebars / move / resize). Force compositing off.
export KWIN_COMPOSE=N
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

# Start Plasma (do not exec — we need a watchdog so "Log Out" ends the xrdp session)
if command -v dbus-run-session >/dev/null 2>&1; then
  dbus-run-session -- startplasma-x11 &
else
  startplasma-x11 &
fi
wmpid=$!

# Wait until Plasma is up (or fail after ~60s)
i=0
while [ "$i" -lt 60 ]; do
  if pgrep -u "$(id -u)" -x plasmashell >/dev/null 2>&1; then
    break
  fi
  # startplasma itself died early
  if ! kill -0 "$wmpid" 2>/dev/null; then
    wait "$wmpid"
    exit $?
  fi
  i=$((i + 1))
  sleep 1
done

# Watchdog: if plasmashell disappears (Log Out / crash), tear down so xrdp
# does not reconnect to a black, half-dead session.
while kill -0 "$wmpid" 2>/dev/null; do
  if ! pgrep -u "$(id -u)" -x plasmashell >/dev/null 2>&1; then
    sleep 2
    if ! pgrep -u "$(id -u)" -x plasmashell >/dev/null 2>&1; then
      kill "$wmpid" 2>/dev/null
      # residual session helpers
      pkill -u "$(id -un)" -f 'plasma_|ksmserver|kded6|kwin|kglobalaccel|kactivity' 2>/dev/null || true
      wait "$wmpid" 2>/dev/null
      exit 0
    fi
  fi
  sleep 3
done

wait "$wmpid"
exit $?
