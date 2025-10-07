# Proxmox SSL Setup - Quick Start Guide

## 🚀 Quick Start

### 1. Download and Setup
```bash
# Clone the repository
git clone https://github.com/matthew-on-git/proxmox-ssl-setup.git
cd proxmox-ssl-setup

# Make scripts executable
chmod +x setup-proxmox-ssl.sh test-ssl-setup.sh
```

### 2. Test Your Environment
```bash
# Run the test script to validate your setup
sudo ./test-ssl-setup.sh
```

### 3. Run the SSL Setup
```bash
# For Proxmox VE (local)
sudo ./setup-proxmox-ssl.sh -d proxmox.example.com -e admin@example.com -t your_cf_token -p ve

# For Proxmox VE (remote with API token)
./setup-proxmox-ssl.sh -d proxmox.example.com -e admin@example.com -t your_cf_token -p ve \
  -a https://proxmox.example.com:8006 -k user@pam!tokenid=secret

# For Proxmox Backup Server (remote)
./setup-proxmox-ssl.sh -d pbs.example.com -e admin@example.com -t your_cf_token -p pbs \
  -a https://pbs.example.com:8007 -k user@pam!tokenid=secret
```

## 📋 Prerequisites Checklist

- [ ] Root access to Proxmox server (for local) OR API token (for remote)
- [ ] Proxmox VE or Proxmox Backup Server installed
- [ ] Domain pointing to server IP
- [ ] Cloudflare API token with Zone:Read and DNS:Edit permissions
- [ ] Internet connectivity
- [ ] curl and jq installed

## 🔧 What You Need

1. **Domain Name**: Your Proxmox domain (e.g., `proxmox.example.com`)
2. **Email Address**: For Let's Encrypt registration
3. **Cloudflare API Token**: With appropriate permissions
4. **Proxmox Type**: Either `ve` (Proxmox VE) or `pbs` (Proxmox Backup Server)
5. **Proxmox API Access**: Either root access (local) or API token (remote)

## 📚 More Information

- **Full Documentation**: See [README.md](README.md)
- **Examples**: Check the `examples/` directory
- **Troubleshooting**: See the troubleshooting section in README.md

## 🆘 Need Help?

1. Run the test script first: `sudo ./test-ssl-setup.sh`
2. Check the troubleshooting section in README.md
3. Review Proxmox and Let's Encrypt documentation
4. Check script logs for error messages

## 🎯 Success Indicators

After successful setup, you should see:
- ✅ ACME account registered successfully
- ✅ Cloudflare plugin configured successfully
- ✅ Certificate order initiated successfully
- ✅ Certificate verification successful
- ✅ HTTPS is working on the correct port (8006 for VE, 8007 for PBS)

## 🔄 Maintenance

- Certificates auto-renew via Proxmox's built-in ACME functionality
- Check certificate status via API: `curl -k "https://proxmox:8006/api2/json/nodes/proxmox/certificates/acme"`
- Manage certificates via Proxmox GUI: Datacenter → ACME → Accounts, System → Certificates
- View logs: `journalctl -u pveproxy` (VE) or `journalctl -u proxmox-backup-proxy` (PBS)
