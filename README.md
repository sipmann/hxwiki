# hxwiki

A small wiki plugin for the [Helix](https://helix-editor.com) editor, written in
[Steel](https://github.com/mattwparas/steel) (a Scheme dialect embedded in Helix's experimental
plugin system). Inspired by [VimWiki](https://github.com/vimwiki/vimwiki): follow/create
`[[wiki-links]]` between Markdown notes and keep a daily diary, without leaving Helix.

## Status

Experimental, built against the
[`steel-event-system`](https://github.com/mattwparas/helix/tree/steel-event-system) branch of
Helix (Helix does not have a stable plugin API yet). Tested on Windows only so far.

## Features

- `[[link]]` following: put the cursor inside a `[[...]]` span and hit `Enter` (normal mode, in
  `.md` files) to open the target note, creating it if it doesn't exist yet — including
  subdirectories, e.g. `[[projects/foo]]`. Links are resolved relative to the *current* note's
  directory (VimWiki's default), so `[[foo]]` written inside `<vault>/projects/bar.md` opens
  `<vault>/projects/foo.md`, not `<vault>/foo.md`. Prefix a link with `/` to anchor it to the
  vault root instead, e.g. `[[/index]]` always opens `<vault>/index.md`.
- Rename-with-link-update: `:hxwiki-rename <new-name>` renames the current note (same `[[link]]`
  name syntax, so it can also move the note into a different/new subdirectory) and rewrites every
  `[[link]]` across the whole vault that pointed at it, preserving each link's own style (root- vs
  directory-relative, and whether it spelled out `.md`).
- Daily diary: one command opens/creates today's entry, organized as `diary/YYYY/MM/DD.md`.
- Wiki index: one command opens the vault's `index.md`.
- Configurable vault root (defaults to `~/hxwiki`).
- "Back" navigation is Helix's native jumplist (`Ctrl-o` / `Ctrl-i`) — nothing to configure.

## Requirements

1. Helix built from the `steel-event-system` branch (Steel scripting is not in stable Helix
   yet):

   ```sh
   git clone https://github.com/mattwparas/helix.git helix-steel
   cd helix-steel
   git checkout steel-event-system
   cargo xtask steel
   ```

   This installs `hx`, `forge` (Steel's package manager) and the Steel language server into
   `~/.cargo/bin`. If you already have stable Helix installed elsewhere on `PATH` (e.g. via
   winget/homebrew), consider renaming the freshly built binary (e.g. to `hx-steel`) so the two
   don't collide.

2. `HELIX_RUNTIME` pointing at that checkout's `runtime/` directory, so tree-sitter grammars and
   queries (syntax highlighting, textobjects, etc.) are found:

   ```sh
   # Windows (persist across sessions)
   setx HELIX_RUNTIME "C:\path\to\helix-steel\runtime"
   ```

   Without this, the custom build still runs the Steel scripts fine, it just has no syntax
   highlighting for any language.

3. `cogs/keymaps.scm` in your Helix config directory (vendored from
   [mattwparas/helix-config](https://github.com/mattwparas/helix-config)) — provides the
   `keymap` macro and `add-global-keybinding`/`set-global-buffer-or-extension-keymap` helpers
   used in the example below. Most Steel-enabled Helix setups already have this.

## Installation

With [forge](https://github.com/mattwparas/steel), Steel's package manager:

```sh
forge pkg install --git https://github.com/sipmann/hxwiki
```

Then, in your `~/.config/helix/init.scm`:

```scheme
(require "hxwiki/hxwiki.scm")
```

While developing locally (before pushing/publishing), you can just `require` the file directly
by path instead, e.g. `(require "E:/projetos_novos/opensource/hxwiki/hxwiki.scm")`.

See [`keybindings-example.scm`](./keybindings-example.scm) for a full example wiring up the vault
path and keybindings — copy the parts you want into your own `init.scm`.

Already running Helix with the plugin `require`d locally? Edit `hxwiki.scm`/`hxwiki-core.scm`,
then run `:config-reload` inside Helix instead of restarting it — that tears down and rebuilds the
whole Steel engine, re-running `helix.scm`/`init.scm` (and therefore re-`require`ing the plugin)
from scratch. Note that only symbols listed in your own `helix.scm`'s `provide` become typable
`:commands`, so a new command also needs adding there.

## Code layout

The plugin is split across two files:

- `hxwiki-core.scm` — vault path handling, `[[link]]` scanning/resolution, and the
  rename-with-link-update machinery. Pure Steel with no Helix dependency, so it can be `require`d
  and exercised directly under a bare `steel` process (see [Tests](#tests) below).
- `hxwiki.scm` — the thin Helix-facing layer: reads the current buffer/cursor, wires up the
  `:hxwiki-*` typable commands, and calls into `hxwiki-core.scm` for the actual logic.

## Tests

```sh
sh tests/run-all.sh
```

Runs each `tests/test-*.scm` suite under a headless `steel` process (no Helix/`hx` required) and
reports pass/fail per suite. Individually: `steel < tests/test-rename.scm` (requires are resolved
relative to the current directory when piping via stdin, so run these from the repo root).

The harness (`tests/harness.scm`) is a minimal homegrown `check-equal!`/`check-true!`/`check-false!`
setup, not a dependency — `steel` ships one too
([`cogs/tests/unit-test.scm`](https://github.com/mattwparas/steel/blob/master/cogs/tests/unit-test.scm)),
worth switching to if this outgrows what a ~60-line harness can do.

## Commands

| Command                     | Description                                                    |
|------------------------------|------------------------------------------------------------------|
| `:hxwiki-index`              | Open (or create) the vault's `index.md`                          |
| `:hxwiki-diary-today`        | Open/create today's diary entry (`diary/YYYY/MM/DD.md`)           |
| `:hxwiki-follow-or-create`   | Follow the `[[link]]` under the cursor, creating it if needed     |
| `:hxwiki-rename <new-name>`  | Rename the current note and update `[[links]]` to it vault-wide   |

`set-hxwiki-root!` is a Scheme function (not a typable command), for use in your `init.scm`:

```scheme
(set-hxwiki-root! "~/hxwiki")          ; "~" expands to the user's home directory
(set-hxwiki-root! "E:/notes/vault")    ; or an absolute path
```

## Suggested keybindings

See [`keybindings-example.scm`](./keybindings-example.scm). The defaults it sets up:

| Keys                | Mode                | Action                       |
|---------------------|---------------------|-------------------------------|
| `space w w`          | normal (global)     | `:hxwiki-index`               |
| `space w d`          | normal (global)     | `:hxwiki-diary-today`         |
| `Enter`              | normal, `.md` only  | `:hxwiki-follow-or-create`    |

These are merged onto Helix's default keymap (via `add-global-keybinding` /
`deep-copy-global-keybindings` + `merge-keybindings`), so built-in bindings are unaffected.

## Known limitations

- Steel does not currently expose a general-purpose regex library to scripts, so
  `[[link]]` detection is a small hand-written scanner over the whole buffer text rather than a
  regex match.
- No backlinks or table-of-contents generation yet. These would be natural follow-ups (backlinks
  could shell out to `rg` over the vault root; a diary index could use `read-dir`).
- Link target names are used as-is for the filename (spaces and subdirectories included), matching
  VimWiki's default behavior — no slugification.
- The buffer for the old path stays open (Helix doesn't know the underlying file moved) after a
  rename; close it manually (e.g. `:bc`) if it's still around.

## Credits

- Inspired by [VimWiki](https://github.com/vimwiki/vimwiki).
- [Steel](https://github.com/mattwparas/steel) and its
  [`steel-event-system`](https://github.com/mattwparas/helix/tree/steel-event-system) Helix
  integration, by [mattwparas](https://github.com/mattwparas).
- Structure cross-checked against real third-party Steel plugins:
  [waddie/nrepl.hx](https://github.com/waddie/nrepl.hx) and
  [waddie/http.hx](https://github.com/waddie/http.hx).
- `tests/harness.scm` and `tests/run-all.sh` are adapted from
  [nrepl.hx's own test suite](https://github.com/waddie/nrepl.hx/tree/main/tests) by
  [Tom Waddington](https://github.com/waddie) (also AGPL-3.0-or-later) — a small
  `check-equal!`/`summarize!` harness run headlessly via `steel < tests/test-*.scm`, with
  `run-all.sh` grepping for a `SUITE-PASS`/`SUITE-FAIL` sentinel since the bare `steel` CLI exits 0
  even on an uncaught error.

## License

AGPL-3.0-or-later

This program is free software: you can redistribute it and/or modify it under the terms of the
GNU Affero General Public License as published by the Free Software Foundation, either version 3
of the License, or (at your option) any later version. See [LICENSE](./LICENSE) for the full
text.
