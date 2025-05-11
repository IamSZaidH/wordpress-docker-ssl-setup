#!/bin/bash

# Cross-Distribution WordPress Docker SSL Setup Script
# Purpose: Set up WordPress with SSL in Docker on various Linux distributions

# Exit on any error
set -e

# Color definitions for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    echo -e "${2}${1}${NC}"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        DISTRO=$DISTRIB_ID
        VERSION=$DISTRIB_RELEASE
    elif [ -f /etc/debian_version ]; then
        DISTRO="debian"
    elif [ -f /etc/redhat-release ]; then
        DISTRO="rhel"
    elif [ -f /etc/fedora-release ]; then
        DISTRO="fedora"
    else
        DISTRO="unknown"
    fi
    
    # Convert to lowercase
    DISTRO=$(echo "$DISTRO" | tr '[:upper:]' '[:lower:]')
    
    print_message "Detected Linux distribution: $DISTRO $VERSION" "$BLUE"
}

# Function to install Docker and Docker Compose
install_docker() {
    if command_exists docker && command_exists docker-compose; then
        print_message "Docker and Docker Compose are already installed." "$GREEN"
        return
    fi
    
    print_message "Installing Docker and Docker Compose..." "$YELLOW"
    
    case $DISTRO in
        ubuntu|debian|linuxmint|pop)
            sudo apt-get update
            sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
            
            # Add Docker's official GPG key
            curl -fsSL https://download.docker.com/linux/$DISTRO/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            
            # Set up the stable repository
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$DISTRO $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # Install Docker Engine
            sudo apt-get update
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
            
        centos|rhel|fedora|rocky|almalinux)
            sudo yum install -y yum-utils
            
            # Add Docker repository
            if [ "$DISTRO" = "fedora" ]; then
                sudo dnf -y install dnf-plugins-core
                sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
                sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin
            else
                sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
                sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            fi
            ;;
            
        opensuse*|suse|sles)
            # OpenSUSE and SUSE Linux
            sudo zypper refresh
            sudo zypper install -y docker docker-compose
            ;;
            
        arch|manjaro)
            # Arch-based distributions
            sudo pacman -Sy docker docker-compose --noconfirm
            ;;
            
        *)
            print_message "Unsupported distribution for automatic Docker installation." "$RED"
            print_message "Please install Docker and Docker Compose manually according to the official documentation:" "$YELLOW"
            print_message "https://docs.docker.com/engine/install/" "$BLUE"
            print_message "Continuing with the script assuming Docker is installed..." "$YELLOW"
            ;;
    esac
    
    # Start and enable Docker service
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Add current user to docker group to avoid using sudo with docker commands
    if ! groups $USER | grep -q "docker"; then
        sudo usermod -aG docker $USER
        print_message "Added user $USER to the docker group. You may need to log out and log back in for this change to take effect." "$YELLOW"
    fi
    
    # Install Docker Compose if it's not installed automatically
    if ! command_exists docker-compose; then
        if command_exists docker compose; then
            print_message "Docker Compose plugin is installed." "$GREEN"
        else
            print_message "Installing Docker Compose..." "$YELLOW"
            # Install Docker Compose
            DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
            sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            sudo chmod +x /usr/local/bin/docker-compose
            sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
        fi
    fi
    
    print_message "Docker and Docker Compose installation completed." "$GREEN"
}

# Function to install Certbot
install_certbot() {
    print_message "Installing Certbot..." "$YELLOW"
    
    case $DISTRO in
        ubuntu|debian|linuxmint|pop)
            sudo apt-get update
            sudo apt-get install -y certbot
            ;;
            
        centos|rhel|rocky|almalinux)
            sudo yum install -y epel-release
            sudo yum install -y certbot
            ;;
            
        fedora)
            sudo dnf install -y certbot
            ;;
            
        opensuse*|suse|sles)
            sudo zypper install -y certbot
            ;;
            
        arch|manjaro)
            sudo pacman -Sy certbot --noconfirm
            ;;
            
        *)
            print_message "Unsupported distribution for automatic Certbot installation." "$RED"
            print_message "Please install Certbot manually according to the official documentation:" "$YELLOW"
            print_message "https://certbot.eff.org/instructions" "$BLUE"
            exit 1
            ;;
    esac
    
    print_message "Certbot installation completed." "$GREEN"
}

