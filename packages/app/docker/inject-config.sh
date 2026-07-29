#!/usr/bin/env bash
# FILE_NAME: inject-config.sh
# DESCRIPTION: Inject APP_CONFIG_* into index.html + FE bundle at container start
# VERSION: 0.5.0
# REFERENCE: backstage/contrib/docker/frontend-with-nginx/docker/inject-config.sh
set -euo pipefail

config="$(
  jq -n 'env |
    with_entries(select(.key | startswith("APP_CONFIG_")) | .key |= sub("APP_CONFIG_"; "")) |
    to_entries |
    reduce .[] as $item (
      {}; setpath($item.key | split("_"); $item.value | try fromjson catch $item.value)
    )'
)"

echo "[T-01] Runtime app config: ${config}" >&2

if [ "${config}" = "{}" ]; then
  echo "[T-02] No APP_CONFIG_* set; leaving baked config" >&2
  exit 0
fi

compact="$(printf '%s' "${config}" | jq -cM .)"
export INJECT_CONFIG="${compact}"

python3 - <<'PY'
import json
import os
import re
from pathlib import Path

cfg = json.loads(os.environ["INJECT_CONFIG"])
html_path = Path("/usr/share/nginx/html/index.html")

# 1) Prefer patching <script type="backstage.io/config"> (new frontend system)
html = html_path.read_text()
pattern = re.compile(
    r'(<script type="backstage\.io/config">)(.*?)(</script>)',
    re.DOTALL,
)
match = pattern.search(html)
if match:
    sources = json.loads(match.group(2))
    if not isinstance(sources, list):
        raise SystemExit("backstage.io/config must be a JSON array")
    # Rewrite baked app/backend baseUrls in-place so DevTools never shows localhost
    for source in sources:
        data = source.get("data") or {}
        if "app" in cfg:
            data.setdefault("app", {}).update(cfg["app"])
        if "backend" in cfg:
            data.setdefault("backend", {}).update(cfg["backend"])
        if "auth" in cfg:
            data.setdefault("auth", {}).update(cfg["auth"])
        source["data"] = data
    sources = [s for s in sources if s.get("context") != "runtime-env"]
    sources.append({"context": "runtime-env", "data": cfg})
    new_block = (
        match.group(1)
        + json.dumps(sources, indent=2)
        + match.group(3)
    )
    html = html[: match.start()] + new_block + html[match.end() :]
    html_path.write_text(html)
    print("[T-03] Patched index.html backstage.io/config", flush=True)
else:
    print("[T-03] No backstage.io/config script in index.html", flush=True)

# 2) Replace __APP_INJECTED_RUNTIME_CONFIG__ inside a JS string literal.
# Source shape: (function(e="__APP_INJECTED_RUNTIME_CONFIG__"){...
# Must become: (function(e="{\"app\":...}"){...
# NEVER strip outer JSON braces — that produces a syntax error and blank UI.
needle = "__APP_INJECTED_RUNTIME_CONFIG__"
# Contents of a double-quoted JS string holding the JSON object text
escaped = json.dumps(json.dumps(cfg, separators=(",", ":")))[1:-1]
static = Path("/usr/share/nginx/html/static")
replaced = False
for path in static.glob("*.js"):
    text = path.read_text()
    if needle not in text:
        continue
    path.write_text(text.replace(needle, escaped, 1))
    print(f"[T-04] Injected runtime config into {path.name}", flush=True)
    replaced = True
if not replaced:
    print("[T-04] Runtime config already written (or placeholder absent)", flush=True)
PY
