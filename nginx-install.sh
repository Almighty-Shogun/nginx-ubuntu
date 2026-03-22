#!/bin/bash

set -euo pipefail

# --- Creating color variables and logger methods. ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}    $*"; }
success() { echo -e "${GREEN}[OK]${NC}      $*"; }
warning() { echo -e "${YELLOW}[WARN]${NC}   $*"; }
error()   { echo -e "${RED}[ERROR]${NC}  $*" >&2; exit 1; }

# --- Checking if script was called from sudo. ---
[[ $EUID -ne 0 ]] && error "Run this script with sudo."

# --- General questions ---
echo ""
info "A few questions before we start the configuration..."
echo ""

while true; do
  read -rsp "What is the password for MariaDB?: " mariaDbPassword
  echo ""
  [[ -n "$mariaDbPassword" ]] && break
  echo "You did not provide a password. Please try again"
done

while true; do
  read -rsp "What is the password for PostgreSQL?: " postDbPassword
  echo ""
  [[ -n "$postDbPassword" ]] && break
  echo "You did not provide a password. Please try again"
done

while true; do
  read -rp "Enter a name for your CloudFlare tunnel (e.g. my-server): " tunnelName
  [[ -n "$tunnelName" ]] && break
  echo "You did not provide a tunnel name. Please try again."
done

# --- Updating system ---
info "Updating system packages..."

apt update
apt upgrade -y

success "System packages have been updated."

# --- Installing cURL ---
info "Installing cURL..."

apt install curl gnupg2 ca-certificates lsb-release -y

success "cURL has been installed."

# --- Installing NGINX ---
info "Installing NGINX..."

curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/ubuntu noble nginx" | tee /etc/apt/sources.list.d/nginx.list
apt update
apt upgrade -y
apt install nginx -y
systemctl enable --now nginx

success "NGINX has been installed and is running."

# --- Installing MariaDB ---
info "Installing MariaDB..."

curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash
apt install mariadb-server -y
systemctl enable --now mariadb

success "MariaDB has been installed and is running."

# --- Installing PostgreSQL ---
info "Installing PostgreSQL..."

apt install -y postgresql-common
/usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y
apt install postgresql-17 -y
systemctl enable --now postgresql

success "PostgreSQL has been installed and is running."

# --- Installing PHP version(s) ---
info "Adding PHP repository..."

add-apt-repository ppa:ondrej/php -y
apt update
apt upgrade -y

for ver in 8.3 8.4 8.5; do
    info "Installing PHP ${ver} and extensions..."

    BASE_EXTENSIONS="php${ver}-fpm php${ver}-cli php${ver}-mbstring php${ver}-xml php${ver}-curl php${ver}-zip php${ver}-bcmath php${ver}-intl php${ver}-gd php${ver}-mysql php${ver}-pgsql php${ver}-sqlite3 php${ver}-redis php${ver}-soap"

    if [[ "$ver" != "8.5" ]]; then
        BASE_EXTENSIONS="$BASE_EXTENSIONS php${ver}-opcache"
    fi

    apt install -y openssl $BASE_EXTENSIONS

    systemctl enable --now php${ver}-fpm

    success "PHP ${ver} has been installed and is running."
done

# --- Installing composer. ---
info "Installing Composer..."

curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

success "Composer has been installed."

# --- Installing .NET 10 SDK ---
info "Installing .NET SDK 10..."

apt install dotnet-sdk-10.0 -y

success ".NET SDK has been installed."

# --- Installing CloudFlare tunnel ---
info "Installing Cloudflared..."

curl -L https://pkg.cloudflare.com/cloudflare-main.gpg | tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared noble main" | tee /etc/apt/sources.list.d/cloudflared.list
apt update
apt upgrade -y
apt install cloudflared -y

success "Cloudflared has been installed."

# --- Installing custom scripts, templates, configs and aliases ---
info "Downloading files from GitHub..."

GITHUB_RAW="https://raw.githubusercontent.com/Almighty-Shogun/nginx-ubuntu/main"

for script in create-website disable-website enable-website remove-website; do
    curl -fsSL "$GITHUB_RAW/scripts/$script" -o /usr/local/bin/$script
    chmod +x /usr/local/bin/$script

    success "$script has been installed."
done

mkdir -p /etc/nginx/templates
for template in nginx-php nginx-dotnet nginx-vue; do
    curl -fsSL "$GITHUB_RAW/templates/$template.template" -o /etc/nginx/templates/$template.template

    success "$template.template has been installed."
done

mkdir -p /etc/nginx/conf.d
for conf in cloudflare-real-ip security-headers; do
    curl -fsSL "$GITHUB_RAW/conf.d/$conf.conf" -o /etc/nginx/conf.d/$conf.conf

    success "$conf.conf has been installed."
done

curl -fsSL "$GITHUB_RAW/aliases" -o /tmp/aliases

if ! grep -q "# Custom aliases" ~/.bashrc; then
  echo "" >> ~/.bashrc
  cat /tmp/aliases >> ~/.bashrc
  rm /tmp/aliases

  success "Aliases have been added to ~/.bashrc"
else
  warning "Aliases already present in ~/.bashrc, skipping."
fi

mkdir -p /etc/cloudflared
curl -fsSL "$GITHUB_RAW/cloudflared/config.yml" -o /etc/cloudflared/config.yml

success "CloudFlared configuration has been installed."

# --- CloudFlare tunnel setup ---
echo ""
info "Open the URL in the browser to authenticate with CloudFlare."
echo ""

cloudflared tunnel login
cloudflared tunnel create "$tunnelName"

TUNNEL_ID=$(cloudflared tunnel list | grep "$tunnelName" | awk '{print $1}')
sed -i "s|{{TUNNEL_NAME}}|$tunnelName|g" /etc/cloudflared/config.yml
sed -i "s|{{TUNNEL_ID}}|$TUNNEL_ID|g" /etc/cloudflared/config.yml

cloudflared service install
systemctl enable --now cloudflared

success "Cloudflare Tunnel '$tunnelName' has been created and is running."

# --- MariaDB configuration. ---
info "Configuring MariaDB..."

mariadb <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '$mariaDbPassword';
FLUSH PRIVILEGES;
EOF

systemctl restart mariadb
success "MariaDB has been configured."

# --- PostgreSQL configuration. ---
info "Configuring PostgreSQL..."

sudo -u postgres psql <<EOF
ALTER USER postgres WITH PASSWORD '$postDbPassword';
\q
EOF

systemctl restart postgresql
success "PostgreSQL has been configured."

# --- Script execution summary. ---
echo ""
echo -e "${GREEN}Setup complete. Summary:${NC}"
echo "  NGINX       → $(systemctl is-active nginx)"
echo "  MariaDB     → $(systemctl is-active mariadb)"
echo "  PostgreSQL  → $(systemctl is-active postgresql)"
echo "  cloudflared → $(systemctl is-active cloudflared)"

for ver in 8.3 8.4 8.5; do
    echo "  PHP ${ver}-FPM → $(systemctl is-active php${ver}-fpm)"
done

echo ""

warning "DO NOT FORGET TO DO THIS AFTERWARDS:"
warning "1. Make sure CloudFlare tunnel has been configured properly."
warning "2. Set CloudFlare SSL mode to Full (strict) in your Cloudflare dashboard"
warning "3. Run: source ~/.bashrc"