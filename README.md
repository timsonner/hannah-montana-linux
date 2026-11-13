# Hannah Montana Linux: container edition (RDP)

A Debian container that serves a KDE Plasma (X11) desktop over xrdp, with the Hannah Montana Linux 26 look (themes, icons, wallpapers, and skel files).

The image is `debian:trixie-slim` plus the desktop packages in the `Dockerfile`, the files under `branding/`, and three session scripts (`docker-entrypoint.sh`, `startwm.sh`, `reconnectwm.sh`). Build it yourself, or pull the public image `ghcr.io/timsonner/hannah-montana-linux:rdp`. Connect with any RDP client.

Branding comes from [Hannah Montana Linux v26](https://gitlab.com/DecaCagle/HannahMontanaLinux26) (`branding/etc/os-release` names that project). This repository is the container packaging. It is not affiliated with Disney or the Hannah Montana franchise.

The longer recipe, including how `branding/` was assembled, is in [GUIDE.md](./GUIDE.md).

## Prerequisites

- A container engine that can build a Dockerfile: Docker, Podman, or [wslc](https://learn.microsoft.com/en-us/windows/wsl/wsl-container) on Windows.
- Git, if you are building from this repository.
- An RDP client. On Windows, `mstsc` is enough.
- Network access during the image build. The `Dockerfile` installs Plasma, `kwin-x11`, xrdp, and networking tools with `apt`.
- Enough free memory for a Plasma session. The run examples below cap the container at 4 GB, which is the limit recorded in `GUIDE.md`.

There is no language runtime or package manager to install in this repo. The product is the container image.

## Install, build, run, and test

### Pull the published image

The public GitHub Container Registry package has one tag: `rdp`.

Docker:

```bash
docker pull ghcr.io/timsonner/hannah-montana-linux:rdp
docker run -d --name hml-rdp -p 13391:3389 -m 4g ghcr.io/timsonner/hannah-montana-linux:rdp
```

Podman (same flags):

```bash
podman pull ghcr.io/timsonner/hannah-montana-linux:rdp
podman run -d --name hml-rdp -p 13391:3389 -m 4g ghcr.io/timsonner/hannah-montana-linux:rdp
```

wslc (PowerShell):

```powershell
wslc pull ghcr.io/timsonner/hannah-montana-linux:rdp
wslc run -d --name hml-rdp -p 13391:3389 -m 4G ghcr.io/timsonner/hannah-montana-linux:rdp
```

`-p 13391:3389` publishes container port 3389 (`EXPOSE` in the `Dockerfile`) on host port 13391. Pick another host port if 13391 is taken, for example `-p 13392:3389`.

### Build from this repository

```bash
git clone https://github.com/timsonner/hannah-montana-linux.git
cd hannah-montana-linux
docker build -t hml26:rdp .
docker run -d --name hml-rdp -p 13391:3389 -m 4g hml26:rdp
```

Podman:

```bash
podman build -t hml26:rdp .
podman run -d --name hml-rdp -p 13391:3389 -m 4g hml26:rdp
```

wslc (PowerShell), from the directory that contains the `Dockerfile`:

```powershell
wslc build -t hml26:rdp .
wslc run -d --name hml-rdp -p 13391:3389 -m 4G hml26:rdp
```

The local tag `hml26:rdp` matches the build comment in the `Dockerfile`. The first build downloads a full desktop stack.

Optional home directory (survives container replacement). Docker example:

```bash
docker run -d --name hml-rdp -p 13391:3389 -m 4g -v hml-rdp-home:/home/hmluser hml26:rdp
```

PowerShell with wslc, using a folder on the host:

```powershell
wslc run -d --name hml-rdp -p 13391:3389 -m 4G -v "$env:USERPROFILE\hml-rdp-home:/home/hmluser" hml26:rdp
```

If name lookup fails at start, `docker-entrypoint.sh` writes public resolvers into `/etc/resolv.conf` when that file is writable. You can also pass `--dns` on `docker run`, `podman run`, or `wslc run`.

### Tests

This repository has no test suite and no CI workflow.

The shell scripts can be syntax-checked from the repo root:

```bash
bash -n docker-entrypoint.sh
sh -n startwm.sh
sh -n reconnectwm.sh
```

After a container is running, the image `HEALTHCHECK` succeeds when `ss` shows a listener on port 3389:

```bash
docker inspect --format '{{json .State.Health}}' hml-rdp
```

Use `podman inspect` or `wslc inspect` with the same format if that is your engine. xrdp process and session logs:

```bash
docker exec hml-rdp bash -lc "pgrep -a xrdp; tail -80 /var/log/xrdp-sesman.log; tail -80 /var/log/xrdp.log"
```

## Usage

Connect to the host port you published.

| Field | Value |
|---|---|
| Address | `127.0.0.1:13391` |
| Username | `hmluser` |
| Password | `hmluser` |

Windows:

```powershell
mstsc /v:127.0.0.1:13391
```

The account is created in the `Dockerfile` (`hmluser` in the `sudo` group, passwordless `sudo`). Change the password before anyone other than you can reach the port:

```bash
docker exec -u hmluser hml-rdp passwd
```

Do not publish port 3389 on a public address while the password is still `hmluser`.

Stop and start the same container:

```bash
docker stop hml-rdp
docker start hml-rdp
```

```powershell
wslc stop hml-rdp
wslc start hml-rdp
```

Closing the RDP window disconnects. The image sets `KillDisconnected=true` in `/etc/xrdp/sesman.ini`, so that session is torn down. Logging out of Plasma also ends the session: `startwm.sh` exits after `plasmashell` is gone. Sign in again for a new desktop. If a client reconnects to a session whose shell has already died, `reconnectwm.sh` starts Plasma again.

The session is X11 (`startplasma-x11` and `kwin-x11`). `startwm.sh` sets `KWIN_COMPOSE=N` because OpenGL compositing does not work under xorgxrdp. Window button defaults live in `branding/etc/skel/.config/kwinrc` and `branding/etc/xdg/kwinrc`.

On start, the entrypoint prints the RDP port and the default user and password, starts dbus and xrdp if they are not already running, then sleeps so the container stays up. A command passed to `docker run` replaces that sleep.

Remove a stopped container before reusing the name:

```bash
docker rm -f hml-rdp
```

## Layout

```text
.
├── Dockerfile              # debian:trixie-slim, packages, user, xrdp, healthcheck
├── docker-entrypoint.sh    # DNS fallback, dbus, xrdp, keep-alive
├── startwm.sh              # Plasma on X11, compositing off, logout watchdog
├── reconnectwm.sh          # Restart Plasma when a client reconnects to a dead shell
├── branding/               # Themes, icons, wallpapers, skel, os-release, kwin/dolphin defaults
├── GUIDE.md                # Full build and publish recipe
├── README.md               # This file
├── .dockerignore
└── .gitignore
```

`branding/etc/os-release` identifies the desktop as Hannah Montana Linux 26. `branding/usr/share/` holds color schemes, icons, Plasma themes, and wallpapers. `.dockerignore` leaves markdown and Calamares files out of the build context.

## License

The image label in the `Dockerfile` is `GPL-3.0-or-later`. Branding files are from Hannah Montana Linux v26, which that project distributes under GPL-3.0-or-later. This repository has no separate `LICENSE` file. Debian packages in the image keep their own licenses.
