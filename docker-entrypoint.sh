#!/bin/bash
set -e

mkdir -p /run/dbus /var/run/xrdp /var/log /tmp/.X11-unix /run/user/1000
chmod 1777 /tmp /tmp/.X11-unix 2>/dev/null || true
rm -f /tmp/.X11-unix/X* /tmp/.X*-lock 2>/dev/null || true
rm -f /run/dbus/pid /var/run/xrdp/*.pid /var/run/xrdp-sesman.pid 2>/dev/null || true

# wslc/docker often ship an empty or broken resolv.conf → apt/ping can't resolve.
# If DNS is dead, install public resolvers (skip if --dns already set a working one).
if ! getent hosts deb.debian.org >/dev/null 2>&1; then
  if [ -w /etc/resolv.conf ] || [ ! -e /etc/resolv.conf ]; then
    cat >/etc/resolv.conf <<'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF
  fi
fi

if id hmluser >/dev/null 2>&1; then
  # Clear leftover RDP/Plasma state from a previous container life
  pkill -9 -u hmluser 2>/dev/null || true
  rm -f /home/hmluser/.xorgxrdp.*.log /tmp/hml-reconnect-plasma.log 2>/dev/null || true
  chown -R hmluser:hmluser /home/hmluser 2>/dev/null || true
  chown hmluser:hmluser /run/user/1000 2>/dev/null || true
  chmod 700 /run/user/1000 2>/dev/null || true
fi

# System bus (Plasma / session helpers)
if [ ! -S /run/dbus/system_bus_socket ]; then
  dbus-daemon --system --fork || true
fi

# xrdp stack
pgrep -x xrdp-sesman >/dev/null 2>&1 || xrdp-sesman || true
pgrep -x xrdp >/dev/null 2>&1 || xrdp || true

echo "Hannah Montana Linux (container) — RDP on port 3389"
echo "  user: hmluser"
echo "  pass: hmluser"
echo "  Best of both worlds."

# Keep container alive; replace with custom command if provided
if [ "$#" -gt 0 ]; then
  exec "$@"
fi
exec sleep infinity
