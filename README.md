# Proxmox SSL Certificate Setup Script

A bash script to automatically configure SSL certificates for Proxmox VE and Proxmox Backup Server using Proxmox's built-in ACME functionality with Cloudflare DNS-01 challenge.

## Overview

This script automates the process of:
- Connecting to Proxmox API (local or remote)
- Registering ACME account with Let's Encrypt
- Configuring Cloudflare DNS challenge plugin
- Ordering SSL certificates via Proxmox's built-in ACME
- Verifying certificate installation and functionality

## Prerequisites

### System Requirements
- **Operating System**: Any system with curl and jq
- **Access**: Root access (for local Proxmox) OR API token (for remote Proxmox)
- **Internet Connectivity**: Required for Let's Encrypt certificate requests
- **Tools**: curl and jq must be installed

### Proxmox Requirements
- Proxmox VE or Proxmox Backup Server must be installed and running
- Domain must point to the server's IP address
- Proxmox must be accessible via the domain name
- Proxmox API must be accessible (local or remote)

### Cloudflare Requirements
- Cloudflare account with the domain
- API token with the following permissions:
  - `Zone:Read` - to read zone information
  - `DNS:Edit` - to create/delete DNS records for DNS-01 challenge

## Installation

1. **Download the script** to your Proxmox server:
   ```bash
   wget https://raw.githubusercontent.com/matthew-on-git/proxmox-ssl-setup/refs/heads/master/setup-proxmox-ssl.sh
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

### Optional Arguments

| Argument | Short | Description | Example |
|----------|-------|-------------|---------|
| `--api-url` | `-a` | Proxmox API URL | `https://proxmox.example.com:8006` |
| `--api-token` | `-k` | Proxmox API token | `user@pam!tokenid=secret` |

### Examples

**For Proxmox VE installation (local):**
```bash
sudo ./setup-proxmox-ssl.sh \
  -d proxmox.example.com \
  -e admin@example.com \
  -t your_cloudflare_api_token \
  -p ve
```

**For Proxmox VE installation (remote):**
```bash
./setup-proxmox-ssl.sh \
  -d proxmox.example.com \
  -e admin@example.com \
  -t your_cloudflare_api_token \
  -p ve \
  -a https://proxmox.example.com:8006 \
  -k user@pam!tokenid=secret
```

**For Proxmox Backup Server installation (remote):**
```bash
./setup-proxmox-ssl.sh \
  -d pbs.example.com \
  -e admin@example.com \
  -t your_cloudflare_api_token \
  -p pbs \
  -a https://pbs.example.com:8007 \
  -k user@pam!tokenid=secret
```

**Show help:**
```bash
./setup-proxmox-ssl.sh --help
```

## What the Script Does

### 1. Prerequisites Check
- Verifies API access (root for local or API token for remote)
- Checks required tools (curl, jq)
- Tests Proxmox API connectivity
- Displays Proxmox version

### 2. ACME Account Registration
- Registers ACME account with Let's Encrypt
- Uses Proxmox's built-in ACME client
- Handles existing account scenarios gracefully

### 3. Cloudflare Plugin Configuration
- Configures Cloudflare DNS challenge plugin
- Stores Cloudflare API token securely in Proxmox
- Uses Proxmox's native plugin system

### 4. Certificate Ordering
- Orders SSL certificate via Proxmox API
- Uses DNS-01 challenge with Cloudflare
- Leverages Proxmox's built-in certificate management

### 5. Certificate Verification
- Checks certificate status via API
- Verifies HTTPS connectivity
- Displays certificate information
- Confirms successful installation

### 6. Automatic Renewal
- Proxmox handles certificate renewal automatically
- No external scripts or cron jobs needed
- Built-in ACME client manages renewal process

## Configuration Details

### Proxmox ACME Configuration
The script configures Proxmox's built-in ACME functionality:
- ACME account registration with Let's Encrypt
- Cloudflare DNS challenge plugin configuration
- Certificate ordering and management via Proxmox API

### Certificate Management
- Certificates are managed by Proxmox's native ACME client
- No manual file copying or permission setting required
- Automatic renewal handled by Proxmox

## API Endpoints Used

| Endpoint | Purpose |
|----------|---------|
| `/api2/json/version` | Check Proxmox connectivity |
| `/api2/json/cluster/acme/accounts` | Register ACME account |
| `/api2/json/cluster/acme/plugins` | Configure challenge plugin |
| `/api2/json/nodes/proxmox/certificates/acme` | Order and manage certificates |

## Ports

- **Proxmox VE**: Uses port 8006 (HTTPS)
- **Proxmox Backup Server**: Uses port 8007 (HTTPS)

## Troubleshooting

### Common Issues

**1. API Connection Issues**
```bash
# Check Proxmox API connectivity
curl -k https://proxmox:8006/api2/json/version

# For remote access, verify API token
curl -k -H "Authorization: PVEAPIToken=user@pam!tokenid=secret" \
  https://proxmox:8006/api2/json/version
```

**2. Cloudflare API Token Issues**
- Verify token has correct permissions (Zone:Read, DNS:Edit)
- Check token is not expired
- Ensure domain is managed by Cloudflare

**3. ACME Account Registration Issues**
- Check if account already exists
- Verify email address is valid
- Ensure Let's Encrypt API is accessible

**4. Certificate Ordering Issues**
- Verify domain points to server IP
- Check DNS propagation
- Ensure Cloudflare plugin is configured correctly

### Check Certificate Status
```bash
# Via API
curl -k https://proxmox:8006/api2/json/nodes/proxmox/certificates/acme

# Via Proxmox GUI
# Datacenter → ACME → Accounts
# System → Certificates
```

### Manual Certificate Management
```bash
# Order certificate via API
curl -k -X POST https://proxmox:8006/api2/json/nodes/proxmox/certificates/acme \
  -d "name=letsencrypt" \
  -d "domain=proxmox.example.com" \
  -d "plugin=cloudflare"
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

- Cloudflare credentials are stored securely in Proxmox's configuration
- API tokens are handled securely and not stored in files
- Certificates are automatically renewed by Proxmox's built-in ACME client
- No external scripts or cron jobs required
- All operations use Proxmox's native security model

## Key Benefits

This script leverages Proxmox's built-in ACME functionality:
- **Native Integration**: Uses Proxmox's built-in certificate management
- **Simplified Management**: Certificates managed through Proxmox GUI
- **Automatic Renewal**: No external scripts or cron jobs needed
- **Remote Support**: Can manage certificates on remote Proxmox instances
- **Better Error Handling**: Uses Proxmox's native error reporting
- **No External Dependencies**: No need for certbot or additional packages

## Support

For issues and questions:
1. Check the troubleshooting section above
2. Review Proxmox and Let's Encrypt documentation
3. Check script logs for error messages
4. Verify all prerequisites are met

## License

This script is part of the proxmox-ssl-setup project. See the main project LICENSE file for details.
