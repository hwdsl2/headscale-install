#!/bin/bash
#
# https://github.com/hwdsl2/headscale-install
#
# Copyright (C) 2026 Lin Song <linsongui@gmail.com>
#
# This work is licensed under the MIT License
# See: https://opensource.org/licenses/MIT

exiterr() {
  echo "Error: $1" >&2
  exit 1
}
exiterr2() { exiterr "Package installation failed. Check your package manager."; }
exiterr3() { exiterr "'yum install' failed."; }
exiterr4() { exiterr "'zypper install' failed."; }

HS_VERSION="0.28.0"
HS_CONF="/etc/headscale/config.yaml"
HS_CONF_DIR="/etc/headscale"
HS_DATA_DIR="/var/lib/headscale"
HS_RUN_DIR="/var/run/headscale"
HS_SOCK="/var/run/headscale/headscale.sock"
HS_BIN="/usr/local/bin/headscale"
HS_SVC="/etc/systemd/system/headscale.service"
HS_IPT_SVC="/etc/systemd/system/headscale-iptables.service"

check_ip() {
  IP_REGEX='^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$'
  printf '%s' "$1" | tr -d '\n' | grep -Eq "$IP_REGEX"
}

check_pvt_ip() {
  IPP_REGEX='^(10|127|172\.(1[6-9]|2[0-9]|3[0-1])|192\.168|169\.254)\.'
  printf '%s' "$1" | tr -d '\n' | grep -Eq "$IPP_REGEX"
}

check_dns_name() {
  FQDN_REGEX='^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'
  printf '%s' "$1" | tr -d '\n' | grep -Eq "$FQDN_REGEX"
}

check_url() {
  printf '%s' "$1" | tr -d '\n' | grep -Eq '^https?://[^[:space:]]+$'
}

check_port() {
  printf '%s' "$1" | tr -d '\n' | grep -Eq '^[0-9]+$' &&
    [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

check_root() {
  if [ "$(id -u)" != 0 ]; then
    exiterr "This installer must be run as root. Try 'sudo bash $0'"
  fi
}

check_shell() {
  if readlink /proc/$$/exe 2>/dev/null | grep -q "dash"; then
    exiterr 'This installer needs to be run with "bash", not "sh".'
  fi
}

check_os() {
  if grep -qs "ubuntu" /etc/os-release; then
    os="ubuntu"
    os_version=$(grep 'VERSION_ID' /etc/os-release | cut -d '"' -f 2 | tr -d '.')
    if [[ -z "$os_version" || ! "$os_version" =~ ^[0-9]+$ || "$os_version" -lt 2004 ]]; then
      ubuntu_codename=$(grep 'UBUNTU_CODENAME' /etc/os-release | cut -d '=' -f 2 | tr -d '"')
      case "$ubuntu_codename" in
      focal) os_version=2004 ;;
      jammy) os_version=2204 ;;
      noble) os_version=2404 ;;
      esac
    fi
  elif [[ -e /etc/debian_version ]]; then
    os="debian"
    os_version=$(grep -oE '[0-9]+' /etc/debian_version | head -1)
    if [[ -z "$os_version" ]]; then
      debian_codename=$(grep '^DEBIAN_CODENAME' /etc/os-release 2>/dev/null | cut -d '=' -f 2)
      case "$debian_codename" in
      buster) os_version=10 ;;
      bullseye) os_version=11 ;;
      bookworm) os_version=12 ;;
      trixie) os_version=13 ;;
      esac
    fi
  elif grep -qs "Alibaba Cloud Linux" /etc/system-release 2>/dev/null; then
    os="centos"
    al_ver=$(grep -oE '[0-9]+' /etc/system-release | head -1)
    if [[ "$al_ver" -ge 3 ]]; then
      os_version=9
    else
      os_version=7
    fi
  elif [[ -e /etc/almalinux-release || -e /etc/rocky-release || -e /etc/centos-release ]]; then
    os="centos"
    os_version=$(grep -shoE '[0-9]+' /etc/almalinux-release /etc/rocky-release /etc/centos-release | head -1)
  elif [[ -e /etc/fedora-release ]]; then
    os="fedora"
    os_version=$(grep -oE '[0-9]+' /etc/fedora-release | head -1)
  elif [[ -e /etc/redhat-release ]]; then
    os="rhel"
    os_version=$(grep -oE '[0-9]+' /etc/redhat-release | head -1)
  elif [[ -e /etc/SUSE-brand && "$(head -1 /etc/SUSE-brand)" == "openSUSE" ]] ||
    grep -qs '^ID=.*opensuse' /etc/os-release; then
    os="openSUSE"
    if [[ -e /etc/SUSE-brand ]]; then
      os_version=$(tail -1 /etc/SUSE-brand | grep -oE '[0-9\\.]+')
    else
      os_version=$(grep 'VERSION_ID' /etc/os-release | cut -d '"' -f 2)
    fi
  else
    exiterr "This installer seems to be running on an unsupported distribution.
Supported distros are Ubuntu, Debian, AlmaLinux, Rocky Linux, CentOS, RHEL, Fedora and openSUSE."
  fi
}

