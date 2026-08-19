#!/usr/bin/env bash
# Copy example Mountain Duck bookmarks into generated/ (gitignored).
# Substitutes usernames from env. Never writes passwords into .duck files.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KOOFR_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SRC="${SCRIPT_DIR}/bookmarks"
OUT="${SCRIPT_DIR}/generated"
ENV_FILE="${KOOFR_ENV:-${KOOFR_DIR}/.env}"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

KOOFR2_USER="${KOOFR2_USER:-shannonjlove@mac.com}"
IDRIVE_E2_VA_ACCESS_KEY="${IDRIVE_E2_VA_ACCESS_KEY:-}"
IDRIVE_E2_OR_ACCESS_KEY="${IDRIVE_E2_OR_ACCESS_KEY:-}"

mkdir -p "${OUT}"
python3 - "${SRC}" "${OUT}" "${KOOFR2_USER}" "${IDRIVE_E2_VA_ACCESS_KEY}" "${IDRIVE_E2_OR_ACCESS_KEY}" <<'PY'
import pathlib
import sys
import xml.etree.ElementTree as ET

src, out, koofr_user, va_key, or_key = sys.argv[1:6]
out_dir = pathlib.Path(out)

# plist uses Apple DTD; parse without resolving the remote DTD.
parser = ET.XMLParser()
# ElementTree 3.8+ still tries to load the DOCTYPE. Strip it first.


def load_plist(path: pathlib.Path) -> ET.Element:
    text = path.read_text(encoding="utf-8")
    text = text.replace(
        '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n',
        "",
    )
    return ET.fromstring(text)


def plist_set(root: ET.Element, key: str, value: str) -> None:
    children = list(root)
    for i, el in enumerate(children):
        if el.tag == "key" and (el.text or "") == key:
            nxt = children[i + 1]
            nxt.text = value
            return
    raise SystemExit(f"missing plist key {key}")


def dump_plist(root: ET.Element, dest: pathlib.Path) -> None:
    body = ET.tostring(root, encoding="unicode")
    dest.write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" '
        '"http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
        f"{body}\n",
        encoding="utf-8",
    )


mapping = {
    "koofr2.duck.example": ("koofr2.duck", "Username", koofr_user),
    "koofr2-stash-media.duck.example": ("koofr2-stash-media.duck", "Username", koofr_user),
    "idrivee2-virginia.duck.example": ("idrivee2-virginia.duck", "Username", va_key),
    "idrivee2-oregon.duck.example": ("idrivee2-oregon.duck", "Username", or_key),
}

for name, (dest_name, key, value) in mapping.items():
    root = load_plist(pathlib.Path(src) / name)
    dict_el = root.find("dict")
    if dict_el is None:
        raise SystemExit(f"{name}: no dict")
    plist_set(dict_el, key, value)
    dest = out_dir / dest_name
    dump_plist(root, dest)
    print(f"WROTE {dest}")
PY

if [[ -n "${KOOFR2_APP_PASSWORD:-}" ]]; then
  obscured="$(rclone obscure "${KOOFR2_APP_PASSWORD}")"
  cat > "${OUT}/rclone-koofr2.conf" <<EOF
[koofr2]
type = webdav
url = ${KOOFR2_WEBDAV_URL:-https://app.koofr.net/dav/Koofr}
vendor = other
user = ${KOOFR2_USER}
pass = ${obscured}
EOF
  chmod 600 "${OUT}/rclone-koofr2.conf"
  echo "WROTE ${OUT}/rclone-koofr2.conf (gitignored; WebDAV only)"
else
  echo "SKIP rclone-koofr2.conf (KOOFR2_APP_PASSWORD empty)"
fi

cat <<EOF

Install on ShaJe'sMBA:
  1. Double-click profiles/*.cyberduckprofile
  2. Double-click generated/*.duck (passwords stay in Keychain)
  3. Connect mode: Online
  4. Suggested local folders: ~/Koofr2  ~/IDriveE2  ~/IDriveE2-Nexus
EOF
