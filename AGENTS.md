# AGENTS.md

Personal scripts repository - a collection of shell scripts, configs, and installation guides organized by target environment.

## Directory Structure

| Directory | Purpose |
|-----------|---------|
| `client/` | General Linux/client scripts, git helpers, monitoring |
| `backup/` | Rsync/backup scripts for distributing files across free web storages |
| `server/` | Server provisioning scripts |
| `alpine/` | Alpine Linux setup scripts |
| `mxlinux/` | MX Linux setup scripts |
| `nix/` | NixOS configuration |
| `pwsh/` | PowerShell scripts |
| `wsl2/` | WSL2 setup scripts |
| `xsh/` | Xonsh shell scripts |
| `conf/` | Server configs (httpd.conf, php.ini) |
| `ai/` | AI window launcher scripts |

## Key Commands

```bash
# Push all changes (requires message argument)
./client/git_push.sh "commit message"
# Or shorthand:
./client/git_push.sh
```

## Backup Scripts (`backup/`)

| Script | Purpose |
|--------|---------|
| `rsyncing.bash` | Mirror folders from external USB drive |
| `rsyncronjobs` | Scheduled rsync jobs for site backups |

## Notes

- No test/lint/typecheck setup - this is a personal scripts collection
- Scripts are standalone shell files, not a package
- Adding new scripts: place in appropriate directory by target environment

## FastAPI Deployment (Vultr/Server)

### Quick Start
```bash
# SSH to server
ssh carrierc@65.20.91.130

# Create app directory
sudo mkdir -p /var/www/domain.com
sudo chown -R carrierc:carrierc /var/www/domain.com

# Upload project via SCP or git clone
# Create virtual environment
cd /var/www/domain.com
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Fix database path in database.py
sed -i 's|sqlite:///../data/business.db|sqlite:////var/www/domain.com/data/business.db|'

# Initialize database
python -c "from database import engine, Base; Base.metadata.create_all(bind=engine)"

# Fix template paths in main.py and routes/*.py
sed -i 's|directory="templates"|directory="/var/www/domain.com/templates"|g'
sed -i 's|directory="static"|directory="/var/www/domain.com/static"|g'
```

### Create Systemd Service
```bash
sudo cat > /etc/systemd/system/appname.service << 'EOF'
[Unit]
Description=FastAPI App
After=network.target

[Service]
User=carrierc
Group=carrierc
WorkingDirectory=/var/www/domain.com
Environment="PATH=/var/www/domain.com/venv/bin"
ExecStart=/var/www/domain.com/venv/bin/uvicorn main:app --host 127.0.0.1 --port 8000
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable appname
sudo systemctl start appname
```

### Nginx Reverse Proxy (SSL already configured)
```bash
sudo cat > /etc/nginx/sites-available/domain.com.conf << 'EOF'
server {
    listen 80;
    server_name domain.com www.domain.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name domain.com www.domain.com;
    ssl_certificate /etc/ssl/domain.com/fullchain.pem;
    ssl_certificate_key /etc/ssl/domain.com/key.pem;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/domain.com.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

### IMPORTANT: Package Versions
**Python 3.13 + FastAPI compatibility issue** - Use specific versions to avoid template rendering errors:
```bash
pip install fastapi==0.100.0 starlette==0.27.0 jinja2==3.1.2 uvicorn==0.23.0
```

### Common Issues
- **Template not found**: Fix path to absolute `/var/www/domain.com/templates`
- **Database error**: Ensure `data/` directory exists and is writable
- **Static files 404**: Fix path to absolute `/var/www/domain.com/static`
- **Import errors**: Ensure all dependencies in requirements.txt are installed

### Commands
```bash
# View logs
sudo journalctl -u appname -f

# Restart
sudo systemctl restart appname

# Check status
systemctl status appname
```