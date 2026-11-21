# Quick Start

Step-by-step from a fresh Linux machine to a working AD domain with a GUI.

## 1. Install Docker

Arch / CachyOS:

```bash
sudo pacman -S docker docker-compose
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
newgrp docker          # or log out and back in
docker version
```

Debian / Ubuntu:

```bash
sudo apt install docker.io docker-compose-v2
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
newgrp docker
```

## 2. Configure

```bash
cd ad-stack/docker
cp .env.example .env
$EDITOR .env
```

Defaults:

```ini
AD_DOMAIN=AD
AD_REALM=AD.EXAMPLE.COM
ADMIN_PASS=Passw0rd!2026
DNS_FORWARDER=1.1.1.1
```

Set these **before the first start**. The domain is provisioned once.

## 3. Start

```bash
./start.sh
```

First start takes ~30–60 seconds while Samba provisions the domain. The script
waits for it and prints the addresses.

## 4. Open the GUI

**http://localhost:8080/templates/login.php**

| Field | Value |
|---|---|
| Username | `Administrator@AD.EXAMPLE.COM` |
| Password | `ADMIN_PASS` from `.env` |
| Profile | `lam` |

The login name must be the UPN form (or the full DN). Plain `Administrator`
does not bind against Samba AD.

LAM's **master password** (for profile management only) is `lam`.

## 5. Check from the command line

```bash
docker exec samba-ad samba-tool user list
docker exec samba-ad samba-tool domain info 127.0.0.1
docker exec samba-ad host -t A dc1.ad.example.com 127.0.0.1
docker exec samba-ad host -t SRV _ldap._tcp.ad.example.com 127.0.0.1
```

Expected DNS answer: `dc1.ad.example.com has address <your-LAN-IP>`.

## 6. First admin tasks in LAM

- **Users** → *New user* → fill in account name, password, optional POSIX attrs.
- **Groups** → *New group* → add members.
- **Computers** → joined machines appear here.

Every change is a live LDAP write to the AD DC — no sync step needed.

## Troubleshooting

**Samba container restarts / port 53 in use**
Disable the systemd-resolved stub listener:

```bash
sudo mkdir -p /etc/systemd/resolved.conf.d
printf '[Resolve]\nDNSStubListener=no\n' | sudo tee /etc/systemd/resolved.conf.d/ad.conf
sudo systemctl restart systemd-resolved
```

or stop `dnsmasq` / `named` if installed.

**GUI shows a blank page**
LAM needs about 10 s after container start. Check `docker logs lam-gui`.

**GUI login fails**
Use `Administrator@<REALM>` exactly (uppercase realm). Verify the password:

```bash
docker exec samba-ad samba-tool user getpassword Administrator
```

**Reset everything**

```bash
cd ad-stack/docker
docker compose down -v
./start.sh
```

**Logs**

```bash
docker compose logs -f samba
docker compose logs -f lam
```
