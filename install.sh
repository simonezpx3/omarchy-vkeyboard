#!/usr/bin/env bash
# Virtual Keyboard & Layout — One-click Installation and Setup for Omarchy Linux
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_PLUGIN_DIR="${HOME}/.config/omarchy/plugins/simonez.vkeyboard"
TARGET_BIN_DIR="${HOME}/.local/bin"
SHELL_CONFIG="${HOME}/.config/omarchy/shell.json"

echo "=== Installing Virtual Keyboard & Layout Plugin ==="

# 1. Ensure Directories & Validate Target
if [[ -z "${HOME:-}" || "${TARGET_PLUGIN_DIR}" != "${HOME}/.config/omarchy/plugins/simonez.vkeyboard" ]]; then
  echo "Error: Invalid or insecure target plugin directory: ${TARGET_PLUGIN_DIR}" >&2
  exit 1
fi
mkdir -p "${TARGET_PLUGIN_DIR}" "${TARGET_BIN_DIR}"

# 2. Deploy Plugin Files atomically via Staging Directory
STAGING_DIR="${TARGET_PLUGIN_DIR}.tmp.$$"
trap 'rm -rf "${STAGING_DIR}"' EXIT INT TERM

echo "-> Preparing atomic staging deploy at ${STAGING_DIR}..."
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"
cp "${SCRIPT_DIR}/manifest.json" "${STAGING_DIR}/"
cp "${SCRIPT_DIR}/Service.qml" "${STAGING_DIR}/"
cp "${SCRIPT_DIR}/BarWidget.qml" "${STAGING_DIR}/"
cp "${SCRIPT_DIR}/Panel.qml" "${STAGING_DIR}/"
cp -r "${SCRIPT_DIR}/views" "${STAGING_DIR}/"
cp -r "${SCRIPT_DIR}/scripts" "${STAGING_DIR}/"
if [[ -d "${SCRIPT_DIR}/bin" ]]; then
  cp -r "${SCRIPT_DIR}/bin" "${STAGING_DIR}/"
fi
if [[ -d "${SCRIPT_DIR}/assets" ]]; then
  cp -r "${SCRIPT_DIR}/assets" "${STAGING_DIR}/"
fi

# Permissions Hardening in Staging
find "${STAGING_DIR}" -type d -exec chmod 0755 {} +
find "${STAGING_DIR}" -type f -exec chmod 0644 {} +
chmod 0755 "${STAGING_DIR}/scripts/vkeyboard_ctl.py"
if [[ -f "${STAGING_DIR}/bin/vkeyboard-ctl" ]]; then
  chmod 0755 "${STAGING_DIR}/bin/vkeyboard-ctl"
fi

# 3. Validate Staging Schema before swap
echo "-> Validating plugin schema in staging..."
omarchy plugin validate "${STAGING_DIR}"
echo "  [OK] Plugin manifest validated in staging"

# 4. Atomic Swap
echo "-> Activating plugin deployment atomically..."
BACKUP_DIR="${TARGET_PLUGIN_DIR}.old.$$"
if [[ -d "${TARGET_PLUGIN_DIR}" ]]; then
  mv "${TARGET_PLUGIN_DIR}" "${BACKUP_DIR}"
fi
mv "${STAGING_DIR}" "${TARGET_PLUGIN_DIR}"
rm -rf "${BACKUP_DIR}"
trap - EXIT INT TERM

# 5. Deploy CLI tool symlink (vkeyboard-ctl)
echo "-> Setting up CLI tool (vkeyboard-ctl)..."
ln -sfn "${TARGET_PLUGIN_DIR}/bin/vkeyboard-ctl" "${TARGET_BIN_DIR}/vkeyboard-ctl"
chmod +x "${TARGET_PLUGIN_DIR}/bin/vkeyboard-ctl" "${TARGET_PLUGIN_DIR}/scripts/vkeyboard_ctl.py"

# 5. Register in shell.json if not present
if [[ -f "$SHELL_CONFIG" ]] && command -v jq >/dev/null 2>&1; then
  if ! jq -e '.bar.layout.right[] | select((.id? == "simonez.vkeyboard") or (. == "simonez.vkeyboard"))' "$SHELL_CONFIG" >/dev/null 2>&1; then
    echo "-> Adding simonez.vkeyboard to bar.layout.right in shell.json..."
    cp -p "$SHELL_CONFIG" "${SHELL_CONFIG}.bak"
    tmp_json=$(mktemp)
    trap 'rm -f "${tmp_json}"' EXIT INT TERM
    chmod 0600 "$tmp_json"
    # Place right near keyboard layout
    jq '.bar.layout.right = [{"id": "simonez.vkeyboard", "showBadge": true}] + .bar.layout.right' "$SHELL_CONFIG" > "$tmp_json" && mv "$tmp_json" "$SHELL_CONFIG"
    trap - EXIT INT TERM
    echo "  [OK] shell.json updated (backup saved to ${SHELL_CONFIG}.bak)"
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
