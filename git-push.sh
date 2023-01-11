#!/bin/bash

# Check if the branch is up-to-date before pushing
UPSTREAM=${1:-'@{u}'}
LOCAL=$(git rev-parse @)
REMOTE=$(git rev-parse "$UPSTREAM")
BASE=$(git merge-base @ "$UPSTREAM")

if [ $LOCAL = $REMOTE ]; then
    echo "Branch is already up-to-date"
    exit 1
elif [ $LOCAL = $BASE ]; then
    echo "Need to pull"
    exit 1
elif [ $REMOTE = $BASE ]; then
    echo "Need to push"
else
  echo "Diverged branches"
  exit 1
fi

# Check if working tree is clean
if ! git diff-index --quiet HEAD --; then
    echo "Uncommited changes found. Please commit them before pushing"
    exit 1
fi

# Check if current branch is the correct one before pushing
branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$branch" != "master" ]; then
    echo "Not on the 'master' branch. Please switch to the correct branch before pushing"
    exit 1
fi

# Add all files in the current directory to the staging area
git add .

# Ask for a commit message
read -p "Enter commit message: " commitMessage

# Commit the changes with the specified message
git commit -m "$commitMessage"

# Pull the latest changes from the remote repository
git pull
if [ $? -ne 0 ]; then
  echo "There were merge conflicts. Please resolve them before pushing."
  exit 1
fi

# Push the changes to the remote repository
git push
