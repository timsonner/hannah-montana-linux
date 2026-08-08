# Hannah Montana Linux — container edition (RDP)

A silly, try-at-home **[Hannah Montana Linux v26](https://gitlab.com/DecaCagle/HannahMontanaLinux26)**-themed desktop in an OCI container.

| | |
|---|---|
| **Base** | `debian:trixie-slim` (Debian 13) |
| **Desktop** | KDE Plasma (X11) over **xrdp** |
| **Branding** | Themes, icons, wallpapers, skel from HML26 `includes.chroot` (GPL-3.0+) |
| **Runtime** | [wslc](https://learn.microsoft.com/en-us/windows/wsl/wsl-container) (Windows), Docker, or Podman |

This is **not** the official live ISO and **not** a live-build output. Same pink look, rebuilt as a normal image anyone can pull and RDP into.

> Plasma wants RAM. Plan on **~4–8 GB** free for a comfortable session.

**Not affiliated with Disney.** Branding credits: [Noah Cagle / HML26](https://gitlab.com/DecaCagle/HannahMontanaLinux26).

Full build recipe and publish notes: **[GUIDE.md](./GUIDE.md)**.

---

## Pull and run (recommended)

Published image: **`ghcr.io/timsonner/hannah-montana-linux`**

### Windows (`wslc`)

```powershell
wslc pull ghcr.io/timsonner/hannah-montana-linux:rdp

wslc remove -f hml-rdp 2>$null
wslc run -d --name hml-rdp -p 13391:3389 -m 4G ghcr.io/timsonner/hannah-montana-linux:rdp
```

### Docker / Podman

```bash
docker pull ghcr.io/timsonner/hannah-montana-linux:rdp
docker run -d --name hml-rdp -p 13391:3389 -m 4g ghcr.io/timsonner/hannah-montana-linux:rdp
```

If the package is **private**, log in first (PAT with `read:packages`):

```powershell
wslc login -u timsonner -p <github_pat> ghcr.io
```

### Connect with RDP

| Field | Value |
|---|---|
| Address | `127.0.0.1:13391` |
| Username | `hmluser` |
| Password | `hmluser` |

```powershell
mstsc /v:127.0.0.1:13391
```

**Day-to-day**

```powershell
wslc stop hml-rdp
wslc start hml-rdp
```

Prefer **closing the RDP window** (disconnect). After Plasma **Log Out**, sign in again for a fresh session.

---

## Tags

| Tag | Meaning |
|---|---|
| `rdp` | This RDP desktop image |
| `latest` | Same as current default publish (when used) |
| `26` | HML major branding version (when published) |

Image is large (**~1.7 GB+**) because of Plasma.

---

## Build from source

```powershell
git clone https://github.com/timsonner/hannah-montana-linux.git
cd hannah-montana-linux

# wslc (Windows)
wslc build -t hml26:rdp .
wslc run -d --name hml-rdp -p 13391:3389 -m 4G hml26:rdp

# docker
docker build -t hml26:rdp .
docker run -d --name hml-rdp -p 13391:3389 -m 4g hml26:rdp
```

First build takes a while (downloads a full desktop stack).

Optional:

```powershell
# Persist home
-v "$env:USERPROFILE\hml-rdp-home:/home/hmluser"

# Force DNS if apt cannot resolve mirrors
--dns 1.1.1.1 --dns 8.8.8.8
```

---

## How the image is made (short)

1. **Base:** `FROM debian:trixie-slim`  
2. **apt:** Plasma, **`kwin-x11`**, xrdp, networking tools (`ping`, `dig`, `wget`, …)  
3. **Branding:** `COPY branding/ /` — mostly HML26 `config/includes.chroot`  
4. **User:** `hmluser` with HML skel applied  
5. **xrdp helpers (ours, not from HML):** `kwinrc` / `dolphinrc` under `branding/`, plus `startwm.sh` (`KWIN_COMPOSE=N`), entrypoint DNS fallback  

Details, snippets, Docker Hub + GHCR publish: **[GUIDE.md](./GUIDE.md)**.

---

## Project layout

```text
.
├── Dockerfile              # Image recipe
├── docker-entrypoint.sh    # DNS fallback, dbus, xrdp
├── startwm.sh              # Plasma + KWIN_COMPOSE=N + logout watchdog
├── reconnectwm.sh          # Reconnect helper
├── branding/               # HML themes/skel + our xrdp kwin/dolphin configs
├── GUIDE.md                # Full step-by-step recipe
├── README.md               # This file
├── .dockerignore
└── .gitignore
```

---

## Credentials & security

Default lab login (change before any non-localhost use):

- **User:** `hmluser`  
- **Password:** `hmluser`  

Do **not** publish port 3389 to the open internet with the default password.

---

## Troubleshooting

| Symptom | Try |
|---|---|
| Port in use (`WSAEADDRINUSE`) | `wslc list -a` then `wslc remove -f <name>`, or `-p 13392:3389` |
| Connection refused | Container running? `wslc list` / `docker ps` |
| Black screen after logout | Image includes session teardown; log in again, or reset: `wslc exec hml-rdp bash -lc "pkill -9 -u hmluser"` |
| No move/resize/close | Need `kwin_x11` + `KWIN_COMPOSE=N` (baked into this image) |
| `apt` can’t resolve hosts | Entrypoint may fix DNS; or run with `--dns 1.1.1.1` |
| Red cgroup/swap warning on `wslc run` | Often harmless if the container shows **running** |

Logs:

```powershell
wslc exec hml-rdp bash -lc "tail -80 /var/log/xrdp-sesman.log; tail -80 /var/log/xrdp.log"
wslc exec hml-rdp bash -lc "pgrep -a kwin; pgrep -a xrdp"
```

---

## Publish (maintainers)

**GitHub Container Registry** (see GUIDE Step 10):

```powershell
# Prefer a classic PAT with write:packages for ghcr.io login (fine-grained for git is separate)
$env:CR_PAT = "<github_pat>"
wslc login -u timsonner -p $env:CR_PAT ghcr.io
wslc tag hml26:rdp ghcr.io/timsonner/hannah-montana-linux:rdp
wslc push ghcr.io/timsonner/hannah-montana-linux:rdp
```

After the first push, set the package to **Public** if you want anonymous pulls. Connect the package to this repository in the GitHub UI if it is not linked yet.

**Docker Hub** (optional, GUIDE Step 9): same image under your Hub username.

`Dockerfile` already sets `org.opencontainers.image.source` to this repo.

---

## License & credits

- **HML branding / themes:** [Hannah Montana Linux v26](https://gitlab.com/DecaCagle/HannahMontanaLinux26) — **GPL-3.0+**  
- **Base packages:** Debian  
- **Container packaging, xrdp session scripts, kwin/dolphin defaults:** this repository  

Not affiliated with Disney, the Hannah Montana franchise, or the original 2009 HML project. Pure nostalgia engineering.
