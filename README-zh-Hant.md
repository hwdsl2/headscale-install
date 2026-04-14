[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# Headscale 伺服器自動安裝腳本

[![Build Status](https://github.com/hwdsl2/headscale-install/actions/workflows/main.yml/badge.svg)](https://github.com/hwdsl2/headscale-install/actions/workflows/main.yml) &nbsp;[![License: MIT](docs/images/license.svg)](https://opensource.org/licenses/MIT)

適用於 Ubuntu、Debian、AlmaLinux、Rocky Linux、CentOS、RHEL、Fedora 和 openSUSE 的 Headscale 伺服器安裝腳本。

本腳本安裝並設定 [Headscale](https://github.com/juanfont/headscale) —— Tailscale 協調伺服器的自託管開源實作。使用官方 Tailscale 客戶端應用程式連線所有裝置，由你自己的伺服器掌控一切。

**另提供：**
- Docker VPN：[WireGuard](https://github.com/hwdsl2/docker-wireguard/blob/main/README-zh-Hant.md)、[OpenVPN](https://github.com/hwdsl2/docker-openvpn/blob/main/README-zh-Hant.md)、[IPsec VPN](https://github.com/hwdsl2/docker-ipsec-vpn-server/blob/master/README-zh-Hant.md)、[Headscale](https://github.com/hwdsl2/docker-headscale/blob/main/README-zh-Hant.md)
- Docker AI/音訊：[Whisper (STT)](https://github.com/hwdsl2/docker-whisper/blob/main/README-zh-Hant.md)、[Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro/blob/main/README-zh-Hant.md)、[Embeddings](https://github.com/hwdsl2/docker-embeddings/blob/main/README-zh-Hant.md)、[LiteLLM](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh-Hant.md)

## 功能特色

- 全自動 Headscale 伺服器安裝，無需使用者輸入
- 支援使用自訂選項進行互動式安裝
- 支援管理使用者、節點和預授權金鑰
- 下載官方 Headscale 二進位檔案並進行校驗和驗證
- 將 Headscale 安裝為具有專用系統使用者的 systemd 服務
- 自動設定防火牆規則（firewalld 或 iptables）

## 系統需求

- 一台 Linux 伺服器（雲端伺服器、VPS 或獨立伺服器）
- 強烈建議在正式環境中使用**可公開存取的具有 HTTPS 的網域名稱**

**注：** 若不使用 HTTPS，部分 Tailscale 客戶端可能無法正常連線。請參閱 [TLS 與反向代理](#tls-與反向代理) 了解設定選項。

## 安裝

在你的 Linux 伺服器上下載腳本：

```bash
wget -O headscale.sh https://get.vpnsetup.net/hs
```

**選項 1：** 使用伺服器 URL 自動安裝。

```bash
sudo bash headscale.sh --auto --serverurl https://hs.example.com
```

請將 `https://hs.example.com` 替換為你的實際 HTTPS 伺服器 URL。若未提供 `--serverurl`，將自動偵測伺服器的公用 IP 位址並使用 HTTP，不建議用於正式環境。請參閱 [TLS 與反向代理](#tls-與反向代理) 了解設定選項。

**注：** 你可以選擇在同一台伺服器上安裝 [WireGuard](https://github.com/hwdsl2/wireguard-install/blob/master/README-zh-Hant.md)、[OpenVPN](https://github.com/hwdsl2/openvpn-install/blob/master/README-zh-Hant.md) 和/或 [IPsec VPN](https://github.com/hwdsl2/setup-ipsec-vpn/blob/master/README-zh-Hant.md)。

**選項 2：** 使用自訂選項進行互動式安裝。

```bash
sudo bash headscale.sh
```

你可以自訂以下選項：伺服器 URL、TCP 連接埠、初始使用者名稱和 MagicDNS 基礎網域。

<details>
<summary>
如果無法下載，請點擊此處。
</summary>

也可使用 `curl` 下載：

```bash
curl -fL -o headscale.sh https://get.vpnsetup.net/hs
```

備用下載地址：

```bash
https://github.com/hwdsl2/headscale-install/raw/main/headscale-install.sh
```

如果仍無法下載，請開啟 [headscale-install.sh](headscale-install.sh)，然後點擊右側的 `Raw` 按鈕。按 `Ctrl/Cmd+A` 全選，`Ctrl/Cmd+C` 複製，然後貼上至你喜歡的編輯器中。
</details>

<details>
<summary>
查看腳本的使用說明。
</summary>

```
用法：bash headscale.sh [選項]

選項：

  --adduser    [使用者名稱]        新增使用者
  --deleteuser [使用者名稱]        刪除使用者（及其所有節點和金鑰）
  --listusers                      列出所有使用者
  --listnodes                      列出所有已註冊節點
  --listnodes  --user [名稱]       列出特定使用者的節點
  --registernode [節點金鑰]        依節點金鑰註冊節點
                --user [名稱]      （需要 --user <名稱>）
  --deletenode [節點 ID]           依數字 ID 刪除節點
  --createkey  --user [名稱]       為使用者建立可重用預授權金鑰
  --listkeys                       列出預授權金鑰
  --uninstall                      移除 Headscale 及所有設定
  -y, --yes                        對提示自動回答「是」
  -h, --help                       顯示此說明訊息並結束

安裝選項（選用）：

  --auto                           使用預設或自訂選項自動安裝 Headscale
  --serverurl  [URL]               伺服器 URL（例如 https://hs.example.com）
  --port       [數字]              Headscale 的 TCP 連接埠（1-65535，預設：8080）
  --listenaddr [位址]              監聽位址（預設：0.0.0.0，僅本機使用：127.0.0.1）
  --username   [名稱]              初始使用者名稱（預設：admin）
  --basedomain [網域]              MagicDNS 基礎網域（預設：headscale.internal）

也可不帶參數執行腳本以使用自訂選項。
```
</details>

## 安裝後

首次執行時，腳本將：
1. 下載並安裝 Headscale 二進位檔案
2. 建立 `headscale` 系統使用者和群組
3. 將設定寫入 `/etc/headscale/config.yaml`
4. 安裝並啟動 `headscale` systemd 服務
5. 建立初始使用者並輸出**可重複使用的預授權金鑰**

複製輸出中的預授權金鑰，使用官方 [Tailscale 客戶端](https://tailscale.com/download)連線裝置：

```bash
tailscale up --login-server https://hs.example.com --authkey <輸出中的金鑰>
```

## 客戶端設定

有關連線客戶端的說明，請參閱 Headscale 文件：

- [Android](https://headscale.net/stable/usage/connect/android/)
- [Apple（iOS / macOS）](https://headscale.net/stable/usage/connect/apple/)
- [Windows](https://headscale.net/stable/usage/connect/windows/)

## 管理 Headscale

安裝完成後，再次執行腳本即可管理你的伺服器。

**依節點金鑰註冊節點：**

```bash
sudo bash headscale.sh --registernode <key> --user admin
```

**新增使用者：**

```bash
sudo bash headscale.sh --adduser alice
```

**刪除使用者：**

```bash
sudo bash headscale.sh --deleteuser alice
```

**為使用者建立預授權金鑰：**

```bash
sudo bash headscale.sh --createkey --user alice
```

**列出所有使用者：**

```bash
sudo bash headscale.sh --listusers
```

**列出所有已註冊節點：**

```bash
sudo bash headscale.sh --listnodes
```

**列出特定使用者的節點：**

```bash
sudo bash headscale.sh --listnodes --user alice
```

**依 ID 刪除節點：**

```bash
sudo bash headscale.sh --deletenode 3
```

**列出預授權金鑰：**

```bash
sudo bash headscale.sh --listkeys
```

**解除安裝 Headscale：**

```bash
sudo bash headscale.sh --uninstall
```

**顯示說明：**

```bash
sudo bash headscale.sh --help
```

也可不帶參數執行腳本以進入互動式管理選單。

也可直接使用 `headscale <命令>` 執行 Headscale 命令。執行 `headscale -h` 或參閱 [Headscale 文件](https://headscale.net/) 查看可用命令。

## TLS 與反向代理

Tailscale 客戶端需要 HTTPS 才能實現完整功能。建議的設定是在 Headscale 前使用反向代理處理 TLS，然後在安裝時傳入 `--serverurl https://hs.example.com`（或在 `/etc/headscale/config.yaml` 中設定 `server_url` 並重新啟動服務）。

使用反向代理時，建議加入 `--listenaddr 127.0.0.1` 以將 Headscale 限制為僅在本機監聽。

**使用 [Caddy](https://caddyserver.com/docs/) 的範例**（透過 Let's Encrypt 自動申請 TLS）：

```
hs.example.com {
  reverse_proxy localhost:8080
}
```

**使用 nginx 的範例：**

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

**防火牆中需要開放的連接埠：**

| 連接埠 | 協定 | 用途 |
|---|---|---|
| `8080` | TCP | Headscale 協調伺服器（或反向代理連接埠） |
| `443` | TCP | HTTPS（使用反向代理時） |

## 設定

設定檔位於 `/etc/headscale/config.yaml`。編輯此檔案可修改伺服器 URL、基礎網域或 DNS 伺服器等設定，然後重新啟動服務：

```bash
sudo systemctl restart headscale
```

查看服務狀態和日誌：

```bash
sudo systemctl status headscale
sudo journalctl -u headscale -n 50
```

## 使用自訂選項自動安裝

```bash
sudo bash headscale.sh --auto \
  --serverurl https://hs.example.com \
  --port 8080 \
  --listenaddr 127.0.0.1 \
  --username admin \
  --basedomain headscale.internal
```

使用 `--auto` 時，所有安裝選項均為選用。若未提供 `--serverurl`，將自動偵測伺服器的公用 IP 位址並使用 HTTP（不建議用於正式環境）。

## 授權條款

Copyright (C) 2026 Lin Song   
本作品依據 [MIT 授權條款](https://opensource.org/licenses/MIT)授權。

**Headscale** 的版權歸 Juan Font 所有（2020 年），遵循 [BSD 3-Clause 授權條款](https://github.com/juanfont/headscale/blob/main/LICENSE)。

Tailscale® 是 Tailscale Inc. 的注冊商標。本專案與 Tailscale Inc. 無關聯，亦未獲其背書。