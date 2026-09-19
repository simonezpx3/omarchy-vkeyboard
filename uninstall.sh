#!/usr/bin/env bash
# Virtual Keyboard & Layout — Uninstallation Script
set -euo pipefail

TARGET_PLUGIN_DIR="${HOME}/.config/omarchy/plugins/simonez.vkeyboard"
TARGET_BIN="${HOME}/.local/bin/vkeyboard-ctl"
SHELL_CONFIG="${HOME}/.config/omarchy/shell.json"

echo "=== Uninstalling Virtual Keyboard ==="

rm -rf "${TARGET_PLUGIN_DIR}"
rm -f "${TARGET_BIN}"

if [[ -f "$SHELL_CONFIG" ]] && command -v jq >/dev/null 2>&1; then
  tmp_json=$(mktemp)
  chmod 0600 "$tmp_json"
  jq '.bar.layout.right = [.bar.layout.right[] | select((.id? != "simonez.vkeyboard") and (. != "simonez.vkeyboard"))]' "$SHELL_CONFIG" > "$tmp_json" && mv "$tmp_json" "$SHELL_CONFIG"
  echo "  [OK] Removed from shell.json"
fi

omarchy restart shell || true
echo "=== Uninstallation complete ==="