check_os_ver() {
  if [[ "$os" == "ubuntu" && "$os_version" -lt 2004 ]]; then
    exiterr "Ubuntu 20.04 or higher is required to use this installer.
This version of Ubuntu is too old and unsupported."
  fi
  if [[ "$os" == "debian" && "$os_version" -lt 11 ]]; then
    exiterr "Debian 11 or higher is required to use this installer.
This version of Debian is too old and unsupported."
  fi
  if [[ "$os" == "centos" && "$os_version" -lt 8 ]]; then
    exiterr "CentOS 8 or higher is required to use this installer.
This version of CentOS is too old and unsupported."
  fi
  if [[ "$os" == "rhel" && "$os_version" -lt 8 ]]; then
    exiterr "RHEL 8 or higher is required to use this installer.
This version of RHEL is too old and unsupported."
  fi
}

check_systemd() {
  if ! command -v systemctl >/dev/null 2>&1; then
    exiterr "This installer requires systemd.
To run Headscale in Docker instead, see: https://github.com/hwdsl2/docker-headscale"
  fi
}

detect_arch() {
  case "$(uname -m)" in
  x86_64) arch="amd64" ;;
  aarch64 | arm64) arch="arm64" ;;
  *)
    exiterr "Unsupported CPU architecture: $(uname -m)
Only x86_64 (amd64) and aarch64 (arm64) are supported."
    ;;
  esac
}

set_username() {
  username="${unsanitized_username//[^0-9a-zA-Z_-]/_}"
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case $1 in
    --auto)
      auto=1
      shift
      ;;
    --adduser)
      add_user=1
      unsanitized_username="$2"
      shift
      shift
      ;;
    --deleteuser)
      delete_user=1
      unsanitized_username="$2"
      shift
      shift
      ;;
    --listusers)
      list_users=1
      shift
      ;;
    --listnodes)
      list_nodes=1
      shift
      ;;
    --deletenode)
      delete_node=1
      target_node_id="$2"
      shift
      shift
      ;;
    --createkey)
      create_key=1
      shift
      ;;
    --listkeys)
      list_keys=1
      shift
      ;;
    --user)
      target_user="$2"
      shift
      shift
      ;;
    --uninstall)
      remove_hs=1
      shift
      ;;
    --serverurl)
      server_url="$2"
      shift
      shift
      ;;
    --port)
      server_port="$2"
      shift
      shift
      ;;
    --username)
      first_username="$2"
      shift
      shift
      ;;
    --basedomain)
      base_domain_arg="$2"
      shift
      shift
      ;;
    -y | --yes)
      assume_yes=1
      shift
      ;;
    -h | --help)
      show_usage
      ;;
    *)
      show_usage "Unknown parameter: $1"
      ;;
    esac
  done
}

check_args() {
  local mgmt_count
  mgmt_count=$((add_user + delete_user + list_users + list_nodes + delete_node + \
    create_key + list_keys))

  if [ "$auto" != 0 ] && [ -e "$HS_CONF" ]; then
    show_usage "Invalid parameter '--auto'. Headscale is already set up on this server."
  fi
  if [ "$remove_hs" = 1 ]; then
    if [ "$((mgmt_count + auto))" -gt 0 ]; then
      show_usage "Invalid parameters. '--uninstall' cannot be specified with other parameters."
    fi
  fi
  if [ ! -e "$HS_CONF" ]; then
    st_text="You must first set up Headscale before"
    [ "$add_user" = 1 ] && exiterr "$st_text adding a user."
    [ "$delete_user" = 1 ] && exiterr "$st_text deleting a user."
    [ "$list_users" = 1 ] && exiterr "$st_text listing users."
    [ "$list_nodes" = 1 ] && exiterr "$st_text listing nodes."
    [ "$delete_node" = 1 ] && exiterr "$st_text deleting a node."
    [ "$create_key" = 1 ] && exiterr "$st_text creating a pre-auth key."
    [ "$list_keys" = 1 ] && exiterr "$st_text listing pre-auth keys."
    [ "$remove_hs" = 1 ] && exiterr "Cannot remove Headscale because it has not been set up on this server."
  fi
  if [ "$mgmt_count" -gt 1 ]; then
    show_usage "Invalid parameters. Specify only one management action at a time."
  fi
  if [ "$add_user" = 1 ]; then
    set_username
    if [ -z "$username" ]; then
      exiterr "Invalid user name. Use one word only, no special characters except '-' and '_'."
    fi
  fi
  if [ "$delete_user" = 1 ]; then
    set_username
    if [ -z "$username" ]; then
      exiterr "Invalid user name. Use one word only, no special characters except '-' and '_'."
    fi
  fi
  if [ "$create_key" = 1 ] && [ -z "$target_user" ]; then
    exiterr "--createkey requires --user <name>."
  fi
  if [ "$delete_node" = 1 ]; then
    if [ -z "$target_node_id" ]; then
      exiterr "--deletenode requires a node ID. Use '--listnodes' to find IDs."
    fi
    if ! printf '%s' "$target_node_id" | grep -Eq '^[0-9]+$'; then
      exiterr "Node ID must be a positive integer."
    fi
  fi
  if [ -n "$server_url" ] || [ -n "$server_port" ] ||
    [ -n "$first_username" ] || [ -n "$base_domain_arg" ]; then
    if [ -e "$HS_CONF" ]; then
      show_usage "Invalid parameters. Headscale is already set up on this server."
    elif [ "$auto" = 0 ]; then
      show_usage "Invalid parameters. You must specify '--auto' when using these parameters."
    fi
  fi
  if [ -n "$server_url" ] && ! check_url "$server_url"; then
    exiterr "Invalid server URL '$server_url'. Must start with http:// or https://."
  fi
  if [ -n "$server_port" ] && ! check_port "$server_port"; then
    exiterr "Invalid port. Must be an integer between 1 and 65535."
  fi
  if [ -n "$first_username" ]; then
    unsanitized_username="$first_username"
    set_username
    if [ -z "$username" ]; then
      exiterr "Invalid user name. Use one word only, no special characters except '-' and '_'."
    fi
  fi
  if [ -n "$base_domain_arg" ] && ! check_dns_name "$base_domain_arg"; then
    exiterr "Invalid base domain '$base_domain_arg'. Must be a valid domain name (e.g. headscale.internal)."
  fi
}

