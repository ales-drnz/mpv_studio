#!/usr/bin/env bash
#
# Installs the MPV Studio desktop entry + themed icon into the current user's
# XDG data dir so the window shows the app icon instead of the Wayland/X11
# fallback.
#
# WHY THIS IS NEEDED
# ------------------
# On Wayland (KWin, Mutter, wlroots, …) a window cannot carry its own pixmap
# icon — the xdg-shell protocol only exposes an `app_id`. Compositors resolve
# the icon by matching that `app_id` to a `<app_id>.desktop` file on the
# system and reading its `Icon=` key from the freedesktop icon theme.
#
# The Flutter GTK runner already sets the app_id to APPLICATION_ID
# (`studio.mpv.mpv_studio`) via `g_set_prgname()` in my_application.cc, so all
# that's missing is the desktop entry + a themed icon of the same name. This
# script installs both. `flutter run` does not do this automatically, so run
# it once (re-run after changing the icon artwork).
#
# Usage:  linux/packaging/install-linux-icon.sh [--uninstall]
set -euo pipefail

APP_ID="studio.mpv.mpv_studio"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
APPS_DIR="$DATA_HOME/applications"
ICONS_ROOT="$DATA_HOME/icons/hicolor"

uninstall() {
  echo "Removing MPV Studio desktop integration…"
  rm -f "$APPS_DIR/$APP_ID.desktop"
  for size in 16 24 32 48 64 128 256 512; do
    rm -f "$ICONS_ROOT/${size}x${size}/apps/$APP_ID.png"
  done
  command -v gtk-update-icon-cache >/dev/null && \
    gtk-update-icon-cache -f -t "$ICONS_ROOT" >/dev/null 2>&1 || true
  command -v update-desktop-database >/dev/null && \
    update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
  echo "Done."
  exit 0
}

[[ "${1:-}" == "--uninstall" ]] && uninstall

SRC_ICON="$SCRIPT_DIR/$APP_ID.png"
SRC_DESKTOP="$SCRIPT_DIR/$APP_ID.desktop"
[[ -f "$SRC_ICON" ]]    || { echo "Missing source icon: $SRC_ICON" >&2; exit 1; }
[[ -f "$SRC_DESKTOP" ]] || { echo "Missing desktop entry: $SRC_DESKTOP" >&2; exit 1; }

# Pick a resizer: ImageMagick 7 (magick), IM6 (convert), or none.
resize() { # $1=size $2=dest
  if command -v magick >/dev/null;  then magick "$SRC_ICON" -resize "${1}x${1}" "$2"
  elif command -v convert >/dev/null; then convert "$SRC_ICON" -resize "${1}x${1}" "$2"
  else cp "$SRC_ICON" "$2"; fi   # no resizer: install full-res at every slot
}

echo "Installing themed icons into $ICONS_ROOT …"
for size in 16 24 32 48 64 128 256 512; do
  dest_dir="$ICONS_ROOT/${size}x${size}/apps"
  mkdir -p "$dest_dir"
  resize "$size" "$dest_dir/$APP_ID.png"
done

# Locate the most recent built binary so launching from the menu works in dev.
# Falls back to the bare name (packaged installs put `mpv_studio` on PATH).
BIN=""
for cfg in release profile debug; do
  cand="$PROJECT_ROOT/build/linux/x64/$cfg/bundle/mpv_studio"
  [[ -x "$cand" ]] && { BIN="$cand"; break; }
done

echo "Installing desktop entry into $APPS_DIR …"
mkdir -p "$APPS_DIR"
if [[ -n "$BIN" ]]; then
  sed "s|^Exec=.*|Exec=$BIN|" "$SRC_DESKTOP" > "$APPS_DIR/$APP_ID.desktop"
  echo "  Exec → $BIN"
else
  cp "$SRC_DESKTOP" "$APPS_DIR/$APP_ID.desktop"
  echo "  Exec → mpv_studio (no local build found; assuming it's on PATH)"
fi
chmod 644 "$APPS_DIR/$APP_ID.desktop"

command -v gtk-update-icon-cache >/dev/null && \
  gtk-update-icon-cache -f -t "$ICONS_ROOT" >/dev/null 2>&1 || true
command -v update-desktop-database >/dev/null && \
  update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true

echo "Done. Restart MPV Studio (and, if the icon still lags, your compositor) to pick it up."
