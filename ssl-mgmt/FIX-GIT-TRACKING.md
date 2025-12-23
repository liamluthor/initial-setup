# Fixing Git Tracking Issue

## The Problem

The `logs/sslmgr.log` file was accidentally committed and is now tracked by git. When you try to pull updates, git complains about local changes to this file.

## Quick Fix (Recommended)

Run these commands from the `initial-setup` directory:

```bash
# Go to the repo root
cd /home/spatialthreat/Repos/initial-setup

# Remove the log file from git tracking (but keep the local file)
git rm --cached ssl-mgmt/logs/sslmgr.log

# Stage the .gitignore file
git add ssl-mgmt/.gitignore
git add ssl-mgmt/logs/.gitkeep
git add ssl-mgmt/backups/.gitkeep
git add ssl-mgmt/nginx/.gitkeep

# Commit the changes
git commit -m "Fix: Stop tracking log files and generated content

- Added .gitignore for ssl-mgmt directory
- Removed logs/sslmgr.log from git tracking
- Added .gitkeep files to preserve directory structure
- Prevents tracking of sensitive config files and backups"

# Now pull should work
git pull

# Then push your changes
git push
```

## Alternative: Stash and Pull

If you want to keep your local log file:

```bash
# Stash your local changes
git stash

# Pull updates
git pull

# Apply your stashed changes (will restore the log file)
git stash pop
```

## What the .gitignore Prevents

The new `.gitignore` file prevents tracking:
- ✅ Log files (`logs/*.log`)
- ✅ Backup files (`backups/*`)
- ✅ Generated nginx configs (`nginx/*`)
- ✅ Domain configuration (`config/domains.conf`)
- ✅ Credential files (`*.ini`)
- ✅ Temporary files

## Verify It Worked

After fixing, verify with:

```bash
# Should show the .gitignore and .gitkeep files as staged/committed
git status

# Should NOT show logs/sslmgr.log as tracked
git ls-files | grep sslmgr.log
# (should return nothing)

# Check what's ignored
git check-ignore -v ssl-mgmt/logs/sslmgr.log
# Should show: ssl-mgmt/.gitignore:2:logs/*.log ssl-mgmt/logs/sslmgr.log
```

## For Future Use

The `.gitkeep` files ensure empty directories are preserved in git, so when others clone the repo, they get the proper directory structure but without any generated files.

## Security Note

**Never commit:**
- Log files (may contain sensitive debugging info)
- Backup files (contain private SSL keys)
- Configuration files with credentials (`.ini` files)
- Domain configuration (may expose internal infrastructure)

These are now all protected by `.gitignore`.
