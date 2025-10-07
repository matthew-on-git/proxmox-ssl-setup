#!/bin/bash

# Proxmox SSL Certificate Setup Script
# Uses Let's Encrypt with Cloudflare DNS-01 challenge

set -euo pipefail

# Default values
DOMAIN=""
EMAIL=""
CF_TOKEN=""
PROXMOX_TYPE=""

# Usage function
usage() {
    cat << EOF
Usage: $0 -d DOMAIN -e EMAIL -t CF_TOKEN -p PROXMOX_TYPE [OPTIONS]

REQUIRED ARGUMENTS:
    -d, --domain DOMAIN        Proxmox domain name (e.g., proxmox.example.com)
    -e, --email EMAIL          Email address for Let's Encrypt registration
    -t, --cf-token TOKEN       Cloudflare API token for DNS-01 challenge
    -p, --proxmox-type TYPE    Proxmox installation type (ve or pbs)

OPTIONS:
    -h, --help                 Show this help message and exit

EXAMPLES:
    # For Proxmox VE installation
    $0 -d proxmox.example.com -e admin@example.com -t your_cf_token -p ve

    # For Proxmox Backup Server installation
    $0 -d pbs.example.com -e admin@example.com -t your_cf_token -p pbs

ENVIRONMENT VARIABLES:
    This script requires the following to be set or provided as arguments:
    - DOMAIN: Your Proxmox domain name
    - EMAIL: Email for Let's Encrypt certificate registration
    - CF_TOKEN: Cloudflare API token with Zone:Read and DNS:Edit permissions
    - PROXMOX_TYPE: Either 've' (Proxmox VE) or 'pbs' (Proxmox Backup Server)

PREREQUISITES:
    - Must be run as root
    - Proxmox must be installed and running
    - Domain must point to this server's IP address
    - Cloudflare API token with appropriate permissions

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--domain)
                DOMAIN="$2"
                shift 2
                ;;
            -e|--email)
                EMAIL="$2"
                shift 2
                ;;
            -t|--cf-token)
                CF_TOKEN="$2"
                shift 2
                ;;
            -p|--proxmox-type)
                PROXMOX_TYPE="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    # Validate required arguments
    if [[ -z "$DOMAIN" ]]; then
        echo "Error: Domain is required"
        usage
        exit 1
    fi

    if [[ -z "$EMAIL" ]]; then
        echo "Error: Email is required"
        usage
        exit 1
    fi

    if [[ -z "$CF_TOKEN" ]]; then
        echo "Error: Cloudflare token is required"
        usage
        exit 1
    fi

    if [[ -z "$PROXMOX_TYPE" ]]; then
        echo "Error: Proxmox type is required"
        usage
        exit 1
    fi

    # Validate Proxmox type
    if [[ "$PROXMOX_TYPE" != "ve" && "$PROXMOX_TYPE" != "pbs" ]]; then
        echo "Error: Proxmox type must be either 've' or 'pbs'"
        usage
        exit 1
    fi
}

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
    
    # Detect OS
    if [[ -f /etc/debian_version ]]; then
        OS="debian"
    elif [[ -f /etc/redhat-release ]]; then
        OS="redhat"
    else
        error "Unsupported operating system"
    fi
    
    # Check if Proxmox is installed
    if [[ "$PROXMOX_TYPE" == "ve" ]]; then
        if ! command -v pveversion &> /dev/null; then
            error "Proxmox VE is not installed or not accessible"
        fi
        log "Proxmox VE version: $(pveversion)"
    elif [[ "$PROXMOX_TYPE" == "pbs" ]]; then
        if ! command -v proxmox-backup-manager &> /dev/null; then
            error "Proxmox Backup Server is not installed or not accessible"
        fi
        log "Proxmox Backup Server detected"
    fi
    
    log "Prerequisites check passed"
}

# Install certbot
install_certbot() {
    log "Installing certbot and Cloudflare plugin..."
    
    if [[ "$OS" == "debian" ]]; then
        apt-get update
        apt-get install -y certbot python3-certbot-dns-cloudflare
    elif [[ "$OS" == "redhat" ]]; then
        yum install -y epel-release
        yum install -y certbot python3-certbot-dns-cloudflare
    fi
    
    log "Certbot installed successfully"
}

# Setup Cloudflare credentials
setup_cloudflare() {
    log "Setting up Cloudflare credentials..."
    
    mkdir -p /etc/letsencrypt
    
    cat > /etc/letsencrypt/cloudflare.ini << EOF
# Cloudflare API token
dns_cloudflare_api_token = ${CF_TOKEN}
EOF
    
    chmod 600 /etc/letsencrypt/cloudflare.ini
    
    log "Cloudflare credentials configured"
}

# Request certificate
request_certificate() {
    log "Requesting Let's Encrypt certificate for $DOMAIN..."
    
    certbot certonly \
        --non-interactive \
        --agree-tos \
        --email "$EMAIL" \
        --dns-cloudflare \
        --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini \
        --dns-cloudflare-propagation-seconds 60 \
        -d "$DOMAIN"
    
    if [[ $? -eq 0 ]]; then
        log "Certificate obtained successfully!"
    else
        error "Failed to obtain certificate"
    fi
}