check_nftables() {
  if [ "$os" = "centos" ] || [ "$os" = "rhel" ]; then
    if systemctl is-active --quiet nftables 2>/dev/null; then
      exiterr "This system has nftables enabled, which is not supported by this installer.
Please disable nftables or open TCP port $port manually in your firewall."
    fi
  fi
}

install_wget() {
  if ! hash wget 2>/dev/null && ! hash curl 2>/dev/null; then
    if [ "$auto" = 0 ]; then
      echo "Wget is required to use this installer."
      read -n1 -r -p "Press any key to install Wget and continue..."
    fi
    if [ "$os" = "debian" ] || [ "$os" = "ubuntu" ]; then
      export DEBIAN_FRONTEND=noninteractive
      (
        set -x
        apt-get -yqq update || apt-get -yqq update
        apt-get -yqq install wget >/dev/null
      ) || exiterr2
    elif [ "$os" = "openSUSE" ]; then
      (
        set -x
        zypper install -y wget >/dev/null
      ) || exiterr4
    else
      (
        set -x
        yum -y -q install wget >/dev/null
      ) || exiterr3
    fi
  fi
}

show_header() {
  cat <<'EOF'

Headscale Script
https://github.com/hwdsl2/headscale-install
EOF
}

show_header2() {
  cat <<'EOF'

Welcome to this Headscale server installer!
GitHub: https://github.com/hwdsl2/headscale-install

EOF
}

show_header3() {
  cat <<'EOF'

Copyright (C) 2026 Lin Song
EOF
}

show_usage() {
  if [ -n "$1" ]; then
    echo "Error: $1" >&2
  fi
  show_header
  show_header3
  cat 1>&2 <<EOF

Usage: bash $0 [options]

Options:

  --adduser    [user name]       add a new user
  --deleteuser [user name]       delete a user (and all their nodes and keys)
  --listusers                    list all users
  --listnodes                    list all registered nodes
  --listnodes  --user [name]     list nodes for a specific user
  --deletenode [node ID]         delete a node by its numeric ID
  --createkey  --user [name]     create a reusable pre-auth key for a user
  --listkeys                     list pre-auth keys (all users)
  --listkeys   --user [name]     list pre-auth keys for a specific user
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
EOF
  exit 1
}

show_welcome() {
  if [ "$auto" = 0 ]; then
    show_header2
    echo 'I need to ask you a few questions before starting setup.'
    echo 'You can use the default options and just press enter if you are OK with them.'
  else
    show_header
    op_text=default
    if [ -n "$server_url" ] || [ -n "$server_port" ] ||
      [ -n "$first_username" ] || [ -n "$base_domain_arg" ]; then
      op_text=custom
    fi
    echo
    echo "Starting Headscale setup using $op_text options."
  fi
}

show_dns_name_note() {
  cat <<EOF

Note: Make sure '$1'
      resolves to the IPv4 address of this server.
EOF
}

find_public_ip() {
  ip_url1="http://ipv4.icanhazip.com"
  ip_url2="http://ip1.dynupdate.no-ip.com"
  get_public_ip=$(grep -m 1 -oE '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' \
    <<<"$(wget -T 10 -t 1 -4qO- "$ip_url1" || curl -m 10 -4Ls "$ip_url1")")
  if ! check_ip "$get_public_ip"; then
    get_public_ip=$(grep -m 1 -oE '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' \
      <<<"$(wget -T 10 -t 1 -4qO- "$ip_url2" || curl -m 10 -4Ls "$ip_url2")")
  fi
}

detect_ip() {
  if [[ $(ip -4 addr | grep inet | grep -vEc '127(\.[0-9]{1,3}){3}') -eq 1 ]]; then
    ip=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' |
      cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}')
  else
    ip=$(ip -4 route get 1 | sed 's/ uid .*//' | awk '{print $NF;exit}' 2>/dev/null)
    if ! check_ip "$ip"; then
      find_public_ip
      ip_match=0
      if [ -n "$get_public_ip" ]; then
        ip_list=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' |
          cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}')
        while IFS= read -r line; do
          if [ "$line" = "$get_public_ip" ]; then
            ip_match=1
            ip="$line"
          fi
        done <<<"$ip_list"
      fi
      if [ "$ip_match" = 0 ]; then
        if [ "$auto" = 0 ]; then
          echo
          echo "Which IPv4 address should be used?"
          num_of_ip=$(ip -4 addr | grep inet | grep -vEc '127(\.[0-9]{1,3}){3}')
          ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' |
            cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | nl -s ') '
          read -rp "IPv4 address [1]: " ip_num
          until [[ -z "$ip_num" || "$ip_num" =~ ^[0-9]+$ && "$ip_num" -le "$num_of_ip" ]]; do
            echo "$ip_num: invalid selection."
            read -rp "IPv4 address [1]: " ip_num
          done
          [[ -z "$ip_num" ]] && ip_num=1
        else
          ip_num=1
        fi
        ip=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' |
          cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | sed -n "$ip_num"p)
      fi
    fi
  fi
  if ! check_ip "$ip"; then
    echo "Error: Could not detect this server's IP address." >&2
    echo "Abort. No changes were made." >&2
    exit 1
  fi
}

