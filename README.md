# Ubuntu 24.04 + NGINX
A personal setup script that installs and configures a production-ready NGINX server on Ubuntu 24.04 with CloudFlare Tunnel support.

---

## What it installs

| Component            | Details |
|----------------------|---|
| NGINX                | Latest version from the official NGINX repository |
| MariaDB              | Latest stable version, root password configured during installation |
| PostgreSQL 17        | Root password configured during installation |
| PHP 8.3, 8.4 and 8.5 | Each with a set of common extensions and PHP-FPM |
| Composer             | Installed globally |
| .NET SDK 10          | For ASP.NET applications |
| CloudFlare Tunnel    | Installed and configured during installation |

## What it configures

- Site management scripts — `create-website`, `enable-website`, `disable-website` and `remove-website`
- NGINX templates for PHP, ASP.NET, Vue and HTML projects.
- Shared NGINX configs — CloudFlare real IP passthrough, security headers, FastCGI.
- CloudFlare Tunnel with your chosen tunnel name.
- Custom command aliases added to `~/.bashrc`

---

## Installation
Download and run the setup script on your server:

```bash
curl -fsSL https://raw.githubusercontent.com/Almighty-Shogun/nginx-ubuntu/main/nginx-install.sh -o setup.sh
sudo bash setup.sh
```

The script asks the following questions upfront before doing anything:

- MariaDB root password
- PostgreSQL root password
- CloudFlare tunnel name

After that it runs fully unattended until the CloudFlare authentication step, where it prints a URL for you to open in your browser to authorize the tunnel.

### Optional arguments

| Argument | Description |
|---|---|
| `--no-mariadb` | Skips MariaDB installation and configuration |
| `--no-postgresql` | Skips PostgreSQL installation and configuration |
| `--no-dotnet` | Skips .NET SDK installation |
| `--no-aliases` | Skips downloading and adding aliases to `~/.bashrc` |
| `--skip-mariadb-password` | Skips MariaDB root password configuration |
| `--skip-postgresql-password` | Skips PostgreSQL root password configuration |
| `--php-versions=x.x,x.x` | Specify which PHP versions to install, e.g. `--php-versions=8.4,8.5` |

Example:

```bash
sudo bash setup.sh --no-mariadb --php-versions=8.4,8.5
```

---

## After installation
1. Set CloudFlare SSL mode to **Full (strict)** in your CloudFlare dashboard
2. Run `source ~/.bashrc` to activate the aliases in your current session (you can skip this if you used `--no-aliases`)
3. Clean up the setup script: `rm setup.sh`

---

## Managing websites

### `create-website`
Creates a new website with the appropriate NGINX configuration, directory structure and CloudFlare Tunnel DNS record.

```bash
sudo create-website <domain.com> [options]
```

| Argument | Values | Description |
|---|---|---|
| `--type` | `php`, `dotnet`, `vue`, `html` | The type of website |
| `--php-version` | e.g. `8.4` | PHP version to use — only valid when `--type=php` |
| `--port` | e.g. `5000` | Port the ASP.NET app runs on — only valid when `--type=dotnet` |
| `--assembly` | e.g. `MyProject` | Name of the `.dll` file — only valid when `--type=dotnet` |

Examples:

```bash
# Example for a PHP website.
sudo create-website domain.com --type=php --php-version=8.4

# Example for a ASP.NET website.
sudo create-website domain.com --type=dotnet --port=5000 --assembly=MyApi

# Example for a Vue/Vite website.
sudo create-website domain.com --type=vue

# Example for a HTML website.
sudo create-website domain.com --type=html
```

> [!NOTE]
> Root domains automatically get a `www` DNS record. Subdomains do not.

---

### `enable-website`
Re-enables a previously disabled website.

```bash
sudo enable-website <domain.com>
```

---

### `disable-website`
Temporarily disables a website without deleting any files.

```bash
sudo disable-website <domain.com>
```

---

### `remove-website`
Permanently removes a website, its files and its CloudFlare Tunnel DNS record. Requires typing the domain name to confirm unless `--force` is used.

```bash
sudo remove-website <domain.com> [--force]
```