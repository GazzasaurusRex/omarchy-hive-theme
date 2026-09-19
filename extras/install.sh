#!/bin/bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
state_dir="$HOME/.local/state/omarchy-hive-theme"
data_dir="$HOME/.local/share/omarchy-hive-theme"
plugin_dir="$HOME/.config/omarchy/plugins"
shell_config="$HOME/.config/omarchy/shell.json"
starship_config="$HOME/.config/starship.toml"
assume_yes=false
with_starship=false
with_lock_screen=false
screensaver_seconds=""
lock_seconds=""

usage() {
  cat <<'EOF'
Usage: extras/install.sh [options]

Options:
  --yes                     Do not ask for confirmation.
  --with-starship           Install the optional Hive Starship prompt.
  --with-lock-screen        Install the visual-only Hive lock-screen clone.
  --screensaver-seconds N   Set the idle screensaver timeout.
  --lock-seconds N          Set the idle lock timeout.
  -h, --help                Show this help.

Without timeout options, existing idle timings are preserved.
EOF
}

while (($#)); do
  case "$1" in
    --yes) assume_yes=true; shift ;;
    --with-starship) with_starship=true; shift ;;
    --with-lock-screen) with_lock_screen=true; shift ;;
    --screensaver-seconds)
      [[ $# -ge 2 ]] || { echo "Missing value for $1" >&2; exit 2; }
      screensaver_seconds=$2; shift 2 ;;
    --lock-seconds)
      [[ $# -ge 2 ]] || { echo "Missing value for $1" >&2; exit 2; }
      lock_seconds=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ ${EUID:-$(id -u)} -ne 0 ]] || { echo "Run this installer as your normal user, not root." >&2; exit 1; }
for value in "$screensaver_seconds" "$lock_seconds"; do
  [[ -z $value || $value =~ ^[0-9]+$ ]] || { echo "Timeouts must be whole seconds." >&2; exit 2; }
done

missing=()
for command in python3 jq omarchy omarchy-shell; do
  command -v "$command" >/dev/null 2>&1 || missing+=("$command")
done
if ((${#missing[@]})); then
  printf 'Missing required command(s): %s\n' "${missing[*]}" >&2
  exit 1
fi
if ! python3 -c 'import cairo, ctypes.util, gi; gi.require_version("Gtk", "4.0"); from gi.repository import Gtk; assert ctypes.util.find_library("GL")' 2>/dev/null; then
  cat >&2 <<'EOF'
Missing a screensaver dependency. Omarchy normally provides these packages:
python, gtk4, python-gobject, python-cairo, and libglvnd.
No files were changed.
EOF
  exit 1
fi
[[ -f $shell_config ]] || { echo "Missing Omarchy shell configuration: $shell_config" >&2; exit 1; }
jq empty "$shell_config" || { echo "Invalid JSON: $shell_config" >&2; exit 1; }
for required in \
  "$repo_root/extras/screensaver/renderer-gl.py" \
  "$repo_root/extras/plugins/hive.idle/manifest.json" \
  "$repo_root/extras/plugins/hive.workspaces/manifest.json"; do
  [[ -f $required ]] || { echo "Incomplete Hive checkout: missing $required" >&2; exit 1; }
done

if $with_lock_screen; then
  stock_lock_dir="${OMARCHY_PATH:-/usr/share/omarchy}/shell/plugins/lock"
  hive_lock_dir="$repo_root/extras/plugins/hive.lock"
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
  if jq -e '(.disabledPlugins // []) | index("omarchy.lock") != null' "$shell_config" >/dev/null \
      && [[ ! -f $state_dir/lock-installed ]]; then
    echo "The stock omarchy.lock plugin is already disabled; refusing to replace an unknown lock configuration." >&2
    exit 1
  fi
  shopt -s nullglob
  for manifest in "$plugin_dir"/*/manifest.json; do
    [[ $manifest == "$plugin_dir/hive.lock/manifest.json" ]] && continue
    if [[ $(jq -r '.omarchy.clonedFrom // empty' "$manifest" 2>/dev/null) == "omarchy.lock" ]]; then
      echo "Another omarchy.lock clone is installed: $manifest" >&2
      exit 1
    fi
  done
  shopt -u nullglob
fi

cat <<EOF
The optional Hive extras will:
  - copy the GPU screensaver to $data_dir
  - install the hive.idle and hive.workspaces Omarchy Shell plugins
  - disable the stock omarchy.idle service while hive.idle is enabled
  - replace an existing omarchy.workspaces bar entry with hive.workspaces
  - preserve your current idle timings unless timeout options were supplied
EOF
$with_starship && printf '  - back up and replace %s with the Hive Starship prompt\n' "$starship_config"
$with_lock_screen && cat <<EOF
  - install hive.lock as a hash-verified visual clone of Omarchy's lock service
  - disable omarchy.lock in shell.json while routing stock lock IPC to hive.lock
  - leave PAM files and the system-owned omarchy.lock plugin untouched
EOF
[[ -n $screensaver_seconds ]] && printf '  - set the screensaver timeout to %s seconds\n' "$screensaver_seconds"
[[ -n $lock_seconds ]] && printf '  - set the lock timeout to %s seconds\n' "$lock_seconds"
printf 'Backups and installation state will be stored in %s\n' "$state_dir"

if ! $assume_yes; then
  read -r -p "Continue? [y/N] " answer
  [[ $answer == [yY] || $answer == [yY][eE][sS] ]] || { echo "Cancelled."; exit 0; }
fi

timestamp=$(date +%Y%m%dT%H%M%S-%N)
mkdir -p "$state_dir/backups/$timestamp" "$plugin_dir" "$(dirname -- "$data_dir")"
cp -a "$shell_config" "$state_dir/backups/$timestamp/shell.json"

if [[ ! -f $state_dir/installed ]]; then
  rm -f "$state_dir"/{replaced-workspaces,disabled-stock-idle,added-clone-restore,prior-idle.json,installed-idle.json,starship-was-missing,starship-installed.sha256,starship.before-extras.toml}
  cp -a "$shell_config" "$state_dir/shell.before-extras.json"
  if jq -e '[.bar.layout[]?[]? | select(.id == "omarchy.workspaces")] | length > 0' "$shell_config" >/dev/null; then
    touch "$state_dir/replaced-workspaces"
  fi
  if ! jq -e '(.disabledPlugins // []) | index("omarchy.idle") != null' "$shell_config" >/dev/null; then
    touch "$state_dir/disabled-stock-idle"
  fi
  if ! jq -e '(.cloneSourceRestores // []) | index("hive.idle") != null' "$shell_config" >/dev/null; then
    touch "$state_dir/added-clone-restore"
  fi
  if [[ -n $screensaver_seconds || -n $lock_seconds ]]; then
    jq -c '.idle // null' "$shell_config" > "$state_dir/prior-idle.json"
  fi
fi

for id in hive.idle hive.workspaces; do
  destination="$plugin_dir/$id"
  if [[ -e $destination && ! -f $state_dir/installed ]]; then
    echo "Refusing to replace pre-existing plugin directory: $destination" >&2
    exit 1
  fi
done
if $with_lock_screen && [[ -e $plugin_dir/hive.lock && ! -f $state_dir/lock-installed ]]; then
  echo "Refusing to replace pre-existing plugin directory: $plugin_dir/hive.lock" >&2
  exit 1
fi
if [[ -e $data_dir && ! -f $state_dir/installed ]]; then
  echo "Refusing to replace pre-existing data directory: $data_dir" >&2
  exit 1
fi

tmp_data=$(mktemp -d "${data_dir}.tmp.XXXXXX")
tmp_idle=$(mktemp -d "$plugin_dir/.hive.idle.tmp.XXXXXX")
tmp_workspaces=$(mktemp -d "$plugin_dir/.hive.workspaces.tmp.XXXXXX")
tmp_lock=""
cleanup() {
  rm -rf -- "$tmp_data" "$tmp_idle" "$tmp_workspaces"
  [[ -z $tmp_lock ]] || rm -rf -- "$tmp_lock"
}
trap cleanup EXIT
cp -a "$repo_root/extras/screensaver" "$tmp_data/"
cp -a "$repo_root/extras/plugins/hive.idle/." "$tmp_idle/"
cp -a "$repo_root/extras/plugins/hive.workspaces/." "$tmp_workspaces/"
if $with_lock_screen; then
  tmp_lock=$(mktemp -d "$plugin_dir/.hive.lock.tmp.XXXXXX")
  cp -a "$repo_root/extras/plugins/hive.lock/." "$tmp_lock/"
fi
rm -rf -- "$data_dir" "$plugin_dir/hive.idle" "$plugin_dir/hive.workspaces"
mv "$tmp_data" "$data_dir"
mv "$tmp_idle" "$plugin_dir/hive.idle"
mv "$tmp_workspaces" "$plugin_dir/hive.workspaces"
if $with_lock_screen; then
  rm -rf -- "$plugin_dir/hive.lock"
  mv "$tmp_lock" "$plugin_dir/hive.lock"
  tmp_lock=""
fi
trap - EXIT

tmp_shell=$(mktemp "${shell_config}.hive.XXXXXX")
jq \
  --arg screensaver "$screensaver_seconds" \
  --arg lock "$lock_seconds" \
  --argjson withLock "$with_lock_screen" '
  .bar.layout |= ((. // {}) | with_entries(.value |= map(if .id == "omarchy.workspaces" then .id = "hive.workspaces" else . end))) |
  .plugins = ((.plugins // []) | if any(.[]; .id == "hive.idle") then . else . + [{"id":"hive.idle"}] end) |
  .disabledPlugins = ((.disabledPlugins // []) | if index("omarchy.idle") then . else . + ["omarchy.idle"] end) |
  .cloneSourceRestores = ((.cloneSourceRestores // []) | if index("hive.idle") then . else . + ["hive.idle"] end) |
  if $withLock then
    .plugins = ((.plugins // []) | if any(.[]; .id == "hive.lock") then . else . + [{"id":"hive.lock"}] end) |
    .disabledPlugins = ((.disabledPlugins // []) | if index("omarchy.lock") then . else . + ["omarchy.lock"] end) |
    .cloneSourceRestores = ((.cloneSourceRestores // []) | if index("hive.lock") then . else . + ["hive.lock"] end)
  else . end |
  if $screensaver != "" then .idle.screensaver = ($screensaver | tonumber) else . end |
  if $lock != "" then .idle.lock = ($lock | tonumber) else . end
  ' "$shell_config" > "$tmp_shell"
jq empty "$tmp_shell"
mv "$tmp_shell" "$shell_config"

$with_lock_screen && touch "$state_dir/lock-installed"

if [[ -n $screensaver_seconds || -n $lock_seconds ]]; then
  jq -c '.idle // null' "$shell_config" > "$state_dir/installed-idle.json"
fi

if $with_starship; then
  if [[ ! -f $state_dir/starship.before-extras.toml && ! -f $state_dir/starship-was-missing ]]; then
    if [[ -f $starship_config ]]; then
      cp -a "$starship_config" "$state_dir/starship.before-extras.toml"
    else
      touch "$state_dir/starship-was-missing"
    fi
  fi
  mkdir -p "$(dirname -- "$starship_config")"
  cp -a "$repo_root/extras/starship/hive.toml" "$starship_config"
  sha256sum "$starship_config" | awk '{print $1}' > "$state_dir/starship-installed.sha256"
fi

date -Iseconds > "$state_dir/installed"
timeout 3 omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true

cat <<EOF
Hive extras installed.
Preview: $data_dir/screensaver/hive-screensaver preview
Remove only the extras: $repo_root/extras/uninstall.sh
EOF