check_nat_ip() {
  if check_pvt_ip "$ip"; then
    find_public_ip
    if ! check_ip "$get_public_ip"; then
      if [ "$auto" = 0 ]; then
        echo
        echo "This server is behind NAT. What is the public IPv4 address?"
        read -rp "Public IPv4 address: " public_ip
        until check_ip "$public_ip"; do
          echo "Invalid input."
          read -rp "Public IPv4 address: " public_ip
        done
      else
        echo "Error: Could not detect this server's public IP." >&2
        echo "Abort. No changes were made." >&2
        exit 1
      fi
    else
      public_ip="$get_public_ip"
    fi
  fi
}

enter_server_url() {
  echo
  echo "Do you want Tailscale clients to connect to this server using a domain name"
  printf "and HTTPS, e.g. https://hs.example.com? [y/N] "
  read -r response
  case $response in
  [yY][eE][sS] | [yY])
    use_domain=1
    echo
    ;;
  *)
    use_domain=0
    ;;
  esac
  if [ "$use_domain" = 1 ]; then
    read -rp "Enter the HTTPS URL for this server (e.g. https://hs.example.com): " srv_url_i
    # Accept bare domain name and add https:// automatically
    if check_dns_name "$srv_url_i"; then
      srv_url_i="https://${srv_url_i}"
    fi
    until check_url "$srv_url_i" && printf '%s' "$srv_url_i" | grep -q '^https://'; do
      echo "Invalid URL. Enter a valid HTTPS URL (e.g. https://hs.example.com)."
      read -rp "Enter the HTTPS URL for this server: " srv_url_i
      if check_dns_name "$srv_url_i"; then
        srv_url_i="https://${srv_url_i}"
      fi
    done
    server_url="${srv_url_i%/}"
    show_dns_name_note "${server_url#https://}"
  else
    detect_ip
    check_nat_ip
    server_url=""
  fi
}

select_port() {
  if [ "$auto" = 0 ]; then
    echo
    echo "Which TCP port should Headscale listen on?"
    read -rp "Port [8080]: " port
    until [[ -z "$port" || "$port" =~ ^[0-9]+$ && "$port" -le 65535 ]]; do
      echo "$port: invalid port."
      read -rp "Port [8080]: " port
    done
    [[ -z "$port" ]] && port=8080
  else
    [ -n "$server_port" ] && port="$server_port" || port=8080
  fi
}

enter_first_username() {
  if [ "$auto" = 0 ]; then
    echo
    echo "Enter a name for the initial user:"
    read -rp "Name [admin]: " unsanitized_username
    set_username
    [[ -z "$username" ]] && username="admin"
  else
    if [ -n "$first_username" ]; then
      unsanitized_username="$first_username"
      set_username
    else
      username="admin"
    fi
  fi
}

enter_base_domain() {
  if [ "$auto" = 0 ]; then
    echo
    echo "Enter the MagicDNS base domain. Node hostnames will be <hostname>.<domain>."
    echo "This domain must not be the same as, or a parent of, your server's domain."
    read -rp "Base domain [headscale.internal]: " bd_i
    if [ -n "$bd_i" ]; then
      until check_dns_name "$bd_i"; do
        echo "Invalid domain. Enter a valid domain name (e.g. headscale.internal)."
        read -rp "Base domain [headscale.internal]: " bd_i
      done
      base_domain="$bd_i"
    else
      base_domain="headscale.internal"
    fi
  else
    [ -n "$base_domain_arg" ] && base_domain="$base_domain_arg" || base_domain="headscale.internal"
  fi
}

compute_server_url() {
  if [ -n "$server_url" ]; then
    computed_server_url="${server_url%/}"
  else
    local addr="${public_ip:-$ip}"
    computed_server_url="http://${addr}:${port}"
  fi
}

show_config() {
  if [ "$auto" != 0 ]; then
    echo
    echo "Server URL:  $computed_server_url"
    echo "Port:        TCP/$port"
    echo "Username:    $username"
    echo "Base domain: $base_domain"
  fi
}

show_setup_ready() {
  if [ "$auto" = 0 ]; then
    echo
    echo "Headscale installation is ready to begin."
  fi
}

abort_and_exit() {
  echo "Abort. No changes were made." >&2
  exit 1
}

confirm_setup() {
  if [ "$auto" = 0 ]; then
    printf "Do you want to continue? [Y/n] "
    read -r response
    case $response in
    [yY][eE][sS] | [yY] | '')
      :
      ;;
    *)
      abort_and_exit
      ;;
    esac
  fi
}

show_start_setup() {
  echo
  echo "Installing Headscale, please wait..."
}

