# Ubuntu 24.04 + NGINX
This is a personally written script that will install and configure my NGINX server on Ubuntu 24.04.

# Features
- Blocks all connections and only allow SSH access.
- Installs and configures MariaDB.
  - Will prompt you for a username and password.
- Installs and configures PostgreSQL.
  - Will prompt you for a username and password.
- Installs PHP 8.3, 8.4 and 8.5 with (all) extensions.
  - Also installs composer.
- Installs .NET SDK 10.0.
- Installs Fail2ban.
- Installs CloudFlared (CloudFlare tunnel)
  - Also prompts you for the configuration.
- Downloads my scripts, templates and config files (the ones in the repository).
- Configures remote access from your local IP (for both MariaDB and PostgreSQL).