# Function to create required directories and configuration files
setup_wordpress_docker() {
    print_message "Setting up WordPress Docker environment..." "$YELLOW"
    
    # Create necessary directories
    mkdir -p "$base_dir/ssl"
    mkdir -p "$base_dir/apache-conf"
    
    # Create Apache configuration files with dynamic domain name
    cat > "$base_dir/apache-conf/default-ssl.conf" << EOF
<IfModule mod_ssl.c>
    <VirtualHost *:443>
        ServerAdmin webmaster@$domain
        ServerName $domain
        ServerAlias www.$domain
        DocumentRoot /var/www/html
        
        ErrorLog \${APACHE_LOG_DIR}/error.log
        CustomLog \${APACHE_LOG_DIR}/access.log combined
        
        SSLEngine on
        SSLCertificateFile /etc/apache2/ssl/certificate.crt
        SSLCertificateKeyFile /etc/apache2/ssl/private.key
        SSLCertificateChainFile /etc/apache2/ssl/ca_bundle.crt
        
        <FilesMatch "\.(cgi|shtml|phtml|php)$">
            SSLOptions +StdEnvVars
        </FilesMatch>
        <Directory /usr/lib/cgi-bin>
            SSLOptions +StdEnvVars
        </Directory>
        
        # WordPress .htaccess settings
        <Directory /var/www/html>
            AllowOverride All
            Options -Indexes +FollowSymLinks
            Require all granted
        </Directory>
    </VirtualHost>
</IfModule>
EOF

    cat > "$base_dir/apache-conf/000-default.conf" << EOF
<VirtualHost *:80>
    ServerAdmin webmaster@$domain
    ServerName $domain
    ServerAlias www.$domain
    DocumentRoot /var/www/html
    
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
    
    RewriteEngine On
    RewriteCond %{HTTPS} off
    RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
    
    # WordPress .htaccess settings
    <Directory /var/www/html>
        AllowOverride All
        Options -Indexes +FollowSymLinks
        Require all granted
    </Directory>
</VirtualHost>
EOF

    # Create custom Dockerfile
    cat > "$base_dir/Dockerfile" << EOF
FROM wordpress:latest

# Install SSL module and enable required Apache modules
RUN apt-get update && apt-get install -y ssl-cert && \\
    a2enmod ssl && a2enmod rewrite && \\
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Enable SSL site configuration
COPY apache-conf/default-ssl.conf /etc/apache2/sites-available/
COPY apache-conf/000-default.conf /etc/apache2/sites-available/
RUN a2ensite default-ssl

# Set recommended PHP settings for WordPress
RUN { \\
    echo 'upload_max_filesize = 64M'; \\
    echo 'post_max_size = 64M'; \\
    echo 'memory_limit = 256M'; \\
    echo 'max_execution_time = 300'; \\
    echo 'max_input_time = 300'; \\
} > /usr/local/etc/php/conf.d/wordpress-recommended.ini

# Expose HTTPS port
EXPOSE 443
EOF

    # Create Docker Compose file with dynamic database credentials
    cat > "$base_dir/docker-compose.yml" << EOF
version: '3.8'

services:
  wordpress:
    build:
      context: .
      dockerfile: Dockerfile
    restart: always
    ports:
      - 80:80
      - 443:443
    environment:
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_USER: $wp_db_user
      WORDPRESS_DB_PASSWORD: $wp_db_password
      WORDPRESS_DB_NAME: $wp_db_name
      WORDPRESS_CONFIG_EXTRA: |
        define('WP_MEMORY_LIMIT', '256M');
        define('WP_MAX_MEMORY_LIMIT', '512M');
        define('FS_METHOD', 'direct');
    volumes:
      - wordpress_data:/var/www/html
      - ./ssl:/etc/apache2/ssl
    depends_on:
      - db
    networks:
      - wordpress_network
      
  db:
    image: mysql:8.0
    restart: always
    environment:
      MYSQL_DATABASE: $wp_db_name
      MYSQL_USER: $wp_db_user
      MYSQL_PASSWORD: $wp_db_password
      MYSQL_RANDOM_ROOT_PASSWORD: '1'
    volumes:
      - db_data:/var/lib/mysql
    networks:
      - wordpress_network
    command: --default-authentication-plugin=mysql_native_password --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci

  # Optional phpMyAdmin container
  phpmyadmin:
    image: phpmyadmin/phpmyadmin
    restart: always
    depends_on:
      - db
    ports:
      - "8080:80"
    environment:
      PMA_HOST: db
      MYSQL_ROOT_PASSWORD: $wp_db_password
      UPLOAD_LIMIT: 50M
    networks:
      - wordpress_network

volumes:
  wordpress_data:
  db_data:

networks:
  wordpress_network:
    driver: bridge
EOF

    # Create helper scripts for easier management
    cat > "$base_dir/start.sh" << EOF
#!/bin/bash
# Start the Docker containers
docker-compose -f "$base_dir/docker-compose.yml" up -d
echo "WordPress containers started!"
EOF

    cat > "$base_dir/stop.sh" << EOF
#!/bin/bash
# Stop the Docker containers
docker-compose -f "$base_dir/docker-compose.yml" down
echo "WordPress containers stopped!"
EOF

    cat > "$base_dir/restart.sh" << EOF
#!/bin/bash
# Restart the Docker containers
docker-compose -f "$base_dir/docker-compose.yml" restart
echo "WordPress containers restarted!"
EOF

    cat > "$base_dir/backup.sh" << EOF
#!/bin/bash
# Create a backup of the WordPress files and database
TIMESTAMP=\$(date +"%Y%m%d-%H%M%S")
BACKUP_DIR="$base_dir/backups"

# Ensure backup directory exists
mkdir -p \$BACKUP_DIR

# Backup WordPress files
echo "Backing up WordPress files..."
docker run --rm --volumes-from \$(docker-compose -f "$base_dir/docker-compose.yml" ps -q wordpress) -v \$BACKUP_DIR:/backup ubuntu tar czf /backup/wordpress-files-\$TIMESTAMP.tar.gz /var/www/html

# Backup database
echo "Backing up database..."
docker-compose -f "$base_dir/docker-compose.yml" exec db mysqldump -u$wp_db_user -p$wp_db_password $wp_db_name > \$BACKUP_DIR/wordpress-db-\$TIMESTAMP.sql

echo "Backup completed! Files stored in \$BACKUP_DIR"
EOF

    # Make helper scripts executable
    chmod +x "$base_dir/start.sh" "$base_dir/stop.sh" "$base_dir/restart.sh" "$base_dir/backup.sh"
    
    print_message "WordPress Docker environment setup completed." "$GREEN"
}

