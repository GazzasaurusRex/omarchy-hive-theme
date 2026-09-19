#!/bin/bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
state_dir="$HOME/.local/state/omarchy-hive-theme"
plugin_dir="$HOME/.config/omarchy/plugins"
shell_config="$HOME/.config/omarchy/shell.json"
stock_lock_dir="${OMARCHY_PATH:-/usr/share/omarchy}/shell/plugins/lock"
hive_lock_dir="$repo_root/extras/plugins/hive.lock"
lock_plugin="$plugin_dir/hive.lock"
assume_yes=false

case "${1:-}" in
  --yes) assume_yes=true ;;
  -h|--help) echo "Usage: extras/lock-screen-enable.sh [--yes]"; exit 0 ;;
  "") ;;
  *) echo "Unknown option: $1" >&2; exit 2 ;;
esac

[[ ${EUID:-$(id -u)} -ne 0 ]] || { echo "Run this as your normal user, not root." >&2; exit 1; }
for command in jq omarchy sha256sum; do
  command -v "$command" >/dev/null 2>&1 || { echo "Missing required command: $command" >&2; exit 1; }
done
[[ -f $shell_config ]] || { echo "Missing Omarchy Shell configuration: $shell_config" >&2; exit 1; }
jq empty "$shell_config" || { echo "Invalid JSON: $shell_config" >&2; exit 1; }
for required in Service.qml LockView.qml manifest.json stock-service.sha256; do
  [[ -f $hive_lock_dir/$required ]] || { echo "Incomplete Hive lock plugin: missing $required" >&2; exit 1; }
done
[[ -f $stock_lock_dir/Service.qml ]] || { echo "Cannot find the installed Omarchy lock service." >&2; exit 1; }
[[ -f /etc/pam.d/omarchy-lock-password ]] || {
  echo "The stock Omarchy password PAM service is unavailable; refusing to install a lock clone." >&2
  exit 1
}

expected_lock_hash=$(awk 'NR == 1 { print $1 }' "$hive_lock_dir/stock-service.sha256")
packaged_lock_hash=$(sha256sum "$hive_lock_dir/Service.qml" | awk '{print $1}')
installed_lock_hash=$(sha256sum "$stock_lock_dir/Service.qml" | awk '{print $1}')
if [[ $packaged_lock_hash != "$expected_lock_hash" || $installed_lock_hash != "$expected_lock_hash" ]]; then
  cat >&2 <<EOF
The Hive lock clone was built for a different Omarchy lock-service revision.
Packaged:  $packaged_lock_hash
Installed: $installed_lock_hash
Expected:  $expected_lock_hash
No files were changed. Update the Hive lock plugin before enabling it.
EOF
  exit 1
fi
omarchy plugin validate "$hive_lock_dir" >/dev/null || {
  echo "The packaged Hive lock plugin failed Omarchy validation; no files were changed." >&2
  exit 1
}

already_managed=false
[[ -f $state_dir/lock-installed ]] && already_managed=true
if jq -e '(.disabledPlugins // []) | index("omarchy.lock") != null' "$shell_config" >/dev/null && ! $already_managed; then
  echo "The stock omarchy.lock plugin is already disabled; refusing to replace an unknown lock configuration." >&2
  exit 1
fi
shopt -s nullglob
for manifest in "$plugin_dir"/*/manifest.json; do
  [[ $manifest == "$lock_plugin/manifest.json" ]] && continue
  if [[ $(jq -r '.omarchy.clonedFrom // empty' "$manifest" 2>/dev/null) == "omarchy.lock" ]]; then
    echo "Another omarchy.lock clone is installed: $manifest" >&2
    exit 1
  fi
done
shopt -u nullglob
if [[ -e $lock_plugin ]] && ! $already_managed; then
  echo "Refusing to replace pre-existing plugin directory: $lock_plugin" >&2
  exit 1
fi

cat <<EOF
The optional Hive lock screen will:
  - copy the verified visual lock clone to $lock_plugin
  - add hive.lock to plugins and cloneSourceRestores in $shell_config
  - add omarchy.lock to disabledPlugins while the clone is active
  - leave PAM, fingerprint configuration, and /usr/share/omarchy untouched
  - store a shell.json backup under $state_dir/backups/
EOF
if ! $assume_yes; then
  read -r -p "Continue? [y/N] " answer
  [[ $answer == [yY] || $answer == [yY][eE][sS] ]] || { echo "Cancelled."; exit 0; }
fi

timestamp=$(date +%Y%m%dT%H%M%S-%N)
mkdir -p "$state_dir/backups/$timestamp" "$plugin_dir"
cp -a "$shell_config" "$state_dir/backups/$timestamp/shell.json"
if ! $already_managed; then
  cp -a "$shell_config" "$state_dir/shell.before-lock.json"
fi

tmp_lock=$(mktemp -d "$plugin_dir/.hive.lock.tmp.XXXXXX")
tmp_shell=$(mktemp "${shell_config}.hive.XXXXXX")
cleanup() {
  rm -rf -- "$tmp_lock"
  rm -f -- "$tmp_shell"
}
trap cleanup EXIT
cp -a "$hive_lock_dir/." "$tmp_lock/"
jq '
  .plugins = ((.plugins // []) | if any(.[]; .id == "hive.lock") then . else . + [{"id":"hive.lock"}] end) |
  .disabledPlugins = ((.disabledPlugins // []) | if index("omarchy.lock") then . else . + ["omarchy.lock"] end) |
  .cloneSourceRestores = ((.cloneSourceRestores // []) | if index("hive.lock") then . else . + ["hive.lock"] end)
  ' "$shell_config" > "$tmp_shell"
jq empty "$tmp_shell"

rm -rf -- "$lock_plugin"
mv "$tmp_lock" "$lock_plugin"
mv "$tmp_shell" "$shell_config"
trap - EXIT
touch "$state_dir/lock-installed"
timeout 3 omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true

echo "Hive lock screen enabled. Restore stock visuals with: $repo_root/extras/lock-screen-disable.sh"
