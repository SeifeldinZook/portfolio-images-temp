#!/bin/bash

# Clean DS_Store files script
# This script removes all .DS_Store files from your machine and prevents future creation

echo "🧹 Cleaning .DS_Store files from your machine..."

# Remove all .DS_Store files from home directory
echo "Removing existing .DS_Store files..."
find ~ -name ".DS_Store" -type f -delete 2>/dev/null || true

# Prevent macOS from creating .DS_Store files on network volumes
echo "Configuring macOS to not create .DS_Store files on network volumes..."
defaults write com.apple.desktopservices DSDontWriteNetworkStores true

# Prevent macOS from creating .DS_Store files on USB drives
echo "Configuring macOS to not create .DS_Store files on USB drives..."
defaults write com.apple.desktopservices DSDontWriteUSBStores true

echo "✅ Done! .DS_Store files have been cleaned and future creation has been minimized."
echo ""
echo "Note: You may need to restart Finder or log out/in for all changes to take effect:"
echo "  killall Finder"
echo ""
echo "To run this script again in the future:"
echo "  chmod +x clean_ds_store.sh"
echo "  ./clean_ds_store.sh"
