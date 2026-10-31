#!/usr/bin/env bash
# Serves build/web as GitHub Pages does, under /mpv_studio/ and without
# COOP or COEP headers, and runs tool/web_smoke.js against it in a browser
# of playwright (chromium or firefox). Needs a build made with
# --base-href /mpv_studio/ and the playwright package.
#
#   tool/web_smoke.sh <chromium|firefox> <screenshot.png>
set -euo pipefail

engine="${1:?usage: tool/web_smoke.sh <chromium|firefox> <screenshot.png>}"
shot="${2:?usage: tool/web_smoke.sh <chromium|firefox> <screenshot.png>}"
root="$(mktemp -d)"
trap 'kill "${server:-}" 2>/dev/null || true; rm -rf "$root"' EXIT
cp -r build/web "$root/mpv_studio"

python3 - "$root" <<'PY' &
import functools, http.server, sys

class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass

Handler.extensions_map['.mjs'] = 'text/javascript'
Handler.extensions_map['.wasm'] = 'application/wasm'
http.server.ThreadingHTTPServer(
    ('127.0.0.1', 8765), functools.partial(Handler, directory=sys.argv[1])
).serve_forever()
PY
server=$!
# Until the server answers: python can take more than a second to bind on a
# slow runner, and the page would then fail to load.
for _ in $(seq 50); do
  curl -sf -o /dev/null http://127.0.0.1:8765/mpv_studio/ && break
  sleep 0.2
done
curl -sf -o /dev/null http://127.0.0.1:8765/mpv_studio/ ||
  { echo "web_smoke: the server did not start" >&2; exit 1; }

node tool/web_smoke.js "$engine" http://127.0.0.1:8765/mpv_studio/ "$shot"
