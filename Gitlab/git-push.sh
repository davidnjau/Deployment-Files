#!/bin/bash
set -e

UPSTREAM=${1:-'@{u}'}
LOCAL=$(git rev-parse @)
REMOTE=$(git rev-parse "$UPSTREAM")
BASE=$(git merge-base @ "$UPSTREAM")

# Abort if the remote has commits we don't have locally
if [ "$LOCAL" = "$REMOTE" ]; then
  echo "Branch is already up-to-date. Nothing to push."
  exit 0
elif [ "$LOCAL" = "$BASE" ]; then
  echo "Error: local branch is behind remote. Run 'git pull' first."
  exit 1
elif [ "$LOCAL" != "$BASE" ] && [ "$REMOTE" != "$BASE" ]; then
  echo "Error: branches have diverged. Resolve the divergence before pushing."
  exit 1
fi

# Enforce deployment from master only
branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$branch" != "master" ]; then
  echo "Error: not on 'master' branch (currently on '$branch'). Switch branches before pushing."
  exit 1
fi

# Show what is staged/unstaged so the user can make a deliberate choice
echo ""
echo "=== Current status ==="
git status --short
echo ""

# Stage only tracked files that have been modified — do not silently add untracked files
git add -u

# Bail out if there is nothing to commit
if git diff --cached --quiet; then
  echo "No staged changes to commit. Push any unpushed commits? (y/N)"
  read -r confirm
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    exit 0
  fi
else
  read -p "Enter commit message: " commitMessage
  if [ -z "$commitMessage" ]; then
    echo "Error: commit message cannot be empty."
    exit 1
  fi
  git commit -m "$commitMessage"
fi

# Push directly — we already verified local is ahead of remote
git push
