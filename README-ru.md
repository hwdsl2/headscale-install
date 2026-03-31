[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# Скрипт автоматической установки сервера Headscale

[![Build Status](https://github.com/hwdsl2/headscale-install/actions/workflows/main.yml/badge.svg)](https://github.com/hwdsl2/headscale-install/actions/workflows/main.yml)

**Также доступно:** [Сервер Headscale на Docker](https://github.com/hwdsl2/docker-headscale/blob/main/README-ru.md).

Установщик сервера Headscale для Ubuntu, Debian, AlmaLinux, Rocky Linux, CentOS, RHEL, Fedora и openSUSE.

Этот скрипт устанавливает и настраивает [Headscale](https://github.com/juanfont/headscale) — самостоятельно размещаемую реализацию координационного сервера Tailscale с открытым исходным кодом. Подключите все свои устройства с помощью официальных клиентских приложений Tailscale, управляя ими через собственный сервер.

См. также: скрипты автоматической установки серверов [WireGuard](https://github.com/hwdsl2/wireguard-install/blob/master/README-ru.md), [OpenVPN](https://github.com/hwdsl2/openvpn-install/blob/master/README-ru.md) и [IPsec VPN](https://github.com/hwdsl2/setup-ipsec-vpn/blob/master/README-ru.md).

## Возможности

- Полностью автоматическая установка сервера Headscale без участия пользователя
- Поддержка интерактивной установки с пользовательскими параметрами
- Поддержка управления пользователями, узлами и ключами предварительной авторизации
- Загрузка официального бинарного файла Headscale с проверкой контрольной суммы
- Установка Headscale как службы systemd с выделенным системным пользователем
- Автоматическая настройка правил файрвола (firewalld или iptables)

## Требования

- Linux-сервер (облачный сервер, VPS или выделенный сервер)
- Для production-использования настоятельно рекомендуется **публично доступное доменное имя с HTTPS**

> **Примечание:** Без HTTPS некоторые клиенты Tailscale могут не подключиться. Варианты настройки см. в разделе [TLS и обратный прокси](#tls-и-обратный-прокси).

## Установка

Загрузите скрипт на ваш Linux-сервер:

```bash
wget -O headscale.sh https://get.vpnsetup.net/hs
```

**Вариант 1:** Автоматическая установка с URL сервера.

```bash
sudo bash headscale.sh --auto --serverurl https://hs.example.com
```

Замените `https://hs.example.com` вашим реальным HTTPS URL сервера. Если `--serverurl` не указан, публичный IP-адрес сервера определяется автоматически и используется HTTP, что не рекомендуется для production. Варианты настройки см. в разделе [TLS и обратный прокси](#tls-и-обратный-прокси).

**Вариант 2:** Интерактивная установка с пользовательскими параметрами.

```bash
sudo bash headscale.sh
```

Вы можете настроить следующие параметры: URL сервера, TCP-порт, начальное имя пользователя и базовый домен MagicDNS.

<details>
<summary>
Нажмите здесь, если не удаётся загрузить.
</summary>

Также можно использовать `curl` для загрузки:

```bash
curl -fL -o headscale.sh https://get.vpnsetup.net/hs
```

Альтернативный URL для загрузки:

```bash
https://github.com/hwdsl2/headscale-install/raw/main/headscale-install.sh
```

Если загрузить не удаётся, откройте [headscale-install.sh](headscale-install.sh), затем нажмите кнопку `Raw` справа. Нажмите `Ctrl/Cmd+A` для выделения всего, `Ctrl/Cmd+C` для копирования, затем вставьте в любой текстовый редактор.
</details>

<details>
<summary>
Просмотреть справку по использованию скрипта.
</summary>

```
Использование: bash headscale.sh [параметры]

Параметры:

  --adduser    [имя]             добавить нового пользователя
  --deleteuser [имя]             удалить пользователя (и все его узлы и ключи)
  --listusers                    список всех пользователей
  --listnodes                    список всех зарегистрированных узлов
  --listnodes  --user [имя]      список узлов конкретного пользователя
  --registernode [ключ узла]     зарегистрировать узел по его ключу
                --user [имя]     (требует --user <имя>)
  --deletenode [ID узла]         удалить узел по числовому ID
  --createkey  --user [имя]      создать многоразовый ключ предавторизации для пользователя
  --listkeys                     список ключей предавторизации (все пользователи)
  --listkeys   --user [имя]      список ключей предавторизации конкретного пользователя
  --uninstall                    удалить Headscale и всю конфигурацию
  -y, --yes                      отвечать «да» на все запросы
  -h, --help                     показать это сообщение и выйти

Параметры установки (необязательные):

  --auto                         автоматически установить Headscale с параметрами по умолчанию или пользовательскими
  --serverurl  [URL]             URL сервера (например, https://hs.example.com)
  --port       [число]           TCP-порт для Headscale (1-65535, по умолчанию: 8080)
  --username   [имя]             имя начального пользователя (по умолчанию: admin)
  --basedomain [домен]           базовый домен MagicDNS (по умолчанию: headscale.internal)

Также можно запустить скрипт без аргументов для пользовательской настройки.
```
</details>

## После установки

При первом запуске скрипт:
1. Загружает и устанавливает бинарный файл Headscale
2. Создаёт системного пользователя и группу `headscale`
3. Записывает конфигурацию в `/etc/headscale/config.yaml`
4. Устанавливает и запускает службу systemd `headscale`
5. Создаёт начального пользователя и выводит **многоразовый ключ предварительной авторизации**

Скопируйте ключ предварительной авторизации из вывода и подключите устройство с помощью официального [клиента Tailscale](https://tailscale.com/download):

```bash
tailscale up --login-server https://hs.example.com --authkey <ключ-из-вывода>
```

## Управление Headscale

После установки запустите скрипт снова для управления сервером.

**Зарегистрировать узел по его ключу:**

```bash
sudo bash headscale.sh --registernode <key> --user admin
```

**Добавить пользователя:**

```bash
sudo bash headscale.sh --adduser alice
```

**Создать ключ предварительной авторизации для пользователя:**

```bash
sudo bash headscale.sh --createkey --user alice
```

**Список всех пользователей:**

```bash
sudo bash headscale.sh --listusers
```

**Список всех зарегистрированных узлов:**

```bash
sudo bash headscale.sh --listnodes
```

**Список узлов конкретного пользователя:**

```bash
sudo bash headscale.sh --listnodes --user alice
```

**Удалить узел по ID:**

```bash
sudo bash headscale.sh --deletenode 3
```

**Список ключей предварительной авторизации:**

```bash
sudo bash headscale.sh --listkeys
```

**Удалить Headscale:**

```bash
sudo bash headscale.sh --uninstall
```

Также можно запустить скрипт без аргументов для интерактивного меню управления.

Также можно выполнять команды Headscale напрямую с помощью `headscale <команда>`. Доступные команды см. в [документации Headscale](https://headscale.net/).

## TLS и обратный прокси

Для полной функциональности клиентам Tailscale необходим HTTPS. Рекомендуемая схема — настроить обратный прокси перед Headscale для обработки TLS, затем передать `--serverurl https://hs.example.com` при установке (или задать `server_url` в `/etc/headscale/config.yaml` и перезапустить службу).

**Пример с Caddy** (автоматический TLS через Let's Encrypt):

```
hs.example.com {
  reverse_proxy localhost:8080
}
```

**Пример с nginx:**

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

**Порты для открытия в файрволе:**

| Порт | Протокол | Назначение |
|---|---|---|
| `8080` | TCP | Координационный сервер Headscale (или порт обратного прокси) |
| `443` | TCP | HTTPS (при использовании обратного прокси) |

## Конфигурация

Файл конфигурации находится по адресу `/etc/headscale/config.yaml`. Отредактируйте его для изменения настроек, таких как URL сервера, базовый домен или DNS-серверы, затем перезапустите службу:

```bash
sudo systemctl restart headscale
```

Проверка статуса службы и просмотр логов:

```bash
sudo systemctl status headscale
sudo journalctl -u headscale -n 50
```

## Автоматическая установка с пользовательскими параметрами

```bash
sudo bash headscale.sh --auto \
  --serverurl https://hs.example.com \
  --port 8080 \
  --username admin \
  --basedomain headscale.internal
```

При использовании `--auto` все параметры установки необязательны. Если `--serverurl` не указан, публичный IP-адрес сервера определяется автоматически и используется HTTP (не рекомендуется для production).

## Лицензия

Copyright (C) 2026 Lin Song
Эта работа распространяется под [лицензией MIT](https://opensource.org/licenses/MIT).

**Headscale** является Copyright (c) 2020, Juan Font, и распространяется под [лицензией BSD 3-Clause](https://github.com/juanfont/headscale/blob/main/LICENSE).

Tailscale® является зарегистрированным товарным знаком Tailscale Inc. Данный проект не связан с Tailscale Inc. и не одобрен ею.