#!/bin/bash
set -e

# Usage: ./sync-repo.sh <repo_url> <branch> <local_dir> <sparse_patterns...>
# Example: ./sync-repo.sh "https://github.com/fastapi/fastapi.git" "master" "docs/fastapi" "docs/en/docs/*" "!docs/en/docs/img"

REPO_URL="$1"
BRANCH="$2"
LOCAL_DIR="$3"
shift 3  # Remove first 3 arguments, rest are sparse-checkout patterns

if [ -z "$REPO_URL" ] || [ -z "$BRANCH" ] || [ -z "$LOCAL_DIR" ]; then
    echo "Usage: $0 <repo_url> <branch> <local_dir> <sparse_patterns...>"
    exit 1
fi

echo "🔄 Syncing $(basename $REPO_URL .git) to $LOCAL_DIR"

# Create temp directory for sparse checkout
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

cd "$TEMP_DIR"

# Initialize git with sparse-checkout
git init
git remote add origin "$REPO_URL"
git config core.sparseCheckout true

# Create sparse-checkout file
mkdir -p .git/info
SPARSE_FILE=".git/info/sparse-checkout"
> "$SPARSE_FILE"  # Clear file

# Add each pattern to sparse-checkout
for pattern in "$@"; do
    echo "$pattern" >> "$SPARSE_FILE"
done

echo "📋 Sparse-checkout patterns:"
cat "$SPARSE_FILE" | sed 's/^/  /'

# Configure to only fetch the specific branch and no tags
git config remote.origin.fetch "+refs/heads/$BRANCH:refs/remotes/origin/$BRANCH"
git config remote.origin.tagOpt --no-tags

# Pull only the specific branch
echo "📥 Fetching $BRANCH branch..."
git pull origin "$BRANCH"

# Go back to the main repo
cd - > /dev/null

# Remove existing directory and copy new content
if [ -d "$LOCAL_DIR" ]; then
    echo "🗑️  Removing existing $LOCAL_DIR"
    rm -rf "$LOCAL_DIR"
fi

echo "📁 Creating $LOCAL_DIR"
mkdir -p "$LOCAL_DIR"

# Copy only the files that were checked out (excluding .git)
if [ "$(ls -A $TEMP_DIR 2>/dev/null | grep -v '^\.git$' | wc -l)" -gt 0 ]; then
    echo "📋 Copying files to $LOCAL_DIR"
    cp -r "$TEMP_DIR"/* "$LOCAL_DIR"/ 2>/dev/null || true
    cp -r "$TEMP_DIR"/.* "$LOCAL_DIR"/ 2>/dev/null || true
    # Remove .git directory from destination
    rm -rf "$LOCAL_DIR/.git" 2>/dev/null || true
else
    echo "⚠️  No files matched sparse-checkout patterns"
fi

# Add a metadata file to track sync info
cat > "$LOCAL_DIR/.sync-info.md" << EOF
# Sync Information

- **Source Repository**: $REPO_URL
- **Branch**: $BRANCH
- **Last Synced**: $(date -u +%Y-%m-%d\ %H:%M:%S\ UTC)
- **Sync Patterns**:
$(printf '%s\n' "$@" | sed 's/^/  - /')

---
*This directory is automatically synced. Do not edit files directly.*
EOF

echo "✅ Sync completed for $(basename $REPO_URL .git)"
echo ""