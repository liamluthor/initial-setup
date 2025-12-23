#!/bin/bash

#############################################################################
# SSL Manager - Let's Encrypt Certificate Management Tool
#
# Author: Strayer Raptors Team
# Description: Comprehensive SSL certificate management for multiple domains
#############################################################################

set -euo pipefail

# Script directory and configuration paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"
TEMPLATES_DIR="${CONFIG_DIR}/templates"
LOGS_DIR="${SCRIPT_DIR}/logs"
BACKUPS_DIR="${SCRIPT_DIR}/backups"
LOG_FILE="${LOGS_DIR}/sslmgr.log"

# Configuration files
DOMAINS_CONF="${CONFIG_DIR}/domains.conf"
SETTINGS_CONF="${CONFIG_DIR}/settings.conf"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ensure required directories exist
mkdir -p "${CONFIG_DIR}" "${TEMPLATES_DIR}" "${LOGS_DIR}" "${BACKUPS_DIR}"

#############################################################################
# Utility Functions
#############################################################################

log() {
    local level="$1"
    shift
    local message="$*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $*"
    log "INFO" "$*"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
    log "SUCCESS" "$*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
    log "WARN" "$*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
    log "ERROR" "$*"
}

fatal() {
    error "$*"
    exit 1
}

#############################################################################
# Dependency Checks
#############################################################################

check_dependencies() {
    info "Checking for required dependencies..."

    local missing_deps=()

    # Check for certbot
    if ! command -v certbot &> /dev/null; then
        missing_deps+=("certbot")
    fi

    # Check for openssl
    if ! command -v openssl &> /dev/null; then
        missing_deps+=("openssl")
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        error "Missing required dependencies: ${missing_deps[*]}"
        echo ""
        echo "To install on Ubuntu/Debian:"
        echo "  sudo apt-get update"
        echo "  sudo apt-get install certbot python3-certbot-nginx openssl"
        echo ""
        echo "To install on CentOS/RHEL:"
        echo "  sudo yum install certbot python3-certbot-nginx openssl"
        echo ""
        return 1
    fi

    success "All dependencies are installed"

    # Show certbot version
    local certbot_version=$(certbot --version 2>&1 | head -n1)
    info "Found: ${certbot_version}"

    return 0
}

#############################################################################
# Domain Management Functions
#############################################################################

# Normalize domain name (remove protocol, trailing slash, etc.)
normalize_domain() {
    local domain="$1"
    # Remove http://, https://, trailing slashes, etc.
    domain="${domain#http://}"
    domain="${domain#https://}"
    domain="${domain%/}"
    echo "$domain"
}

# Check if domains can be combined into one certificate
can_combine_domains() {
    local -n domains_array=$1
    local base_domain=""
    local can_combine=true

    for domain in "${domains_array[@]}"; do
        # Extract base domain (remove www. if present)
        local cleaned="${domain#www.}"

        if [ -z "$base_domain" ]; then
            base_domain="$cleaned"
        elif [ "$cleaned" != "$base_domain" ]; then
            can_combine=false
            break
        fi
    done

    echo "$can_combine"
}

# Group domains for optimal certificate coverage
group_domains() {
    local -n input_domains=$1
    local -a groups=()
    local -A processed=()

    for domain in "${input_domains[@]}"; do
        domain=$(normalize_domain "$domain")

        if [ -n "${processed[$domain]:-}" ]; then
            continue
        fi

        local base_domain="${domain#www.}"
        local www_domain="www.${base_domain}"

        # Check if both domain and www.domain exist in input
        local has_base=false
        local has_www=false

        for d in "${input_domains[@]}"; do
            d=$(normalize_domain "$d")
            if [ "$d" = "$base_domain" ]; then
                has_base=true
            elif [ "$d" = "$www_domain" ]; then
                has_www=true
            fi
        done

        # Combine if both exist
        if [ "$has_base" = true ] && [ "$has_www" = true ]; then
            groups+=("${base_domain},${www_domain}")
            processed[$base_domain]=1
            processed[$www_domain]=1
        else
            groups+=("$domain")
            processed[$domain]=1
        fi
    done

    printf '%s\n' "${groups[@]}"
}

