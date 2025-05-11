# WordPress Docker SSL Setup

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

> One-command WordPress installation with Docker, SSL, and cross-distribution compatibility

## Quick Start

```bash
# Clone the repository
git clone https://github.com/username/wordpress-docker-ssl-setup.git

# Navigate to the directory
cd wordpress-docker-ssl-setup

# Run the setup script
sudo bash setup-wp-docker-ssl.sh
```

Follow the prompts to enter your domain, email, and database details.

## Requirements

- Linux server with root access
- Domain name pointing to your server
- Open ports: 80, 443, 8080

## Supported Operating Systems

- ✅ **Fully tested on:** Ubuntu, Debian
- ⚠️ **Should work on:** CentOS, Fedora, RHEL, Rocky Linux, AlmaLinux
- ⚠️ **Limited support:** Arch Linux, Manjaro, openSUSE
- ❌ **Not supported:** Windows, macOS

## Features

- ✅ Auto-installs Docker and all dependencies
- ✅ Configures Let's Encrypt SSL with auto-renewal
- ✅ Includes phpMyAdmin for database management
- ✅ Helper scripts for maintenance (start/stop/backup)

## Post-Installation

Access your new WordPress site at: `https://yourdomain.com`  
Access phpMyAdmin at: `http://yourdomain.com:8080`

## Helper Commands

```bash
# Start WordPress
./start.sh

# Stop WordPress
./stop.sh

# Backup WordPress
./backup.sh
```

## License

MIT
