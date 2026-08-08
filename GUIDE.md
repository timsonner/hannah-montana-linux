# Hannah Montana Linux — container edition

Exact recipe used to build the RDP desktop image with **`wslc`** on Windows.

---

## What this is (one sentence)

**`debian:trixie-slim` + apt (KDE Plasma, xrdp, networking tools) + Hannah Montana Linux v26 branding files (from the HML git repo) + small session scripts.**

It is **not** the HML live ISO, not `live-build`, and not a squashfs import.

| Piece | Source |
|---|---|
| Base OS | Official Docker image `debian:trixie-slim` (Debian 13) |
| Desktop + RDP | Installed with `apt` in the Dockerfile |
| Look / themes / skel | Copied from [HML26](https://gitlab.com/DecaCagle/HannahMontanaLinux26) `config/includes.chroot/` into `branding/` |
| xrdp usability configs | **Ours** (not in HML): `kwinrc`, `dolphinrc` under `branding/` — see Step 1b |
| RDP user | `hmluser` / `hmluser` (created in Dockerfile; home filled from skel) |

---

## Project layout

```text
hml-rdp/
├── Dockerfile              # Image recipe
├── docker-entrypoint.sh    # DNS fallback, dbus, xrdp, keep-alive
├── startwm.sh              # Plasma session + KWIN_COMPOSE=N + logout watchdog
├── reconnectwm.sh          # Reconnect helper if shell died
├── branding/               # HML26 includes.chroot + our xrdp-only config files (Step 1b)
├── README.md               # Short quick start
└── GUIDE.md                # This file
```

---

## Step 1 — Clone HML26 and copy branding (from upstream)

```powershell
cd $env:USERPROFILE
git clone https://gitlab.com/DecaCagle/HannahMontanaLinux26
mkdir hml-rdp
```

Copy the live-build **chroot overlay** (not the whole repo) into the image build context:

```powershell
# From PowerShell
$src = "$env:USERPROFILE\HannahMontanaLinux26\config\includes.chroot"
$dst = "$env:USERPROFILE\hml-rdp\branding"
robocopy $src $dst /E

# Optional: drop installer-only bits (Calamares)
Remove-Item -Recurse -Force "$dst\etc\calamares" -ErrorAction SilentlyContinue
Remove-Item -Force "$dst\usr\share\applications\calamares-install-debian.desktop" -ErrorAction SilentlyContinue
```

### What comes from HML26 (upstream)

These are in `config/includes.chroot` and make it “look like Hannah Montana Linux”:

| Path under `branding/` | Role |
|---|---|
| `etc/os-release` | Distro name “Hannah Montana Linux 26” |
| `etc/skel/.config/kdedefaults/`, `kdeglobals`, … | PrettyPink colors, HannahMontana icons, plasma defaults |
| `usr/share/color-schemes/PrettyPink*` | Color schemes |
| `usr/share/icons/HannahMontana*` | Icon theme |
| `usr/share/plasma/…` | Look-and-feel + desktop theme |
| `usr/share/wallpapers/HannahMontanaTheme` | Wallpaper |

Upstream does **not** ship the three files in Step 1b.

---

## Step 1b — Container-only configs we add (not from HML)

**Source: this project / xrdp packaging — not the original HML26 repo.**

After copying branding (Step 1), create these files yourself (or keep them as we maintain them under `hml-rdp/branding/`). They fix usability over **xrdp + xorgxrdp** (KWin compositing, titlebar buttons, Dolphin menu). You can skip them and still have HML themes, but windows may not move/close correctly and Dolphin may hide File → Quit.

### Why

| Problem without these files | What we set |
|---|---|
| KWin may try OpenGL, exit, no move/resize/close | Compositing off + buttons `IAX` |
| Dolphin had menu bar disabled in some sessions | Force menu bar on |

Titlebar letters: **I** = minimize, **A** = maximize, **X** = close.

Also pair with **`KWIN_COMPOSE=N`** in `startwm.sh` and package **`kwin-x11`** (Step 2 / Step 7) — the files below alone are not enough if KWin never starts.

### File 1 — `branding/etc/skel/.config/kwinrc`

Copied into every new user’s home (and applied to `hmluser` via `cp -a /etc/skel/. …` in the Dockerfile).

```ini
[Compositing]
Enabled=false
Backend=QPainter
OpenGLIsUnsafe=true

[org.kde.kdecoration2]
ButtonsOnLeft=
ButtonsOnRight=IAX
library=org.kde.breeze
theme=Breeze
BorderSize=Normal

[Windows]
BorderlessMaximizedWindows=false
TitlebarDoubleClickCommand=Maximize

[Desktops]
Number=1
Rows=1
```

### File 2 — `branding/etc/xdg/kwinrc`

System-wide defaults (same idea for any user / first session).

```ini
# System-wide defaults (xrdp / xorgxrdp has no working GL)
[Compositing]
Enabled=false
OpenGLIsUnsafe=true

[org.kde.kdecoration2]
ButtonsOnLeft=
ButtonsOnRight=IAX
library=org.kde.breeze
theme=Breeze
BorderSize=Normal

[Windows]
BorderlessMaximizedWindows=false
```

### File 3 — `branding/etc/skel/.config/dolphinrc`

```ini
[General]
Version=202
# Show menu bar so File → Quit is always available
ShowMenuBar=true

[MainWindow]
MenuBar=Enabled
ToolBarsMovable=Disabled
```

### Create them from PowerShell (optional one-shot)

```powershell
$base = "$env:USERPROFILE\hml-rdp\branding"
New-Item -ItemType Directory -Force -Path "$base\etc\skel\.config" | Out-Null
New-Item -ItemType Directory -Force -Path "$base\etc\xdg" | Out-Null

@'
[Compositing]
Enabled=false
Backend=QPainter
OpenGLIsUnsafe=true

[org.kde.kdecoration2]
ButtonsOnLeft=
ButtonsOnRight=IAX
library=org.kde.breeze
theme=Breeze
BorderSize=Normal

[Windows]
BorderlessMaximizedWindows=false
TitlebarDoubleClickCommand=Maximize

[Desktops]
Number=1
Rows=1
'@ | Set-Content -NoNewline -Encoding utf8 "$base\etc\skel\.config\kwinrc"

@'
# System-wide defaults (xrdp / xorgxrdp has no working GL)
[Compositing]
Enabled=false
OpenGLIsUnsafe=true

[org.kde.kdecoration2]
ButtonsOnLeft=
ButtonsOnRight=IAX
library=org.kde.breeze
theme=Breeze
BorderSize=Normal

[Windows]
BorderlessMaximizedWindows=false
'@ | Set-Content -NoNewline -Encoding utf8 "$base\etc\xdg\kwinrc"

@'
[General]
Version=202
ShowMenuBar=true

[MainWindow]
MenuBar=Enabled
ToolBarsMovable=Disabled
'@ | Set-Content -NoNewline -Encoding utf8 "$base\etc\skel\.config\dolphinrc"
```

(Prefer LF line endings in the image; if you edit on Windows, the Docker build still usually works.)

---

## Step 2 — Dockerfile (what the image does)

High-level stages in `Dockerfile`:

```dockerfile
FROM debian:trixie-slim

# 1) Install desktop + RDP + networking tools
RUN apt-get update && apt-get install -y --no-install-recommends \
      … plasma-desktop plasma-workspace kwin-x11 \
      xrdp xorgxrdp … \
      iproute2 curl wget iputils-ping traceroute \
      bind9-dnsutils netcat-openbsd …

# 2) Overlay HML branding onto the root filesystem
COPY branding/ /

# 3) Create RDP user and apply HML skel
RUN useradd -m -s /bin/bash -G sudo hmluser \
 && echo 'hmluser:hmluser' | chpasswd \
 && cp -a /etc/skel/. /home/hmluser/ …

# 4) Session scripts + xrdp policy
COPY startwm.sh /etc/xrdp/startwm.sh
COPY reconnectwm.sh /etc/xrdp/reconnectwm.sh
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
# KillDisconnected=true so RDP disconnect tears down the session
```

### Packages that matter

| Area | Packages |
|---|---|
| Desktop | `plasma-desktop`, `plasma-workspace`, **`kwin-x11`** (required for X11 titlebars/move/resize) |
| RDP | `xrdp`, `xorgxrdp`, Xorg packages |
| Apps | `dolphin`, `konsole`, `systemsettings`, breeze, fonts, `fastfetch` |
| Networking | `iproute2`, `net-tools`, `curl`, `wget`, `iputils-ping`, `iputils-tracepath`, `traceroute`, `bind9-dnsutils`, `bind9-host`, `netcat-openbsd`, `ca-certificates` |

### Session scripts (why they exist)

| File | Role |
|---|---|
| `docker-entrypoint.sh` | If DNS can’t resolve `deb.debian.org`, write `1.1.1.1` / `8.8.8.8`; start dbus + xrdp; `sleep infinity` |
| `startwm.sh` | `KWIN_COMPOSE=N` (xorgxrdp has no GL — otherwise KWin exits and windows don’t work); start Plasma; end session when plasmashell dies (logout) |
| `reconnectwm.sh` | Best-effort Plasma restart on RDP reconnect if the shell died |

**Not Wayland:** classic xrdp + xorgxrdp is **X11** (`startplasma-x11` + `kwin_x11`).

---

## Step 3 — Build the image

From the project directory (must contain `Dockerfile` and `branding/`):

```powershell
cd $env:USERPROFILE\hml-rdp
wslc build -t hml26:rdp .
```

Equivalent with Docker:

```powershell
docker build -t hml26:rdp .
```

First build takes a while (Plasma is large). Result: local image **`hml26:rdp`** (~1.7 GB).

---

## Step 4 — Run the container

```powershell
# Free the name/port if an old container exists
wslc list -a
wslc remove -f hml-rdp 2>$null

# One-line run (recommended)
wslc run -d --name hml-rdp -p 13391:3389 -m 4G hml26:rdp
```

| Flag | Meaning |
|---|---|
| `-d` | Detached |
| `--name hml-rdp` | Container name |
| `-p 13391:3389` | Host RDP port → container xrdp |
| `-m 4G` | Memory limit (Plasma wants room) |

Optional extras:

```powershell
# Persist home directory
wslc run -d --name hml-rdp -p 13391:3389 -m 4G `
  -v "$env:USERPROFILE\hml-rdp-home:/home/hmluser" `
  hml26:rdp

# Force public DNS (usually unnecessary; entrypoint fixes broken resolv.conf)
wslc run -d --name hml-rdp -p 13391:3389 -m 4G --dns 1.1.1.1 --dns 8.8.8.8 hml26:rdp
```

### Port already in use?

```text
Failed to map port '127.0.0.1:13391/tcp' … WSAEADDRINUSE
```

```powershell
wslc list -a
wslc remove -f <name-using-the-port>
# or pick another host port: -p 13392:3389
```

PowerShell may print a red cgroup/swap warning; if `wslc list` shows the container **running**, that is normal noise.

---

## Step 5 — Connect with RDP

| Field | Value |
|---|---|
| Address | `127.0.0.1:13391` |
| Username | `hmluser` |
| Password | `hmluser` |

```powershell
mstsc /v:127.0.0.1:13391
```

### Day-to-day

```powershell
wslc stop hml-rdp
wslc start hml-rdp
```

Prefer **closing the RDP window** (disconnect). After Plasma **Log Out**, log in again for a fresh session.

---

## Step 6 — Networking & apt (what we fixed)

### Apt repositories

Debian slim uses **deb822**, not a classic `/etc/apt/sources.list`:

```text
/etc/apt/sources.list.d/debian.sources
→ http://deb.debian.org/debian (trixie, trixie-updates)
→ http://deb.debian.org/debian-security (trixie-security)
→ Components: main
```

Package indexes are cleared at build time (`rm -rf /var/lib/apt/lists/*`). After start:

```bash
sudo apt-get update
sudo apt-get install -y htop
```

### DNS

If apt fails with `Temporary failure resolving 'deb.debian.org'`:

1. Entrypoint should auto-write public resolvers when resolution fails.  
2. Or recreate with `--dns 1.1.1.1 --dns 8.8.8.8`.  
3. Or inside the container:

```bash
echo -e 'nameserver 1.1.1.1\nnameserver 8.8.8.8' | sudo tee /etc/resolv.conf
sudo apt-get update
```

### Tools in the image

| Tool | Package |
|---|---|
| `ping` | `iputils-ping` |
| `dig` / `nslookup` / `host` | `bind9-dnsutils`, `bind9-host` |
| `wget` / `curl` | `wget`, `curl` |
| `ip` / `ss` | `iproute2` |
| `ifconfig` / `netstat` | `net-tools` |
| `traceroute` / `tracepath` | `traceroute`, `iputils-tracepath` |
| `nc` | `netcat-openbsd` |

Smoke check:

```powershell
wslc exec hml-rdp bash -c "which ping dig wget; getent hosts deb.debian.org; apt-get update"
```

---

## Step 7 — Window manager notes (KWin)

Without these, you get a desktop with **no move/resize/close**:

1. Install **`kwin-x11`** (not only `kwin-wayland`).  
2. Set **`KWIN_COMPOSE=N`** in `startwm.sh` (OpenGL compositing fails under xorgxrdp and KWin exits).  
3. Titlebar buttons in `kwinrc`: `ButtonsOnRight=IAX` (min / max / close).

Verify while logged in:

```powershell
wslc exec hml-rdp bash -c "pgrep -a kwin"
# expect: kwin_x11 …
```

---

## Step 8 — Rebuild after changes

```powershell
cd $env:USERPROFILE\hml-rdp
wslc build -t hml26:rdp .
wslc remove -f hml-rdp
wslc run -d --name hml-rdp -p 13391:3389 -m 4G hml26:rdp
```

---

## Step 9 — Tag and push to Docker Hub

### 9.1 Register / log in

1. Create an account at [https://hub.docker.com](https://hub.docker.com/).  
2. (Recommended) create an **Access Token** under Account Settings → Security.  
3. Log in with `wslc` (this is your **Docker Hub** username, not `hmluser`):

```powershell
wslc login
# Username: <dockerhub username>
# Password: Hub password or access token
```

### 9.2 Tag the local image

```powershell
wslc tag hml26:rdp <dockerhub username>/hannah-montana-linux:rdp
wslc tag hml26:rdp <dockerhub username>/hannah-montana-linux:26
wslc tag hml26:rdp <dockerhub username>/hannah-montana-linux:latest
```

### 9.3 Push

```powershell
wslc push <dockerhub username>/hannah-montana-linux:rdp
wslc push <dockerhub username>/hannah-montana-linux:26
wslc push <dockerhub username>/hannah-montana-linux:latest
```

First push is large (~1.7 GB layers) and can take a long time.

### 9.4 Others pull and run

```powershell
wslc pull docker.io/<dockerhub username>/hannah-montana-linux:rdp
wslc run -d --name hml-rdp -p 13391:3389 -m 4G docker.io/<dockerhub username>/hannah-montana-linux:rdp
mstsc /v:127.0.0.1:13391
```

```bash
docker pull <dockerhub username>/hannah-montana-linux:rdp
docker run -d --name hml-rdp -p 13391:3389 -m 4g <dockerhub username>/hannah-montana-linux:rdp
```

### 9.5 Suggested Docker Hub overview text

```markdown
# Hannah Montana Linux (container / RDP)

Debian trixie + KDE Plasma + xrdp, themed with branding from
[Hannah Montana Linux v26](https://gitlab.com/DecaCagle/HannahMontanaLinux26) (GPL-3.0+).

Not the official live ISO. Not affiliated with Disney.

## Run

```bash
docker run -d --name hml-rdp -p 13391:3389 -m 4g <dockerhub username>/hannah-montana-linux:rdp
```

## RDP

| | |
|---|---|
| Address | `127.0.0.1:13391` |
| User | `hmluser` |
| Password | `hmluser` |

~4–8 GB RAM recommended. Change the password before exposing the port beyond localhost.
```

You can publish to **Docker Hub and/or GitHub Container Registry** (Step 10). Same local image; different registry URL and login.

---

## Step 10 — Tag and push to GitHub Container Registry (ghcr.io)

[GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry) stores OCI/Docker images at **`ghcr.io`**, next to your GitHub account or org (GitHub Packages). Good when the source lives on GitHub and you want packages linked to a repo / Actions.

| | Docker Hub (Step 9) | GHCR (this step) |
|---|---|---|
| Host | `docker.io` (default) | **`ghcr.io`** |
| Image name | `<dockerhub username>/hannah-montana-linux:rdp` | `ghcr.io/<github username>/hannah-montana-linux:rdp` |
| Auth | Hub password or access token | **Personal access token (classic)** with package scopes |
| First publish | Often public-friendly | Package is often **private** until you change visibility |

`<github username>` = your GitHub user **or** org name (the GHCR namespace). It does **not** have to match Docker Hub.

### 10.1 Create a PAT (classic)

1. GitHub → **Settings** → **Developer settings** → **Personal access tokens** → **Tokens (classic)**.  
2. Generate a token with at least:
   - `write:packages` (push images; UI may also tick `repo` — avoid broad `repo` if you only need packages; see [GitHub’s packages scopes note](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry#authenticating-with-a-personal-access-token-classic))
   - `read:packages` (pull)
   - optional: `delete:packages`
3. Store the token somewhere safe (you will not see it again).

Fine-grained PATs are **not** what GitHub documents for this registry login flow; use a **classic** PAT.

### 10.2 Log in to ghcr.io

```powershell
# Prefer env var so the token is not left in shell history as much
$env:CR_PAT = "<github classic PAT>"

# wslc
wslc login -u <github username> -p $env:CR_PAT ghcr.io

# or docker CLI
# echo $env:CR_PAT | docker login ghcr.io -u <github username> --password-stdin
```

### 10.3 Tag the local image for GHCR

```powershell
wslc tag hml26:rdp ghcr.io/<github username>/hannah-montana-linux:rdp
wslc tag hml26:rdp ghcr.io/<github username>/hannah-montana-linux:26
wslc tag hml26:rdp ghcr.io/<github username>/hannah-montana-linux:latest
```

### 10.4 Push

```powershell
wslc push ghcr.io/<github username>/hannah-montana-linux:rdp
wslc push ghcr.io/<github username>/hannah-montana-linux:26
wslc push ghcr.io/<github username>/hannah-montana-linux:latest
```

Large desktop images can hit long uploads; GHCR also documents a **10 minute upload timeout** and a **10 GB per layer** limit — our image is under the layer cap, but a flaky network may need a retry.

### 10.5 Visibility and linking a repo

After the first push:

1. Open GitHub → your profile/org → **Packages** (or the package URL shown after push).  
2. Set the package to **Public** if you want anonymous pulls.  
3. Optionally **connect the package to a GitHub repository** (source code + README).

To help GHCR associate the image with a repo, set OCI labels in the Dockerfile (you can adjust the URL when you create the git repo):

```dockerfile
LABEL org.opencontainers.image.source=https://github.com/<github username>/<repo>
LABEL org.opencontainers.image.description="Hannah Montana Linux container edition (RDP)"
LABEL org.opencontainers.image.licenses=GPL-3.0-or-later
```

Publishing from **GitHub Actions** with `GITHUB_TOKEN` often links the package to the workflow repo automatically. CLI pushes do not always link by themselves unless labels/UI connect them.

### 10.6 Others pull and run from GHCR

```powershell
wslc pull ghcr.io/<github username>/hannah-montana-linux:rdp
wslc run -d --name hml-rdp -p 13391:3389 -m 4G ghcr.io/<github username>/hannah-montana-linux:rdp
mstsc /v:127.0.0.1:13391
```

```bash
docker pull ghcr.io/<github username>/hannah-montana-linux:rdp
docker run -d --name hml-rdp -p 13391:3389 -m 4g ghcr.io/<github username>/hannah-montana-linux:rdp
```

If the package is **private**, pullers must `docker login` / `wslc login` to `ghcr.io` with a PAT that has `read:packages`.

### 10.7 Optional: GitHub Actions sketch

```yaml
# .github/workflows/publish-ghcr.yml
name: Publish to GHCR
on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  packages: write

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: |
            ghcr.io/${{ github.repository_owner }}/hannah-montana-linux:rdp
            ghcr.io/${{ github.repository_owner }}/hannah-montana-linux:latest
```

Use this once the `hml-rdp` project is a GitHub repository. Owner name is lowercased on GHCR in many setups — if push fails on case, use the lowercase form of `<github username>`.

---

## Command cheat sheet

```powershell
# Build
cd $env:USERPROFILE\hml-rdp
wslc build -t hml26:rdp .

# Run
wslc remove -f hml-rdp 2>$null
wslc run -d --name hml-rdp -p 13391:3389 -m 4G hml26:rdp

# Connect
mstsc /v:127.0.0.1:13391
# hmluser / hmluser

# Inspect
wslc list
wslc exec hml-rdp bash -c "pgrep -a xrdp; pgrep -a kwin; cat /etc/os-release"

# Publish — Docker Hub
wslc login
wslc tag hml26:rdp <dockerhub username>/hannah-montana-linux:rdp
wslc tag hml26:rdp <dockerhub username>/hannah-montana-linux:latest
wslc push <dockerhub username>/hannah-montana-linux:rdp
wslc push <dockerhub username>/hannah-montana-linux:latest

# Publish — GitHub Container Registry
$env:CR_PAT = "<github classic PAT>"
wslc login -u <github username> -p $env:CR_PAT ghcr.io
wslc tag hml26:rdp ghcr.io/<github username>/hannah-montana-linux:rdp
wslc tag hml26:rdp ghcr.io/<github username>/hannah-montana-linux:latest
wslc push ghcr.io/<github username>/hannah-montana-linux:rdp
wslc push ghcr.io/<github username>/hannah-montana-linux:latest
```

---

## Security

Default `hmluser` / `hmluser` is for **localhost demos only**. Do not publish port 3389 to the internet without changing the password and hardening access.

---

## Credits

- Branding / theme work: [Hannah Montana Linux v26](https://gitlab.com/DecaCagle/HannahMontanaLinux26) by Noah Cagle — **GPL-3.0+**  
- Base system: Debian  
- Container packaging: this project  

Not affiliated with Disney or the original 2009 HML project.
