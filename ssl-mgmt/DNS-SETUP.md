# DNS-01 Challenge Setup Guide

## Overview

DNS-01 challenge validation is required for:
- **Wildcard certificates** (e.g., `*.example.com`)
- **Servers without public port 80** access
- **Internal/private networks**

## Automatic DNS Plugin Detection

The sslmgr.sh script now automatically detects installed DNS provider plugins:
- Cloudflare
- Route53 (AWS)
- DigitalOcean
- Google Cloud DNS

When you choose DNS-01 during setup, the script will:
1. Check if a DNS plugin is installed
2. Use it automatically if found
3. Provide setup instructions if not found
4. Mark domains as `dns-manual-required` for manual renewal

## Quick Setup

### Using the DNS Setup Assistant

```bash
./sslmgr.sh --dns-setup
```

This interactive tool guides you through:
1. Choosing your DNS provider
2. Installation commands
3. Configuration file setup
4. Testing the configuration

### Cloudflare Example (Most Common)

1. **Install the plugin:**
   ```bash
   sudo apt-get install python3-certbot-dns-cloudflare
   ```

2. **Get your API token:**
   - Log into Cloudflare dashboard
   - Go to My Profile > API Tokens
   - Create token with `Zone:DNS:Edit` permissions
   - Copy the token

3. **Create credentials file:**
   ```bash
   sudo nano /etc/letsencrypt/cloudflare.ini
   ```

   Add:
   ```ini
   dns_cloudflare_api_token = YOUR_API_TOKEN_HERE
   ```

4. **Secure the file:**
   ```bash
   sudo chmod 600 /etc/letsencrypt/cloudflare.ini
   ```

5. **Test it:**
   ```bash
   sudo certbot certonly --dns-cloudflare \
     --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini \
     -d example.com -d *.example.com \
     --dry-run
   ```

6. **Use with sslmgr.sh:**
   ```bash
   ./sslmgr.sh --setup
   # Choose DNS-01 when prompted
   # Enter your domains (including wildcards)

   # The script will automatically detect and use the Cloudflare plugin
   sudo ./sslmgr.sh --renew
   ```

### Route53 (AWS) Example

1. **Install:**
   ```bash
   sudo apt-get install python3-certbot-dns-route53
   ```

2. **Configure AWS credentials:**

   Option A - IAM Role (recommended for EC2):
   - Attach IAM role to instance with Route53 permissions

   Option B - AWS CLI:
   ```bash
   aws configure
   ```

   Option C - Credentials file:
   ```bash
   sudo nano /etc/letsencrypt/route53.ini
   ```
   ```ini
   [default]
   aws_access_key_id=YOUR_ACCESS_KEY
   aws_secret_access_key=YOUR_SECRET_KEY
   ```

3. **Required IAM permissions:**
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "route53:ListHostedZones",
           "route53:GetChange"
         ],
         "Resource": "*"
       },
       {
         "Effect": "Allow",
         "Action": "route53:ChangeResourceRecordSets",
         "Resource": "arn:aws:route53:::hostedzone/*"
       }
     ]
   }
   ```

4. **Test:**
   ```bash
   sudo certbot certonly --dns-route53 \
     -d example.com -d *.example.com \
     --dry-run
   ```

### DigitalOcean Example

1. **Install:**
   ```bash
   sudo apt-get install python3-certbot-dns-digitalocean
   ```

2. **Get API token:**
   - DigitalOcean Control Panel > API > Generate New Token
   - Name it "LetsEncrypt" with read/write access

3. **Create credentials:**
   ```bash
   sudo nano /etc/letsencrypt/digitalocean.ini
   ```
   ```ini
   dns_digitalocean_token = YOUR_DO_API_TOKEN
   ```

4. **Secure:**
   ```bash
   sudo chmod 600 /etc/letsencrypt/digitalocean.ini
   ```

5. **Test:**
   ```bash
   sudo certbot certonly --dns-digitalocean \
     --dns-digitalocean-credentials /etc/letsencrypt/digitalocean.ini \
     -d example.com -d *.example.com \
     --dry-run
   ```

## Manual DNS Challenge (No Plugin Available)

If your DNS provider doesn't have a plugin:

1. **Run manual challenge:**
   ```bash
   sudo certbot certonly --manual \
     --preferred-challenges dns \
     -d example.com -d *.example.com
   ```

2. **Certbot will display:**
   ```
   Please deploy a DNS TXT record under the name
   _acme-challenge.example.com with the following value:

   abc123def456ghi789

   Press Enter to Continue
   ```

3. **Add the TXT record** to your DNS:
   - Name: `_acme-challenge.example.com`
   - Type: `TXT`
   - Value: `abc123def456ghi789`

4. **Verify it propagated:**
   ```bash
   dig -t TXT _acme-challenge.example.com
   nslookup -type=TXT _acme-challenge.example.com
   ```

5. **Press Enter** in certbot to continue

6. **⚠️ Important:** Manual certificates cannot auto-renew with cron
   - You'll need to repeat this process every 90 days
   - Consider using a DNS provider with plugin support for production

## Automated Renewal

Once DNS plugin is configured, automated renewal works seamlessly:

```bash
# Setup cron job
./sslmgr.sh --cron