download_headscale() {
  detect_arch
  local hs_bin="headscale_${HS_VERSION}_linux_${arch}"
  local hs_base_url="https://github.com/juanfont/headscale/releases/download/v${HS_VERSION}"
  local tmp_dir
  tmp_dir=$(mktemp -d 2>/dev/null) || exiterr "Failed to create temporary directory."
  echo "  Downloading Headscale v${HS_VERSION} (${arch})..."
  (
    set -x
    wget -t 3 -T 60 -q -O "$tmp_dir/$hs_bin" "$hs_base_url/$hs_bin" ||
      curl -m 90 -fsSL "$hs_base_url/$hs_bin" -o "$tmp_dir/$hs_bin"
  ) 2>/dev/null || {
    rm -rf "$tmp_dir"
    exiterr "Failed to download Headscale. Check your internet connection."
  }
  (
    set -x
    wget -t 3 -T 30 -q -O "$tmp_dir/checksums.txt" "$hs_base_url/checksums.txt" ||
      curl -m 30 -fsSL "$hs_base_url/checksums.txt" -o "$tmp_dir/checksums.txt"
  ) 2>/dev/null || {
    rm -rf "$tmp_dir"
    exiterr "Failed to download checksums file."
  }
  echo "  Verifying checksum..."
  (cd "$tmp_dir" && grep " $hs_bin$" checksums.txt | sha256sum -c -) >/dev/null 2>&1 ||
    {
      rm -rf "$tmp_dir"
      exiterr "Headscale checksum verification failed."
    }
  mv "$tmp_dir/$hs_bin" "$HS_BIN"
  chmod 755 "$HS_BIN"
  rm -rf "$tmp_dir"
}

create_headscale_user() {
  if ! getent group headscale >/dev/null 2>&1; then
    groupadd --system headscale
  fi
  if ! id headscale >/dev/null 2>&1; then
    useradd --system --shell /usr/sbin/nologin \
      --gid headscale --home-dir "$HS_DATA_DIR" \
      --comment "Headscale daemon" headscale
  fi
}

create_directories() {
  mkdir -p "$HS_CONF_DIR" "$HS_DATA_DIR" "$HS_RUN_DIR"
  chown root:headscale "$HS_CONF_DIR"
  chmod 750 "$HS_CONF_DIR"
  chown headscale:headscale "$HS_DATA_DIR" "$HS_RUN_DIR"
  chmod 750 "$HS_DATA_DIR" "$HS_RUN_DIR"
}

create_config() {
  # Config structure derived from config-example.yaml in juanfont/headscale
  # https://github.com/juanfont/headscale (BSD 3-Clause License)
  cat >"$HS_CONF" <<EOF
# Headscale configuration
# Generated by headscale-install — edit this file to change settings.
# https://github.com/hwdsl2/headscale-install

server_url: ${computed_server_url}
listen_addr: 0.0.0.0:${port}
metrics_listen_addr: 127.0.0.1:9090
grpc_listen_addr: 127.0.0.1:50443
grpc_allow_insecure: false

noise:
  private_key_path: ${HS_DATA_DIR}/noise_private.key

prefixes:
  v4: 100.64.0.0/10
  v6: fd7a:115c:a1e0::/48
  allocation: sequential

derp:
  server:
    enabled: false
  urls:
    - https://controlplane.tailscale.com/derpmap/default
  auto_update_enabled: true
  update_frequency: 3h

disable_check_updates: false
ephemeral_node_inactivity_timeout: 30m

database:
  type: sqlite
  sqlite:
    path: ${HS_DATA_DIR}/db.sqlite
    write_ahead_log: true

log:
  level: info
  format: text

policy:
  mode: file
  path: ""

dns:
  magic_dns: true
  base_domain: ${base_domain}
  override_local_dns: true
  nameservers:
    global:
      - 1.1.1.1
      - 1.0.0.1

unix_socket: ${HS_SOCK}
unix_socket_permission: "0770"

logtail:
  enabled: false
randomize_client_port: false
EOF
  chmod 640 "$HS_CONF"
  chown root:headscale "$HS_CONF"
}

install_service() {
  # Service file structure references packaging/systemd/headscale.service
  # in juanfont/headscale (BSD 3-Clause License)
  cat >"$HS_SVC" <<EOF
[Unit]
Description=Headscale coordination server for Tailscale
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=headscale
Group=headscale
ExecStart=${HS_BIN} serve -c ${HS_CONF}
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=5
WorkingDirectory=${HS_DATA_DIR}
RuntimeDirectory=headscale
ReadWritePaths=${HS_DATA_DIR} ${HS_RUN_DIR}

NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict

[Install]
WantedBy=multi-user.target
EOF
  (
    set -x
    systemctl daemon-reload
  )
}

create_firewall_rules() {
  check_nftables
  if systemctl is-active --quiet firewalld.service; then
    firewall-cmd -q --add-port="$port"/tcp
    firewall-cmd -q --permanent --add-port="$port"/tcp
  else
    iptables_path=$(command -v iptables)
    if [[ $(systemd-detect-virt 2>/dev/null) == "openvz" ]] &&
      readlink -f "$(command -v iptables)" 2>/dev/null | grep -q "nft" &&
      hash iptables-legacy 2>/dev/null; then
      iptables_path=$(command -v iptables-legacy)
    fi
    echo "[Unit]
After=network-online.target
Wants=network-online.target
[Service]
Type=oneshot
ExecStart=$iptables_path -w 5 -I INPUT -p tcp --dport $port -j ACCEPT
ExecStop=$iptables_path -w 5 -D INPUT -p tcp --dport $port -j ACCEPT
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target" >"$HS_IPT_SVC"
    (
      set -x
      systemctl enable --now headscale-iptables.service >/dev/null 2>&1
    )
  fi
}

