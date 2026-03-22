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

# --- Configure Firewall ---
info "Configuring firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw --force enable
success "Firewall has been configured configured."

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
sudo systemctl enable --now nginx
success "NGINX has been installed and is running."

# --- Installing MariaDB ---
info "Installing MariaDB..."
curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash
apt install mariadb-server -y
sudo systemctl enable --now mariadb
success "MariaDB has been installed and is running."

# --- Installing PostgreSQL ---
info "Installing PostgreSQL..."
apt install -y postgresql-common
/usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y
apt install postgresql-17 -y
sudo systemctl enable --now postgresql
success "PostgreSQL has been installed and is running."

# --- Installing PHP version(s) ---
info "Adding PHP repository..."
add-apt-repository ppa:ondrej/php
apt update
apt upgrade -y

for ver in 8.3 8.4 8.5; do
  info "Installing PHP ${ver} and extensions..."

  apt install -y openssl \
    php${ver}-fpm php${ver}-bcmath php${ver}-enchant php${ver}-imap \
    php${ver}-mysqli php${ver}-pdo_sqlite php${ver}-pspell \
    php${ver}-sodium php${ver}-sysvshm php${ver}-curl \
    php${ver}-intl php${ver}-pdo_mysql \
    php${ver}-pgsql php${ver}-redis php${ver}-sqlite3 php${ver}-tidy php${ver}-xsl \
    php${ver}-dba php${ver}-gd php${ver}-ldap php${ver}-odbc php${ver}-pdo_odbc \
    php${ver}-snmp php${ver}-sysvmsg php${ver}-xdebug php${ver}-zip \
    php${ver}-imagick php${ver}-mbstring php${ver}-opcache \
    php${ver}-pdo_pgsql php${ver}-soap php${ver}-sysvsem

    systemctl enable php${ver}-fpm
    systemctl start php${ver}-fpm

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

# --- Installing Fail2ban ---
info "Installing Fail2ban..."
apt install fail2ban -y
sudo systemctl enable --now fail2ban
success "Fail2ban has been installed and is running."

# --- Installing CloudFlare tunnel ---
info "Installing Cloudflared..."
curl -L https://pkg.cloudflare.com/cloudflare-main.gpg | tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared noble main" | tee /etc/apt/sources.list.d/cloudflared.list
apt update
apt upgrade -y
apt install cloudflared -y
success "Cloudflared has been installed."

# --- CloudFlare tunnel setup ---
echo ""
info "Open the URL in the browser to authenticate with CloudFlare."
echo ""
cloudflared tunnel login

while true; do
  read -rp "Enter a name for your tunnel (e.g. my-server): " tunnelName
  [[ -n "$tunnelName" ]] && break
  echo "You did not provide a tunnel name. Please try again."
done

cloudflared tunnel create "$tunnelName"
cloudflared service install
sudo systemctl enable --now cloudflared
success "Cloudflare Tunnel '$tunnelName' has been created and is running."

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
for conf in cloudflare-realip security-headers; do
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

# --- General questions ---
echo ""
info "A few questions before configuring databases..."
echo ""

while true; do
  read -rp "What is your server IP?: " serverIp
  [[ -n "$serverIp" ]] && break
  echo "You did not provide a server IP. Please try again"
done

while true; do
  read -rp "What is your public (device) IP?: " deviceIp
  [[ -n "$deviceIp" ]] && break
  echo "You did not provide a public (device) IP. Please try again"
done

while true; do
  read -rp "What is the database username for MariaDB?: " mariaDbUser
  [[ -n "$databaseUser" ]] && break;
  echo "You did not provide a username. Please try again"
done

while true; do
  read -rsp "What is the password for MariaDB?: " mariaDbPassword
  echo ""
  [[ -n "$databasePassword" ]] && break
  echo "You did not provide a password. Please try again"
done

while true; do
  read -rp "What is the database username for PostgreSQL?: " postDbUser
  [[ -n "$databaseUser" ]] && break;
  echo "You did not provide a username. Please try again"
done

while true; do
  read -rsp "What is the password for PostgreSQL?: " postDbPassword
  echo ""
  [[ -n "$databasePassword" ]] && break
  echo "You did not provide a password. Please try again"
done

# --- MariaDB remote access ---
info "Configuring MariaDB remote access..."
sed -i "s/bind-address\s*=\s*127.0.0.1/bind-address = 127.0.0.1,$serverIp/" /etc/mysql/mariadb.conf.d/50-server.cnf

mariadb <<EOF
CREATE USER '$mariaDbUser'@'$deviceIp' IDENTIFIED BY '$mariaDbPassword';
GRANT ALL PRIVILEGES ON *.* TO '$mariaDbUser'@'$deviceIp';
FLUSH PRIVILEGES;
EOF

systemctl restart mariadb
ufw allow from "$deviceIp" to any port 3306 proto tcp
success "MariaDB has been configured. Listening on:"
ss -tlnp | grep 3306

# --- PostgreSQL remote access ---
info "Configuring PostgreSQL remote access..."
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = 'localhost,$serverIp'/" /etc/postgresql/17/main/postgresql.conf

echo "host    all    $postDbUser    $deviceIp/32    scram-sha-256" | tee -a /etc/postgresql/17/main/pg_hba.conf

sudo -u postgres psql <<EOF
CREATE USER $postDbUser WITH PASSWORD '$postDbPassword' SUPERUSER;
\q
EOF

systemctl restart postgresql
ufw allow from "$deviceIp" to any port 5432 proto tcp
success "PostgreSQL has been configured. Listening on:"
ss -tlnp | grep 5432

# --- Reloading Firewall ---
ufw reload

# --- Finished ---
echo ""
echo -e "${GREEN}Setup complete. Summary:${NC}"
echo "  NGINX       → $(systemctl is-active nginx)"
echo "  MariaDB     → $(systemctl is-active mariadb)"
echo "  PostgreSQL  → $(systemctl is-active postgresql)"
echo "  Fail2ban    → $(systemctl is-active fail2ban)"
echo "  cloudflared → $(systemctl is-active cloudflared)"

for ver in 8.3 8.4 8.5; do
    echo "  PHP ${ver}-FPM → $(systemctl is-active php${ver}-fpm)"
done

echo ""

warning "DO NOT FORGET TO DO THIS AFTERWARDS:"
warning "1. Configure Fail2ban jails"
warning "2. Set CloudFlare SSL mode to Full (strict) in your Cloudflare dashboard"
warning "3. Run: source ~/.bashrc"