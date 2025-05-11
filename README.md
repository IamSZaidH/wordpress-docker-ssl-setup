# WordPress Docker SSL Setup

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

> One-command WordPress installation with Docker, SSL, and cross-distribution compatibility

## Quick Start

```bash
sudo bash setup-wp-docker-ssl.sh
```

Follow the prompts to enter your domain, email, and database details.

## Requirements

- Linux server with root access
- Domain name pointing to your server
- Open ports: 80, 443, 8080

## Features

- ✅ Works on Ubuntu, Debian, CentOS, Fedora, Arch, etc.
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
