# create_website.sh

## Purpose
Create a new website with Nginx, SSL certificate, and proper folder structure.

## Usage

```bash
# Single domain
./create_website.sh example.com

# With www subdomain
./create_website.sh example.com www.example.com
```

## What it does

1. **Creates directories**
   - Web root: `/var/www/{domain}/`

2. **Creates default index.html**
   - Simple "Under Construction" page

3. **Issues SSL certificate**
   - Uses acme.sh with Let's Encrypt
   - Supports both domain and www subdomain

4. **Installs SSL certificates**
   - Location: `/etc/ssl/{domain}/`
   - Files: `fullchain.pem`, `key.pem`

5. **Creates nginx config**
   - Location: `/etc/nginx/sites-available/{domain}.conf`
   - HTTP → HTTPS redirect
   - SSL enabled on port 443

6. **Enables site**
   - Creates symlink in `sites-enabled/`
   - Tests and reloads nginx

## Examples

```bash
# Create ecomsense.in (full website with SSL)
./create_website.sh ecomsense.in

# Create parked domain (no SSL, simple HTTP)
./create_website.sh --parked sriarasutex.com

# Create parked domain with custom message
./create_website.sh --parked sriarasutex.com --message "Moved Permanently"
```

## Parked Domains

For domains that should show a simple landing page without SSL:
- No SSL certificate needed
- Simple HTTP nginx config only
- Use `--parked` flag

```bash
./create_website.sh --parked sriarasutex.com
./create_website.sh --parked sriarasutex.com --message "Moved Permanently"
```

## Key Locations

| Item | Location |
|------|-----------|
| Web root | `/var/www/{domain}/` |
| SSL certs | `/etc/ssl/{domain}/` |
| Nginx config | `/etc/nginx/sites-available/{domain}.conf` |
| Enabled sites | `/etc/nginx/sites-enabled/` |