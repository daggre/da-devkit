#!/usr/bin/env bash
# Turn a screen recording into a README-sized GIF.
#
#   tools/make-gif.sh raw/anims-menu.mp4 docs/media/anims-menu.gif
#   tools/make-gif.sh raw/editor.mp4 docs/media/editor.gif --start 3 --duration 12
#
# Never record straight to GIF — capture MP4 (ShareX, OBS) and convert here. This uses
# ffmpeg's two-pass palette method: pass one derives a 256-colour palette from the
# actual footage, pass two encodes against it. A single-pass GIF of the same clip is
# roughly 3-5x larger and visibly banded, which matters when the result sits at the top
# of the README.
#
# Requires ffmpeg:  sudo apt install ffmpeg

set -euo pipefail

IN="${1:-}"
OUT="${2:-}"
shift 2 2>/dev/null || true

WIDTH=900        # GitHub's README column is ~880px; wider just gets downscaled
FPS=15           # below 12 looks choppy, above 15 costs size for little gain
START=""
DURATION=""
MAX_MB=5

while [[ $# -gt 0 ]]; do
    case "$1" in
        --start)    START="$2"; shift 2 ;;
        --duration) DURATION="$2"; shift 2 ;;
        --width)    WIDTH="$2"; shift 2 ;;
        --fps)      FPS="$2"; shift 2 ;;
        *) echo "unknown option: $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$IN" || -z "$OUT" ]]; then
    echo "usage: $0 <input.mp4> <output.gif> [--start S] [--duration S] [--width PX] [--fps N]" >&2
    exit 1
fi

if ! command -v ffmpeg >/dev/null; then
    echo "ffmpeg is not installed. Run: sudo apt install ffmpeg" >&2
    exit 1
fi

[[ -f "$IN" ]] || { echo "no such file: $IN" >&2; exit 1; }

mkdir -p "$(dirname "$OUT")"

TRIM=()
[[ -n "$START" ]]    && TRIM+=(-ss "$START")
[[ -n "$DURATION" ]] && TRIM+=(-t "$DURATION")

PALETTE="$(mktemp --suffix=.png)"
trap 'rm -f "$PALETTE"' EXIT

FILTERS="fps=$FPS,scale=$WIDTH:-1:flags=lanczos"

echo "==> pass 1: palette"
ffmpeg -loglevel error -y "${TRIM[@]}" -i "$IN" \
    -vf "$FILTERS,palettegen=stats_mode=diff" "$PALETTE"

echo "==> pass 2: encode"
# bayer dithering keeps flat UI panels from getting noisy; diff stats favour the
# moving region, which is what you actually want in a screen capture.
ffmpeg -loglevel error -y "${TRIM[@]}" -i "$IN" -i "$PALETTE" \
    -lavfi "$FILTERS[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle" \
    "$OUT"

SIZE_B=$(stat -c%s "$OUT")
SIZE_MB=$(awk "BEGIN{printf \"%.1f\", $SIZE_B/1048576}")
DIMS=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height \
       -of csv=p=0:s=x "$OUT" 2>/dev/null || echo "?")

echo
echo "==> $OUT"
echo "    ${DIMS}  ${SIZE_MB} MB"

if (( $(awk "BEGIN{print ($SIZE_MB > $MAX_MB)}") )); then
    echo
    echo "!! Over ${MAX_MB} MB — this will be slow on mobile. Options, cheapest first:" >&2
    echo "     --duration 10      shorter clip (biggest lever by far)" >&2
    echo "     --fps 12           fewer frames" >&2
    echo "     --width 800        smaller" >&2
    exit 1
fi
