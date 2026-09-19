#!/bin/bash
set -euo pipefail

state_dir="$HOME/.local/state/omarchy-hive-theme"
data_dir="$HOME/.local/share/omarchy-hive-theme"
plugin_dir="$HOME/.config/omarchy/plugins"
shell_config="$HOME/.config/omarchy/shell.json"
starship_config="$HOME/.config/starship.toml"
assume_yes=false

case "${1:-}" in
  --yes) assume_yes=true ;;
  -h|--help) echo "Usage: extras/uninstall.sh [--yes]"; exit 0 ;;
  "") ;;
  *) echo "Unknown option: $1" >&2; exit 2 ;;
esac

[[ ${EUID:-$(id -u)} -ne 0 ]] || { echo "Run this uninstaller as your normal user, not root." >&2; exit 1; }
[[ -f $state_dir/installed ]] || { echo "Hive extras are not recorded as installed." >&2; exit 1; }
command -v jq >/dev/null || { echo "jq is required to edit Omarchy's shell configuration safely." >&2; exit 1; }
[[ -f $shell_config ]] || { echo "Missing Omarchy shell configuration: $shell_config" >&2; exit 1; }
[[ -f $state_dir/shell.before-extras.json ]] || { echo "Missing the pre-install Shell snapshot; refusing a partial rollback." >&2; exit 1; }
jq empty "$state_dir/shell.before-extras.json" || { echo "Invalid pre-install Shell snapshot." >&2; exit 1; }
plugins_key_existed=$(jq 'has("plugins")' "$state_dir/shell.before-extras.json")

cat <<EOF
This removes the Hive screensaver and plugins, restores the stock workspace,
idle, and lock plugin entries that the installer changed, and restores the
Starship prompt only if it has not been edited since installation.
EOF
if ! $assume_yes; then
  read -r -p "Continue? [y/N] " answer
  [[ $answer == [yY] || $answer == [yY][eE][sS] ]] || { echo "Cancelled."; exit 0; }
fi

timestamp=$(date +%Y%m%dT%H%M%S-%N)
mkdir -p "$state_dir/backups/$timestamp"
cp -a "$shell_config" "$state_dir/backups/$timestamp/shell.json"

tmp_shell=$(mktemp "${shell_config}.hive.XXXXXX")
jq --argjson keepPluginsKey "$plugins_key_existed" '
  .plugins = ((.plugins // []) | map(select(.id != "hive.idle"))) |
  if ((.plugins | length) == 0 and ($keepPluginsKey | not)) then del(.plugins) else . end |
  .cloneSourceRestores = ((.cloneSourceRestores // []) | map(select(. != "hive.idle"))) |
  if (.cloneSourceRestores | length) == 0 then del(.cloneSourceRestores) else . end
  ' "$shell_config" > "$tmp_shell"

if [[ -f $state_dir/replaced-workspaces ]]; then
  next=$(mktemp "${shell_config}.hive.XXXXXX")
  jq '.bar.layout |= with_entries(.value |= map(if .id == "hive.workspaces" then .id = "omarchy.workspaces" else . end))' "$tmp_shell" > "$next"
  mv "$next" "$tmp_shell"
fi
if [[ -f $state_dir/disabled-stock-idle ]]; then
  next=$(mktemp "${shell_config}.hive.XXXXXX")
  jq '
    .disabledPlugins = ((.disabledPlugins // []) | map(select(. != "omarchy.idle"))) |
    if (.disabledPlugins | length) == 0 then del(.disabledPlugins) else . end
    ' "$tmp_shell" > "$next"
  mv "$next" "$tmp_shell"
fi
if [[ -f $state_dir/lock-installed ]]; then
  next=$(mktemp "${shell_config}.hive.XXXXXX")
  jq --argjson keepPluginsKey "$plugins_key_existed" '
    .plugins = ((.plugins // []) | map(select(.id != "hive.lock"))) |
    if ((.plugins | length) == 0 and ($keepPluginsKey | not)) then del(.plugins) else . end |
    .cloneSourceRestores = ((.cloneSourceRestores // []) | map(select(. != "hive.lock"))) |
    if (.cloneSourceRestores | length) == 0 then del(.cloneSourceRestores) else . end |
    .disabledPlugins = ((.disabledPlugins // []) | map(select(. != "omarchy.lock"))) |
    if (.disabledPlugins | length) == 0 then del(.disabledPlugins) else . end
    ' "$tmp_shell" > "$next"
  mv "$next" "$tmp_shell"
fi
if [[ -f $state_dir/prior-idle.json && -f $state_dir/installed-idle.json ]]; then
  current_idle=$(jq -c '.idle // null' "$tmp_shell")
  installed_idle=$(cat "$state_dir/installed-idle.json")
  if [[ $current_idle == "$installed_idle" ]]; then
    prior_idle=$(cat "$state_dir/prior-idle.json")
    next=$(mktemp "${shell_config}.hive.XXXXXX")
    jq --argjson prior "$prior_idle" 'if $prior == null then del(.idle) else .idle = $prior end' "$tmp_shell" > "$next"
    mv "$next" "$tmp_shell"
  else
    echo "Idle timings changed after installation; leaving them untouched." >&2
  fi
fi
jq empty "$tmp_shell"
mv "$tmp_shell" "$shell_config"

if [[ -f $state_dir/starship-installed.sha256 ]]; then
  expected=$(cat "$state_dir/starship-installed.sha256")
  actual=$([[ -f $starship_config ]] && sha256sum "$starship_config" | awk '{print $1}' || true)
  if [[ $actual == "$expected" ]]; then
    if [[ -f $state_dir/starship.before-extras.toml ]]; then
      cp -a "$state_dir/starship.before-extras.toml" "$starship_config"
    elif [[ -f $state_dir/starship-was-missing ]]; then
      rm -f -- "$starship_config"
    fi
  else
    echo "Starship configuration changed after installation; leaving it untouched." >&2
  fi
fi

if [[ -f $state_dir/lock-installed ]]; then
  rm -rf -- "$plugin_dir/hive.lock"
  rm -f -- "$state_dir/lock-installed" "$state_dir/shell.before-lock.json"
fi
rm -rf -- "$data_dir" "$plugin_dir/hive.idle" "$plugin_dir/hive.workspaces"
rm -f -- "$state_dir/installed"
date -Iseconds > "$state_dir/uninstalled"
timeout 3 omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true

echo "Hive extras removed. The base Hive theme remains installed."
