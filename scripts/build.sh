#!/bin/bash
# Cross-compile aphex.c → ARM64 dsp.so via Docker, package as tar.gz.
#
# Uses the docker build (COPY src/) + docker create + docker cp pattern because
# `-v` bind mounts fail silently on Windows Docker (container sees empty dirs).
# Also explicitly checks the container exit code — `set -e` does NOT propagate
# `docker start` failures on Git Bash, so a failed compile would otherwise ship
# the previous successful dsp.so.
set -e

MODULE_ID="aphex"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$SCRIPT_DIR/.."

echo "Building $MODULE_ID for ARM64 (aarch64)..."

# Build the cross-compile image with src/ COPY'd in (Windows bind mounts fail).
docker build -t ${MODULE_ID}-builder -f "$ROOT/scripts/Dockerfile" "$ROOT"

# Create a one-shot container that compiles + reports back.
CONTAINER_ID=$(docker create ${MODULE_ID}-builder bash -c "
    set -e
    mkdir -p /build/dist/$MODULE_ID
    aarch64-linux-gnu-gcc \
      -O2 -shared -fPIC -ffast-math \
      -Wall -Wno-unused -Wno-format \
      -I /build/src/dsp \
      -o /build/dist/$MODULE_ID/dsp.so \
      /build/src/dsp/$MODULE_ID.c \
      -lm
    cp /build/src/module.json /build/dist/$MODULE_ID/
    echo '=== Build complete ==='
    ls -la /build/dist/$MODULE_ID/
    echo '=== GLIBC check ==='
    strings /build/dist/$MODULE_ID/dsp.so | grep GLIBC_ | sort -uV
")

docker start -a "$CONTAINER_ID"

# Explicit exit-code check — set -e does not catch docker start failures on
# Windows Git Bash / MSYS. Without this, a failed compile silently deploys
# the previous .so.
EXIT_CODE=$(docker inspect "$CONTAINER_ID" --format='{{.State.ExitCode}}')
if [ "$EXIT_CODE" != "0" ]; then
    echo "ERROR: Compile failed (exit $EXIT_CODE). Check output above."
    docker rm "$CONTAINER_ID" > /dev/null
    exit 1
fi

# Extract artifacts.
mkdir -p "$ROOT/dist/$MODULE_ID"
docker cp "$CONTAINER_ID:/build/dist/$MODULE_ID/dsp.so"      "$ROOT/dist/$MODULE_ID/dsp.so"
docker cp "$CONTAINER_ID:/build/dist/$MODULE_ID/module.json" "$ROOT/dist/$MODULE_ID/module.json"
docker rm "$CONTAINER_ID" > /dev/null

# Create release tarball.
cd "$ROOT/dist"
tar -czf ${MODULE_ID}-module.tar.gz ${MODULE_ID}/
echo "Built: dist/${MODULE_ID}/ and dist/${MODULE_ID}-module.tar.gz"
ls -lh "$ROOT/dist/${MODULE_ID}/dsp.so"