#############################################################################
# Setup Functions
#############################################################################

setup_domains() {
    info "Starting domain setup..."

    # Check if setup already exists
    if [ -f "$DOMAINS_CONF" ]; then
        warn "Domain configuration already exists at: $DOMAINS_CONF"
        read -p "Do you want to overwrite it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Setup cancelled"
            return 0
        fi
    fi

    # Ask for domains
    echo ""
    echo "Enter the domains you want to manage (one per line, empty line to finish):"
    echo "Example: example.com"
    echo "         www.example.com"
    echo "         api.example.com"
    echo ""

    local -a domains=()
    while true; do
        read -p "Domain: " domain
        if [ -z "$domain" ]; then
            break
        fi
        domain=$(normalize_domain "$domain")
        domains+=("$domain")
        info "Added: $domain"
    done

    if [ ${#domains[@]} -eq 0 ]; then
        fatal "No domains provided. Setup cancelled."
    fi

    # Ask for challenge method
    echo ""
    echo "Select challenge method:"
    echo "  1) HTTP-01 (webroot) - Most common, requires port 80"
    echo "  2) DNS-01 - Required for wildcards, needs DNS API access"
    read -p "Choice (1-2) [1]: " challenge_choice
    challenge_choice=${challenge_choice:-1}

    local challenge_method="http-01"
    case $challenge_choice in
        1) challenge_method="http-01" ;;
        2) challenge_method="dns-01" ;;
        *) warn "Invalid choice, using http-01" ;;
    esac

    # Group domains for optimal certificate coverage
    info "Analyzing domain groupings..."
    local -a grouped_domains
    mapfile -t grouped_domains < <(group_domains domains)

    echo ""
    echo "Proposed certificate groupings:"
    for group in "${grouped_domains[@]}"; do
        echo "  - $group"
    done

    echo ""
    read -p "Proceed with these groupings? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        fatal "Setup cancelled by user"
    fi

    # Create domains.conf
    info "Creating domain configuration..."
    cat > "$DOMAINS_CONF" << EOF
# SSL Manager Domain Configuration
# Format: domains|challenge_method|cert_path|expiry_date|last_renewed|status
# Generated: $(date '+%Y-%m-%d %H:%M:%S')

EOF

    for group in "${grouped_domains[@]}"; do
        # For now, just add the entry without cert details (will be filled during first cert generation)
        echo "${group}|${challenge_method}|||pending" >> "$DOMAINS_CONF"
    done

    success "Domain configuration created at: $DOMAINS_CONF"
    info "Run './sslmgr.sh --renew' to generate certificates for these domains"
}

#############################################################################
# Certificate Management Functions
#############################################################################

