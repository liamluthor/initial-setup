# SSL Manager - Usage Examples

## Example 1: Single Domain Setup

### Scenario
You want to set up SSL for `example.com` with www redirect.

### Steps

```bash
# 1. Run setup
./sslmgr.sh --setup

# Enter domains:
Domain: example.com
Domain: www.example.com
Domain: (press enter)

# Select HTTP-01 challenge
Choice: 1

# 2. Test certificate generation
./sslmgr.sh --test

# 3. Generate actual certificates
sudo ./sslmgr.sh --renew

# 4. Generate nginx config
./sslmgr.sh --nginx

# 5. Deploy to nginx
sudo cp nginx/example.com.conf /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/example.com.conf /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# 6. Setup auto-renewal
./sslmgr.sh --cron
```

---

## Example 2: Multiple Independent Domains

### Scenario
You manage multiple unrelated domains: `example.com`, `myapp.com`, `blog.net`

### Steps

```bash
# Setup
./sslmgr.sh --setup

Domain: example.com
Domain: www.example.com
Domain: myapp.com
Domain: www.myapp.com
Domain: blog.net
Domain: www.blog.net
Domain: (press enter)

# The script will create 3 certificates:
# - example.com,www.example.com
# - myapp.com,www.myapp.com
# - blog.net,www.blog.net

# Renew all at once
sudo ./sslmgr.sh --renew

# Generate all nginx configs
./sslmgr.sh --nginx
```

---

## Example 3: Adding API Subdomain Later

### Scenario
You already have `example.com` set up, now you want to add `api.example.com`

### Steps

```bash
# Add the new domain
./sslmgr.sh --add api.example.com

# Check what's managed
./sslmgr.sh --list

# Generate certificate for new domain
sudo ./sslmgr.sh --renew

# Generate nginx config
./sslmgr.sh --nginx

# Edit the api config to proxy to your API server
nano nginx/api.example.com.conf

# Deploy
sudo cp nginx/api.example.com.conf /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/api.example.com.conf /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

---

## Example 4: Node.js/Express Application

### Scenario
You have a Node.js app running on port 5000 and want HTTPS with nginx reverse proxy.

### Steps

```bash
# 1. Setup SSL
./sslmgr.sh --setup
Domain: myapp.com
Domain: www.myapp.com
Domain: (press enter)

# 2. Generate certificate
sudo ./sslmgr.sh --renew

# 3. Generate nginx config
./sslmgr.sh --nginx

# 4. Edit the nginx config to proxy to Node.js
nano nginx/myapp.com.conf
```

Edit the location block to proxy:
```nginx
location / {
    proxy_pass http://localhost:5000;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_cache_bypass $http_upgrade;
}
```

```bash
# 5. Deploy
sudo cp nginx/myapp.com.conf /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/myapp.com.conf /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

---

## Example 5: Multiple Subdomains

### Scenario
You want SSL for: `example.com`, `www`, `api`, `admin`, `staging`

### Steps

```bash
./sslmgr.sh --setup

Domain: example.com
Domain: www.example.com
Domain: api.example.com
Domain: admin.example.com
Domain: staging.example.com
Domain: (press enter)

# This creates:
# - example.com,www.example.com (combined)
# - api.example.com (separate)
# - admin.example.com (separate)
# - staging.example.com (separate)
```

---

## Example 6: Monitoring and Maintenance

### Check Certificate Status

```bash
# Check expiration dates
./sslmgr.sh --status

# Example output:
Checking: example.com
  Valid for 75 days

Checking: api.example.com
  Expires in 25 days - RENEWAL RECOMMENDED
```

### Manual Renewal

```bash
# Renew all certificates
sudo ./sslmgr.sh --renew
```

### Backup Before Changes

```bash
# Create backup
./sslmgr.sh --backup

# Backup saved to: backups/certs_backup_20251223_120000.tar.gz
```

### View Logs

```bash
# View recent activity
tail -50 logs/sslmgr.log

# Follow logs in real-time
tail -f logs/sslmgr.log
```

---

## Example 7: Removing a Domain

### Scenario
You no longer need SSL for `old.example.com`

### Steps

```bash
# Remove from management
./sslmgr.sh --remove old.example.com

# Optionally delete the certificate
sudo certbot delete --cert-name old.example.com

# Remove nginx config
sudo rm /etc/nginx/sites-enabled/old.example.com.conf
sudo rm /etc/nginx/sites-available/old.example.com.conf
sudo systemctl reload nginx
```

---

## Example 8: Testing Setup (Recommended First Step)

### Scenario
You want to test everything before generating real certificates to avoid rate limits.

