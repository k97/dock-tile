#!/bin/bash
# Builds the vendored actool into the standalone compiler the app bundles.
# Output: Vendor/actool/target/release/docktile-actool
set -euo pipefail
cd "$(dirname "$0")/../Vendor/actool"
command -v cargo >/dev/null || { echo "error: Rust toolchain required — install via https://rustup.rs" >&2; exit 1; }
cargo build --release --locked
BIN=$(ls target/release/ | grep -x 'actool' || true)
cp "target/release/${BIN:-actool}" target/release/docktile-actool
strip target/release/docktile-actool
echo "built: $(pwd)/target/release/docktile-actool ($(du -h target/release/docktile-actool | cut -f1))"
