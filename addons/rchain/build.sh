#!/usr/bin/env bash
# Build the RChain crypto GDExtension and install the shared library.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GDEXT_DIR="$DIR/gdext"
BIN_DIR="$DIR/bin"

echo "==> Building RChain GDExtension (release)..."
(cd "$GDEXT_DIR" && cargo build --release)

mkdir -p "$BIN_DIR"
cp "$GDEXT_DIR/target/release/librchain_gdext.so" "$BIN_DIR/"

echo "==> Installed to $BIN_DIR/librchain_gdext.so"
