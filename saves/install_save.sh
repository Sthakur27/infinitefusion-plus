#!/usr/bin/env bash
# install_save.sh - install the sidmod showcase save into your Infinite Fusion save folder.
# Linux/macOS companion to install_save.ps1 (for mkxp-z installs).
#
# Usage:
#   ./saves/install_save.sh                 # install to first FREE slot
#   ./saves/install_save.sh --list          # just show your slots
#   ./saves/install_save.sh --slot C        # install to a specific slot
#   ./saves/install_save.sh --slot A --force # overwrite an occupied slot (backed up first)
#   SAVE_DIR=/custom/path ./saves/install_save.sh   # override save folder detection
#
# Same safety rules as the PowerShell version: refuses while the game is running,
# only writes to an empty slot unless --force, backs up before any overwrite,
# and verifies the copy by checksum.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SRC_DIR/File A.rxdata"
SLOT=""; FORCE=0; LIST=0

while [ $# -gt 0 ]; do
  case "$1" in
    --slot) SLOT="$(printf '%s' "${2:-}" | tr '[:lower:]' '[:upper:]')"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --list) LIST=1; shift ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ---- detect the save folder ----
if [ -n "${SAVE_DIR:-}" ]; then
  save_dir="$SAVE_DIR"
elif [ "$(uname -s)" = "Darwin" ]; then
  save_dir="$HOME/Library/Application Support/infinitefusion"
elif [ -n "${APPDATA:-}" ]; then
  save_dir="$APPDATA/infinitefusion"                       # Git Bash / WSL-with-APPDATA
else
  save_dir="${XDG_CONFIG_HOME:-$HOME/.config}/infinitefusion"
fi

slot_path() { printf '%s/File %s.rxdata' "$save_dir" "$1"; }

show_slots() {
  echo
  echo "Save folder: $save_dir"
  for l in A B C D E F G H; do
    p="$(slot_path "$l")"
    if [ -f "$p" ]; then
      sz=$(du -h "$p" 2>/dev/null | cut -f1)
      echo "  File $l  OCCUPIED  ${sz}"
    else
      echo "  File $l  free"
    fi
  done
  echo
}

[ -f "$SRC" ] || { echo "ERROR: shipped save not found: $SRC" >&2; exit 1; }
[ -d "$save_dir" ] || { echo "Save folder does not exist yet, creating: $save_dir"; mkdir -p "$save_dir"; }
[ "$LIST" = 1 ] && { show_slots; exit 0; }

# ---- game must be closed ----
if pgrep -fi 'InfiniteFusion|mkxp' >/dev/null 2>&1; then
  echo "ERROR: Infinite Fusion appears to be RUNNING. Close it first - an open game" >&2
  echo "       overwrites save files on its next save." >&2
  exit 2
fi

# ---- pick destination ----
if [ -n "$SLOT" ]; then
  case "$SLOT" in [A-H]) ;; *) echo "ERROR: slot must be A-H" >&2; exit 1 ;; esac
  target="$SLOT"
else
  target=""
  for l in A B C D E F G H; do
    [ -f "$(slot_path "$l")" ] || { target="$l"; break; }
  done
  if [ -z "$target" ]; then
    show_slots
    echo "ERROR: all 8 slots occupied. Re-run with --slot <X> --force (existing file is backed up)." >&2
    exit 3
  fi
  echo "No --slot given; using first free slot: File $target"
fi
dest="$(slot_path "$target")"

# ---- never clobber silently ----
if [ -f "$dest" ]; then
  if [ "$FORCE" != 1 ]; then
    show_slots
    echo "ERROR: File $target already exists. Re-run with --force to overwrite (it will be" >&2
    echo "       backed up first), or choose a free slot." >&2
    exit 4
  fi
  bk="$save_dir/sidmod_save_backups/$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$bk"
  cp "$dest" "$bk/File $target.rxdata"
  echo "backed up your existing File $target -> $bk"
fi

# ---- install + verify ----
cp "$SRC" "$dest"

# Hash via stdin, never by filename: GNU sha256sum prefixes its output line with
# a backslash when the path contains one (Git Bash dests look like C:\Users\...),
# which made a correct copy compare as a mismatch.
hash_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum < "$1" | cut -d' ' -f1
  else shasum -a 256 < "$1" | cut -d' ' -f1; fi
}
if [ "$(hash_of "$SRC")" != "$(hash_of "$dest")" ]; then
  echo "ERROR: copy verification FAILED (checksum mismatch). Do not load this slot." >&2
  exit 5
fi

echo
echo "Installed sidmod save -> File $target"
echo "  path   : $dest"
echo "  sha256 : $(hash_of "$dest")"
echo
echo "Launch the game and pick save slot $target."
