# Optional Hive extras

These files are executable and are intentionally separate from the standard
Omarchy color theme.

`omarchy theme install` clones the repository and leaves this directory on
disk, but it does not execute these files, register the plugins, or change idle
settings. Nothing here is enabled until the user explicitly runs
`extras/install.sh`.

Before confirmation, `install.sh` checks dependencies and prints every class of
change it will make. It runs as the normal user and does not call `sudo`.

It modifies only:

- `~/.config/omarchy/shell.json`
- `~/.config/omarchy/plugins/hive.idle/`
- `~/.config/omarchy/plugins/hive.workspaces/`
- `~/.config/omarchy/plugins/hive.lock/` only with `--with-lock-screen`
- `~/.local/share/omarchy-hive-theme/`
- `~/.config/starship.toml` only with `--with-starship`
- `~/.local/state/omarchy-hive-theme/` for backups and uninstall state

The installer preserves existing idle timings unless explicit timeout options
are provided. It replaces an existing `omarchy.workspaces` bar entry in place,
so its section and surrounding widgets remain unchanged.

## Optional Hive lock screen

The lock screen is an additional opt-in because it is an authentication-capable
Omarchy Shell plugin. It is not installed by the default extras command.

`hive.lock` is cloned directly from the stock `omarchy.lock` plugin. Its
`Service.qml` is byte-for-byte identical to the revision verified on Omarchy
4.0.3 and 4.0.4; only `LockView.qml` changes the presentation. The installer
verifies that both the packaged and installed stock services match the recorded
SHA-256 before it changes anything. If Omarchy has updated the stock lock
service, installation stops so that an older authentication implementation is
never substituted.

The lock option:

- copies `hive.lock` into the user plugin directory;
- adds `hive.lock` to `plugins` in `shell.json`;
- adds `omarchy.lock` to `disabledPlugins` while the clone is active;
- adds `hive.lock` to `cloneSourceRestores`, using Omarchy's normal clone
  replacement mechanism;
- never edits `/etc/pam.d`, `/usr/share/omarchy`, fingerprint enrollment, or
  any other authentication configuration.

Enable it along with the other extras:

```bash
./extras/install.sh --with-lock-screen
```

Or enable only the lock screen without changing any other Hive integration:

```bash
./extras/lock-screen-enable.sh
```

Restore only the stock lock screen while leaving the other Hive extras active:

```bash
./extras/lock-screen-disable.sh
```

Install:

```bash
./extras/install.sh
```

Non-interactive/test installation:

```bash
./extras/install.sh --yes
```

Uninstall:

```bash
./extras/uninstall.sh
```

The included sounds are never enabled automatically.
