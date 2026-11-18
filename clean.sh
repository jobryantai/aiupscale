#!/bin/bash
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BASE_DIR"

echo "🧹 Cleaning up previous output files and extracted frames..."

if [ -d "outputfile" ]; then
    rm -rf outputfile/* 2>/dev/null || true
    echo "✅ Cleared outputfile/"
fi

if [ -d "inputfile/frames" ]; then
    rm -rf inputfile/frames/* 2>/dev/null || true
    echo "✅ Cleared inputfile/frames/"
fi

echo "✨ Workspace is completely clean!"