### Steps

```bash
# 1. Initial setup
./sslmgr.sh --setup

# 2. Test with Let's Encrypt staging server
./sslmgr.sh --test

# This uses staging certificates (not trusted by browsers)
# But verifies your setup is correct

# 3. If test succeeds, generate real certificates
sudo ./sslmgr.sh --renew
```

---

## Example 9: Automated Weekly Renewals

### Scenario
Set it and forget it - automatic certificate renewals.

### Steps

```bash
# Setup cron job for automatic renewal
./sslmgr.sh --cron

# Default: 3 AM every Monday
# Customize if prompted

# Verify cron job
crontab -l | grep sslmgr

# Check logs after cron runs
cat logs/sslmgr.log
```

---

## Example 10: Full Production Deployment

### Complete workflow for a production website

```bash
# 1. Initial setup
./sslmgr.sh --setup
Domain: mysite.com
Domain: www.mysite.com
Domain: (press enter)
Challenge: 1 (HTTP-01)

# 2. Test first
./sslmgr.sh --test

# 3. Generate real certificates
sudo ./sslmgr.sh --renew

# 4. Generate nginx config
./sslmgr.sh --nginx

# 5. Edit nginx config with your actual web root
nano nginx/mysite.com.conf
# Change: root /var/www/mysite.com/public;

# 6. Deploy nginx config
sudo cp nginx/mysite.com.conf /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/mysite.com.conf /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# 7. Setup automatic renewals
./sslmgr.sh --cron

# 8. Create initial backup
./sslmgr.sh --backup

# 9. Verify HTTPS is working
curl -I https://mysite.com

# 10. Monitor
./sslmgr.sh --status
```

---

## Common nginx Customizations

### Static HTML Site

```nginx
root /var/www/mysite.com/public;
index index.html;

location / {
    try_files $uri $uri/ =404;
}
```

### WordPress

```nginx
root /var/www/mysite.com/public;
index index.php index.html;

location / {
    try_files $uri $uri/ /index.php?$args;
}

location ~ \.php$ {
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
}
```

### React/Vue/Angular SPA

```nginx
root /var/www/mysite.com/dist;
index index.html;

location / {
    try_files $uri $uri/ /index.html;
}
```

### API Backend Proxy

```nginx
location /api {
    proxy_pass http://localhost:3000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

---

## Troubleshooting Examples

### Issue: Port 80 not accessible

**Symptom:**
```
Failed to renew certificate
Connection refused on port 80
```

**Solution:**
```bash
# Check if port 80 is open
sudo netstat -tlnp | grep :80

# Check firewall
sudo ufw status
sudo ufw allow 80/tcp

# For cloud providers, check security groups
```

### Issue: Webroot path incorrect

**Symptom:**
```
Failed validation, challenge returned 404
```

**Solution:**
```bash
# Ensure webroot exists and is accessible
sudo mkdir -p /var/www/html/.well-known/acme-challenge
sudo chown -R www-data:www-data /var/www/html

# Test by creating a test file
echo "test" | sudo tee /var/www/html/.well-known/acme-challenge/test.txt
curl http://yoursite.com/.well-known/acme-challenge/test.txt
```

### Issue: Rate limit hit

**Symptom:**
```
Error: too many certificates already issued
```

**Solution:**
```bash
# Use test mode to avoid rate limits
./sslmgr.sh --test

# Wait for rate limit window (usually 1 week)
# Check: https://letsencrypt.org/docs/rate-limits/
```

---

## Best Practices Summary

1. **Always test first** - Use `--test` before `--renew`
2. **Backup regularly** - Use `--backup` before major changes
3. **Monitor expiration** - Run `--status` monthly
4. **Automate renewals** - Setup cron with `--cron`
5. **Check logs** - Review `logs/sslmgr.log` after operations
6. **Secure configs** - Review generated nginx configs before deployment
7. **Test nginx** - Always run `sudo nginx -t` before reload
8. **Keep updated** - Keep certbot and the script updated

---

## Quick Reference

```bash
# Common commands
./sslmgr.sh --setup           # Initial setup
./sslmgr.sh --list            # List domains
./sslmgr.sh --status          # Check expiration
./sslmgr.sh --add DOMAIN      # Add domain
./sslmgr.sh --remove DOMAIN   # Remove domain
./sslmgr.sh --renew           # Renew certificates
./sslmgr.sh --nginx           # Generate nginx configs
./sslmgr.sh --backup          # Backup certificates
./sslmgr.sh --cron            # Setup auto-renewal
./sslmgr.sh --test            # Test with staging
./sslmgr.sh --help            # Show help
```
