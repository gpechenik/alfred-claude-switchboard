#!/bin/bash

# Install/update this workflow into Alfred as a LIVE development copy whose script
# actions point at THIS repo by absolute path — so editing workflow/scripts/*.sh
# takes effect immediately (no rebuild, no reimport). Re-run after any change to
# workflow/info.plist (new keyword / config var) to resync the live plist.
#
#   ./dev/install-live.sh
#
# (For a normal install, use the packaged dist/*.alfredworkflow instead.)

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SRC_PLIST="$REPO/workflow/info.plist"
SCRIPTS_DIR="$REPO/workflow/scripts"

# Locate Alfred's workflows directory (honors a synced prefs folder if set).
SYNC="$(defaults read com.runningwithcrayons.Alfred-Preferences syncfolder 2>/dev/null || true)"
SYNC="${SYNC/#\~/$HOME}"
LOCAL_PREFS="$HOME/Library/Application Support/Alfred/Alfred.alfredpreferences"
if [[ -n "$SYNC" && -d "$SYNC/Alfred.alfredpreferences/workflows" ]]; then
  WORKFLOWS="$SYNC/Alfred.alfredpreferences/workflows"
elif [[ -d "$LOCAL_PREFS/workflows" ]]; then
  WORKFLOWS="$LOCAL_PREFS/workflows"
else
  echo "❌ Alfred workflows dir not found (synced='$SYNC', local='$LOCAL_PREFS')" >&2
  exit 1
fi

TARGET="$WORKFLOWS/user.workflow.claude-switchboard"
mkdir -p "$TARGET"

# Write an absolute-path copy of the plist (./scripts/X.sh → $SCRIPTS_DIR/X.sh).
SCRIPTS_DIR="$SCRIPTS_DIR" python3 - "$SRC_PLIST" "$TARGET/info.plist" <<'PY'
import plistlib, os, re, sys
src, dst = sys.argv[1], sys.argv[2]
scripts = os.environ["SCRIPTS_DIR"]
p = plistlib.load(open(src, "rb"))
for o in p["objects"]:
    c = o.get("config", {})
    if c.get("script"):
        c["script"] = re.sub(r'\./scripts/([\w.-]+\.sh)', scripts + r'/\1', c["script"])
# Preserve any already-configured workflow variables on re-install. (Alfred also
# keeps config values in a separate prefs.plist, which we never touch.)
if os.path.exists(dst):
    try:
        old = plistlib.load(open(dst, "rb"))
        if old.get("variables"):
            p["variables"] = old["variables"]
    except Exception:
        pass
plistlib.dump(p, open(dst, "wb"))
PY

cp -f "$REPO/workflow/icon.png" "$TARGET/icon.png" 2>/dev/null || true
chmod +x "$SCRIPTS_DIR"/*.sh

echo "✅ Live workflow installed → $TARGET"
echo "   scripts run from: $SCRIPTS_DIR  (edit there; changes are live)"
echo "   Reload Alfred (open it) to pick up the workflow, then Configure Workflow."
