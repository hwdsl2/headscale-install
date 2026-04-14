[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# Headscale 服务器自动安装脚本

[![Build Status](https://github.com/hwdsl2/headscale-install/actions/workflows/main.yml/badge.svg)](https://github.com/hwdsl2/headscale-install/actions/workflows/main.yml) &nbsp;[![License: MIT](docs/images/license.svg)](https://opensource.org/licenses/MIT)

适用于 Ubuntu、Debian、AlmaLinux、Rocky Linux、CentOS、RHEL、Fedora 和 openSUSE 的 Headscale 服务器安装脚本。

本脚本安装并配置 [Headscale](https://github.com/juanfont/headscale) —— Tailscale 协调服务器的自托管开源实现。使用官方 Tailscale 客户端应用连接所有设备，由你自己的服务器掌控一切。

**另提供：**
- Docker VPN：[WireGuard](https://github.com/hwdsl2/docker-wireguard/blob/main/README-zh.md)、[OpenVPN](https://github.com/hwdsl2/docker-openvpn/blob/main/README-zh.md)、[IPsec VPN](https://github.com/hwdsl2/docker-ipsec-vpn-server/blob/master/README-zh.md)、[Headscale](https://github.com/hwdsl2/docker-headscale/blob/main/README-zh.md)
- Docker AI/音频：[Whisper (STT)](https://github.com/hwdsl2/docker-whisper/blob/main/README-zh.md)、[Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro/blob/main/README-zh.md)、[Embeddings](https://github.com/hwdsl2/docker-embeddings/blob/main/README-zh.md)、[LiteLLM](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh.md)

## 功能特性

- 全自动 Headscale 服务器安装，无需用户输入
- 支持使用自定义选项进行交互式安装
- 支持管理用户、节点和预授权密钥
- 下载官方 Headscale 二进制文件并进行校验和验证
- 将 Headscale 安装为具有专用系统用户的 systemd 服务
- 自动配置防火墙规则（firewalld 或 iptables）

## 系统要求

- 一台 Linux 服务器（云服务器、VPS 或独立服务器）
- 强烈建议在生产环境中使用**可公开访问的带有 HTTPS 的域名**

**注：** 若不使用 HTTPS，部分 Tailscale 客户端可能无法正常连接。请参阅 [TLS 与反向代理](#tls-与反向代理) 了解配置选项。

## 安装

在你的 Linux 服务器上下载脚本：

```bash
wget -O headscale.sh https://get.vpnsetup.net/hs
```

**选项 1：** 使用服务器 URL 自动安装。

```bash
sudo bash headscale.sh --auto --serverurl https://hs.example.com
```

请将 `https://hs.example.com` 替换为你的实际 HTTPS 服务器 URL。若未提供 `--serverurl`，将自动检测服务器的公网 IP 地址并使用 HTTP，不推荐用于生产环境。请参阅 [TLS 与反向代理](#tls-与反向代理) 了解配置选项。

**注：** 你可以选择在同一台服务器上安装 [WireGuard](https://github.com/hwdsl2/wireguard-install/blob/master/README-zh.md)、[OpenVPN](https://github.com/hwdsl2/openvpn-install/blob/master/README-zh.md) 和/或 [IPsec VPN](https://github.com/hwdsl2/setup-ipsec-vpn/blob/master/README-zh.md)。

**选项 2：** 使用自定义选项进行交互式安装。

```bash
sudo bash headscale.sh
```

你可以自定义以下选项：服务器 URL、TCP 端口、初始用户名和 MagicDNS 基础域名。

<details>
<summary>
如果无法下载，请点击此处。
</summary>

也可使用 `curl` 下载：

```bash
curl -fL -o headscale.sh https://get.vpnsetup.net/hs
```

备用下载地址：

```bash
https://github.com/hwdsl2/headscale-install/raw/main/headscale-install.sh
```

如果仍无法下载，请打开 [headscale-install.sh](headscale-install.sh)，然后点击右侧的 `Raw` 按钮。按 `Ctrl/Cmd+A` 全选，`Ctrl/Cmd+C` 复制，然后粘贴到你喜欢的编辑器中。
</details>

<details>
<summary>
查看脚本的使用说明。
</summary>

```
用法：bash headscale.sh [选项]

选项：

  --adduser    [用户名]            添加新用户
  --deleteuser [用户名]            删除用户（及其所有节点和密钥）
  --listusers                      列出所有用户
  --listnodes                      列出所有已注册节点
  --listnodes  --user [名称]       列出特定用户的节点
  --registernode [节点密钥]        按节点密钥注册节点
                --user [名称]      （需要 --user <名称>）
  --deletenode [节点 ID]           按数字 ID 删除节点
  --createkey  --user [名称]       为用户创建可重用预授权密钥
  --listkeys                       列出预授权密钥
  --uninstall                      删除 Headscale 及所有配置
  -y, --yes                        对提示自动回答"是"
  -h, --help                       显示此帮助信息并退出

安装选项（可选）：

  --auto                           使用默认或自定义选项自动安装 Headscale
  --serverurl  [URL]               服务器 URL（例如 https://hs.example.com）
  --port       [数字]              Headscale 的 TCP 端口（1-65535，默认：8080）
  --listenaddr [地址]              监听地址（默认：0.0.0.0，仅本地使用：127.0.0.1）
  --username   [名称]              初始用户名称（默认：admin）
  --basedomain [域名]              MagicDNS 基础域名（默认：headscale.internal）

也可不带参数运行脚本以使用自定义选项。
```
</details>

## 安装后

首次运行时，脚本将：
1. 下载并安装 Headscale 二进制文件
2. 创建 `headscale` 系统用户和组
3. 将配置写入 `/etc/headscale/config.yaml`
4. 安装并启动 `headscale` systemd 服务
5. 创建初始用户并输出**可重复使用的预授权密钥**

复制输出中的预授权密钥，使用官方 [Tailscale 客户端](https://tailscale.com/download)连接设备：

```bash
tailscale up --login-server https://hs.example.com --authkey <输出中的密钥>
```

## 客户端配置

有关连接客户端的说明，请参阅 Headscale 文档：

- [Android](https://headscale.net/stable/usage/connect/android/)
- [Apple（iOS / macOS）](https://headscale.net/stable/usage/connect/apple/)
- [Windows](https://headscale.net/stable/usage/connect/windows/)

## 管理 Headscale

安装完成后，再次运行脚本即可管理你的服务器。

**按节点密钥注册节点：**

```bash
sudo bash headscale.sh --registernode <key> --user admin
```

**添加用户：**

```bash
sudo bash headscale.sh --adduser alice
```

**删除用户：**

```bash
sudo bash headscale.sh --deleteuser alice
```

**为用户创建预授权密钥：**

```bash
sudo bash headscale.sh --createkey --user alice
```

**列出所有用户：**

```bash
sudo bash headscale.sh --listusers
```

**列出所有已注册节点：**

```bash
sudo bash headscale.sh --listnodes
```

**列出特定用户的节点：**

```bash
sudo bash headscale.sh --listnodes --user alice
```

**按 ID 删除节点：**

```bash
sudo bash headscale.sh --deletenode 3
```

**列出预授权密钥：**

```bash
sudo bash headscale.sh --listkeys
```

**卸载 Headscale：**

```bash
sudo bash headscale.sh --uninstall
```

**显示帮助信息：**

```bash
sudo bash headscale.sh --help
```

也可不带参数运行脚本以进入交互式管理菜单。

也可直接使用 `headscale <命令>` 运行 Headscale 命令。运行 `headscale -h` 或参阅 [Headscale 文档](https://headscale.net/) 查看可用命令。

## TLS 与反向代理

Tailscale 客户端需要 HTTPS 才能实现完整功能。推荐的配置是在 Headscale 前使用反向代理处理 TLS，然后在安装时传入 `--serverurl https://hs.example.com`（或在 `/etc/headscale/config.yaml` 中设置 `server_url` 并重启服务）。

使用反向代理时，建议添加 `--listenaddr 127.0.0.1` 以将 Headscale 限制为仅在本地监听。

**使用 [Caddy](https://caddyserver.com/docs/) 的示例**（通过 Let's Encrypt 自动申请 TLS）：

```
hs.example.com {
  reverse_proxy localhost:8080
}
```

**使用 nginx 的示例：**

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

**防火墙中需要开放的端口：**

| 端口 | 协议 | 用途 |
|---|---|---|
| `8080` | TCP | Headscale 协调服务器（或反向代理端口） |
| `443` | TCP | HTTPS（使用反向代理时） |

## 配置

配置文件位于 `/etc/headscale/config.yaml`。编辑此文件可修改服务器 URL、基础域名或 DNS 服务器等设置，然后重启服务：

```bash
sudo systemctl restart headscale
```

查看服务状态和日志：

```bash
sudo systemctl status headscale
sudo journalctl -u headscale -n 50
```

## 使用自定义选项自动安装

```bash
sudo bash headscale.sh --auto \
  --serverurl https://hs.example.com \
  --port 8080 \
  --listenaddr 127.0.0.1 \
  --username admin \
  --basedomain headscale.internal
```

使用 `--auto` 时，所有安装选项均为可选。若未提供 `--serverurl`，将自动检测服务器的公网 IP 地址并使用 HTTP（不推荐用于生产环境）。

## 授权协议

Copyright (C) 2026 Lin Song   
本作品依据 [MIT 许可证](https://opensource.org/licenses/MIT)授权。

**Headscale** 的版权归 Juan Font 所有（2020 年），遵循 [BSD 3-Clause 许可证](https://github.com/juanfont/headscale/blob/main/LICENSE)。

Tailscale® 是 Tailscale Inc. 的注册商标。本项目与 Tailscale Inc. 无关联，亦未获其背书。