# Configure Proxmox VE
configure_proxmox_ve() {
    log "Configuring Proxmox VE..."
    
    # Backup current configuration
    cp /etc/pve/local/pve-ssl.pem /etc/pve/local/pve-ssl.pem.backup.$(date +%Y%m%d%H%M%S) 2>/dev/null || true
    cp /etc/pve/local/pve-ssl.key /etc/pve/local/pve-ssl.key.backup.$(date +%Y%m%d%H%M%S) 2>/dev/null || true
    
    # Copy certificates
    cp /etc/letsencrypt/live/${DOMAIN}/fullchain.pem /etc/pve/local/pve-ssl.pem
    cp /etc/letsencrypt/live/${DOMAIN}/privkey.pem /etc/pve/local/pve-ssl.key
    
    # Set proper permissions
    chown root:www-data /etc/pve/local/pve-ssl.pem /etc/pve/local/pve-ssl.key
    chmod 640 /etc/pve/local/pve-ssl.pem /etc/pve/local/pve-ssl.key
    
    # Restart Proxmox services
    log "Restarting Proxmox services..."
    systemctl restart pveproxy
    systemctl restart pvedaemon
    
    log "Proxmox VE configured successfully"
}

# Configure Proxmox Backup Server
configure_proxmox_pbs() {
    log "Configuring Proxmox Backup Server..."
    
    # Backup current configuration
    cp /etc/proxmox-backup/proxy.pem /etc/proxmox-backup/proxy.pem.backup.$(date +%Y%m%d%H%M%S) 2>/dev/null || true
    cp /etc/proxmox-backup/proxy.key /etc/proxmox-backup/proxy.key.backup.$(date +%Y%m%d%H%M%S) 2>/dev/null || true
    
    # Copy certificates
    cp /etc/letsencrypt/live/${DOMAIN}/fullchain.pem /etc/proxmox-backup/proxy.pem
    cp /etc/letsencrypt/live/${DOMAIN}/privkey.pem /etc/proxmox-backup/proxy.key
    
    # Set proper permissions
    chown root:backup /etc/proxmox-backup/proxy.pem /etc/proxmox-backup/proxy.key
    chmod 640 /etc/proxmox-backup/proxy.pem /etc/proxmox-backup/proxy.key
    
    # Restart Proxmox Backup Server services
    log "Restarting Proxmox Backup Server services..."
    systemctl restart proxmox-backup-proxy
    
    log "Proxmox Backup Server configured successfully"
}

# Setup auto-renewal
setup_renewal() {
    log "Setting up automatic renewal..."
    
    # Create renewal hook script
    mkdir -p /etc/letsencrypt/renewal-hooks/deploy
    
    cat > /etc/letsencrypt/renewal-hooks/deploy/proxmox-reload.sh << 'EOF'
#!/bin/bash
# Reload Proxmox after certificate renewal

if command -v pveversion &> /dev/null; then
    echo "Reloading Proxmox VE services..."
    systemctl reload pveproxy
    systemctl reload pvedaemon
elif command -v proxmox-backup-manager &> /dev/null; then
    echo "Reloading Proxmox Backup Server services..."
    systemctl reload proxmox-backup-proxy
fi
EOF
    
    chmod +x /etc/letsencrypt/renewal-hooks/deploy/proxmox-reload.sh
    
    # Test renewal
    log "Testing certificate renewal..."
    certbot renew --dry-run
    
    if [[ $? -eq 0 ]]; then
        log "Auto-renewal configured successfully"
    else
        warn "Auto-renewal test failed. Please check configuration."
    fi
}

# Verify certificate
verify_certificate() {
    log "Verifying certificate installation..."
    
    # Wait for services to be ready
    sleep 10
    
    # Check HTTPS
    if curl -ksI "https://${DOMAIN}:8006" | grep -q "200 OK\|302 Found"; then
        log "Proxmox VE HTTPS is working!"
    elif curl -ksI "https://${DOMAIN}:8007" | grep -q "200 OK\|302 Found"; then
        log "Proxmox Backup Server HTTPS is working!"
    else
        warn "HTTPS check failed. Proxmox might still be starting up."
    fi
    
    # Show certificate info
    log "Certificate details:"
    if [[ "$PROXMOX_TYPE" == "ve" ]]; then
        openssl s_client -connect "${DOMAIN}:8006" -servername "${DOMAIN}" < /dev/null 2>/dev/null | \
            openssl x509 -noout -subject -issuer -dates
    else
        openssl s_client -connect "${DOMAIN}:8007" -servername "${DOMAIN}" < /dev/null 2>/dev/null | \
            openssl x509 -noout -subject -issuer -dates
    fi
}

# Main execution
main() {
    # Parse command line arguments
    parse_args "$@"
    
    cat << EOF
====================================
Proxmox SSL Certificate Setup Script
====================================
Domain: $DOMAIN
Email: $EMAIL
Proxmox Type: $PROXMOX_TYPE
====================================

This script will:
1. Install certbot with Cloudflare plugin
2. Request a Let's Encrypt certificate
3. Configure Proxmox to use the certificate
4. Setup automatic renewal

EOF

    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    
    check_prerequisites
    install_certbot
    setup_cloudflare
    request_certificate
    
    if [[ "$PROXMOX_TYPE" == "ve" ]]; then
        configure_proxmox_ve
    elif [[ "$PROXMOX_TYPE" == "pbs" ]]; then
        configure_proxmox_pbs
    else
        error "Unknown Proxmox type: $PROXMOX_TYPE"
    fi
    
    setup_renewal
    verify_certificate
    
    cat << EOF

${GREEN}✅ SSL Certificate Setup Complete!${NC}

Your Proxmox instance is now accessible at:
https://${DOMAIN}:8006${NC}

Certificate will auto-renew before expiration.

To manually renew:
sudo certbot renew

To check certificate status:
sudo certbot certificates

${YELLOW}Note: DNS must point to this server's IP for the certificate to work externally.${NC}

EOF
}

# Run main function
main "$@"
