#!/usr/bin/env bash
# Virtual Keyboard & Layout — One-click Installation and Setup for Omarchy Linux
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_PLUGIN_DIR="${HOME}/.config/omarchy/plugins/simonez.vkeyboard"
TARGET_BIN_DIR="${HOME}/.local/bin"
SHELL_CONFIG="${HOME}/.config/omarchy/shell.json"

echo "=== Installing Virtual Keyboard & Layout Plugin ==="

# 1. Ensure Directories
mkdir -p "${TARGET_PLUGIN_DIR}" "${TARGET_BIN_DIR}"

# 2. Deploy Plugin Files
echo "-> Deploying plugin files to ${TARGET_PLUGIN_DIR}..."
rm -rf "${TARGET_PLUGIN_DIR}"
mkdir -p "${TARGET_PLUGIN_DIR}"
cp "${SCRIPT_DIR}/manifest.json" "${TARGET_PLUGIN_DIR}/"
cp "${SCRIPT_DIR}/BarWidget.qml" "${TARGET_PLUGIN_DIR}/"
cp "${SCRIPT_DIR}/Panel.qml" "${TARGET_PLUGIN_DIR}/"
cp -r "${SCRIPT_DIR}/views" "${TARGET_PLUGIN_DIR}/"
cp -r "${SCRIPT_DIR}/scripts" "${TARGET_PLUGIN_DIR}/"
if [[ -d "${SCRIPT_DIR}/assets" ]]; then
  cp -r "${SCRIPT_DIR}/assets" "${TARGET_PLUGIN_DIR}/"
fi

# Permissions Hardening
find "${TARGET_PLUGIN_DIR}" -type d -exec chmod 0755 {} +
find "${TARGET_PLUGIN_DIR}" -type f -exec chmod 0644 {} +
chmod 0755 "${TARGET_PLUGIN_DIR}/scripts/vkeyboard_ctl.py"

# 3. Deploy CLI tool (vkeyboard-ctl)
echo "-> Setting up CLI tool (vkeyboard-ctl)..."
ln -sfn "${SCRIPT_DIR}/bin/vkeyboard-ctl" "${TARGET_BIN_DIR}/vkeyboard-ctl"
chmod +x "${SCRIPT_DIR}/bin/vkeyboard-ctl" "${SCRIPT_DIR}/scripts/vkeyboard_ctl.py"

# 4. Validate Plugin Schema
echo "-> Validating plugin schema with Omarchy CLI..."
omarchy plugin validate "${TARGET_PLUGIN_DIR}"
echo "  [OK] Plugin manifest validated"

# 5. Register in shell.json if not present
if [[ -f "$SHELL_CONFIG" ]] && command -v jq >/dev/null 2>&1; then
  if ! jq -e '.bar.layout.right[] | select((.id? == "simonez.vkeyboard") or (. == "simonez.vkeyboard"))' "$SHELL_CONFIG" >/dev/null 2>&1; then
    echo "-> Adding simonez.vkeyboard to bar.layout.right in shell.json..."
    tmp_json=$(mktemp)
    chmod 0600 "$tmp_json"
    # Place right near keyboard layout
    jq '.bar.layout.right = [{"id": "simonez.vkeyboard", "showBadge": true}] + .bar.layout.right' "$SHELL_CONFIG" > "$tmp_json" && mv "$tmp_json" "$SHELL_CONFIG"
    echo "  [OK] shell.json updated"
  fi
fi

# 6. Reload / Restart Shell
echo "-> Restarting Omarchy Shell..."
if [[ -x "/usr/share/omarchy/bin/omarchy-restart-shell" ]]; then
  /usr/share/omarchy/bin/omarchy-restart-shell || true
elif command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins || true
fi

echo "=== Virtual Keyboard installed successfully! ==="