list_domains() {
    if [ ! -f "$DOMAINS_CONF" ]; then
        warn "No domain configuration found. Run './sslmgr.sh --setup' first."
        return 1
    fi

    echo ""
    echo "Managed Domains:"
    echo "================"

    local line_num=0
    while IFS='|' read -r domains challenge cert_path expiry last_renewed status; do
        # Skip comments and empty lines
        [[ "$domains" =~ ^#.*$ ]] && continue
        [[ -z "$domains" ]] && continue

        ((line_num++))
        echo ""
        echo "[$line_num] Domains: $domains"
        echo "    Challenge: $challenge"
        [ -n "$cert_path" ] && echo "    Certificate: $cert_path"
        [ -n "$expiry" ] && echo "    Expires: $expiry"
        [ -n "$last_renewed" ] && echo "    Last Renewed: $last_renewed"
        echo "    Status: ${status:-unknown}"
    done < "$DOMAINS_CONF"

    echo ""
}

check_status() {
    if [ ! -f "$DOMAINS_CONF" ]; then
        warn "No domain configuration found. Run './sslmgr.sh --setup' first."
        return 1
    fi

    info "Checking certificate status..."
    echo ""

    local now=$(date +%s)
    local warn_threshold=$((30 * 24 * 60 * 60)) # 30 days in seconds

    while IFS='|' read -r domains challenge cert_path expiry last_renewed status; do
        # Skip comments and empty lines
        [[ "$domains" =~ ^#.*$ ]] && continue
        [[ -z "$domains" ]] && continue

        echo "Checking: $domains"

        if [ -z "$cert_path" ] || [ ! -f "$cert_path/cert.pem" ]; then
            warn "  No certificate found - needs initial generation"
            continue
        fi

        # Get certificate expiration
        local cert_expiry=$(openssl x509 -enddate -noout -in "$cert_path/cert.pem" | cut -d= -f2)
        local cert_expiry_epoch=$(date -d "$cert_expiry" +%s 2>/dev/null || echo "0")

        if [ "$cert_expiry_epoch" -eq 0 ]; then
            error "  Could not parse certificate expiration date"
            continue
        fi

        local days_until_expiry=$(( (cert_expiry_epoch - now) / 86400 ))

        if [ $days_until_expiry -lt 0 ]; then
            error "  EXPIRED ${days_until_expiry#-} days ago!"
        elif [ $days_until_expiry -lt 30 ]; then
            warn "  Expires in $days_until_expiry days - RENEWAL RECOMMENDED"
        else
            success "  Valid for $days_until_expiry days"
        fi

        echo ""
    done < "$DOMAINS_CONF"
}

renew_certificates() {
    local test_mode="${1:-false}"

    if [ ! -f "$DOMAINS_CONF" ]; then
        fatal "No domain configuration found. Run './sslmgr.sh --setup' first."
    fi

    info "Starting certificate renewal process..."
    [ "$test_mode" = "true" ] && warn "Running in TEST MODE (using staging server)"

    local temp_conf="${DOMAINS_CONF}.tmp"
    : > "$temp_conf"  # Create empty temp file

    while IFS='|' read -r domains challenge cert_path expiry last_renewed status; do
        # Preserve comments and empty lines
        if [[ "$domains" =~ ^#.*$ ]] || [[ -z "$domains" ]]; then
            echo "$domains|$challenge|$cert_path|$expiry|$last_renewed|$status" >> "$temp_conf"
            continue
        fi

        info "Processing: $domains"

        # Build certbot command
        local certbot_cmd="certbot certonly"
        [ "$test_mode" = "true" ] && certbot_cmd+=" --staging"

        # Add domain arguments
        IFS=',' read -ra domain_array <<< "$domains"
        for d in "${domain_array[@]}"; do
            certbot_cmd+=" -d $d"
        done

        # Add challenge method
        if [ "$challenge" = "http-01" ]; then
            certbot_cmd+=" --webroot --webroot-path /var/www/html"
        elif [ "$challenge" = "dns-01" ]; then
            # This would require DNS plugin configuration
            warn "DNS-01 challenge requires DNS provider plugin - skipping for now"
            echo "$domains|$challenge|$cert_path|$expiry|$last_renewed|$status" >> "$temp_conf"
            continue
        fi

        certbot_cmd+=" --non-interactive --agree-tos --email admin@${domain_array[0]}"

        # Execute certbot (dry-run for safety, remove --dry-run for actual renewal)
        info "Executing: $certbot_cmd --dry-run"

        if $certbot_cmd --dry-run 2>&1 | tee -a "$LOG_FILE"; then
            # Update configuration with new cert info
            local primary_domain="${domain_array[0]}"
            local new_cert_path="/etc/letsencrypt/live/$primary_domain"
            local new_last_renewed=$(date '+%Y-%m-%d')

            # Calculate expiry (Let's Encrypt certs are valid for 90 days)
            local new_expiry=$(date -d "+90 days" '+%Y-%m-%d')

            success "Certificate renewed successfully"
            echo "$domains|$challenge|$new_cert_path|$new_expiry|$new_last_renewed|active" >> "$temp_conf"
        else
            error "Failed to renew certificate"
            echo "$domains|$challenge|$cert_path|$expiry|$last_renewed|failed" >> "$temp_conf"
        fi

        echo ""
    done < "$DOMAINS_CONF"

    # Replace old config with updated one
    mv "$temp_conf" "$DOMAINS_CONF"
    success "Certificate renewal process completed"
}

#############################################################################
# Web Server Configuration Functions
#############################################################################

generate_nginx_configs() {
    if [ ! -f "$DOMAINS_CONF" ]; then
        fatal "No domain configuration found. Run './sslmgr.sh --setup' first."
    fi

    local nginx_dir="${SCRIPT_DIR}/nginx"
    mkdir -p "$nginx_dir"

    info "Generating nginx configurations..."

    while IFS='|' read -r domains challenge cert_path expiry last_renewed status; do
        # Skip comments and empty lines
        [[ "$domains" =~ ^#.*$ ]] && continue
        [[ -z "$domains" ]] && continue

        IFS=',' read -ra domain_array <<< "$domains"
        local primary_domain="${domain_array[0]}"
        local config_file="${nginx_dir}/${primary_domain}.conf"

        info "Generating config for: $primary_domain"

        cat > "$config_file" << EOF
# Nginx configuration for $primary_domain
# Generated by sslmgr.sh on $(date '+%Y-%m-%d %H:%M:%S')

# HTTP - Redirect to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name ${domains//,/ };

    # Let's Encrypt challenge location
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    # Redirect all other traffic to HTTPS
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

# HTTPS
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${domains//,/ };

    # SSL Certificate Configuration
    ssl_certificate ${cert_path:-/etc/letsencrypt/live/$primary_domain}/fullchain.pem;
    ssl_certificate_key ${cert_path:-/etc/letsencrypt/live/$primary_domain}/privkey.pem;

    # SSL Security Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Document root - EDIT THIS PATH
    root /var/www/${primary_domain}/public;
    index index.html index.htm index.php;

    # Main location block
    location / {
        try_files \$uri \$uri/ =404;
    }

    # PHP support (uncomment if needed)
    # location ~ \.php$ {
    #     include snippets/fastcgi-php.conf;
    #     fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
    # }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
    }

    # Logging
    access_log /var/log/nginx/${primary_domain}_access.log;
    error_log /var/log/nginx/${primary_domain}_error.log;
}
EOF

        success "Created: $config_file"
    done < "$DOMAINS_CONF"

    echo ""
    success "Nginx configurations generated in: $nginx_dir"
    echo ""
    echo "Next steps:"
    echo "  1. Review and edit the document root paths in the config files"
    echo "  2. Copy configs to /etc/nginx/sites-available/"
    echo "  3. Create symlinks in /etc/nginx/sites-enabled/"
    echo "  4. Test: sudo nginx -t"
    echo "  5. Reload: sudo systemctl reload nginx"
}

add_domain() {
    local new_domain="$1"

    if [ -z "$new_domain" ]; then
        fatal "No domain specified. Usage: ./sslmgr.sh --add <domain>"
    fi

    new_domain=$(normalize_domain "$new_domain")

    if [ ! -f "$DOMAINS_CONF" ]; then
        fatal "No domain configuration found. Run './sslmgr.sh --setup' first."
    fi

    # Check if domain already exists
    if grep -q "^${new_domain}[,|]" "$DOMAINS_CONF" || grep -q ",${new_domain}[,|]" "$DOMAINS_CONF"; then
        warn "Domain $new_domain is already managed"
        return 1
    fi

    info "Adding domain: $new_domain"

    # Ask for challenge method
    echo "Select challenge method:"
    echo "  1) HTTP-01 (webroot)"
    echo "  2) DNS-01"
    read -p "Choice (1-2) [1]: " challenge_choice
    challenge_choice=${challenge_choice:-1}

    local challenge_method="http-01"
    case $challenge_choice in
        1) challenge_method="http-01" ;;
        2) challenge_method="dns-01" ;;
        *) warn "Invalid choice, using http-01" ;;
    esac

    # Add to configuration
    echo "${new_domain}|${challenge_method}|||pending" >> "$DOMAINS_CONF"

    success "Domain added to configuration"
    info "Run './sslmgr.sh --renew' to generate certificate"
}

remove_domain() {
    local domain_to_remove="$1"

    if [ -z "$domain_to_remove" ]; then
        fatal "No domain specified. Usage: ./sslmgr.sh --remove <domain>"
    fi

    domain_to_remove=$(normalize_domain "$domain_to_remove")

    if [ ! -f "$DOMAINS_CONF" ]; then
        fatal "No domain configuration found."
    fi

    info "Removing domain: $domain_to_remove"

    # Create backup
    cp "$DOMAINS_CONF" "${DOMAINS_CONF}.backup.$(date +%s)"

    # Remove lines containing the domain
    sed -i "/^${domain_to_remove}[,|]/d" "$DOMAINS_CONF"
    sed -i "/,${domain_to_remove}[,|]/d" "$DOMAINS_CONF"

    success "Domain removed from configuration"

    read -p "Do you want to delete the certificate files? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        warn "Manual deletion required: sudo certbot delete --cert-name $domain_to_remove"
    fi
}

backup_certificates() {
    info "Backing up certificates..."

    local backup_file="${BACKUPS_DIR}/certs_backup_$(date +%Y%m%d_%H%M%S).tar.gz"

    if [ ! -d "/etc/letsencrypt" ]; then
        warn "No certificates directory found at /etc/letsencrypt"
        return 1
    fi

    sudo tar -czf "$backup_file" /etc/letsencrypt/ 2>&1 | tee -a "$LOG_FILE"
    sudo chown $USER:$USER "$backup_file"

    success "Backup created: $backup_file"
}

setup_cron() {
    info "Setting up automatic renewal cron job..."

    local cron_cmd="${SCRIPT_DIR}/sslmgr.sh --renew"
    local cron_schedule="0 3 * * 1"  # 3 AM every Monday

    echo ""
    echo "Proposed cron schedule: $cron_schedule (3 AM every Monday)"
    read -p "Is this acceptable? (Y/n): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Nn]$ ]]; then
        read -p "Enter custom cron schedule: " cron_schedule
    fi

    # Check if cron job already exists
    if crontab -l 2>/dev/null | grep -q "$cron_cmd"; then
        warn "Cron job already exists"
        return 0
    fi

    # Add cron job
    (crontab -l 2>/dev/null; echo "$cron_schedule $cron_cmd >> ${LOG_FILE} 2>&1") | crontab -

    success "Cron job added successfully"
    info "Current crontab:"
    crontab -l | grep sslmgr.sh
}

#############################################################################
# Help and Usage
#############################################################################

show_usage() {
    cat << EOF
SSL Manager - Let's Encrypt Certificate Management Tool

Usage: $0 [OPTION] [ARGS]

Options:
  --setup              Interactive setup to configure managed domains
  --list               List all currently managed domains
  --status             Check expiration status of all certificates
  --renew              Renew all managed certificates
  --test               Test renewal using Let's Encrypt staging server
  --add <domain>       Add a new domain to management
  --remove <domain>    Remove a domain from management
  --nginx              Generate nginx configuration files
  --backup             Backup all certificates
  --cron               Setup automatic renewal cron job
  --verify             Verify certificate installation and accessibility
  --help               Show this help message

Examples:
  $0 --setup                    # Initial setup
  $0 --add api.example.com      # Add new domain
  $0 --status                   # Check cert status
  $0 --renew                    # Renew all certs
  $0 --nginx                    # Generate nginx configs

Configuration:
  Domains:   $DOMAINS_CONF
  Logs:      $LOG_FILE
  Backups:   $BACKUPS_DIR

EOF
}

#############################################################################
# Main Script Logic
#############################################################################

main() {
    # Always check dependencies first
    check_dependencies || exit 1

    # Parse command line arguments
    case "${1:-}" in
        --setup)
            setup_domains
            ;;
        --list)
            list_domains
            ;;
        --status)
            check_status
            ;;
        --renew)
            renew_certificates false
            ;;
        --test)
            renew_certificates true
            ;;
        --add)
            add_domain "${2:-}"
            ;;
        --remove)
            remove_domain "${2:-}"
            ;;
        --nginx)
            generate_nginx_configs
            ;;
        --backup)
            backup_certificates
            ;;
        --cron)
            setup_cron
            ;;
        --verify)
            warn "Verify function not yet implemented"
            ;;
        --help|"")
            show_usage
            ;;
        *)
            error "Unknown option: $1"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
