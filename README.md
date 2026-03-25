# Ubuntu 24.04 + NGINX
A personal setup script that installs and configures a production-ready NGINX server on Ubuntu 24.04 with Cloudflare Tunnel support.

---

## What it installs

| Component | Details |
|---|---|
| NGINX | Latest version from the official NGINX repository |
| MariaDB | Latest stable version, root password configured during installation |
| PostgreSQL 17 | Root password configured during installation |
| PHP 8.3, 8.4 and 8.5 | Each with a set of common extensions and PHP-FPM |
| Composer | Installed globally |
| .NET SDK 10 | For ASP.NET applications |
| Cloudflare Tunnel | Installed and configured during installation |

## What it configures

- Site management scripts — `create-website`, `enable-website`, `disable-website`, `remove-website` and `update-files`
- Database management scripts — `mariadb-add-user`, `mariadb-remove-user`, `mariadb-update-password`, `postgresql-add-user`, `postgresql-remove-user` and `postgresql-update-password`
- NGINX templates for PHP, ASP.NET, Vue and HTML projects
- Shared NGINX configs — Cloudflare real IP passthrough, security headers, FastCGI
- Cloudflare Tunnel with your chosen tunnel name
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

### Optional arguments

| Argument | Description |
|---|---|
| `--no-mariadb` | Skips MariaDB installation and configuration |
| `--no-postgresql` | Skips PostgreSQL installation and configuration |
| `--no-dotnet` | Skips .NET SDK installation |
| `--no-aliases` | Skips downloading and adding aliases to `~/.bashrc` |
| `--no-database-scripts` | Skips installing the MariaDB and PostgreSQL management scripts |
| `--skip-mariadb-password` | Skips MariaDB root password configuration |
| `--skip-postgresql-password` | Skips PostgreSQL root password configuration |
| `--php-versions=x.x,x.x` | Specify which PHP versions to install, e.g. `--php-versions=8.4,8.5` |

Example:

```bash
sudo bash setup.sh --no-mariadb --php-versions=8.4,8.5
```

---

## After installation
1. Set CloudFlare SSL mode to Full (strict) in your Cloudflare dashboard.
2. Make sure CloudFlare tunnel has been configured properly.
3. After CloudFlare tunnel configuration, run: `systemctl enable --now cloudflared`
4. Run `source ~/.bashrc` to activate the aliases in your current session (skip if `--no-aliases` was used)
5. Clean up the setup script: `rm setup.sh`

---

## Managing websites

### `create-website`
Creates a new website with the appropriate NGINX configuration and directory structure. Prints a reminder to add the Cloudflare tunnel record manually to the dashboard.

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
Permanently removes a website and its files. Requires typing the domain name to confirm unless `--force` is used. Prints a reminder to delete the Cloudflare tunnel record manually from the dashboard.

```bash
sudo remove-website <domain.com> [options]
```

| Argument | Description |
|---|---|
| `--force` | Skips the domain name confirmation prompt |

---

### `update-files`
Re-downloads and replaces all installed scripts, NGINX templates and NGINX snippets from GitHub. Only updates MariaDB and PostgreSQL scripts if they are already present in `/usr/local/bin`. Sections can be skipped with the optional flags below.

```bash
sudo update-files [options]
```

| Argument | Description |
|---|---|
| `--no-base` | Skips updating the website management scripts |
| `--no-mariadb` | Skips updating the MariaDB scripts |
| `--no-postgresql` | Skips updating the PostgreSQL scripts |
| `--no-templates` | Skips updating the NGINX templates |
| `--no-snippets` | Skips updating the NGINX snippets |

---

## Managing databases

### MariaDB
#### `mariadb-add-user`
Creates a new MariaDB user with no privileges. If `--database` is provided, the database is created if it does not already exist and the user is granted `ALL PRIVILEGES` on it. Use `--grant` to skip user creation and grant an existing user access to a database instead.

```bash
sudo mariadb-add-user [options]
```

| Argument | Description |
|---|---|
| `--user=<username>` | Username for the new user |
| `--database=<database>` | Database to grant access to — created automatically if it does not exist |
| `--grant` | Skip user creation and grant an existing user access to `--database` |

---

#### `mariadb-remove-user`
Permanently removes a MariaDB user and all their privileges. Requires typing the username to confirm unless `--force` is used.

```bash
sudo mariadb-remove-user [options]
```

| Argument | Description |
|---|---|
| `--user=<username>` | Username to remove |
| `--force` | Skips the username confirmation prompt |

---

#### `mariadb-update-password`
Updates the password for an existing MariaDB user.

```bash
sudo mariadb-update-password [options]
```

| Argument | Description |
|---|---|
| `--user=<username>` | Username whose password will be updated |

---

### PostgreSQL

#### `postgresql-add-user`
Creates a new PostgreSQL user (`NOSUPERUSER NOCREATEDB NOCREATEROLE`) with no privileges. If `--database` is provided, the database is created if it does not already exist and the user is granted `ALL PRIVILEGES` on it. Use `--grant` to skip user creation and grant an existing user access to a database instead.

```bash
sudo postgresql-add-user [options]
```

| Argument | Description |
|---|---|
| `--user=<username>` | Username for the new user |
| `--database=<database>` | Database to grant access to — created automatically if it does not exist |
| `--grant` | Skip user creation and grant an existing user access to `--database` |

---

#### `postgresql-remove-user`
Permanently removes a PostgreSQL user and all their privileges. Requires typing the username to confirm unless `--force` is used.

```bash
sudo postgresql-remove-user [options]
```

| Argument | Description |
|---|---|
| `--user=<username>` | Username to remove |
| `--force` | Skips the username confirmation prompt |

---

#### `postgresql-update-password`
Updates the password for an existing PostgreSQL user.

```bash
sudo postgresql-update-password [options]
```

| Argument | Description |
|---|---|
| `--user=<username>` | Username whose password will be updated |