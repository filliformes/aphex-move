#!/bin/bash
# Deploy aphex to a Move via scp.
#
# Notes:
# - SSH user is `ableton`, NOT `root` (Schwung modules are owned by ableton:users).
# - Flat scp into a pre-created directory (NOT `scp -r dist/aphex host:DEST/`,
#   which creates nested aphex/aphex/ on subsequent installs).
# - There is NO `schwung` systemd service — modules are loaded by MoveOriginal
#   via dlopen. To reload after deploy: remove + re-add the module from a slot
#   on device (reloads .so) or power-cycle the Move (also reloads module.json).
set -e

MODULE_ID="aphex"
MOVE_HOST="${MOVE_HOST:-move.local}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$SCRIPT_DIR/.."
DEST="/data/UserData/schwung/modules/sound_generators/$MODULE_ID"

if [ ! -f "$ROOT/dist/$MODULE_ID/dsp.so" ]; then
    echo "dsp.so not found. Run scripts/build.sh first."
    exit 1
fi

echo "Installing $MODULE_ID to ableton@$MOVE_HOST..."
ssh "ableton@$MOVE_HOST" "mkdir -p $DEST"
HELP=""; [ -f "$ROOT/dist/$MODULE_ID/help.json" ] && HELP="$ROOT/dist/$MODULE_ID/help.json"
scp "$ROOT/dist/$MODULE_ID/dsp.so" "$ROOT/dist/$MODULE_ID/module.json" $HELP "ableton@$MOVE_HOST:$DEST/"
ssh "ableton@$MOVE_HOST" "chown -R ableton:users $DEST && chmod 755 $DEST/dsp.so"

echo "Installed to $DEST"
echo "On device: remove + re-add the module to reload, or power-cycle to reload module.json."
