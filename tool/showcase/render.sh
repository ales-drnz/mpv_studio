#!/usr/bin/env bash
# Renders a showcase scene to a GIF, an MP4 and three stills.
#
#   tool/showcase/render.sh <scene> [out_dir]
#
# <scene> names test/showcase/<scene>_scene_test.dart. The scene plays in
# a widget test that writes one PNG per frame; ffmpeg then encodes them.
# It plays twice: once at the GIF's rate with the live readouts (the
# spectrum, the playhead) stepping a few times a second, as each step
# redraws a whole curve or column and costs a GIF dearly; once at a high
# rate with everything moving every frame, for the MP4.
#
#   <out_dir>/<scene>.gif         looping GIF, palette made for the scene
#   <out_dir>/<scene>.mp4         H.264
#   <out_dir>/<scene>_start.png   first, middle and last frames of the GIF
#   <out_dir>/<scene>_middle.png
#   <out_dir>/<scene>_end.png
#
# out_dir defaults to build/showcase. The frames are deleted afterwards.
# Knobs (environment):
#
#   GIF_FPS=20          GIF frame rate (a divisor of 100: GIF delays are
#                       in hundredths of a second)
#   GIF_UPDATE_HZ=10    readout steps per second in the GIF
#   MAX_MB=1.6          GIF size budget: the palette starts at 128 colours
#                       and shrinks until the GIF fits (the app is mostly
#                       greys, the cover art flat colours)
#   COLORS=             a fixed palette size instead of the budget search
#   STATS=full          palettegen stats_mode: full keeps the colours of
#                       still parts (the cover); diff favours what moves
#   DITHER=none         paletteuse dither (sierra2_4a, bayer...); none
#                       keeps flat areas flat, so unchanged pixels stay
#                       unchanged from frame to frame
#   BAYER_SCALE=5       the bayer pattern scale, with DITHER=bayer
#   MP4_FPS=50          MP4 frame rate; MP4=0 skips the MP4
#   CRF=16              x264 quality (lower is better)
#   SCALE=1             capture pixels per logical pixel; above 1 frames
#                       are scaled back down with lanczos
#   KEEP_FRAMES=1       keeps the frames in <out_dir>/.frames-<scene>-*
set -euo pipefail

scene=${1:?usage: render.sh <scene> [out_dir]}
root=$(cd "$(dirname "$0")/../.." && pwd)
out=${2:-$root/build/showcase}
mkdir -p "$out"
out=$(cd "$out" && pwd)
test_file="test/showcase/${scene}_scene_test.dart"
gif_fps=${GIF_FPS:-20}
gif_hz=${GIF_UPDATE_HZ:-10}
colors=${COLORS:-}
max_mb=${MAX_MB:-1.6}
stats=${STATS:-full}
dither=${DITHER:-none}
bayer_scale=${BAYER_SCALE:-5}
mp4_fps=${MP4_FPS:-50}
crf=${CRF:-16}
scale=${SCALE:-1}

[[ -f "$root/$test_file" ]] || { echo "no scene at $test_file" >&2; exit 1; }
if (( 100 % gif_fps != 0 )); then
  echo "GIF_FPS ($gif_fps) must divide 100" >&2
  exit 1
fi

gif_frames="$out/.frames-$scene-gif"
mp4_frames="$out/.frames-$scene-mp4"
cleanup() {
  [[ -n "${KEEP_FRAMES:-}" ]] || rm -rf "$gif_frames" "$mp4_frames"
}
trap cleanup EXIT

# play <frames dir> <fps> [update Hz]: runs the scene, one PNG a frame.
play() {
  local dir=$1 fps=$2 hz=${3:-}
  rm -rf "$dir"
  mkdir -p "$dir"
  echo "== rendering $scene at $fps fps${hz:+, readouts at $hz Hz}"
  (
    cd "$root"
    SHOWCASE_OUT="$dir" SHOWCASE_FPS="$fps" SHOWCASE_SCALE="$scale" \
      SHOWCASE_UPDATE_HZ="$hz" \
      flutter test --run-skipped --tags showcase "$test_file"
  )
  local count
  count=$(find "$dir" -name 'frame_*.png' | wc -l)
  (( count > 0 )) || { echo "the scene wrote no frames" >&2; exit 1; }
}

count() { find "$1" -name 'frame_*.png' | wc -l; }
mb() { awk -v b="$(stat -c %s "$1")" 'BEGIN { printf "%.2f MB", b / 1048576 }'; }

# The logical size: the frame size divided by the capture scale.
size_of() {
  local pw ph
  IFS=, read -r pw ph < <(ffprobe -v error -select_streams v:0 \
    -show_entries stream=width,height -of csv=p=0 "$1/frame_00000.png")
  local w h
  w=$(awk -v p="$pw" -v s="$scale" 'BEGIN { printf "%d", p / s + 0.5 }')
  h=$(awk -v p="$ph" -v s="$scale" 'BEGIN { printf "%d", p / s + 0.5 }')
  echo "scale=${w}:${h}:flags=lanczos"
}

play "$gif_frames" "$gif_fps" "$gif_hz"
size=$(size_of "$gif_frames")
if [[ "$dither" == bayer ]]; then
  use="paletteuse=dither=bayer:bayer_scale=${bayer_scale}:diff_mode=rectangle"
else
  use="paletteuse=dither=${dither}:diff_mode=rectangle"
fi
encode_gif() {
  ffmpeg -v error -y -framerate "$gif_fps" -i "$gif_frames/frame_%05d.png" \
    -vf "${size},split[a][b];[a]palettegen=stats_mode=${stats}:max_colors=$1[p];[b][p]${use}" \
    -loop 0 "$out/$scene.gif"
}
if [[ -n "$colors" ]]; then
  encode_gif "$colors"
else
  limit=$(awk -v m="$max_mb" 'BEGIN { printf "%d", m * 1048576 }')
  for colors in 128 96 72 56 48 40 32; do
    encode_gif "$colors"
    (( $(stat -c %s "$out/$scene.gif") <= limit )) && break
  done
fi

n=$(count "$gif_frames")
still() {
  ffmpeg -v error -y -i "$(printf '%s/frame_%05d.png' "$gif_frames" "$1")" \
    -vf "$size" "$out/${scene}_$2.png"
}
still 0 start
still $(( n / 2 )) middle
still $(( n - 1 )) end
echo "== $out/$scene.gif: $(mb "$out/$scene.gif"), $n frames at $gif_fps fps, $colors colours"

if [[ "${MP4:-1}" != 0 ]]; then
  play "$mp4_frames" "$mp4_fps"
  # x264 in 4:2:0 needs even sides: drop an odd last row or column.
  ffmpeg -v error -y -framerate "$mp4_fps" -i "$mp4_frames/frame_%05d.png" \
    -vf "$(size_of "$mp4_frames"),crop=trunc(iw/2)*2:trunc(ih/2)*2:0:0" \
    -c:v libx264 -preset slow -crf "$crf" -pix_fmt yuv420p \
    -movflags +faststart "$out/$scene.mp4"
  echo "== $out/$scene.mp4: $(mb "$out/$scene.mp4"), $(count "$mp4_frames") frames at $mp4_fps fps"
fi
