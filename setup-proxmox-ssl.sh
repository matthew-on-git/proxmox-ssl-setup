#!/bin/bash

# Proxmox SSL Certificate Setup Script
# Uses Proxmox's built-in ACME functionality with Cloudflare DNS-01 challenge

set -euo pipefail

# Default values
DOMAIN=""
EMAIL=""
CF_TOKEN=""
PROXMOX_TYPE=""
PROXMOX_API_URL=""
PROXMOX_API_TOKEN=""

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
    -a, --api-url URL          Proxmox API URL (default: https://localhost:8006)
    -k, --api-token TOKEN      Proxmox API token (if not provided, will use local auth)
    -h, --help                 Show this help message and exit

EXAMPLES:
    # For Proxmox VE installation (local)
    $0 -d proxmox.example.com -e admin@example.com -t your_cf_token -p ve

    # For Proxmox Backup Server installation (remote)
    $0 -d pbs.example.com -e admin@example.com -t your_cf_token -p pbs -a https://proxmox.example.com:8006 -k user@pam!tokenid=secret

ENVIRONMENT VARIABLES:
    This script requires the following to be set or provided as arguments:
    - DOMAIN: Your Proxmox domain name
    - EMAIL: Email for Let's Encrypt certificate registration
    - CF_TOKEN: Cloudflare API token with Zone:Read and DNS:Edit permissions
    - PROXMOX_TYPE: Either 've' (Proxmox VE) or 'pbs' (Proxmox Backup Server)
    - PROXMOX_API_URL: Proxmox API URL (optional, defaults to localhost)
    - PROXMOX_API_TOKEN: Proxmox API token (optional, uses local auth if not provided)

PREREQUISITES:
    - Must be run as root (for local Proxmox) or have API access
    - Proxmox must be installed and running
    - Domain must point to this server's IP address
    - Cloudflare API token with appropriate permissions
    - curl and jq must be installed

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
            -a|--api-url)
                PROXMOX_API_URL="$2"
                shift 2
                ;;
            -k|--api-token)
                PROXMOX_API_TOKEN="$2"
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

    # Set default API URL if not provided
    if [[ -z "$PROXMOX_API_URL" ]]; then
        PROXMOX_API_URL="https://localhost:8006"
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
    
    # Check if running as root (for local Proxmox) or have API access
    if [[ -z "$PROXMOX_API_TOKEN" && $EUID -ne 0 ]]; then
        error "This script must be run as root for local Proxmox or provide API token for remote access"
    fi
    
    # Check required tools
    if ! command -v curl &> /dev/null; then
        error "curl is required but not installed"
    fi
    
    if ! command -v jq &> /dev/null; then
        error "jq is required but not installed"
    fi
    
    # Check if Proxmox is accessible
    if ! check_proxmox_connection; then
        error "Cannot connect to Proxmox API at $PROXMOX_API_URL"
    fi
    
    log "Prerequisites check passed"
}

# Check Proxmox connection
check_proxmox_connection() {
    local response
    if [[ -n "$PROXMOX_API_TOKEN" ]]; then
        response=$(curl -s -k -H "Authorization: PVEAPIToken=${PROXMOX_API_TOKEN}" "${PROXMOX_API_URL}/api2/json/version" 2>/dev/null)
    else
        response=$(curl -s -k "${PROXMOX_API_URL}/api2/json/version" 2>/dev/null)
    fi
    
    if echo "$response" | jq -e '.data' > /dev/null 2>&1; then
        local version=$(echo "$response" | jq -r '.data.version')
        log "Connected to Proxmox version: $version"
        return 0
    else
        return 1
    fi
}

# Register ACME account
register_acme_account() {
    log "Registering ACME account..."
    
    local response
    if [[ -n "$PROXMOX_API_TOKEN" ]]; then
        response=$(curl -s -k -X POST "${PROXMOX_API_URL}/api2/json/cluster/acme/accounts" \
            -H "Authorization: PVEAPIToken=${PROXMOX_API_TOKEN}" \
            -d "name=letsencrypt" \
            -d "email=${EMAIL}" \
            -d "directory=https://acme-v02.api.letsencrypt.org/directory")
    else
        response=$(curl -s -k -X POST "${PROXMOX_API_URL}/api2/json/cluster/acme/accounts" \
            -d "name=letsencrypt" \
            -d "email=${EMAIL}" \
            -d "directory=https://acme-v02.api.letsencrypt.org/directory")
    fi
    
    if echo "$response" | jq -e '.data == null' > /dev/null 2>&1; then
        log "ACME account registered successfully"
    else
        local error_msg=$(echo "$response" | jq -r '.errors[0].message // "Unknown error"' 2>/dev/null || echo "Failed to parse response")
        if [[ "$error_msg" == "null" || "$error_msg" == "Unknown error" ]]; then
            log "ACME account may already exist or was registered successfully"
        else
            error "Failed to register ACME account: $error_msg"
        fi
    fi
}

