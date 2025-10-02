#!/bin/bash

# Reset staging area in case we modified files since last 'add'
# e.g. if we had to remove secrest from files. 
#git reset
#git restore --staged .
#git add -A
#git status
#git commit -m "Latest Update"
#git push origin master

# COMPLETELY RESET GIT FOLDER
# Delete .gitfolder and re-link it to remote repo
# Was having issues when trying to push files to remote repo...
# - Staged files with: git add -A
# - Git showed errors or secrets which could not be pushed
# - Fixed issues in files
# - Tried to unstage erroneous files (or all files) and re-add to push
# - Couldn't unstage erroroneous files no matter what.
# The only solution to unstaging files was to re-initialise the repo then push. 
rm -rf .git
git init
# Re-link to remote repo - not sensitive since public key configured on GitHub
# and private key specified in SSH config file.
git remote add origin git@github.com:danteali/Docker_Treafik2
git add -A
git status
git commit -m "Latest Update"
git push origin master