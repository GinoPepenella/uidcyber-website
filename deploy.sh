#!/bin/bash

############################################################################
# uidcyber.com - Complete Deployment Script
# Automated deployment with dependency installation, DNS checking, and SSL
############################################################################

set -e  # Exit on any error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="uidcyber.com"
EMAIL="g.pepenella@gmail.com"
WEB_ROOT="/var/www/uidcyber"
NGINX_CONF="/etc/nginx/sites-available/uidcyber"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

############################################################################
# Banner
############################################################################

echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   █░█ █ █▀▄ █▀▀ █▄█ █▄▄ █▀▀ █▀█   █▀▀ █▀█ █▀▄▀█         ║
║   █▄█ █ █▄▀ █▄▄ ░█░ █▄█ ██▄ █▀▄   █▄▄ █▄█ █░▀░█         ║
║                                                           ║
║          Complete Deployment Script                       ║
║          Professional Cybersecurity Portfolio             ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

############################################################################
# Pre-flight Checks
############################################################################

echo -e "${BLUE}[PREFLIGHT] Running pre-flight checks...${NC}\n"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}ERROR: This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Get public IP
PUBLIC_IP=$(curl -s https://api.ipify.org || echo "Unable to detect")
echo -e "${GREEN}✓${NC} Public IP detected: ${YELLOW}$PUBLIC_IP${NC}"

# Check OS
if [ -f /etc/debian_version ]; then
    echo -e "${GREEN}✓${NC} OS: Debian/Ubuntu detected"
else
    echo -e "${YELLOW}⚠${NC}  Warning: This script is optimized for Debian/Ubuntu"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""

############################################################################
# DNS Configuration Prompt
############################################################################

echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║                 DNS CONFIGURATION REQUIRED                ║${NC}"
echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${CYAN}Before proceeding, you need to configure DNS records:${NC}\n"
echo -e "${YELLOW}Required DNS Records:${NC}"
echo -e "  Type: A     Name: @      Value: ${GREEN}$PUBLIC_IP${NC}"
echo -e "  Type: A     Name: www    Value: ${GREEN}$PUBLIC_IP${NC}"
echo -e "  Type: CAA   Name: @      Value: ${GREEN}0 issue \"letsencrypt.org\"${NC}\n"

echo -e "${CYAN}Steps to configure DNS:${NC}"
echo -e "  1. Log into your domain registrar"
echo -e "  2. Go to DNS management for ${YELLOW}$DOMAIN${NC}"
echo -e "  3. Add the DNS records shown above"
echo -e "  4. Save changes\n"

echo -e "${RED}═══════════════════════════════════════════════════${NC}"
read -p "$(echo -e ${YELLOW}Have you configured the DNS records? [y/N]: ${NC})" -n 1 -r
echo -e "${RED}═══════════════════════════════════════════════════${NC}\n"

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Please configure DNS records and run this script again.${NC}"
    exit 0
fi

############################################################################
# DNS Propagation Check
############################################################################

echo -e "\n${BLUE}[DNS CHECK] Waiting for DNS propagation...${NC}\n"

check_dns() {
    local dns_ip=$(dig +short $DOMAIN @8.8.8.8 | tail -1)
    if [ "$dns_ip" == "$PUBLIC_IP" ]; then
        return 0
    else
        return 1
    fi
}

echo -e "${CYAN}Checking DNS resolution for ${DOMAIN}...${NC}"
echo -e "${CYAN}This may take a few minutes. Will check every 30 seconds.${NC}\n"

MAX_ATTEMPTS=60  # 30 minutes max
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))

    DNS_IP=$(dig +short $DOMAIN @8.8.8.8 | tail -1)
    WWW_DNS_IP=$(dig +short www.$DOMAIN @8.8.8.8 | tail -1)

    echo -e "${YELLOW}Attempt $ATTEMPT/$MAX_ATTEMPTS:${NC}"
    echo -e "  $DOMAIN    → ${CYAN}$DNS_IP${NC}"
    echo -e "  www.$DOMAIN → ${CYAN}$WWW_DNS_IP${NC}"

    if [ "$DNS_IP" == "$PUBLIC_IP" ] && [ "$WWW_DNS_IP" == "$PUBLIC_IP" ]; then
        echo -e "\n${GREEN}✓ DNS propagation complete!${NC}\n"
        break
    else
        if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
            echo -e "\n${RED}✗ DNS propagation timeout${NC}"
            echo -e "${YELLOW}DNS does not point to this server yet.${NC}\n"
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
            break
        fi
        echo -e "${YELLOW}Waiting 30 seconds...${NC}\n"
        sleep 30
    fi
