#!/bin/bash
set -e

BASE_DIR="/mnt/e/aiupscale"

echo "=== [CLEANUP] Resetting Pipeline Directories ==="

# Safely remove and recreate frame folders (bypasses 'argument list too long' errors)
echo "--> Clearing old input frames..."
rm -rf "$BASE_DIR/input_frames"
mkdir -p "$BASE_DIR/input_frames"

echo "--> Clearing old output frames..."
rm -rf "$BASE_DIR/output_frames"
mkdir -p "$BASE_DIR/output_frames"

echo "--> Removing old output MP4 files..."
rm -f "$BASE_DIR"/*.mp4

echo "=== CLEANUP COMPLETE! ==="
echo "Your workspace is pristine and ready for a new clip."
