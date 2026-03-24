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

# --- Parse optional arguments. ---
INSTALL_MARIADB=true
INSTALL_POSTGRESQL=true
INSTALL_DOTNET=true
ADD_ALIASES=true
INSTALL_DATABASE_SCRIPTS=true
SKIP_MARIADB_PASSWORD=false
SKIP_POSTGRESQL_PASSWORD=false
PHP_VERSIONS="8.3 8.4 8.5"

for arg in "$@"; do
  case $arg in
    --no-mariadb) INSTALL_MARIADB=false ;;
    --no-postgresql) INSTALL_POSTGRESQL=false ;;
    --no-dotnet) INSTALL_DOTNET=false ;;
    --no-aliases) ADD_ALIASES=false ;;
    --no-database-scripts) INSTALL_DATABASE_SCRIPTS=false ;;
    --skip-mariadb-password) SKIP_MARIADB_PASSWORD=true ;;
    --skip-postgresql-password) SKIP_POSTGRESQL_PASSWORD=true ;;
    --php-versions=*) PHP_VERSIONS="${arg#*=}" PHP_VERSIONS="${PHP_VERSIONS//,/ }" ;;
    *) error "Unknown argument: $arg" ;;
  esac
done

# --- General questions. ---
echo ""
info "A few questions before we start the configuration..."
echo ""

if [[ "$INSTALL_MARIADB" == true ]] && [[ "$SKIP_MARIADB_PASSWORD" == false ]]; then
  while true; do
    read -rsp "What is the password for MariaDB?: " mariaDbPassword
    echo ""
    [[ -n "$mariaDbPassword" ]] && break
    echo "You did not provide a password. Please try again"
  done
fi

if [[ "$INSTALL_POSTGRESQL" == true ]] && [[ "$SKIP_POSTGRESQL_PASSWORD" == false ]]; then
  while true; do
    read -rsp "What is the password for PostgreSQL?: " postDbPassword
    echo ""
    [[ -n "$postDbPassword" ]] && break
    echo "You did not provide a password. Please try again"
  done
fi

while true; do
  read -rp "Enter a name for your CloudFlare tunnel (e.g. my-server): " tunnelName
  [[ -n "$tunnelName" ]] && break
  echo "You did not provide a tunnel name. Please try again."
done

# --- Updating system. ---
info "Updating system packages..."
apt update
apt upgrade -y
success "System packages have been updated."

# --- Installing cURL. ---
info "Installing cURL..."
apt install curl gnupg2 ca-certificates lsb-release software-properties-common -y
success "cURL has been installed."

# --- Installing NGINX. ---
info "Installing NGINX..."
curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/ubuntu noble nginx" | tee /etc/apt/sources.list.d/nginx.list > /dev/null
apt update
apt upgrade -y
apt install nginx -y
systemctl enable --now nginx
success "NGINX has been installed and is running."

# --- Installing MariaDB. ---
if [[ "$INSTALL_MARIADB" == true ]]; then
  info "Installing MariaDB..."
  apt install mariadb-server -y
  systemctl enable --now mariadb
  success "MariaDB has been installed and is running."
fi

# --- Installing PostgreSQL. ---
if [[ "$INSTALL_POSTGRESQL" == true ]]; then
  info "Installing PostgreSQL..."
  apt install -y postgresql-common
  /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y > /dev/null
  apt install postgresql-17 -y
  systemctl enable --now postgresql
  success "PostgreSQL has been installed and is running."
fi

# --- Installing PHP version(s). ---
info "Adding PHP repository..."
add-apt-repository ppa:ondrej/php -y
apt update
apt upgrade -y

for ver in $PHP_VERSIONS; do
  info "Installing PHP ${ver} and extensions..."

  BASE_EXTENSIONS="php${ver}-fpm php${ver}-cli php${ver}-mbstring php${ver}-xml php${ver}-curl php${ver}-zip php${ver}-bcmath php${ver}-intl php${ver}-gd php${ver}-mysql php${ver}-pgsql php${ver}-sqlite3 php${ver}-redis php${ver}-soap"

  if [[ "$ver" != "8.5" ]]; then
    BASE_EXTENSIONS="$BASE_EXTENSIONS php${ver}-opcache"
  fi

  apt install -y openssl $BASE_EXTENSIONS

  sed -i 's/listen.owner = www-data/listen.owner = nginx/' /etc/php/${ver}/fpm/pool.d/www.conf
  sed -i 's/listen.group = www-data/listen.group = nginx/' /etc/php/${ver}/fpm/pool.d/www.conf

  systemctl enable --now php${ver}-fpm

  success "PHP ${ver} has been installed and is running."
done

# --- Installing Composer. ---
info "Installing Composer..."
curl -fsSL https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
success "Composer has been installed."

# --- Installing .NET 10 SDK. ---
if [[ "$INSTALL_DOTNET" == true ]]; then
  info "Installing .NET SDK 10..."
  apt install dotnet-sdk-10.0 -y
  success ".NET SDK has been installed."
fi

# --- Installing CloudFlare tunnel. ---
info "Installing Cloudflared..."
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | tee /usr/share/keyrings/cloudflare-main.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared noble main" | tee /etc/apt/sources.list.d/cloudflared.list > /dev/null
apt update
apt upgrade -y
apt install cloudflared -y
success "Cloudflared has been installed."

# --- Installing custom scripts, templates, configs and aliases. ---
info "Downloading files from GitHub..."

