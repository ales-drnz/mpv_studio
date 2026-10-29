#!/usr/bin/env bash
# Serves build/web as GitHub Pages does, under /mpv_studio/ and without
# COOP or COEP headers, and runs tool/web_smoke.js against it. Needs a
# build made with --base-href /mpv_studio/ and the playwright package.
#
#   tool/web_smoke.sh <screenshot.png>
set -euo pipefail

shot="${1:?usage: tool/web_smoke.sh <screenshot.png>}"
root="$(mktemp -d)"
trap 'kill "$server" 2>/dev/null; rm -rf "$root"' EXIT
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
sleep 1

node tool/web_smoke.js http://127.0.0.1:8765/mpv_studio/ "$shot"
