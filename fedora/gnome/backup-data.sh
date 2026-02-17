#!/bin/bash

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
    "distrobox/development"
    "distrobox/softwares"
)

if ! mountpoint -q "/mnt/samc-1TB"; then
    echo "❌ Error: External HDD is not mounted!"
    exit 1
fi

DEST_ROOT="/mnt/samc-1TB/backups" # <--- UPDATE THIS
DATE=$(date +%d-%b-%Y_%I-%M-%p)
CURRENT_BACKUP="$DEST_ROOT/$DATE"
LATEST_LINK="$DEST_ROOT/latest"

# 1. Create the today's backup directory
mkdir -p "$CURRENT_BACKUP"

echo "🚀 Starting focused backup..."

# 2. Loop through each target and back it up
for ITEM in "${TARGETS[@]}"; do
    echo "  -> Syncing: $ITEM"
    
    # We use -R (relative) so it recreates the folder structure in the backup
    # We exclude node_modules and dist globally within those folders
    rsync -avR --delete \
        --exclude='**/node_modules/' \
        --exclude='**/dist/' \
        --link-dest="$LATEST_LINK" \
        "$HOME/./$ITEM" "$CURRENT_BACKUP/"
done

# 3. Update the 'latest' symlink for the next run's deduplication
rm -f "$LATEST_LINK"
ln -s "$DATE" "$LATEST_LINK"

echo "----------------------------------------"
echo "📊 Storage Report for $DATE:"
du -sh "$CURRENT_BACKUP" | awk '{print "Visible size: " $1}'
echo -n "Actual disk space used: "
du -sh --apparent-size "$CURRENT_BACKUP" | awk '{print $1}'
echo "----------------------------------------"

echo "✅ Backup complete. Only the specified folders were processed."
