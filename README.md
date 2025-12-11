# uidcyber.com - Cybersecurity Portfolio Website

A professional portfolio website showcasing cybersecurity expertise with automated deployment.

## Features

- Modern, responsive dark theme design
- Complete security hardening (TLS 1.2/1.3, HSTS, security headers)
- Automated deployment with one script
- Let's Encrypt SSL with automatic renewal
- Nginx web server with HTTP/2

## Quick Start

### Prerequisites

- Debian/Ubuntu server (AWS EC2, DigitalOcean, etc.)
- Root/sudo access
- Domain with DNS configured to point to your server

### Deployment

1. Copy files to your server:
```bash
scp -r . user@your-server:~/uidcyber-website/
```

2. SSH into your server:
```bash
ssh user@your-server
```

3. Run the deployment script:
```bash
cd ~/uidcyber-website
sudo ./deploy.sh
```

The script will:
- Update system packages
- Install nginx, certbot, and dependencies
- Configure firewall (UFW)
- Deploy website files
- Obtain SSL certificate from Let's Encrypt
- Configure nginx with HTTPS
- Set up automatic certificate renewal

## DNS Configuration

Before running the deployment, configure these DNS records:

```
Type    Name    Value
A       @       <YOUR_SERVER_IP>
A       www     <YOUR_SERVER_IP>
CAA     @       0 issue "letsencrypt.org"
```

## File Structure

```
uidcyber-website/
├── deploy.sh       # Complete deployment script
├── index.html      # Main website
├── styles.css      # Stylesheet
├── nginx.conf      # Nginx configuration (reference)
└── README.md       # This file
```

## Security Features

- TLS 1.2 & 1.3 only
- Strong cipher suites
- HSTS enabled (2 year max-age)
- Security headers (X-Frame-Options, CSP, etc.)
- UFW firewall configured
- Automatic SSL certificate renewal

## Maintenance

### Update Website Content

```bash
# Edit files locally, then copy to server
scp index.html user@server:/var/www/uidcyber/
scp styles.css user@server:/var/www/uidcyber/
```

### Check SSL Certificate

```bash
sudo certbot certificates
```

### View Logs

```bash
sudo tail -f /var/log/nginx/uidcyber_access.log
```

## License

Personal portfolio - All rights reserved
