# SSL Manager - Let's Encrypt Certificate Management Tool

A comprehensive Bash script for managing Let's Encrypt SSL certificates across multiple domains with automatic renewal, nginx configuration generation, and more.

## Features

- ✅ **Automatic dependency checking** - Verifies certbot and openssl are installed
- ✅ **Smart domain grouping** - Combines `example.com` and `www.example.com` into single certificates
- ✅ **Multiple challenge methods** - HTTP-01 (webroot) and DNS-01 support
- ✅ **Certificate status monitoring** - Check expiration dates and renewal needs
- ✅ **Nginx config generation** - Auto-generate secure nginx configurations
- ✅ **Backup functionality** - Easy certificate backup and restore
- ✅ **Automated renewals** - Set up cron jobs for automatic certificate renewal
- ✅ **Detailed logging** - All operations logged for audit trail
- ✅ **Test mode** - Use Let's Encrypt staging server for testing

## Installation

```bash
# Clone or download the script
cd /path/to/initial-setup/ssl-mgmt

# Make executable
chmod +x sslmgr.sh

# Check dependencies
./sslmgr.sh --help
```

### Dependencies

The script will automatically check for:
- `certbot` - Let's Encrypt client
- `openssl` - SSL toolkit

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install certbot python3-certbot-nginx openssl
```

**CentOS/RHEL:**
```bash
sudo yum install certbot python3-certbot-nginx openssl
```

## Quick Start

### 1. Initial Setup

```bash
./sslmgr.sh --setup
```

This will:
- Prompt you to enter all domains you want to manage
- Ask which challenge method to use (HTTP-01 or DNS-01)
- Analyze domains and suggest optimal certificate groupings
- Create a configuration file to track managed domains

**Example interaction:**
```
Enter the domains you want to manage (one per line, empty line to finish):
Domain: example.com
Domain: www.example.com
Domain: api.example.com
Domain:

Select challenge method:
  1) HTTP-01 (webroot) - Most common, requires port 80
  2) DNS-01 - Required for wildcards, needs DNS API access
Choice (1-2) [1]: 1

Proposed certificate groupings:
  - example.com,www.example.com
  - api.example.com

Proceed with these groupings? (Y/n): y
```

### 2. Generate Certificates

```bash
# Test first with staging server (recommended)
./sslmgr.sh --test

# Generate actual certificates
./sslmgr.sh --renew
```

### 3. Generate Nginx Configs

```bash
./sslmgr.sh --nginx
```

This creates nginx configuration files in the `nginx/` directory. You'll need to:
1. Edit the `root` directive to point to your actual web root
2. Copy configs to `/etc/nginx/sites-available/`
3. Create symlinks in `/etc/nginx/sites-enabled/`
4. Test and reload nginx

### 4. Set Up Automatic Renewal

```bash
./sslmgr.sh --cron
```

This adds a cron job to automatically renew certificates (default: 3 AM every Monday).

## Usage

### Available Commands

```bash
./sslmgr.sh --setup              # Interactive setup
./sslmgr.sh --list               # List all managed domains
./sslmgr.sh --status             # Check certificate expiration status
./sslmgr.sh --renew              # Renew all certificates
./sslmgr.sh --test               # Test renewal with staging server
./sslmgr.sh --add <domain>       # Add new domain
./sslmgr.sh --remove <domain>    # Remove domain
./sslmgr.sh --nginx              # Generate nginx configs
./sslmgr.sh --backup             # Backup all certificates
./sslmgr.sh --cron               # Setup auto-renewal cron job
./sslmgr.sh --help               # Show help
```

### Common Workflows

#### Add a New Domain

```bash
./sslmgr.sh --add blog.example.com
./sslmgr.sh --renew
./sslmgr.sh --nginx
```

#### Check Certificate Status

```bash
./sslmgr.sh --status
```

Output:
```
Checking: example.com
  Valid for 75 days

Checking: api.example.com
  Expires in 25 days - RENEWAL RECOMMENDED
