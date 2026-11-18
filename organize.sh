#!/bin/bash
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BASE_DIR"

echo "📂 Organizing workspace files into corresponding directories..."

# Create structured archive directories if they don't exist
mkdir -p archives/outputs archives/logs

# Move any loose timestamped output folders into archives/outputs
for dir in outputfile_*; do
    if [ -d "$dir" ] && [ "$dir" != "outputfile_*" ]; then
        echo "Moving $dir to archives/outputs/"
        mv "$dir" archives/outputs/
    fi
done

# Move any loose log files or text outputs if present
if ls *.log 1> /dev/null 2>&1; then
    mv *.log archives/logs/
    echo "Moved log files to archives/logs/"
fi

echo "✨ Organization complete! All outputs are now neatly sorted."
