#!/bin/sh
# Called by xrdp when a client reconnects to an existing session.
# Recover from "Log Out" / crashed shell leaving a black screen.

if pgrep -u "$(id -u)" -x plasmashell >/dev/null 2>&1; then
  exit 0
fi

export XDG_SESSION_TYPE=x11
export DESKTOP_SESSION=plasma
export XDG_CURRENT_DESKTOP=KDE
export KWIN_COMPOSE=N
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

# Drop dead helpers; keep Xorg (owned by this session)
pkill -u "$(id -un)" -f 'startplasma|plasma_session|plasmashell|ksmserver|kded6|kwin_x11' 2>/dev/null || true
sleep 1

if command -v dbus-run-session >/dev/null 2>&1; then
  nohup dbus-run-session -- startplasma-x11 >/tmp/hml-reconnect-plasma.log 2>&1 &
else
  nohup startplasma-x11 >/tmp/hml-reconnect-plasma.log 2>&1 &
fi
exit 0
