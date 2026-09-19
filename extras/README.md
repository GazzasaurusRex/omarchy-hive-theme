# Optional Hive extras

These files are executable and are intentionally separate from the standard
Omarchy color theme.

Before confirmation, `install.sh` checks dependencies and prints every class of
change it will make. It runs as the normal user and does not call `sudo`.

It modifies only:

- `~/.config/omarchy/shell.json`
- `~/.config/omarchy/plugins/hive.idle/`
- `~/.config/omarchy/plugins/hive.workspaces/`
- `~/.local/share/omarchy-hive-theme/`
- `~/.config/starship.toml` only with `--with-starship`
- `~/.local/state/omarchy-hive-theme/` for backups and uninstall state

The installer preserves existing idle timings unless explicit timeout options
are provided. It replaces an existing `omarchy.workspaces` bar entry in place,
so its section and surrounding widgets remain unchanged.

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
