#!/bin/bash

set -uo pipefail

# --- CONFIGURATION ---
# List exactly what you want to backup (relative to your Home folder)
# No trailing slashes here; we handle that in the loop.
    #"books"
TARGETS=(
    "Documents"
    "Pictures"
    "study-projects"
    "setup-scripts"
    "Zotero"
    ".zen"
    ".config/kitty"
    ".config/mpv"
    ".config/yazi"
    ".config/zellij"
    ".var/app/com.usebottles.bottles/data/bottles/bottles/adult/drive_c/users/steamuser/AppData/Roaming/RenPy"
    ".renpy"
    "distrobox/development"
    "distrobox/softwares"
)

MOUNT_POINT="/mnt/samc-1TB"
DEST_ROOT="$MOUNT_POINT/backups" 

if ! mountpoint -q "$MOUNT_POINT"; then
    echo "❌ Error: External HDD is not mounted at $MOUNT_POINT"
    exit 1
fi

# --- LOCK FILE (prevents concurrent runs) ---
LOCK_FILE="/tmp/backup_samc.lock"
if [ -e "$LOCK_FILE" ]; then
    echo "❌ Error: Backup is already running (lock file: $LOCK_FILE)"
    exit 1
fi
touch "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

DATE=$(date +%d-%b-%Y_%I-%M-%p)
CURRENT_BACKUP="$DEST_ROOT/$DATE"
LATEST_LINK="$DEST_ROOT/latest"
LOG_FILE="$DEST_ROOT/backup.log"

exec > >(tee -a "$LOG_FILE") 2>&1
echo "============ Backup Process Started: $(date) ============="

echo "Validating targets..."
for ITEM in "${TARGETS[@]}"; do
    if [ ! -e "$HOME/$ITEM" ]; then
        echo " WARNING: '$ITEM' does not exist, will be skipped by rsync."
    fi
done

# --- DISK SPACE CHECK ---
AVAILABLE=$(df -BG "$DEST_ROOT" | awk 'NR==2 {gsub("G","",$4); print $4}')
echo "💾 Available space on backup drive: ${AVAILABLE}GB"
if [ "$AVAILABLE" -lt 5 ]; then
    echo "❌ Error: Less than 5GB free on backup drive. Aborting."
    exit 1
fi

# 1. Create the today's backup directory
mkdir -p "$CURRENT_BACKUP"
echo "🚀 Starting focused backup..."

# 2. Loop through each target and back it up
ERRORS=0
for ITEM in "${TARGETS[@]}"; do
    echo "  -> Syncing: $ITEM"
    
    # We use -R (relative) so it recreates the folder structure in the backup
    # We exclude node_modules and dist globally within those folders
    if ! rsync -avR --delete \
        --exclude='node_modules/' \
        --exclude='dist/' \
        --link-dest="$LATEST_LINK" \
        "$HOME/./$ITEM" "$CURRENT_BACKUP/"; then
        echo " ⚠️  WARNING: Failed to sync '$ITEM'"
        ERRORS=$((ERRORS + 1))
    fi
done

# 3. Update the 'latest' symlink for the next run's deduplication
rm -f "$LATEST_LINK"
ln -s "$DATE" "$LATEST_LINK"

echo "----------------------------------------"
echo "📊 Storage Report for $DATE:"
echo -n " Apparent size (all files): "
du -sh --apparent-size "$CURRENT_BACKUP" | awk '{print $1}'

echo -n " Actual disk space used: "
du -sh "$CURRENT_BACKUP" | awk '{print $1}'
echo "----------------------------------------"

if [ "$ERRORS" -gt 0 ]; then
    echo " ⚠️  Backup finished with $ERRORS error(s). Check log: $LOG_FILE"
    notify-send "Backup Failed ⚠️" "$ERRORS error(s) occurred. Check $LOG_FILE" --urgency=critical
    exit 1
else 
    echo "✅ Backup complete. Only the specified folders were processed."
    notify-send "Backup Complete ✅" "All targets synced successfully."
fi
