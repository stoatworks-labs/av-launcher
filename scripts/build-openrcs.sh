#!/bin/bash
# Build the openrcs launcher .app — bundles openrcs-server + the openrcs config.
# Sign + notarize separately (Developer ID + notarytool). Example:
#   OPENRCS_SERVER=~/Projects/openrcs/target/aarch64-apple-darwin/release/openrcs-server \
#     scripts/build-openrcs.sh
set -euo pipefail
cd "$(dirname "$0")/.."
SERVER="${OPENRCS_SERVER:-$HOME/Projects/openrcs/target/aarch64-apple-darwin/release/openrcs-server}"
TARGET="${TARGET:-aarch64-apple-darwin}"
# Stage the bundle config: relative command (resolved against the .app's
# Resources), and no cwd so the server runs from the writable app-config dir.
sed -e 's#^command = .*#command = "openrcs-server"#' -e '/^cwd = /d' \
  launchers/openrcs.toml > src-tauri/launcher.toml
cp "$SERVER" src-tauri/openrcs-server
npm run tauri -- build --config src-tauri/tauri.openrcs.conf.json --bundles app --target "$TARGET"
git checkout -- src-tauri/launcher.toml 2>/dev/null || true   # leave the tree clean
echo "built: src-tauri/target/$TARGET/release/bundle/macos/openrcs.app"
