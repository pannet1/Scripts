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