# Configure Cloudflare DNS challenge plugin
configure_cloudflare_plugin() {
    log "Configuring Cloudflare DNS challenge plugin..."
    
    local response
    if [[ -n "$PROXMOX_API_TOKEN" ]]; then
        response=$(curl -s -k -X POST "${PROXMOX_API_URL}/api2/json/cluster/acme/plugins" \
            -H "Authorization: PVEAPIToken=${PROXMOX_API_TOKEN}" \
            -d "id=cloudflare" \
            -d "type=dns" \
            -d "api=cloudflare" \
            -d "data=api_token=${CF_TOKEN}")
    else
        response=$(curl -s -k -X POST "${PROXMOX_API_URL}/api2/json/cluster/acme/plugins" \
            -d "id=cloudflare" \
            -d "type=dns" \
            -d "api=cloudflare" \
            -d "data=api_token=${CF_TOKEN}")
    fi
    
    if echo "$response" | jq -e '.data == null' > /dev/null 2>&1; then
        log "Cloudflare plugin configured successfully"
    else
        local error_msg=$(echo "$response" | jq -r '.errors[0].message // "Unknown error"' 2>/dev/null || echo "Failed to parse response")
        if [[ "$error_msg" == "null" || "$error_msg" == "Unknown error" ]]; then
            log "Cloudflare plugin may already exist or was configured successfully"
        else
            error "Failed to configure Cloudflare plugin: $error_msg"
        fi
    fi
}

# Order certificate
order_certificate() {
    log "Ordering certificate for $DOMAIN..."
    
    local response
    if [[ -n "$PROXMOX_API_TOKEN" ]]; then
        response=$(curl -s -k -X POST "${PROXMOX_API_URL}/api2/json/nodes/proxmox/certificates/acme" \
            -H "Authorization: PVEAPIToken=${PROXMOX_API_TOKEN}" \
            -d "name=letsencrypt" \
            -d "domain=${DOMAIN}" \
            -d "plugin=cloudflare")
    else
        response=$(curl -s -k -X POST "${PROXMOX_API_URL}/api2/json/nodes/proxmox/certificates/acme" \
            -d "name=letsencrypt" \
            -d "domain=${DOMAIN}" \
            -d "plugin=cloudflare")
    fi
    
    if echo "$response" | jq -e '.data == null' > /dev/null 2>&1; then
        log "Certificate order initiated successfully"
    else
        local error_msg=$(echo "$response" | jq -r '.errors[0].message // "Unknown error"' 2>/dev/null || echo "Failed to parse response")
        error "Failed to order certificate: $error_msg"
    fi
}

# Check certificate status
check_certificate_status() {
    log "Checking certificate status..."
    
    local response
    if [[ -n "$PROXMOX_API_TOKEN" ]]; then
        response=$(curl -s -k -X GET "${PROXMOX_API_URL}/api2/json/nodes/proxmox/certificates/acme" \
            -H "Authorization: PVEAPIToken=${PROXMOX_API_TOKEN}")
    else
        response=$(curl -s -k -X GET "${PROXMOX_API_URL}/api2/json/nodes/proxmox/certificates/acme")
    fi
    
    if echo "$response" | jq -e '.data[] | select(.domain == "'"$DOMAIN"'")' > /dev/null 2>&1; then
        local cert_info=$(echo "$response" | jq -r '.data[] | select(.domain == "'"$DOMAIN"'")')
        local status=$(echo "$cert_info" | jq -r '.status // "unknown"')
        local fingerprint=$(echo "$cert_info" | jq -r '.fingerprint // "unknown"')
        
        log "Certificate found for $DOMAIN"
        log "Status: $status"
        log "Fingerprint: $fingerprint"
        
        if [[ "$status" == "valid" ]]; then
            log "Certificate is valid and ready to use"
            return 0
        else
            warn "Certificate status is: $status"
            return 1
        fi
    else
        warn "No certificate found for $DOMAIN"
        return 1
    fi
}

# Verify certificate
verify_certificate() {
    log "Verifying certificate installation..."
    
    # Wait for certificate processing
    log "Waiting for certificate to be processed..."
    sleep 30
    
    # Check certificate status
    if check_certificate_status; then
        log "Certificate verification successful!"
        
        # Check HTTPS connectivity
        local port
        if [[ "$PROXMOX_TYPE" == "ve" ]]; then
            port="8006"
        else
            port="8007"
        fi
        
        if curl -ksI "https://${DOMAIN}:${port}" | grep -q "200 OK\|302 Found"; then
            log "Proxmox HTTPS is working on port ${port}!"
        else
            warn "HTTPS check failed. Proxmox might still be starting up."
        fi
        
        # Show certificate info
        log "Certificate details:"
        openssl s_client -connect "${DOMAIN}:${port}" -servername "${DOMAIN}" < /dev/null 2>/dev/null | \
            openssl x509 -noout -subject -issuer -dates 2>/dev/null || warn "Could not retrieve certificate details"
    else
        error "Certificate verification failed"
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
API URL: $PROXMOX_API_URL
====================================

This script will:
1. Connect to Proxmox API
2. Register ACME account with Let's Encrypt
3. Configure Cloudflare DNS challenge plugin
4. Order SSL certificate via Proxmox's built-in ACME
5. Verify certificate installation

EOF

    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    
    check_prerequisites
    register_acme_account
    configure_cloudflare_plugin
    order_certificate
    verify_certificate
    
    cat << EOF

${GREEN}✅ SSL Certificate Setup Complete!${NC}

Your Proxmox instance is now accessible at:
https://${DOMAIN}:$(if [[ "$PROXMOX_TYPE" == "ve" ]]; then echo "8006"; else echo "8007"; fi)

Certificate will auto-renew via Proxmox's built-in ACME functionality.

To check certificate status via API:
curl -k "${PROXMOX_API_URL}/api2/json/nodes/proxmox/certificates/acme"

To manage certificates via Proxmox GUI:
Datacenter → ACME → Accounts
System → Certificates

${YELLOW}Note: DNS must point to this server's IP for the certificate to work externally.${NC}

EOF
}

# Run main function
main "$@"
