# AD Stack

A self-hosted **Active Directory–compatible** domain for Linux, with a web GUI
for day-to-day administration. Fully open source, Docker-based, and set up in
three commands.

```text
┌──────────────────────────────────────────────────────────────┐
│                        Your Linux host                       │
│                                                              │
│  ┌──────────────────────┐        ┌────────────────────────┐  │
│  │  Samba AD DC         │        │  LDAP Account Manager  │  │
│  │  • LDAP      :389    │◄──────►│  • Web GUI :8080       │  │
│  │  • Kerberos  :88     │        │  • users / groups      │  │
│  │  • DNS       :53     │        │  • computers           │  │
│  │  • SMB       :445    │        │  • password resets     │  │
│  └──────────────────────┘        └────────────────────────┘  │
│            ▲                              ▲                  │
│            └──────── host network ────────┘                  │
└──────────────────────────────────────────────────────────────┘
```

| Component | Role | License |
|---|---|---|
| [Samba AD DC](https://www.samba.org/) | Directory, Kerberos, DNS, LDAP, SMB | GPLv3 |
| [LDAP Account Manager](https://www.ldap-account-manager.org/) | Web administration GUI | GPLv3 |

---

## Features

- AD-compatible domain (`AD.EXAMPLE.COM`, NetBIOS `AD`)
- Add/edit/delete **users and groups** from a browser
- Manage **computers**, POSIX attributes, account flags and passwords
- Real Kerberos KDC and DNS zone — Linux/Windows clients can join
- LDAP endpoint for automation (`ldap://localhost:389`)
- One-command start / stop / status / reset scripts
- Everything persisted in Docker volumes

## Requirements

- Linux with Docker Engine + Compose v2
- A normal LAN interface (the stack uses **host networking** so AD's DNS
  records point at an address clients can actually reach)
- These host ports free: `53/udp`, `88`, `135`, `139`, `389`, `445`, `464`,
  `636`, `3268`, `8080`

> **Port 53 busy?** Disable the systemd-resolved stub listener — see
> [Troubleshooting](#troubleshooting). dnsmasq or named must be stopped too.

---

## Quick start

```bash
git clone <your-repo-url> ad-stack
cd ad-stack
./start.sh
```

`start.sh` creates `.env` on first run, provisions the domain (~30–60 s),
builds LAM's AD profile automatically, and prints your credentials.

Open the GUI:

**http://localhost:8080/templates/login.php**

| Field | Value |
|---|---|
| Username | `Administrator@AD.EXAMPLE.COM` |
| Password | `ADMIN_PASS` from `docker/.env` (default `Passw0rd!2026`) |
| Profile | `lam` |
| LAM master password | `lam` (profile management only) |

The username must be in UPN form (or the full DN). Plain `Administrator` does
not bind against Samba AD.

---

## Scripts

| Command | What it does |
|---|---|
| `./start.sh` | Create `.env` if missing, start the stack, wait for provisioning, configure LAM, print credentials |
| `./stop.sh` | Stop containers, keep all data |
| `./status.sh` | Show container state, AD users, DNS record, GUI reachability |
| `./logs.sh samba` | Follow Samba logs (`./logs.sh lam` for the GUI) |
| `./reset.sh` | Delete containers **and all AD data**, then start clean |

Configuration lives in `docker/.env`:

```ini
AD_DOMAIN=AD
AD_REALM=AD.EXAMPLE.COM
ADMIN_PASS=Passw0rd!2026
DNS_FORWARDER=1.1.1.1
```

Set these **before the first start**. Samba provisions the domain once; to rename
it later you must run `./reset.sh` first.

---

## Verify the install

```bash
# users known to the domain
docker exec samba-ad samba-tool user list

# domain / KDC health
docker exec samba-ad samba-tool domain info 127.0.0.1

# DNS answer should be your LAN IP
docker exec samba-ad host -t A dc1.ad.example.com 127.0.0.1

# GUI
curl -I http://localhost:8080/templates/login.php
```

Or just run `./status.sh`.

## Common admin tasks

**In the GUI** — *Users → New user*, *Groups → New group*, *Computers*. Every
change is written straight to the AD DC; there is no sync step.

**From the CLI:**

```bash
# create a user
docker exec samba-ad samba-tool user create alice 'Str0ng!Pass'

# reset a password
docker exec samba-ad samba-tool user setpassword alice --newpassword='N3w!Pass'

# disable / enable an account
docker exec samba-ad samba-tool user disable alice
docker exec samba-ad samba-tool user enable alice

# list groups / members
docker exec samba-ad samba-tool group list
```

**Join a Linux client** (on the client machine):

```bash
sudo pacman -S samba krb5        # Arch / CachyOS
sudo apt install samba winbind krb5-user   # Debian / Ubuntu
# then point its DNS at this host and use realm AD.EXAMPLE.COM
```

## Data & persistence

| What | Where |
|---|---|
| Samba config, database, sysvol, Kerberos keys | volume `ad-stack_samba_data` |
| LAM profiles and settings | volume `ad-stack_lam_data` |

`./stop.sh` keeps both volumes. `./reset.sh` deletes them.

Backup example:

```bash
docker run --rm -v ad-stack_samba_data:/data -v "$PWD":/backup alpine \
  tar czf /backup/samba-data-$(date +%F).tar.gz -C /data .
```

## Troubleshooting

**Samba keeps restarting / `port 53` in use**

```bash
sudo mkdir -p /etc/systemd/resolved.conf.d
printf '[Resolve]\nDNSStubListener=no\n' | sudo tee /etc/systemd/resolved.conf.d/ad.conf
sudo systemctl restart systemd-resolved
```

Also stop `dnsmasq` / `named` if installed. Samba must own port 53.

**`localhost:8080` refuses or resets**

Check `docker logs lam-gui`. The image's Apache listens on 8080 (not 80); the
compose file already maps that and runs LAM on the host network.

**GUI login fails**

Use `Administrator@AD.EXAMPLE.COM` exactly (uppercase realm), the `ADMIN_PASS`
from `.env`, and profile `lam`. Confirm the password works over LDAP:

```bash
docker exec lam-gui php -r '$c=ldap_connect("ldap://localhost:389");
ldap_set_option($c,LDAP_OPT_PROTOCOL_VERSION,3);
echo ldap_bind($c,"Administrator@AD.EXAMPLE.COM","Passw0rd!2026")?"OK\n":"FAIL\n";'
```

**Start over**

```bash
./reset.sh
./start.sh
```

## Security notes

This stack targets **labs and small trusted networks**. Before exposing it:

- Change `ADMIN_PASS` and the LAM master password (`lam` → Configuration → Profile)
- Add TLS: mount certificates and use `ldaps://` (636); LAM supports it in the profile
- Restrict port 8080 to localhost or put a reverse proxy in front of LAM
- Schedule backups of `ad-stack_samba_data`
- For high availability, add a second Samba DC and replicate

## Layout

```text
ad-stack/
├── start.sh              # start everything
├── stop.sh               # stop, keep data
├── status.sh             # health summary
├── logs.sh               # follow logs
├── reset.sh              # wipe and start over
├── docker/
│   ├── docker-compose.yml
│   ├── .env.example
│   └── start.sh          # real startup logic used by ./start.sh
├── docs/QUICKSTART.md
└── README.md
```

## License

The stack glue in this repository is MIT. Samba is GPLv3; LAM is GPLv3.
