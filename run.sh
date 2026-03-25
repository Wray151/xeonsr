#!/bin/bash
# ETDS 2x Video Super-Resolution (OpenVINO)
# Usage: ./run.sh input_video.mp4 [-o output.mp4]

_ETDS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_ETDS_ARGS=("$@")

# Activate venv
if [ -f "$_ETDS_DIR/.venv/bin/activate" ]; then
    source "$_ETDS_DIR/.venv/bin/activate"
fi

# Find Python 3.9+
PYTHON=""
for py in python3.13 python3.12 python3.11 python3.10 python3.9 python3; do
    if command -v "$py" &>/dev/null; then
        ver=$("$py" -c "import sys; print(sys.version_info.minor)")
        if [ "$ver" -ge 9 ] 2>/dev/null; then
            PYTHON="$py"
            break
        fi
    fi
done

if [ -z "$PYTHON" ]; then
    echo "Error: Python 3.9+ not found."
    exit 1
fi

echo "Using Python: $PYTHON ($($PYTHON --version))"

# Check dependencies
$PYTHON -c "import numpy, cv2, openvino" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "Installing dependencies..."
    $PYTHON -m pip install openvino==2025.2.0 numpy opencv-python-headless
fi

# Ensure ffmpeg/ffprobe available
_ensure_ffmpeg() {
    local bin_dir="$_ETDS_DIR/bin"
    # 1) Check bundled
    if [ -x "$bin_dir/ffmpeg" ] && [ -x "$bin_dir/ffprobe" ]; then
        return 0
    fi
    # 2) Check system
    if command -v ffmpeg &>/dev/null && command -v ffprobe &>/dev/null; then
        mkdir -p "$bin_dir"
        ln -sf "$(command -v ffmpeg)" "$bin_dir/ffmpeg"
        ln -sf "$(command -v ffprobe)" "$bin_dir/ffprobe"
        echo "Using system ffmpeg: $(ffmpeg -version 2>&1 | head -1)"
        return 0
    fi
    # 3) Download static build
    echo "Downloading static ffmpeg..."
    mkdir -p "$bin_dir"
    local tmp_dir=$(mktemp -d)
    curl -sL https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz -o "$tmp_dir/ffmpeg.tar.xz"
    tar -xf "$tmp_dir/ffmpeg.tar.xz" -C "$tmp_dir/"
    cp "$tmp_dir"/ffmpeg-*-amd64-static/ffmpeg "$bin_dir/ffmpeg"
    cp "$tmp_dir"/ffmpeg-*-amd64-static/ffprobe "$bin_dir/ffprobe"
    chmod +x "$bin_dir/ffmpeg" "$bin_dir/ffprobe"
    rm -rf "$tmp_dir"
    echo "Downloaded: $("$bin_dir/ffmpeg" -version 2>&1 | head -1)"
}

_ensure_ffmpeg

$PYTHON "$_ETDS_DIR/sr_video_ov.py" "${_ETDS_ARGS[@]}"