# Function to obtain SSL certificates
obtain_ssl_certificates() {
    print_message "Obtaining SSL certificates..." "$YELLOW"
    
    # Stop any services that might be using port 80
    if [ -f "$base_dir/docker-compose.yml" ] && command_exists docker-compose; then
        docker-compose -f "$base_dir/docker-compose.yml" down
    fi
    
    # Check for port 80 usage
    if netstat -tuln | grep -q ":80 "; then
        print_message "Warning: Port 80 is already in use. Certbot needs port 80 to be free." "$RED"
        read -p "Would you like to stop services using port 80 and continue? (y/n): " stop_services
        if [ "$stop_services" = "y" ] || [ "$stop_services" = "Y" ]; then
            case $DISTRO in
                ubuntu|debian|linuxmint|pop)
                    sudo systemctl stop apache2 nginx 2>/dev/null || true
                    ;;
                centos|rhel|fedora|rocky|almalinux)
                    sudo systemctl stop httpd nginx 2>/dev/null || true
                    ;;
                *)
                    print_message "Please stop the services using port 80 manually." "$YELLOW"
                    read -p "Press Enter to continue when port 80 is free..."
                    ;;
            esac
        else
            print_message "SSL certificate acquisition aborted. Please free port 80 before running this script." "$RED"
            exit 1
        fi
    fi
    
    # Obtain SSL certificates
    sudo certbot certonly --standalone \
      --preferred-challenges http \
      --email "$email" \
      --agree-tos \
      --no-eff-email \
      -d "$domain" -d "www.$domain"
    
    # Check if certificates were obtained successfully
    if [ ! -d "/etc/letsencrypt/live/$domain" ]; then
        print_message "Failed to obtain SSL certificates. Please check the error messages above." "$RED"
        exit 1
    fi
    
    # Copy SSL certificates to directory
    sudo cp "/etc/letsencrypt/live/$domain/fullchain.pem" "$base_dir/ssl/certificate.crt"
    sudo cp "/etc/letsencrypt/live/$domain/privkey.pem" "$base_dir/ssl/private.key"
    sudo cp "/etc/letsencrypt/live/$domain/chain.pem" "$base_dir/ssl/ca_bundle.crt"
    
    # Set permissions for SSL certificates
    sudo chmod 644 "$base_dir/ssl/certificate.crt"
    sudo chmod 644 "$base_dir/ssl/ca_bundle.crt"
    sudo chmod 600 "$base_dir/ssl/private.key"
    
    print_message "SSL certificates obtained successfully." "$GREEN"
}

