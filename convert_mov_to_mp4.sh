#!/bin/bash

# Script to convert .mov files to compressed .mp4 files.
# If run with no arguments, scans the current directory for *.mov/*.MOV
# and converts each file sequentially. If given one or more filenames,
# converts those files only.

set -euo pipefail
shopt -s nullglob

print_usage() {
    echo "Usage: $0 [-n|--dry-run] [file1.mov [file2.mov ...]]"
    echo "If no files are provided the script will convert all .mov files in the current directory."
    echo "  -n, --dry-run   Show what would be done without running ffmpeg or moving files"
}

# Parse flags (only -n/--dry-run and -h/--help supported)
DRY_RUN=0
while [ $# -gt 0 ] && [[ "$1" == -* ]]; do
    case "$1" in
        -n|--dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

FILES=()
if [ $# -eq 0 ]; then
    for f in *.mov *.MOV; do
        [ -f "$f" ] || continue
        FILES+=("$f")
    done
else
    for arg in "$@"; do
        FILES+=("$arg")
    done
fi

if [ ${#FILES[@]} -eq 0 ]; then
    echo "No .mov files found or provided."
    print_usage
    exit 0
fi

TOTAL=0
SUCCESS=0
SKIPPED=0
FAILED=0

convert_file() {
    local INPUT_FILE="$1"
    ((TOTAL++))

    if [ ! -f "$INPUT_FILE" ]; then
        echo "[$TOTAL] Skipping: '$INPUT_FILE' (not found)"
        ((FAILED++))
        return 1
    fi

    local ext="${INPUT_FILE##*.}"
    if [[ "${ext,,}" != "mov" ]]; then
        echo "[$TOTAL] Skipping: '$INPUT_FILE' (not a .mov file)"
        ((SKIPPED++))
        return 0
    fi

    local OUTPUT_FILE="${INPUT_FILE%.*}.mp4"

    if [ -f "$OUTPUT_FILE" ]; then
        echo "[$TOTAL] Skipping: '$INPUT_FILE' -> '$OUTPUT_FILE' (output exists)"
        ((SKIPPED++))
        return 0
    fi

    echo "[$TOTAL] Converting: $INPUT_FILE"
    echo "    Output: $OUTPUT_FILE"

    local ORIGINAL_SIZE
    ORIGINAL_SIZE=$(du -h "$INPUT_FILE" | cut -f1)
    echo "    Original size: $ORIGINAL_SIZE"

    if [ "$DRY_RUN" -eq 1 ]; then
        echo "    (dry-run) Would run: ffmpeg -i '$INPUT_FILE' ... -> '$OUTPUT_FILE'"
        echo "    (dry-run) Would not move original to Trash"
        ((SUCCESS++))
        return 0
    fi

    if ! ffmpeg -y -i "$INPUT_FILE" \
        -c:v libx264 -crf 28 -preset medium \
        -c:a aac -b:a 128k \
        -vf "scale='min(1920,iw)':'min(1080,ih)':force_original_aspect_ratio=decrease" \
        -movflags +faststart \
        "$OUTPUT_FILE"; then
        echo "    ✗ Conversion failed for: $INPUT_FILE"
        ((FAILED++))
        [ -f "$OUTPUT_FILE" ] && rm -f "$OUTPUT_FILE"
        return 1
    fi

    if [ -f "$OUTPUT_FILE" ]; then
        local NEW_SIZE
        NEW_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
        echo "    ✓ Conversion successful — New size: $NEW_SIZE"

        echo "    Moving original to Trash: $INPUT_FILE"
        if mv "$INPUT_FILE" "$HOME/.Trash/"; then
            echo "    ✓ Moved original to Trash"
        else
            echo "    ✗ Failed to move original to Trash"
        fi

        ((SUCCESS++))
        return 0
    else
        echo "    ✗ Conversion finished but output not found: $OUTPUT_FILE"
        ((FAILED++))
        return 1
    fi
}

for f in "${FILES[@]}"; do
    convert_file "$f"
done

echo
echo "Summary:"
echo "  Total:   $TOTAL"
echo "  Success: $SUCCESS"
echo "  Skipped: $SKIPPED"
echo "  Failed:  $FAILED"

echo "Done."