GITHUB_RAW="https://raw.githubusercontent.com/Almighty-Shogun/nginx-ubuntu/main"

for script in create-website disable-website enable-website remove-website update-files; do
  curl -fsSL "$GITHUB_RAW/scripts/$script" -o /usr/local/bin/$script
  chmod +x /usr/local/bin/$script
  success "$script has been installed."
done

if [[ "$INSTALL_MARIADB" == true ]] && [[ "$INSTALL_DATABASE_SCRIPTS" == true ]]; then
  for script in mariadb-add-user mariadb-remove-user mariadb-update-password; do
      curl -fsSL "$GITHUB_RAW/scripts/$script" -o /usr/local/bin/$script
      chmod +x /usr/local/bin/$script
      success "$script has been installed."
  done
fi

if [[ "$INSTALL_POSTGRESQL" == true ]] && [[ "$INSTALL_DATABASE_SCRIPTS" == true ]]; then
  for script in postgresql-add-user postgresql-remove-user postgresql-update-password; do
      curl -fsSL "$GITHUB_RAW/scripts/$script" -o /usr/local/bin/$script
      chmod +x /usr/local/bin/$script
      success "$script has been installed."
  done
fi

mkdir -p /etc/nginx/templates
for template in nginx-php nginx-dotnet nginx-vue nginx-html dotnet-app.service asp_index php_index vue_index html_index; do
  curl -fsSL "$GITHUB_RAW/templates/$template.template" -o /etc/nginx/templates/$template.template
  success "$template.template has been installed."
done

mkdir -p /etc/nginx/snippets
for conf in cloudflare-real-ip security-headers fastcgi-php; do
  curl -fsSL "$GITHUB_RAW/snippets/$conf.conf" -o /etc/nginx/snippets/$conf.conf
  success "$conf.conf has been installed."
done

if [[ "$ADD_ALIASES" == true ]]; then
  curl -fsSL "$GITHUB_RAW/aliases" -o /tmp/aliases

  if ! grep -q "# Custom aliases" ~/.bashrc; then
    echo "" >> ~/.bashrc
    cat /tmp/aliases >> ~/.bashrc
    rm /tmp/aliases
    success "Aliases have been added to ~/.bashrc"
  else
    warning "Aliases already present in ~/.bashrc, skipping."
  fi
fi

curl -fsSL "$GITHUB_RAW/cloudflared/config.yml" -o /tmp/cloudflared-config.yml
success "CloudFlared configuration has been downloaded."

# --- CloudFlare tunnel setup. ---
echo ""
info "Open the URL in the browser to authenticate with CloudFlare."
echo ""

rm -f /root/.cloudflared/cert.pem
rm -f /root/.cloudflared/*.json

cloudflared tunnel login
cloudflared tunnel create "$tunnelName"

TUNNEL_ID=$(cloudflared tunnel list | grep "$tunnelName" | awk '{print $1}')
mkdir -p /etc/cloudflared
cp /tmp/cloudflared-config.yml /etc/cloudflared/config.yml
rm /tmp/cloudflared-config.yml
sed -i "s|{{TUNNEL_NAME}}|$tunnelName|g" /etc/cloudflared/config.yml
sed -i "s|{{TUNNEL_ID}}|$TUNNEL_ID|g" /etc/cloudflared/config.yml

cloudflared service install
systemctl enable --now cloudflared
success "Cloudflare Tunnel '$tunnelName' has been created and is running."

# --- MariaDB configuration. ---
if [[ "$INSTALL_MARIADB" == true ]] && [[ "$SKIP_MARIADB_PASSWORD" == false ]]; then
  info "Configuring MariaDB..."
  sql_mariadb_password="${mariaDbPassword//\\/\\\\}"
  sql_mariadb_password="${sql_mariadb_password//\'/\'\'}"
  mariadb <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '$sql_mariadb_password';
FLUSH PRIVILEGES;
EOF
  systemctl restart mariadb
  success "MariaDB has been configured."
fi

# --- PostgreSQL configuration. ---
if [[ "$INSTALL_POSTGRESQL" == true ]] && [[ "$SKIP_POSTGRESQL_PASSWORD" == false ]]; then
  info "Configuring PostgreSQL..."
  sql_pg_password="${postDbPassword//\'/\'\'}"
  sudo -u postgres psql -q <<EOF
ALTER USER postgres WITH PASSWORD '$sql_pg_password';
EOF

  systemctl restart postgresql
  success "PostgreSQL has been configured."
fi

# --- Script execution summary. ---
echo ""
echo -e "${GREEN}Setup complete. Summary:${NC}"
echo "  NGINX       → $(systemctl is-active nginx)"
[[ "$INSTALL_MARIADB" == true ]]    && echo "  MariaDB     → $(systemctl is-active mariadb)"
[[ "$INSTALL_POSTGRESQL" == true ]] && echo "  PostgreSQL  → $(systemctl is-active postgresql)"
echo "  CloudFlared → $(systemctl is-active cloudflared)"

for ver in $PHP_VERSIONS; do
    echo "  PHP ${ver}-FPM → $(systemctl is-active php${ver}-fpm)"
done

echo ""

warning "DO NOT FORGET TO DO THIS AFTERWARDS:"
warning "1. Make sure CloudFlare tunnel has been configured properly."
warning "2. Set CloudFlare SSL mode to Full (strict) in your Cloudflare dashboard"

if [[ "$ADD_ALIASES" == true ]]; then
    warning "3. Run: source ~/.bashrc"
fi