#!/bin/bash

# Test script for Proxmox SSL setup
# This script validates the setup without making changes

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Test function
test_prerequisites() {
    log "Testing prerequisites..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
    
    # Check if Proxmox is installed
    if command -v pveversion &> /dev/null; then
        log "Proxmox VE detected: $(pveversion)"
        PROXMOX_TYPE="ve"
    elif command -v proxmox-backup-manager &> /dev/null; then
        log "Proxmox Backup Server detected"
        PROXMOX_TYPE="pbs"
    else
        error "No Proxmox installation detected"
    fi
    
    # Check if certbot is available
    if command -v certbot &> /dev/null; then
        log "Certbot is installed: $(certbot --version)"
    else
        warn "Certbot is not installed"
    fi
    
    # Check if Cloudflare plugin is available
    if certbot plugins | grep -q "dns-cloudflare"; then
        log "Cloudflare DNS plugin is available"
    else
        warn "Cloudflare DNS plugin is not available"
    fi
    
    log "Prerequisites test completed"
}

# Test Cloudflare connectivity
test_cloudflare() {
    if [[ -z "${CF_TOKEN:-}" ]]; then
        warn "CF_TOKEN not set, skipping Cloudflare test"
        return
    fi
    
    log "Testing Cloudflare API connectivity..."
    
    response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
        -H "Authorization: Bearer $CF_TOKEN" \
        -H "Content-Type: application/json")
    
    if echo "$response" | grep -q '"success":true'; then
        log "Cloudflare API token is valid"
    else
        error "Cloudflare API token validation failed: $response"
    fi
}

# Test domain resolution
test_domain() {
    if [[ -z "${DOMAIN:-}" ]]; then
        warn "DOMAIN not set, skipping domain test"
        return
    fi
    
    log "Testing domain resolution for $DOMAIN..."
    
    if nslookup "$DOMAIN" &> /dev/null; then
        log "Domain $DOMAIN resolves successfully"
    else
        warn "Domain $DOMAIN does not resolve"
    fi
}

# Test Proxmox services
test_proxmox_services() {
    log "Testing Proxmox services..."
    
    if [[ "$PROXMOX_TYPE" == "ve" ]]; then
        if systemctl is-active --quiet pveproxy; then
            log "Proxmox VE proxy service is running"
        else
            warn "Proxmox VE proxy service is not running"
        fi
        
        if systemctl is-active --quiet pvedaemon; then
            log "Proxmox VE daemon service is running"
        else
            warn "Proxmox VE daemon service is not running"
        fi
    else
        if systemctl is-active --quiet proxmox-backup-proxy; then
            log "Proxmox Backup Server proxy service is running"
        else
            warn "Proxmox Backup Server proxy service is not running"
        fi
    fi
}

# Test SSL configuration
test_ssl_config() {
    log "Testing current SSL configuration..."
    
    if [[ "$PROXMOX_TYPE" == "ve" ]]; then
        if [[ -f "/etc/pve/local/pve-ssl.pem" ]]; then
            log "Proxmox VE SSL certificate exists"
            openssl x509 -in /etc/pve/local/pve-ssl.pem -text -noout | grep -E "(Subject:|Not Before|Not After)"
        else
            warn "Proxmox VE SSL certificate not found"
        fi
    else
        if [[ -f "/etc/proxmox-backup/proxy.pem" ]]; then
            log "Proxmox Backup Server SSL certificate exists"
            openssl x509 -in /etc/proxmox-backup/proxy.pem -text -noout | grep -E "(Subject:|Not Before|Not After)"
        else
            warn "Proxmox Backup Server SSL certificate not found"
        fi
    fi
}

# Main test function
main() {
    echo "====================================="
    echo "Proxmox SSL Setup Test Script"
    echo "====================================="
    echo
    
    test_prerequisites
    test_cloudflare
    test_domain
    test_proxmox_services
    test_ssl_config
    
    echo
    log "All tests completed!"
    echo
    echo "If all tests passed, you can run the SSL setup script:"
    echo "sudo ./setup-proxmox-ssl.sh -d your-domain.com -e your-email@example.com -t your-cf-token -p $PROXMOX_TYPE"
}

# Run main function
main "$@"
