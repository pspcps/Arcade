#!/bin/bash
# Lytx Version Checker — one-shot GitHub setup (macOS)
# Usage: bash setup.sh
set -e

echo "🔧 Lytx Version Checker — GitHub setup"

# 1) Homebrew (needed to install gh)
if ! command -v brew >/dev/null 2>&1; then
  echo "📦 Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
else
  echo "✅ Homebrew already installed"
fi

# 2) GitHub CLI
if ! command -v gh >/dev/null 2>&1; then
  echo "📦 Installing GitHub CLI..."
  brew install gh
else
  echo "✅ gh already installed ($(gh --version | head -1))"
fi

# 3) Auth — only if not already logged in
if ! gh auth status >/dev/null 2>&1; then
  echo "🔐 Logging in to GitHub..."
  echo "   Pick: GitHub.com → HTTPS → Yes → Login with a web browser"
  echo "   ⚠️  On the success page, click 'Configure SSO → Authorize' for lytx-services"
  gh auth login
else
  echo "✅ Already authenticated with GitHub"
fi

# 4) Copy token to clipboard
if gh auth token | pbcopy 2>/dev/null; then
  echo ""
  echo "🎉 Done! Token copied to clipboard."
  echo "👉 Open the Version Checker → GitHub Access → paste & Save."
else
  echo "❌ Could not copy token. Run manually: gh auth token | pbcopy"
  exit 1
fi