```

#### Manual Renewal

```bash
./sslmgr.sh --renew
```

#### Backup Before Changes

```bash
./sslmgr.sh --backup
```

## Configuration Files

### Directory Structure

```
ssl-mgmt/
├── sslmgr.sh                 # Main script
├── config/
│   ├── domains.conf          # Managed domains
│   └── templates/            # Config templates
├── logs/
│   └── sslmgr.log           # Operation log
├── backups/                  # Certificate backups
└── nginx/                    # Generated nginx configs
```

### domains.conf Format

```
# Format: domains|challenge_method|cert_path|expiry_date|last_renewed|status
example.com,www.example.com|http-01|/etc/letsencrypt/live/example.com|2025-03-15|2025-01-10|active
api.example.com|http-01|/etc/letsencrypt/live/api.example.com|2025-03-20|2025-01-15|active
```

## Generated Nginx Configuration

The `--nginx` command generates secure nginx configurations with:

- **Automatic HTTP to HTTPS redirect**
- **Modern SSL/TLS settings** (TLS 1.2/1.3 only)
- **Security headers** (HSTS, X-Frame-Options, etc.)
- **Let's Encrypt challenge location** (for renewals)
- **Logging configuration**
- **PHP support** (commented out, uncomment if needed)

### Example Generated Config

```nginx
# HTTP - Redirect to HTTPS
server {
    listen 80;
    server_name example.com www.example.com;

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS
server {
    listen 443 ssl http2;
    server_name example.com www.example.com;

    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;

    # SSL Security Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:...';

    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000" always;

    root /var/www/example.com/public;
    index index.html;

    # ... more config
}
```

## Challenge Methods

### HTTP-01 (Webroot)

**Best for:**
- Most common use case
- Standard domain validation
- Multiple domains on one certificate

**Requirements:**
- Port 80 must be accessible from internet
- Web server must serve files from webroot

**Usage:**
```bash
# During setup, select option 1
Select challenge method:
  1) HTTP-01 (webroot) - Most common, requires port 80
Choice: 1
```

### DNS-01

**Best for:**
- Wildcard certificates (*.example.com)
- Internal servers (no public port 80)
- Multiple subdomains

**Requirements:**
- DNS provider API access
- DNS plugin for certbot
- Additional configuration

**Note:** DNS-01 implementation requires additional setup with your DNS provider's certbot plugin.

## Troubleshooting

### Certificates Not Renewing

1. Check logs: `tail -f logs/sslmgr.log`
2. Verify port 80 is accessible
3. Test with staging: `./sslmgr.sh --test`
4. Check webroot path is correct

### "Missing Dependencies" Error

Install certbot:
```bash
# Ubuntu/Debian
sudo apt-get install certbot python3-certbot-nginx

# CentOS/RHEL
sudo yum install certbot python3-certbot-nginx
```

### Rate Limiting Issues

Let's Encrypt has rate limits:
- 50 certificates per registered domain per week
- 5 duplicate certificates per week

**Solution:** Use `--test` mode first to verify everything works.

### Permission Denied Errors

Certbot typically requires root/sudo access:
```bash
sudo ./sslmgr.sh --renew
```

## Security Considerations

1. **File Permissions:**
   - Configuration files: `600` or `644`
   - Private keys: `600` (managed by certbot)
   - Log files: `640`

2. **Backup Security:**
   - Certificate backups contain private keys
   - Store backups securely
   - Encrypt backups for long-term storage

3. **Cron Jobs:**
   - Renewal cron runs with user permissions
   - May need sudo configuration for certbot

4. **Nginx Configuration:**
   - Review generated configs before deployment
   - Adjust security headers for your needs
   - Test thoroughly: `sudo nginx -t`

## Best Practices

1. **Always test first:** Use `--test` before `--renew`
2. **Monitor expiration:** Run `--status` regularly
3. **Backup before changes:** Use `--backup` before major changes
4. **Review logs:** Check `logs/sslmgr.log` for issues
5. **Separate environments:** Use different configs for staging/production
6. **Automate renewals:** Set up cron job with `--cron`

## Advanced Usage

### Custom Webroot Path

Edit the generated command in the script or manually run:
```bash
certbot certonly --webroot --webroot-path /custom/path -d example.com
```

### Multiple Web Roots

For different domains with different webroots, you'll need to:
1. Generate certificates separately
2. Manually specify webroot paths

### Wildcard Certificates

Requires DNS-01 challenge:
```bash
# Manual DNS challenge (example)
certbot certonly --manual --preferred-challenges dns -d "*.example.com" -d example.com
```

## Logging

All operations are logged to `logs/sslmgr.log`:

```
[2025-12-23 12:00:00] [INFO] Starting domain setup...
[2025-12-23 12:00:15] [SUCCESS] Domain configuration created
[2025-12-23 12:05:00] [INFO] Starting certificate renewal process...
[2025-12-23 12:05:30] [SUCCESS] Certificate renewed successfully
```

## Roadmap / TODO

- [ ] Implement `--verify` command to check HTTPS accessibility
- [ ] Add `--apache` support for Apache virtual hosts
- [ ] DNS-01 challenge with common DNS provider plugins
- [ ] Email notifications for expiring certificates
- [ ] Restore from backup functionality
- [ ] Certificate rotation (complete key regeneration)
- [ ] Support for other ACME providers besides Let's Encrypt
- [ ] Web dashboard for monitoring

## License

This tool is provided as-is for educational and administrative purposes.

## Support

For issues, questions, or contributions, contact the Strayer Raptors team.

---

**Created by:** Strayer Raptors Cybersecurity Team
**Last Updated:** December 23, 2025
