#!/bin/sh
# Install or upgrade GNU flex via Homebrew (often newer than Xcode’s /usr/bin/flex).
# Requires a writable Homebrew prefix. If `brew` errors on /opt/homebrew/Cellar, fix ownership first.
set -euo pipefail

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Install from https://brew.sh then re-run this script." >&2
  exit 1
fi

if [ ! -w "$(brew --prefix)/Cellar" ] 2>/dev/null; then
  echo "Homebrew Cellar is not writable. On your MacBook, run once:"
  echo "  sudo chown -R \"$(whoami)\" \"$(brew --prefix)/Cellar\""
  echo "Then re-run: $0"
  exit 1
fi

brew update
brew install flex 2>/dev/null || brew upgrade flex

echo "Homebrew flex:"
command -v flex
flex --version

echo "Apple/Xcode flex (still available): /usr/bin/flex — $(/usr/bin/flex --version 2>&1 | head -1)"