remove_firewall_rules() {
  local fwd_port
  fwd_port=$(grep '^listen_addr:' "$HS_CONF" 2>/dev/null | grep -oE '[0-9]+$')
  [ -z "$fwd_port" ] && fwd_port=8080
  if systemctl is-active --quiet firewalld.service; then
    firewall-cmd -q --remove-port="$fwd_port"/tcp 2>/dev/null
    firewall-cmd -q --permanent --remove-port="$fwd_port"/tcp 2>/dev/null
  elif [ -f "$HS_IPT_SVC" ]; then
    systemctl disable --now headscale-iptables.service 2>/dev/null
    rm -f "$HS_IPT_SVC"
  fi
}

update_rclocal() {
  ipt_cmd="systemctl restart headscale-iptables.service"
  if [ -f "$HS_IPT_SVC" ] && ! grep -qs "$ipt_cmd" /etc/rc.local; then
    if [ ! -f /etc/rc.local ]; then
      echo '#!/bin/sh' >/etc/rc.local
    else
      if [ "$os" = "ubuntu" ] || [ "$os" = "debian" ]; then
        sed --follow-symlinks -i '/^exit 0/d' /etc/rc.local
      fi
    fi
    cat >>/etc/rc.local <<EOF2

$ipt_cmd
EOF2
    if [ "$os" = "ubuntu" ] || [ "$os" = "debian" ]; then
      echo "exit 0" >>/etc/rc.local
    fi
    chmod +x /etc/rc.local
  fi
}

remove_rclocal_rules() {
  ipt_cmd="systemctl restart headscale-iptables.service"
  if grep -qs "$ipt_cmd" /etc/rc.local 2>/dev/null; then
    sed --follow-symlinks -i "/^$ipt_cmd/d" /etc/rc.local
  fi
}

start_hs_service() {
  (
    set -x
    systemctl enable --now headscale.service >/dev/null 2>&1
  )
}

wait_for_socket() {
  local i=0
  echo
  printf 'Waiting for Headscale to start'
  while [ "$i" -lt 30 ]; do
    [ -S "$HS_SOCK" ] && echo "" && return 0
    printf '.'
    sleep 1
    i=$((i + 1))
  done
  echo ""
  return 1
}

hs_cmd() {
  "$HS_BIN" -c "$HS_CONF" "$@"
}

get_user_id() {
  local uname="$1"
  hs_cmd users list --name "$uname" -o json 2>/dev/null |
    tr -d ' \n\t' | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2
}

create_initial_user() {
  echo
  echo "Creating user '$username'..."
  hs_cmd users create "$username" 2>&1 || true
}

create_initial_key() {
  local user_id
  user_id=$(get_user_id "$username")
  echo
  echo "=================================================================="
  echo " Initial pre-auth key"
  echo " (user: $username, reusable, expires in 90 days)"
  echo "=================================================================="
  if [ -n "$user_id" ]; then
    hs_cmd preauthkeys create \
      --user "$user_id" \
      --reusable \
      --expiration 90d 2>&1 || true
  else
    echo "Warning: Could not find user '$username'. Skipping pre-auth key creation." >&2
    echo "Create a key manually: bash $0 --createkey --user $username" >&2
  fi
  echo "=================================================================="
}

finish_setup() {
  echo
  echo "Finished!"
  echo
  echo "Headscale server URL: $computed_server_url"
  echo
  echo "Connect a Tailscale client to this server:"
  echo "  tailscale up --login-server $computed_server_url --authkey <key-above>"
  echo
  echo "Manage this server by running this script again."
  if [ -z "$server_url" ] && check_ip "${public_ip:-$ip}" 2>/dev/null; then
    echo
    echo "  *** NOTE: Using plain HTTP. For production, set up a TLS reverse proxy ***"
    echo "  *** and re-run with --serverurl https://your-domain.example.com        ***"
  fi
}

select_menu_option() {
  echo
  echo "Headscale is already installed."
  echo
  echo "Select an option:"
  echo "   1) Add a new user"
  echo "   2) Delete a user"
  echo "   3) List users"
  echo "   4) List all nodes"
  echo "   5) Delete a node"
  echo "   6) Create a pre-auth key"
  echo "   7) List pre-auth keys"
  echo "   8) Remove Headscale"
  echo "   9) Exit"
  read -rp "Option: " option
  until [[ "$option" =~ ^[1-9]$ ]]; do
    echo "$option: invalid selection."
    read -rp "Option: " option
  done
}

check_service_running() {
  if ! systemctl is-active --quiet headscale.service 2>/dev/null; then
    exiterr "Headscale service is not running. Start it with: systemctl start headscale"
  fi
  if [ ! -S "$HS_SOCK" ]; then
    exiterr "Headscale socket not found at $HS_SOCK. Service may not have started correctly."
  fi
}

enter_username_interactive() {
  echo
  echo "Provide a user name:"
  read -rp "Name: " unsanitized_username
  [ -z "$unsanitized_username" ] && abort_and_exit
  set_username
  while [ -z "$username" ]; do
    echo "Invalid user name. Use one word only, no special characters except '-' and '_'."
    read -rp "Name: " unsanitized_username
    [ -z "$unsanitized_username" ] && abort_and_exit
    set_username
  done
}

do_add_user() {
  echo
  echo "Adding user '$username'..."
  if hs_cmd users create "$username" 2>&1; then
    echo
    echo "User '$username' created."
    echo "Create a pre-auth key for this user:"
    echo "  bash $0 --createkey --user $username"
  else
    echo
    echo "Failed to create user '$username' (it may already exist)." >&2
    echo "Use '--listusers' to see existing users." >&2
    exit 1
  fi
  echo
}

