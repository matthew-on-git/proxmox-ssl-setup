# Proxmox SSL Certificate Setup Script

A bash script to automatically configure SSL certificates for Proxmox VE and Proxmox Backup Server using Let's Encrypt with Cloudflare DNS-01 challenge.

## Overview

This script automates the process of:
- Installing certbot with Cloudflare DNS plugin
- Requesting Let's Encrypt SSL certificates
- Configuring Proxmox (VE or Backup Server) to use the certificates
- Setting up automatic certificate renewal

## Prerequisites

### System Requirements
- **Operating System**: Debian/Ubuntu or Red Hat/CentOS
- **Root Access**: Script must be run as root
- **Internet Connectivity**: Required for Let's Encrypt certificate requests

### Proxmox Requirements
- Proxmox VE or Proxmox Backup Server must be installed and running
- Domain must point to the server's IP address
- Proxmox must be accessible via the domain name

### Cloudflare Requirements
- Cloudflare account with the domain
- API token with the following permissions:
  - `Zone:Read` - to read zone information
  - `DNS:Edit` - to create/delete DNS records for DNS-01 challenge

## Installation

1. **Download the script** to your Proxmox server:
   ```bash
   wget https://raw.githubusercontent.com/your-repo/proxmox-ssl-setup/main/setup-proxmox-ssl.sh
   chmod +x setup-proxmox-ssl.sh
   ```

2. **Create Cloudflare API Token**:
   - Log into Cloudflare dashboard
   - Go to "My Profile" → "API Tokens"
   - Click "Create Token"
   - Use "Custom token" template
   - Set permissions: `Zone:Read`, `DNS:Edit`
   - Select your domain zone
   - Create and copy the token

## Usage

### Basic Usage

```bash
sudo ./setup-proxmox-ssl.sh -d <domain> -e <email> -t <cf_token> -p <proxmox_type>
```

### Required Arguments

| Argument | Short | Description | Example |
|----------|-------|-------------|---------|
| `--domain` | `-d` | Proxmox domain name | `proxmox.example.com` |
| `--email` | `-e` | Email for Let's Encrypt registration | `admin@example.com` |
| `--cf-token` | `-t` | Cloudflare API token | `your_api_token_here` |
| `--proxmox-type` | `-p` | Proxmox installation type | `ve` or `pbs` |

### Examples

**For Proxmox VE installation:**
```bash
sudo ./setup-proxmox-ssl.sh \
  -d proxmox.example.com \
  -e admin@example.com \
  -t your_cloudflare_api_token \
  -p ve
```

**For Proxmox Backup Server installation:**
```bash
sudo ./setup-proxmox-ssl.sh \
  -d pbs.example.com \
  -e admin@example.com \
  -t your_cloudflare_api_token \
  -p pbs
```

**Show help:**
```bash
./setup-proxmox-ssl.sh --help
```

## What the Script Does

### 1. Prerequisites Check
- Verifies root access
- Detects operating system (Debian/Red Hat)
- Checks if Proxmox is installed and running
- Displays Proxmox version

### 2. Certbot Installation
- Installs certbot and Cloudflare DNS plugin
- Uses appropriate package manager for your OS

### 3. Cloudflare Configuration
- Creates secure credentials file at `/etc/letsencrypt/cloudflare.ini`
- Sets proper file permissions (600)

### 4. Certificate Request
- Requests Let's Encrypt certificate using DNS-01 challenge
- Uses Cloudflare API to create/delete DNS records
- Waits for DNS propagation (60 seconds)

### 5. Proxmox Configuration

#### For Proxmox VE:
- Backs up existing SSL certificates
- Copies new certificates to `/etc/pve/local/`
- Sets proper ownership and permissions
- Restarts Proxmox services (`pveproxy`, `pvedaemon`)

#### For Proxmox Backup Server:
- Backs up existing SSL certificates
- Copies new certificates to `/etc/proxmox-backup/`
- Sets proper ownership and permissions
- Restarts Proxmox Backup Server services (`proxmox-backup-proxy`)

### 6. Auto-Renewal Setup
- Creates renewal hook script
- Configures automatic certificate renewal
- Tests renewal process with dry-run

### 7. Verification
- Verifies HTTPS is working on the correct port
- Displays certificate information
- Shows next steps

## Configuration Details

### Proxmox VE Configuration
The script updates the following files:
- `/etc/pve/local/pve-ssl.pem` - SSL certificate
- `/etc/pve/local/pve-ssl.key` - SSL private key

### Proxmox Backup Server Configuration
The script updates the following files:
- `/etc/proxmox-backup/proxy.pem` - SSL certificate
- `/etc/proxmox-backup/proxy.key` - SSL private key

## File Locations

| File | Purpose |
|------|---------|
| `/etc/letsencrypt/cloudflare.ini` | Cloudflare API credentials |
| `/etc/letsencrypt/live/domain/` | SSL certificates |
| `/etc/letsencrypt/renewal-hooks/deploy/proxmox-reload.sh` | Renewal hook script |
| `/etc/pve/local/pve-ssl.*` | Proxmox VE SSL files |
| `/etc/proxmox-backup/proxy.*` | Proxmox Backup Server SSL files |

## Ports

- **Proxmox VE**: Uses port 8006 (HTTPS)
- **Proxmox Backup Server**: Uses port 8007 (HTTPS)

## Troubleshooting

### Common Issues

**1. Permission Denied**
```bash
# Make sure you're running as root
sudo ./setup-proxmox-ssl.sh [arguments]
```

**2. Cloudflare API Token Issues**
- Verify token has correct permissions
- Check token is not expired
- Ensure domain is managed by Cloudflare

**3. DNS Propagation Issues**
- Wait for DNS changes to propagate
- Check DNS records manually
- Verify domain points to server IP

**4. Proxmox Not Accessible**
- Check Proxmox service status
- Verify firewall settings
- Check Proxmox logs

### Manual Certificate Renewal
```bash
sudo certbot renew
```

### Check Certificate Status
```bash
sudo certbot certificates
```

### View Proxmox Logs
```bash
# For Proxmox VE
journalctl -u pveproxy
journalctl -u pvedaemon

# For Proxmox Backup Server
journalctl -u proxmox-backup-proxy
```

### Check Proxmox Status
```bash
# For Proxmox VE
systemctl status pveproxy pvedaemon

# For Proxmox Backup Server
systemctl status proxmox-backup-proxy
```

## Security Notes

- Cloudflare credentials are stored with restricted permissions (600)
- Script requires root access for system-level operations
- Certificates are automatically renewed before expiration
- HTTP traffic is redirected to HTTPS

## Differences from GitLab Script

This script is specifically designed for Proxmox environments and includes:
- Support for both Proxmox VE and Proxmox Backup Server
- Proper file locations and permissions for Proxmox
- Service restart commands specific to Proxmox
- Port verification (8006 for VE, 8007 for PBS)
- Proxmox-specific certificate file names

## Support

For issues and questions:
1. Check the troubleshooting section above
2. Review Proxmox and Let's Encrypt documentation
3. Check script logs for error messages
4. Verify all prerequisites are met

## License

This script is part of the proxmox-ssl-setup project. See the main project LICENSE file for details.