# The cron job will automatically renew all certificates including DNS-01
```

## Troubleshooting

### DNS Plugin Not Detected

Check if installed:
```bash
which certbot-dns-cloudflare
pip3 list | grep certbot-dns
```

Reinstall if needed:
```bash
sudo apt-get install --reinstall python3-certbot-dns-cloudflare
```

### Credentials File Not Found

Ensure file exists and has correct path:
```bash
ls -la /etc/letsencrypt/*.ini
```

### DNS Propagation Issues

Wait for DNS to propagate (can take up to 10 minutes):
```bash
# Check propagation
dig -t TXT _acme-challenge.example.com @8.8.8.8
```

### Permission Errors

Fix file permissions:
```bash
sudo chmod 600 /etc/letsencrypt/*.ini
sudo chown root:root /etc/letsencrypt/*.ini
```

## Provider-Specific Notes

### Cloudflare
- API token is preferred over Global API Key
- Zone:DNS:Edit permission required
- Works with both Cloudflare proxy on/off

### Route53
- Can use IAM roles (no credentials file needed)
- Requires Route53 hosted zone for domain
- Cross-account zones supported with proper IAM policies

### DigitalOcean
- Token expires after 90 days by default (create non-expiring)
- Works with domains managed in DO DNS

## Supported DNS Providers

Full list of available DNS plugins:
- certbot-dns-cloudflare
- certbot-dns-route53 (AWS)
- certbot-dns-digitalocean
- certbot-dns-google (Google Cloud DNS)
- certbot-dns-rfc2136
- certbot-dns-dnsmadeeasy
- certbot-dns-gehirn
- certbot-dns-linode
- certbot-dns-luadns
- certbot-dns-nsone
- certbot-dns-ovh
- certbot-dns-sakuracloud

Install with:
```bash
sudo apt-get install python3-certbot-dns-<provider>
```

## Security Best Practices

1. **Limit API token permissions** to DNS only
2. **Set short TTL** on API tokens (30-90 days)
3. **Secure credential files** with chmod 600
4. **Use IAM roles** when possible (AWS)
5. **Rotate tokens** periodically
6. **Monitor API usage** for unexpected activity
7. **Backup credentials** securely

## Integration with sslmgr.sh

The script automatically:
1. Detects installed DNS plugins during `--renew`
2. Uses appropriate plugin for DNS-01 domains
3. Falls back to manual instructions if no plugin found
4. Logs all DNS operations
5. Updates domain status in configuration

### Status Values for DNS Domains

- `active` - DNS plugin found, auto-renewal working
- `dns-manual-required` - No plugin, manual renewal needed
- `pending` - Not yet generated
- `failed` - Last renewal attempt failed

Check status:
```bash
./sslmgr.sh --status
```

## References

- [Let's Encrypt DNS Validation](https://letsencrypt.org/docs/challenge-types/#dns-01-challenge)
- [Certbot DNS Plugins](https://eff-certbot.readthedocs.io/en/stable/using.html#dns-plugins)
- [Cloudflare API Tokens](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/)
- [AWS Route53 IAM Policies](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/access-control-managing-permissions.html)
