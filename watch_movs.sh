#!/bin/bash

# Script to watch for new .mov files and automatically convert them to .mp4
# This script monitors the current directory for new .mov files

WATCH_DIR="$(cd "$(dirname "$0")" && pwd)"
CONVERTER_SCRIPT="$WATCH_DIR/convert_mov_to_mp4.sh"

echo "Watching directory: $WATCH_DIR"
echo "Press Ctrl+C to stop watching"
echo "---"

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg is not installed"
    echo "Install it with: brew install ffmpeg"
    exit 1
fi

# Check if converter script exists
if [ ! -f "$CONVERTER_SCRIPT" ]; then
    echo "Error: Converter script not found at $CONVERTER_SCRIPT"
    exit 1
fi

# Make converter script executable
chmod +x "$CONVERTER_SCRIPT"

# Function to process a .mov file
process_mov_file() {
    local mov_file="$1"

    # Skip if file doesn't exist or isn't a regular file
    if [ ! -f "$mov_file" ]; then
        return
    fi

    # Skip if corresponding .mp4 already exists
    local mp4_file="${mov_file%.mov}.mp4"
    if [ -f "$mp4_file" ]; then
        echo "Skipping $mov_file (mp4 already exists)"
        return
    fi

    echo "New .mov file detected: $mov_file"
    echo "Starting conversion..."
    "$CONVERTER_SCRIPT" "$mov_file"
    echo "---"
}

# Check for fswatch (better file watching tool for macOS)
if command -v fswatch &> /dev/null; then
    echo "Using fswatch for file monitoring (more efficient)"
    echo ""

    # Process any existing .mov files first
    for mov_file in "$WATCH_DIR"/*.mov; do
        if [ -f "$mov_file" ]; then
            process_mov_file "$mov_file"
        fi
    done

    # Watch for new or modified .mov files
    fswatch -0 -e ".*" -i "\\.mov$" "$WATCH_DIR" | while read -d "" path; do
        # Wait a moment to ensure file is fully written
        sleep 2
        process_mov_file "$path"
    done
else
    echo "fswatch not found. Using polling method (less efficient)"
    echo "Install fswatch with: brew install fswatch"
    echo ""

    # Keep track of processed files
    declare -A processed_files

    # Process any existing .mov files first
    for mov_file in "$WATCH_DIR"/*.mov; do
        if [ -f "$mov_file" ]; then
            process_mov_file "$mov_file"
            processed_files["$mov_file"]=1
        fi
    done

    # Poll directory every 5 seconds for new .mov files
    while true; do
        for mov_file in "$WATCH_DIR"/*.mov; do
            if [ -f "$mov_file" ] && [ -z "${processed_files[$mov_file]}" ]; then
                # Wait a moment to ensure file is fully written
                sleep 2
                process_mov_file "$mov_file"
                processed_files["$mov_file"]=1
            fi
        done
        sleep 5
    done
fi