done

############################################################################
# System Update & Package Installation
############################################################################

echo -e "${BLUE}[1/7] Updating system packages...${NC}"
apt update -qq && apt upgrade -y -qq
echo -e "${GREEN}✓ System updated${NC}\n"

echo -e "${BLUE}[2/7] Installing nginx, certbot, and dependencies...${NC}"
apt install -y -qq nginx certbot python3-certbot-nginx ufw dnsutils curl > /dev/null 2>&1
echo -e "${GREEN}✓ Packages installed${NC}\n"

############################################################################
# Firewall Configuration
############################################################################

echo -e "${BLUE}[3/7] Configuring firewall...${NC}"
ufw --force enable > /dev/null 2>&1
ufw allow 22/tcp > /dev/null 2>&1   # SSH
ufw allow 80/tcp > /dev/null 2>&1   # HTTP
ufw allow 443/tcp > /dev/null 2>&1  # HTTPS
echo -e "${GREEN}✓ Firewall configured (ports 22, 80, 443 open)${NC}\n"

############################################################################
# Deploy Website Files
############################################################################

echo -e "${BLUE}[4/7] Deploying website files...${NC}"

# Create directories
mkdir -p $WEB_ROOT
mkdir -p /var/www/certbot

# Copy website files
cp "$SCRIPT_DIR/index.html" $WEB_ROOT/
cp "$SCRIPT_DIR/styles.css" $WEB_ROOT/

# Copy resume (check both possible locations)
if [ -f "$SCRIPT_DIR/GinoPepenella.pdf" ]; then
    cp "$SCRIPT_DIR/GinoPepenella.pdf" $WEB_ROOT/
elif [ -f "/home/cyber/GinoPepenella.pdf" ]; then
    cp "/home/cyber/GinoPepenella.pdf" $WEB_ROOT/
else
    echo -e "${YELLOW}⚠  Resume PDF not found, skipping...${NC}"
fi

# Set permissions
chown -R www-data:www-data $WEB_ROOT
chmod -R 755 $WEB_ROOT

echo -e "${GREEN}✓ Website files deployed to $WEB_ROOT${NC}\n"

############################################################################
# Configure Nginx (HTTP First)
############################################################################

echo -e "${BLUE}[5/7] Configuring nginx (HTTP)...${NC}"

cat > $NGINX_CONF << 'NGINX_CONFIG'
server {
    listen 80;
    listen [::]:80;
    server_name uidcyber.com www.uidcyber.com;

    root /var/www/uidcyber;
    index index.html;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        try_files $uri $uri/ =404;
    }

    location /GinoPepenella.pdf {
        alias /var/www/uidcyber/GinoPepenella.pdf;
        add_header Content-Disposition 'inline; filename="GinoPepenella_Resume.pdf"';
        add_header Cache-Control "public, max-age=3600";
    }

    location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    access_log /var/log/nginx/uidcyber_access.log;
    error_log /var/log/nginx/uidcyber_error.log;
}
NGINX_CONFIG

# Enable site
ln -sf $NGINX_CONF /etc/nginx/sites-enabled/uidcyber
rm -f /etc/nginx/sites-enabled/default

# Test and restart nginx
nginx -t && systemctl restart nginx
echo -e "${GREEN}✓ Nginx configured and running${NC}\n"

