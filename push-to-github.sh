#!/bin/bash

##############################################################################
# GitHub Repository Setup Script
# Creates a new repository on GitHub and pushes the code
##############################################################################

set -e

echo "========================================="
echo "GitHub Repository Setup"
echo "========================================="
echo ""

# Check if gh CLI is available
if command -v gh &> /dev/null; then
    echo "Using GitHub CLI to create repository..."
    gh repo create uidcyber-website \
        --public \
        --source=. \
        --description "Professional cybersecurity portfolio website with automated deployment" \
        --push

    echo ""
    echo "✓ Repository created and code pushed!"
    echo "View at: https://github.com/$(git config user.name)/uidcyber-website"
    exit 0
fi

# If gh CLI is not available, provide instructions
echo "GitHub CLI (gh) is not installed."
echo ""
echo "To create the repository on GitHub:"
echo ""
echo "Option 1: Install GitHub CLI and run this script again"
echo "  sudo apt install gh"
echo "  gh auth login"
echo "  ./push-to-github.sh"
echo ""
echo "Option 2: Create repository manually"
echo "  1. Go to https://github.com/new"
echo "  2. Repository name: uidcyber-website"
echo "  3. Description: Professional cybersecurity portfolio website with automated deployment"
echo "  4. Make it Public"
echo "  5. Do NOT initialize with README (we already have one)"
echo "  6. Click 'Create repository'"
echo ""
echo "  Then run these commands:"
echo "    git remote add origin https://github.com/$(git config user.name)/uidcyber-website.git"
echo "    git branch -M master"
echo "    git push -u origin master"
echo ""
echo "Option 3: Use the GitHub API"
echo "  You'll need a Personal Access Token from:"
echo "  https://github.com/settings/tokens/new"
echo "  (Select 'repo' scope)"
echo ""
read -p "Do you have a GitHub Personal Access Token? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    read -p "Enter your GitHub Personal Access Token: " -s GITHUB_TOKEN
    echo ""

    if [ -z "$GITHUB_TOKEN" ]; then
        echo "No token provided. Please use one of the manual options above."
        exit 1
    fi

    echo "Creating repository on GitHub..."
    RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        https://api.github.com/user/repos \
        -d "{\"name\":\"uidcyber-website\",\"description\":\"Professional cybersecurity portfolio website with automated deployment\",\"private\":false}")

    if echo "$RESPONSE" | grep -q '"clone_url"'; then
        REPO_URL=$(echo "$RESPONSE" | grep -o '"clone_url": "[^"]*"' | cut -d'"' -f4)
        echo "✓ Repository created!"
        echo "Repository URL: $REPO_URL"
        echo ""
        echo "Pushing code to GitHub..."
        git remote add origin "$REPO_URL" 2>/dev/null || git remote set-url origin "$REPO_URL"
        git push -u origin master
        echo ""
        echo "✓ Code pushed successfully!"
        echo "View at: https://github.com/$(git config user.name)/uidcyber-website"
    else
        echo "Error creating repository:"
        echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
        echo ""
        echo "Please create the repository manually using Option 2 above."
        exit 1
    fi
else
    echo ""
    echo "Please use Option 1 or 2 above to create the repository."
fi