do_delete_user() {
  if [ "$assume_yes" != 1 ]; then
    echo
    read -rp "Delete user '$username' and all their nodes and keys? [y/N]: " confirm
    case $confirm in
    [yY][eE][sS] | [yY]) ;;
    *)
      echo
      echo "Deletion aborted."
      echo
      exit 1
      ;;
    esac
  fi
  echo
  echo "Deleting user '$username'..."
  if hs_cmd users delete "$username" 2>&1; then
    echo
    echo "User '$username' deleted."
  else
    echo
    echo "Failed to delete user '$username'." >&2
    echo "Use '--listusers' to verify the user name." >&2
    exit 1
  fi
  echo
}

do_list_users() {
  echo
  echo "Users:"
  echo
  hs_cmd users list 2>&1
  echo
}

do_list_nodes() {
  echo
  if [ -n "$target_user" ]; then
    echo "Nodes for user '$target_user':"
    echo
    hs_cmd nodes list --user "$target_user" 2>&1
  else
    echo "All registered nodes:"
    echo
    hs_cmd nodes list 2>&1
  fi
  echo
}

enter_node_id_interactive() {
  echo
  do_list_nodes
  read -rp "Enter the node ID to delete: " target_node_id
  [ -z "$target_node_id" ] && abort_and_exit
  until printf '%s' "$target_node_id" | grep -Eq '^[0-9]+$'; do
    echo "Invalid ID. Enter a numeric node ID."
    read -rp "Enter the node ID to delete: " target_node_id
    [ -z "$target_node_id" ] && abort_and_exit
  done
}

confirm_delete_node() {
  if [ "$assume_yes" != 1 ]; then
    echo
    read -rp "Delete node ID $target_node_id? This cannot be undone. [y/N]: " confirm
    case $confirm in
    [yY][eE][sS] | [yY]) ;;
    *)
      echo
      echo "Deletion aborted."
      echo
      exit 1
      ;;
    esac
  fi
}

do_delete_node() {
  echo
  echo "Deleting node ID $target_node_id..."
  if hs_cmd nodes delete --identifier "$target_node_id" --force 2>&1; then
    echo
    echo "Node $target_node_id deleted."
  else
    echo
    echo "Failed to delete node $target_node_id." >&2
    echo "Use '--listnodes' to verify the node ID." >&2
    exit 1
  fi
  echo
}

do_create_key() {
  echo
  local user_id
  user_id=$(get_user_id "$target_user")
  if [ -z "$user_id" ]; then
    exiterr "User '$target_user' not found. Use '--listusers' to see existing users."
  fi
  echo "Creating reusable pre-auth key for user '$target_user' (ID: $user_id)..."
  echo
  if hs_cmd preauthkeys create \
    --user "$user_id" \
    --reusable \
    --expiration 90d 2>&1; then
    echo
    echo "Pre-auth key created (reusable, expires in 90 days)."
    local srv_url
    srv_url=$(grep '^server_url:' "$HS_CONF" 2>/dev/null | awk '{print $2}')
    if [ -n "$srv_url" ]; then
      echo "Connect a Tailscale client:"
      echo "  tailscale up --login-server $srv_url --authkey <key-above>"
    fi
  else
    echo
    echo "Failed to create pre-auth key for user '$target_user'." >&2
    exit 1
  fi
  echo
}

do_list_keys() {
  echo
  if [ -n "$target_user" ]; then
    echo "Pre-auth keys for user '$target_user':"
    echo
    hs_cmd preauthkeys list --user "$target_user" 2>&1
  else
    echo "All pre-auth keys:"
    echo
    hs_cmd preauthkeys list 2>&1
  fi
  echo
}

confirm_remove_hs() {
  if [ "$assume_yes" != 1 ]; then
    echo
    read -rp "Confirm Headscale removal? Configuration will be deleted. [y/N]: " remove
    until [[ "$remove" =~ ^[yYnN]*$ ]]; do
      echo "$remove: invalid selection."
      read -rp "Confirm Headscale removal? [y/N]: " remove
    done
  else
    remove=y
  fi
}

print_remove_hs() {
  echo
  echo "Removing Headscale, please wait..."
}

disable_hs_service() {
  systemctl disable --now headscale.service 2>/dev/null
}

remove_hs_files() {
  rm -f "$HS_BIN"
  rm -f "$HS_SVC"
  systemctl daemon-reload 2>/dev/null
  rm -rf "$HS_CONF_DIR"
}

ask_remove_data() {
  if [ "$assume_yes" != 1 ]; then
    echo
    read -rp "Also delete Headscale data (database, keys) in $HS_DATA_DIR? [y/N]: " del_data
  else
    del_data=y
  fi
  if [[ "$del_data" =~ ^[yY]$ ]]; then
    rm -rf "$HS_DATA_DIR"
    rm -rf "$HS_RUN_DIR"
    echo "Data directory removed."
  fi
}

remove_headscale_user() {
  if id headscale >/dev/null 2>&1; then
    if [ "$assume_yes" != 1 ]; then
      echo
      read -rp "Remove the 'headscale' system user and group? [y/N]: " del_user
    else
      del_user=n
    fi
    if [[ "$del_user" =~ ^[yY]$ ]]; then
      userdel headscale 2>/dev/null
      groupdel headscale 2>/dev/null
      echo "Headscale system user removed."
    fi
  fi
}

print_hs_removed() {
  echo
  echo "Headscale removed!"
}

