# Ubuntu 24.04 + NGINX

A personal setup script that installs and configures a production-ready NGINX server on Ubuntu 24.04 with Cloudflare Tunnel support.

## What it installs

- **NGINX** — latest version from the official NGINX repository
- **MariaDB** — latest version, root password set during installation
- **PostgreSQL 17** — root password set during installation
- **PHP 8.3, 8.4 and 8.5** — each with a set of common extensions and PHP-FPM
- **Composer** — installed globally
- **.NET SDK 10** — for ASP.NET applications
- **Cloudflare Tunnel** — installed and configured during installation

## What it configures

- Downloads and installs custom site management scripts (`create-website`, `enable-website`, `disable-website`, `remove-website`)
- Downloads NGINX templates for PHP, ASP.NET and Vue projects
- Downloads shared NGINX configs (Cloudflare real IP passthrough, security headers)
- Adds custom aliases to `~/.bashrc`

## Installation

Run the following command on your server:

```bash
curl -fsSL https://raw.githubusercontent.com/Almighty-Shogun/nginx-ubuntu/main/nginx-install.sh -o setup.sh
sudo bash setup.sh
```

The script will ask you the following questions upfront before doing anything:

- MariaDB root password
- PostgreSQL root password
- Cloudflare tunnel name

After that it runs fully unattended until the Cloudflare authentication step, where it will print a URL for you to open in your browser to authorize the tunnel.

## After installation

Once the script finishes, make sure to do the following:

1. Configure the Cloudflare tunnel routing in your Cloudflare dashboard
2. Set Cloudflare SSL mode to **Full (strict)** in your Cloudflare dashboard
3. Run `source ~/.bashrc` to activate the aliases in your current session
4. Remove the `setup.sh` script using `rm setup.sh`

## Managing websites

```bash
sudo create-website domain.com    # create a new site
sudo enable-website domain.com    # enable a disabled site
sudo disable-website domain.com   # temporarily disable a site
sudo remove-website domain.com    # permanently remove a site
```