[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# Headscale Server Auto Setup Script

[![Build Status](https://github.com/hwdsl2/headscale-install/actions/workflows/main.yml/badge.svg)](https://github.com/hwdsl2/headscale-install/actions/workflows/main.yml)

**Also available:** [Headscale server on Docker](https://github.com/hwdsl2/docker-headscale).

Headscale server installer for Ubuntu, Debian, AlmaLinux, Rocky Linux, CentOS, RHEL, Fedora and openSUSE.

This script installs and configures [Headscale](https://github.com/juanfont/headscale) — a self-hosted, open-source implementation of the Tailscale coordination server. Connect all your devices using the official Tailscale client apps, with your own server in control.

See also: [WireGuard](https://github.com/hwdsl2/wireguard-install), [OpenVPN](https://github.com/hwdsl2/openvpn-install) and [IPsec VPN](https://github.com/hwdsl2/setup-ipsec-vpn) server auto setup scripts.

## Features

- Fully automated Headscale server setup, no user input needed
- Supports interactive install using custom options
- Supports managing users, nodes and pre-auth keys
- Downloads the official Headscale binary with checksum verification
- Installs Headscale as a systemd service with a dedicated system user
- Configures firewall rules automatically (firewalld or iptables)

## Requirements

- A Linux server (cloud server, VPS or dedicated server)
- A **publicly reachable domain name with HTTPS** is strongly recommended for production use

> **Note:** Without HTTPS some Tailscale clients may not connect properly. See [TLS and reverse proxy](#tls-and-reverse-proxy) for setup options.

## Installation

Download the script on your Linux server:

```bash
wget -O headscale.sh https://get.vpnsetup.net/hs
```

**Option 1:** Auto install with a server URL.

```bash
sudo bash headscale.sh --auto --serverurl https://hs.example.com
```

Replace `https://hs.example.com` with your actual HTTPS server URL. If `--serverurl` is not provided, the server's public IP address is auto-detected and HTTP is used, which is not recommended for production. See [TLS and reverse proxy](#tls-and-reverse-proxy) for setup options.

**Option 2:** Interactive install using custom options.

```bash
sudo bash headscale.sh
```

You can customize the following options: server URL, TCP port, initial username and MagicDNS base domain.

<details>
<summary>
Click here if you are unable to download.
</summary>

You may also use `curl` to download:

```bash
curl -fL -o headscale.sh https://get.vpnsetup.net/hs
```

Alternative setup URL:

```bash
https://github.com/hwdsl2/headscale-install/raw/main/headscale-install.sh
```

If you are unable to download, open [headscale-install.sh](headscale-install.sh), then click the `Raw` button on the right. Press `Ctrl/Cmd+A` to select all, `Ctrl/Cmd+C` to copy, then paste into your favorite editor.
</details>

<details>
<summary>
View usage information for the script.
</summary>

```
Usage: bash headscale.sh [options]

Options:

  --adduser    [user name]       add a new user
  --deleteuser [user name]       delete a user (and all their nodes and keys)
  --listusers                    list all users
  --listnodes                    list all registered nodes
  --listnodes  --user [name]     list nodes for a specific user
  --registernode [node key]      register a node by its node key
                --user [name]    (requires --user <name>)
  --deletenode [node ID]         delete a node by its numeric ID
  --createkey  --user [name]     create a reusable pre-auth key for a user
  --listkeys                     list pre-auth keys
  --uninstall                    remove Headscale and delete all configuration
  -y, --yes                      assume "yes" as answer to prompts
  -h, --help                     show this help message and exit

Install options (optional):

  --auto                         auto install Headscale using default or custom options
  --serverurl  [URL]             server URL (e.g. https://hs.example.com)
  --port       [number]          TCP port for Headscale (1-65535, default: 8080)
  --username   [name]            name for the initial user (default: admin)
  --basedomain [domain]          MagicDNS base domain (default: headscale.internal)

To customize options, you may also run this script without arguments.
```
</details>

## After installation

On first run, the script:
1. Downloads and installs the Headscale binary
2. Creates a `headscale` system user and group
3. Writes the configuration to `/etc/headscale/config.yaml`
4. Installs and starts the `headscale` systemd service
5. Creates the initial user and prints a **reusable pre-auth key**

Copy the pre-auth key from the output and connect a device with the official [Tailscale client](https://tailscale.com/download):

```bash
tailscale up --login-server https://hs.example.com --authkey <key-from-output>
```

## Client configuration

Refer to the Headscale documentation for instructions on connecting clients:

- [Android](https://headscale.net/stable/usage/connect/android/)
- [Apple (iOS / macOS)](https://headscale.net/stable/usage/connect/apple/)
- [Windows](https://headscale.net/stable/usage/connect/windows/)

## Managing Headscale

After setup, run the script again to manage your server.

**Register a node by its node key:**

```bash
sudo bash headscale.sh --registernode <key> --user admin
```

**Add a user:**

```bash
sudo bash headscale.sh --adduser alice
```

**Delete a user:**

```bash
sudo bash headscale.sh --deleteuser alice
```

**Create a pre-auth key for a user:**

```bash
sudo bash headscale.sh --createkey --user alice
```

**List all users:**

```bash
sudo bash headscale.sh --listusers
```

**List all registered nodes:**

```bash
sudo bash headscale.sh --listnodes
```

**List nodes for a specific user:**

```bash
sudo bash headscale.sh --listnodes --user alice
```

**Delete a node by ID:**

```bash
sudo bash headscale.sh --deletenode 3
```

**List pre-auth keys:**

```bash
sudo bash headscale.sh --listkeys
```

**Remove Headscale:**

```bash
sudo bash headscale.sh --uninstall
```

**Show help:**

```bash
sudo bash headscale.sh --help
```

You may also run the script without arguments for an interactive management menu.

You can also run Headscale commands directly using `headscale <command>`. Run `headscale -h` or refer to the [Headscale documentation](https://headscale.net/) for available commands.

## TLS and reverse proxy

Tailscale clients require HTTPS for full functionality. The recommended setup is a reverse proxy in front of Headscale that handles TLS, then pass `--serverurl https://hs.example.com` during install (or set `server_url` in `/etc/headscale/config.yaml` and restart the service).

**Example with [Caddy](https://caddyserver.com/docs/)** (automatic TLS via Let's Encrypt):

```
hs.example.com {
  reverse_proxy localhost:8080
}
```

**Example with nginx:**

```nginx
server {
    listen 443 ssl;
    server_name hs.example.com;

    ssl_certificate     /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 3600s;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

**Firewall ports to open:**

| Port | Protocol | Purpose |
|---|---|---|
| `8080` | TCP | Headscale coordination server (or your reverse proxy port) |
| `443` | TCP | HTTPS (if using a reverse proxy) |

## Configuration

The configuration file is at `/etc/headscale/config.yaml`. Edit this file to change settings such as the server URL, base domain or DNS servers, then restart the service:

```bash
sudo systemctl restart headscale
```

Check service status and logs:

```bash
sudo systemctl status headscale
sudo journalctl -u headscale -n 50
```

## Auto install using custom options

```bash
sudo bash headscale.sh --auto \
  --serverurl https://hs.example.com \
  --port 8080 \
  --username admin \
  --basedomain headscale.internal
```

All install options are optional when using `--auto`. If `--serverurl` is not provided, the server's public IP address is auto-detected and HTTP is used (not recommended for production).

## License

Copyright (C) 2026 Lin Song
This work is licensed under the [MIT License](https://opensource.org/licenses/MIT).

**Headscale** is Copyright (c) 2020, Juan Font, and is distributed under the [BSD 3-Clause License](https://github.com/juanfont/headscale/blob/main/LICENSE).

Tailscale® is a registered trademark of Tailscale Inc. This project is not affiliated with or endorsed by Tailscale Inc.