print_hs_removal_aborted() {
  echo
  echo "Headscale removal aborted!"
}

hssetup() {

  export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

  check_root
  check_shell
  check_os
  check_os_ver
  check_systemd

  auto=0
  assume_yes=0
  add_user=0
  delete_user=0
  list_users=0
  list_nodes=0
  delete_node=0
  create_key=0
  list_keys=0
  remove_hs=0
  server_url=""
  server_port=""
  first_username=""
  base_domain_arg=""
  target_user=""
  target_node_id=""
  unsanitized_username=""
  username=""
  computed_server_url=""
  public_ip=""
  ip=""
  port=8080
  base_domain=""

  parse_args "$@"
  check_args

  # -----------------------------------------------
  # Management actions (Headscale already installed)
  # -----------------------------------------------

  if [ "$add_user" = 1 ]; then
    show_header
    check_service_running
    do_add_user
    exit 0
  fi

  if [ "$delete_user" = 1 ]; then
    show_header
    check_service_running
    do_delete_user
    exit 0
  fi

  if [ "$list_users" = 1 ]; then
    show_header
    check_service_running
    do_list_users
    exit 0
  fi

  if [ "$list_nodes" = 1 ]; then
    show_header
    check_service_running
    do_list_nodes
    exit 0
  fi

  if [ "$delete_node" = 1 ]; then
    show_header
    check_service_running
    confirm_delete_node
    do_delete_node
    exit 0
  fi

  if [ "$create_key" = 1 ]; then
    show_header
    check_service_running
    do_create_key
    exit 0
  fi

  if [ "$list_keys" = 1 ]; then
    show_header
    check_service_running
    do_list_keys
    exit 0
  fi

  if [ "$remove_hs" = 1 ]; then
    show_header
    confirm_remove_hs
    if [[ "$remove" =~ ^[yY]$ ]]; then
      print_remove_hs
      remove_firewall_rules
      remove_rclocal_rules
      disable_hs_service
      remove_hs_files
      ask_remove_data
      remove_headscale_user
      print_hs_removed
      exit 0
    else
      print_hs_removal_aborted
      exit 1
    fi
  fi

  # -----------------------------------------------
  # Fresh install
  # -----------------------------------------------

  if [[ ! -e "$HS_CONF" ]]; then
    install_wget
    show_welcome
    if [ "$auto" = 0 ]; then
      enter_server_url
      select_port
      # Finalize server URL (after port is known if using IP)
      compute_server_url
      if [ -z "$server_url" ]; then
        echo
        echo "  *** NOTE: HTTPS is strongly recommended for production use. ***"
        echo "  *** Set up a TLS reverse proxy and re-run with:            ***"
        echo "  *** --serverurl https://your-domain.example.com            ***"
      fi
      enter_first_username
      enter_base_domain
    else
      # Auto mode
      [ -n "$server_port" ] && port="$server_port" || port=8080
      if [ -z "$server_url" ]; then
        detect_ip
        check_nat_ip
      fi
      if [ -n "$first_username" ]; then
        unsanitized_username="$first_username"
        set_username
      else
        username="admin"
      fi
      [ -n "$base_domain_arg" ] && base_domain="$base_domain_arg" || base_domain="headscale.internal"
      compute_server_url
    fi
    show_config
    show_setup_ready
    confirm_setup
    show_start_setup
    download_headscale
    create_headscale_user
    create_directories
    create_config
    install_service
    create_firewall_rules
    update_rclocal
    start_hs_service
    if ! wait_for_socket; then
      echo "Error: Headscale failed to start within 30 seconds." >&2
      echo "Check the service logs: journalctl -u headscale -n 50" >&2
      exit 1
    fi
    create_initial_user
    create_initial_key
    if [ "$auto" = 0 ] && [ -n "$server_url" ]; then
      local_domain="${server_url#https://}"
      local_domain="${local_domain%%/*}"
      check_dns_name "$local_domain" && show_dns_name_note "$local_domain"
    fi
    finish_setup

  # -----------------------------------------------
  # Already installed: interactive management menu
  # -----------------------------------------------

  else
    show_header
    select_menu_option
    case "$option" in
    1)
      check_service_running
      enter_username_interactive
      do_add_user
      exit 0
      ;;
    2)
      check_service_running
      enter_username_interactive
      do_delete_user
      exit 0
      ;;
    3)
      check_service_running
      do_list_users
      exit 0
      ;;
    4)
      check_service_running
      target_user=""
      do_list_nodes
      exit 0
      ;;
    5)
      check_service_running
      target_user=""
      target_node_id=""
      enter_node_id_interactive
      confirm_delete_node
      do_delete_node
      exit 0
      ;;
    6)
      check_service_running
      echo
      read -rp "Username for the pre-auth key: " target_user
      [ -z "$target_user" ] && abort_and_exit
      do_create_key
      exit 0
      ;;
    7)
      check_service_running
      target_user=""
      do_list_keys
      exit 0
      ;;
    8)
      confirm_remove_hs
      if [[ "$remove" =~ ^[yY]$ ]]; then
        print_remove_hs
        remove_firewall_rules
        remove_rclocal_rules
        disable_hs_service
        remove_hs_files
        ask_remove_data
        remove_headscale_user
        print_hs_removed
        exit 0
      else
        print_hs_removal_aborted
        exit 1
      fi
      ;;
    9)
      exit 0
      ;;
    esac
  fi
}

## Defer setup until we have the complete script
hssetup "$@"

exit 0