# Function to set up automatic SSL renewal
setup_ssl_renewal() {
    print_message "Setting up automatic SSL renewal..." "$YELLOW"
    
    # Create renewal script
    cat > "$base_dir/renew-ssl.sh" << EOF
#!/bin/bash
# Script to renew SSL certificates and restart containers

# Renew certificates
certbot renew --quiet

# Copy new certificates
cp /etc/letsencrypt/live/$domain/fullchain.pem $base_dir/ssl/certificate.crt
cp /etc/letsencrypt/live/$domain/privkey.pem $base_dir/ssl/private.key
cp /etc/letsencrypt/live/$domain/chain.pem $base_dir/ssl/ca_bundle.crt

# Update permissions
chmod 644 $base_dir/ssl/certificate.crt
chmod 644 $base_dir/ssl/ca_bundle.crt
chmod 600 $base_dir/ssl/private.key

# Restart WordPress container
cd $base_dir && docker-compose restart wordpress
EOF
    
    # Make renewal script executable
    chmod +x "$base_dir/renew-ssl.sh"
    
    # Set up cron job for automatic renewal
    (crontab -l 2>/dev/null; echo "0 3 * * 1 $base_dir/renew-ssl.sh") | crontab -
    
    print_message "Automatic SSL renewal has been set up to run weekly." "$GREEN"
}