############################################################################
# Obtain SSL Certificate
############################################################################

echo -e "${BLUE}[6/7] Obtaining Let's Encrypt SSL certificate...${NC}\n"

echo -e "${CYAN}This will obtain a free SSL certificate from Let's Encrypt.${NC}"
echo -e "${CYAN}The certificate is valid for 90 days and renews automatically.${NC}\n"

# Obtain certificate
certbot certonly --webroot \
    --webroot-path=/var/www/certbot \
    --email $EMAIL \
    --agree-tos \
    --no-eff-email \
    --non-interactive \
    -d $DOMAIN \
    -d www.$DOMAIN

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✓ SSL certificate obtained successfully${NC}\n"
else
    echo -e "\n${RED}✗ Failed to obtain SSL certificate${NC}"
    echo -e "${YELLOW}The website is running on HTTP. You can manually run:${NC}"
    echo -e "${CYAN}sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN${NC}\n"
    exit 1
fi

############################################################################
# Configure Nginx with HTTPS
############################################################################

echo -e "${BLUE}[7/7] Configuring nginx with HTTPS...${NC}"

# Backup HTTP-only config
cp $NGINX_CONF ${NGINX_CONF}.http-backup

# Create full HTTPS configuration
cat > $NGINX_CONF << 'NGINX_HTTPS_CONFIG'
server {
    listen 80;
    listen [::]:80;
    server_name uidcyber.com www.uidcyber.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name uidcyber.com www.uidcyber.com;

    ssl_certificate /etc/letsencrypt/live/uidcyber.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/uidcyber.com/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-CHACHA20-POLY1305;
    ssl_prefer_server_ciphers on;

    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;

    ssl_stapling on;
    ssl_stapling_verify on;
    ssl_trusted_certificate /etc/letsencrypt/live/uidcyber.com/chain.pem;
    resolver 8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout 5s;

    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    root /var/www/uidcyber;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    location /GinoPepenella.pdf {
        alias /var/www/uidcyber/GinoPepenella.pdf;
        add_header Content-Disposition 'inline; filename="GinoPepenella_Resume.pdf"';
        add_header Cache-Control "public, max-age=3600";
    }

    location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    access_log /var/log/nginx/uidcyber_access.log;
    error_log /var/log/nginx/uidcyber_error.log;
}
NGINX_HTTPS_CONFIG

# Test and reload nginx
nginx -t && systemctl reload nginx

echo -e "${GREEN}✓ HTTPS configured${NC}\n"

############################################################################
# Deployment Complete
############################################################################

echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║              ✓ DEPLOYMENT SUCCESSFUL!                     ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

echo -e "${CYAN}Your website is now live at:${NC}"
echo -e "  ${GREEN}https://$DOMAIN${NC}"
echo -e "  ${GREEN}https://www.$DOMAIN${NC}\n"

echo -e "${CYAN}SSL Certificate Status:${NC}"
certbot certificates | grep -A 5 "$DOMAIN"

echo -e "\n${CYAN}Next Steps:${NC}"
echo -e "  1. ${GREEN}Visit https://$DOMAIN to see your site${NC}"
echo -e "  2. ${GREEN}Test SSL: https://www.ssllabs.com/ssltest/${NC}"
echo -e "  3. ${GREEN}Certificate auto-renewal is configured${NC}"
echo -e "  4. ${GREEN}Check logs: sudo tail -f /var/log/nginx/uidcyber_access.log${NC}\n"

echo -e "${CYAN}Security Features Enabled:${NC}"
echo -e "  ${GREEN}✓${NC} TLS 1.2 & 1.3"
echo -e "  ${GREEN}✓${NC} HSTS enabled"
echo -e "  ${GREEN}✓${NC} Security headers configured"
echo -e "  ${GREEN}✓${NC} Firewall (UFW) active"
echo -e "  ${GREEN}✓${NC} Auto SSL renewal (certbot timer)\n"

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Deployment completed at: $(date)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
