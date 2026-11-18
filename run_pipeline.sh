#!/bin/bash
set -e

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BASE_DIR"

INPUT_DIR="$BASE_DIR/inputfile"
WORK_INPUT_FRAMES="$BASE_DIR/workspaces/inputframes"
WORK_OUTPUT_FRAMES="$BASE_DIR/workspaces/outputframes"
FINAL_OUTPUT_DIR="$BASE_DIR/outputfile"

# 1. Ensure required base directories exist
mkdir -p "$INPUT_DIR" "$WORK_INPUT_FRAMES" "$WORK_OUTPUT_FRAMES" "$FINAL_OUTPUT_DIR"

# Auto-activate virtual environment if present
if [ -d "venv" ]; then
    source venv/bin/activate
elif [ -d ".venv" ]; then
    source .venv/bin/activate
fi

# Ensure correct permissions
sudo chown -R $USER:$USER "$BASE_DIR" 2>/dev/null || true

# Find source video (.mov or .mp4) in inputfile without modifying it
VIDEO_FILE=$(find "$INPUT_DIR" -maxdepth 1 \( -name "*.mov" -o -name "*.MOV" -o -name "*.mp4" -o -name "*.MP4" \) | head -n 1)
if [ -z "$VIDEO_FILE" ]; then
    echo "❌ Error: No video file found in $INPUT_DIR!"
    exit 1
fi

VIDEO_FILENAME=$(basename -- "$VIDEO_FILE")
VIDEO_NAME_NO_EXT="${VIDEO_FILENAME%.*}"

# 2 & 3. Create video-specific subfolders under workspaces/inputframes and workspaces/outputframes
FRAMES_DIR="$WORK_INPUT_FRAMES/$VIDEO_NAME_NO_EXT"
OUTPUT_FRAMES_DIR="$WORK_OUTPUT_FRAMES/$VIDEO_NAME_NO_EXT"
mkdir -p "$FRAMES_DIR" "$OUTPUT_FRAMES_DIR"

echo "🎥 Found source video: $VIDEO_FILENAME"
echo "📂 Input frames directory: $FRAMES_DIR"
echo "📂 Output frames directory: $OUTPUT_FRAMES_DIR"

# Ensure FFmpeg is present
if ! command -v ffmpeg &> /dev/null; then
    sudo apt update && sudo apt install -y ffmpeg
fi

# Extract frames if not already present
if [ -z "$(ls -A "$FRAMES_DIR" 2>/dev/null)" ]; then
    echo "🎬 Extracting frames..."
    ffmpeg -i "$VIDEO_FILE" -qscale:v 1 "$FRAMES_DIR/%08d.png"
fi

echo "🚀 Running Python RTX 5090 upscaling..."
python3 upscale_cuda.py "$FRAMES_DIR" "$OUTPUT_FRAMES_DIR" "4"

# 4. Move final output video to C:\aiupscale\outputfile with video name prefix
FINAL_OUTPUT="$FINAL_OUTPUT_DIR/${VIDEO_NAME_NO_EXT}_upscaled.mp4"
echo "🎞️ Stitching frames into $FINAL_OUTPUT..."
FPS=$(ffprobe -v 0 -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 "$VIDEO_FILE")

ffmpeg -y -framerate "$FPS" -i "$OUTPUT_FRAMES_DIR/%08d.png" \
       -i "$VIDEO_FILE" -map 0:v:0 -map 1:a? \
       -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p \
       -c:a aac -b:a 192k "$FINAL_OUTPUT"

echo "🎉 Done! Final output saved to: $FINAL_OUTPUT"