# Function to check ports availability
check_ports() {
    print_message "Checking if required ports are available..." "$YELLOW"
    
    local ports=("80" "443" "8080")
    local used_ports=()
    
    for port in "${ports[@]}"; do
        if netstat -tuln | grep -q ":$port "; then
            used_ports+=("$port")
        fi
    done
    
    if [ ${#used_ports[@]} -gt 0 ]; then
        print_message "Warning: The following ports are already in use: ${used_ports[*]}" "$RED"
        print_message "These ports are needed for the WordPress setup:" "$YELLOW"
        print_message "  - Port 80: HTTP" "$YELLOW"
        print_message "  - Port 443: HTTPS" "$YELLOW"
        print_message "  - Port 8080: phpMyAdmin (optional)" "$YELLOW"
        
        read -p "Would you like to continue anyway? (y/n): " continue_setup
        if [ "$continue_setup" != "y" ] && [ "$continue_setup" != "Y" ]; then
            print_message "Setup aborted. Please free the required ports and try again." "$RED"
            exit 1
        fi
    else
        print_message "All required ports are available." "$GREEN"
    fi
}

# Function to validate domain
validate_domain() {
    # Basic domain validation
    if ! echo "$domain" | grep -qE '^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$'; then
        print_message "Error: Invalid domain name format." "$RED"
        return 1
    fi
    return 0
}

# Function to validate email
validate_email() {
    # Basic email validation
    if ! echo "$email" | grep -qE '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'; then
        print_message "Error: Invalid email address format." "$RED"
        return 1
    fi
    return 0
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_message "This script requires root privileges to run correctly." "$RED"
        print_message "Please run it with sudo or as root." "$YELLOW"
        exit 1
    fi
}

# Main function
main() {
    print_message "WordPress Docker SSL Setup Script" "$BLUE"
    print_message "=================================" "$BLUE"
    
    # Check if running as root
    check_root
    
    # Detect Linux distribution
    detect_distro
    
    # Prompt user for required information
    while true; do
        read -p "Enter your domain name (e.g., yourdomain.com): " domain
        if validate_domain; then
            break
        fi
    done
    
    while true; do
        read -p "Enter your email address: " email
        if validate_email; then
            break
        fi
    done
    
    read -p "Enter WordPress database username: " wp_db_user
    read -s -p "Enter WordPress database password: " wp_db_password
    echo
    read -p "Enter WordPress database name: " wp_db_name
    read -p "Enter a name for your website directory (e.g., mywebsite): " website_name
    
    # Set base directory
    base_dir="/var/www/$website_name"
    
    # Check if directory already exists
    if [ -d "$base_dir" ]; then
        print_message "Warning: Directory $base_dir already exists." "$YELLOW"
        read -p "Do you want to overwrite the existing directory? (y/n): " overwrite
        if [ "$overwrite" != "y" ] && [ "$overwrite" != "Y" ]; then
            print_message "Setup aborted. Please choose a different directory name." "$RED"
            exit 1
        fi
    fi
    
    # Create the base directory if it doesn't exist
    mkdir -p "$base_dir"
    
    # Check ports
    check_ports
    
    # Install dependencies
    install_docker
    install_certbot
    
    # Set up WordPress Docker environment
    setup_wordpress_docker
    
    # Obtain SSL certificates
    obtain_ssl_certificates
    
    # Set permissions for the website directory
    chown -R $SUDO_USER:$SUDO_USER "$base_dir"
    
    # Start Docker containers
    cd "$base_dir"
    docker-compose up -d
    
    # Set up automatic SSL renewal
    setup_ssl_renewal
    
    # Output success message
    print_message "=====================================" "$GREEN"
    print_message "WordPress with SSL setup completed!" "$GREEN"
    print_message "=====================================" "$GREEN"
    echo
    print_message "Website Details:" "$BLUE"
    print_message "- Website URL: https://$domain" "$GREEN"
    print_message "- Website Directory: $base_dir" "$GREEN"
    print_message "- phpMyAdmin URL: http://$domain:8080" "$GREEN"
    echo
    print_message "Helper Scripts:" "$BLUE"
    print_message "- Start containers: $base_dir/start.sh" "$GREEN"
    print_message "- Stop containers: $base_dir/stop.sh" "$GREEN"
    print_message "- Restart containers: $base_dir/restart.sh" "$GREEN"
    print_message "- Backup website: $base_dir/backup.sh" "$GREEN"
    echo
    print_message "Note: You may need to configure your DNS settings to point your domain to this server's IP address." "$YELLOW"
    print_message "Note: SSL certificates will be automatically renewed weekly." "$YELLOW"
}

# Execute main function
main
