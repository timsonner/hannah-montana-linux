# Hannah Montana Linux (container edition)
# Branding from HML26 (Noah Cagle) + Debian trixie + Plasma + xrdp
# Build:  wslc build -t hml26:rdp .
#         docker build -t <dockerhub username>/hannah-montana-linux:rdp .
# Run:    wslc run -d --name hml-rdp -p 13391:3389 hml26:rdp

FROM debian:trixie-slim

LABEL org.opencontainers.image.title="Hannah Montana Linux (RDP)"
LABEL org.opencontainers.image.description="Silly HML26-themed Debian/KDE Plasma desktop over RDP — container edition"
# Packaging repo (helps GHCR link the package). Branding origin: HML26 on GitLab.
LABEL org.opencontainers.image.source="https://github.com/timsonner/hannah-montana-linux"
LABEL org.opencontainers.image.licenses="GPL-3.0-or-later"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Desktop + RDP stack (no live-boot, no Calamares, no kernel/firmware)
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        sudo passwd adduser \
        dbus dbus-x11 \
        xrdp xorgxrdp \
        xorg xserver-xorg-core xserver-xorg-input-all \
        xserver-xorg-video-all xauth x11-xserver-utils \
        plasma-desktop plasma-workspace \
        kwin-x11 \
        systemsettings dolphin konsole \
        plasma-nm plasma-pa breeze breeze-icon-theme \
        fonts-noto fonts-noto-color-emoji \
        fastfetch \
        # Networking: stacks + diagnostics (image previously only had curl/ip/net-tools)
        iproute2 procps net-tools curl wget \
        iputils-ping iputils-tracepath traceroute \
        bind9-dnsutils bind9-host \
        netcat-openbsd \
        ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# HML branding (themes, wallpapers, skel, os-release)
COPY branding/ /

# Default session user (RDP login)
RUN useradd -m -s /bin/bash -G sudo hmluser \
    && echo 'hmluser:hmluser' | chpasswd \
    && echo 'hmluser ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/hmluser \
    && chmod 440 /etc/sudoers.d/hmluser \
    # Apply skel (HML configs) onto the user home
    && cp -a /etc/skel/. /home/hmluser/ \
    && chown -R hmluser:hmluser /home/hmluser \
    && printf '%s\n' '#!/bin/sh' 'exec startplasma-x11' > /home/hmluser/.xsession \
    && chown hmluser:hmluser /home/hmluser/.xsession \
    && chmod +x /home/hmluser/.xsession

# xrdp is X11 (not Wayland). startwm watchdog ends session after Plasma logout.
COPY startwm.sh /etc/xrdp/startwm.sh
COPY reconnectwm.sh /etc/xrdp/reconnectwm.sh
RUN chmod +x /etc/xrdp/startwm.sh /etc/xrdp/reconnectwm.sh \
    && mkdir -p /etc/X11 \
    && printf '%s\n' 'allowed_users=anybody' 'needs_root_rights=yes' > /etc/X11/Xwrapper.config \
    # Drop half-dead sessions on disconnect so reconnect is not a black screen
    && sed -i 's/^KillDisconnected=.*/KillDisconnected=true/' /etc/xrdp/sesman.ini \
    && sed -i 's/^DisconnectedTimeLimit=.*/DisconnectedTimeLimit=0/' /etc/xrdp/sesman.ini

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 3389

# Health: xrdp listening (best-effort)
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD bash -c 'ss -lntp 2>/dev/null | grep -q 3389 || exit 1'

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD []
