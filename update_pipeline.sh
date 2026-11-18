#!/bin/bash
set -e

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BASE_DIR"

echo "🔄 Starting AI Upscale Pipeline Update..."

# 1. Update local git repositories if they exist
for repo in BasicSR Real-ESRGAN realesrgan-ncnn-vulkan; do
    if [ -d "$repo/.git" ]; then
        echo "📥 Pulling latest updates for $repo..."
        git -C "$repo" pull || true
    fi
done

# 2. Activate virtual environment
if [ -f "$HOME/.venvs/aiupscale/bin/activate" ]; then
    source "$HOME/.venvs/aiupscale/bin/activate"
    PYTHON_BIN="$HOME/.venvs/aiupscale/bin/python"
elif [ -f "$BASE_DIR/venv/bin/activate" ]; then
    source "$BASE_DIR/venv/bin/activate"
    PYTHON_BIN="$BASE_DIR/venv/bin/python"
else
    echo "❌ Error: Virtual environment not found!"
    exit 1
fi

# 3. Ensure BasicSR setup.py is patched for Python 3.14 compatibility
if [ -f "BasicSR/setup.py" ]; then
    echo "🛠️ Ensuring BasicSR setup.py is patched..."
    sed -i 's/version=get_version()/version="1.4.2"/g' BasicSR/setup.py
    pip install --no-build-isolation -e BasicSR/
fi

# 4. Refresh dependent libraries
echo "📦 Verifying core upscaling packages..."
pip install --upgrade realesrgan gfpgan facexlib opencv-python

# 5. Quick GPU & Import Verification Test
echo "🔍 Verifying Python CUDA and BasicSR module imports..."
"$PYTHON_BIN" -c '
import torch
import cv2
from basicsr.archs.rrdbnet_arch import RRDBNet
print("---------------------------------------------------")
print("✅ PyTorch Version:", torch.__version__)
print("✅ CUDA Available:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("✅ Active GPU:", torch.cuda.get_device_name(0))
print("✅ BasicSR Architecture Loaded Successfully!")
print("---------------------------------------------------")
'

echo "🎉 Update and verification complete! You can now run ./run_pipeline.sh"
