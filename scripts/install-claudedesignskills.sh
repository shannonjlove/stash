#!/usr/bin/env bash
# Clone shannonjlove/claudedesignskills and install its plugins for Cursor.
set -euo pipefail

REPO_URL="${CLAUDEDESIGNSKILLS_REPO:-https://github.com/shannonjlove/claudedesignskills.git}"
CLONE_DIR="${CLAUDEDESIGNSKILLS_DIR:-${HOME}/.cache/claudedesignskills}"
DEST="${CURSOR_PLUGIN_LOCAL_ROOT:-${HOME}/.cursor/plugins/local}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="${SCRIPT_DIR}/cursor/install_cursor_plugins.py"

mkdir -p "$(dirname "${CLONE_DIR}")"
if [[ -d "${CLONE_DIR}/.git" ]]; then
  git -C "${CLONE_DIR}" fetch --depth 1 origin
  git -C "${CLONE_DIR}" reset --hard FETCH_HEAD
else
  git clone --depth 1 "${REPO_URL}" "${CLONE_DIR}"
fi

if [[ -f "${CLONE_DIR}/scripts/cursor/install_cursor_plugins.py" ]]; then
  python3 "${CLONE_DIR}/scripts/cursor/install_cursor_plugins.py" --root "${CLONE_DIR}" --dest "${DEST}"
elif [[ -f "${INSTALLER}" ]]; then
  python3 "${INSTALLER}" --root "${CLONE_DIR}" --dest "${DEST}"
else
  echo "Missing Cursor installer. Expected ${CLONE_DIR}/scripts/cursor/install_cursor_plugins.py" >&2
  exit 1
fi
