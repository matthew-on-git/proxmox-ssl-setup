# Proxmox SSL Setup - Quick Start Guide

## 🚀 Quick Start

### 1. Download and Setup
```bash
# Clone the repository
git clone https://github.com/your-username/proxmox-ssl-setup.git
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
# For Proxmox VE
sudo ./setup-proxmox-ssl.sh -d proxmox.example.com -e admin@example.com -t your_cf_token -p ve

# For Proxmox Backup Server
sudo ./setup-proxmox-ssl.sh -d pbs.example.com -e admin@example.com -t your_cf_token -p pbs
```

## 📋 Prerequisites Checklist

- [ ] Root access to Proxmox server
- [ ] Proxmox VE or Proxmox Backup Server installed
- [ ] Domain pointing to server IP
- [ ] Cloudflare API token with Zone:Read and DNS:Edit permissions
- [ ] Internet connectivity

## 🔧 What You Need

1. **Domain Name**: Your Proxmox domain (e.g., `proxmox.example.com`)
2. **Email Address**: For Let's Encrypt registration
3. **Cloudflare API Token**: With appropriate permissions
4. **Proxmox Type**: Either `ve` (Proxmox VE) or `pbs` (Proxmox Backup Server)

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
- ✅ Certificate obtained successfully
- ✅ Proxmox configured successfully
- ✅ Auto-renewal configured successfully
- ✅ HTTPS is working on the correct port (8006 for VE, 8007 for PBS)

## 🔄 Maintenance

- Certificates auto-renew before expiration
- Manual renewal: `sudo certbot renew`
- Check status: `sudo certbot certificates`
- View logs: `journalctl -u pveproxy` (VE) or `journalctl -u proxmox-backup-proxy` (PBS)
