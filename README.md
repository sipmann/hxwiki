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
  subdirectories, e.g. `[[projects/foo]]` -> `<vault>/projects/foo.md`.
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

## Commands

| Command                     | Description                                                    |
|------------------------------|------------------------------------------------------------------|
| `:hxwiki-index`              | Open (or create) the vault's `index.md`                          |
| `:hxwiki-diary-today`        | Open/create today's diary entry (`diary/YYYY/MM/DD.md`)           |
| `:hxwiki-follow-or-create`   | Follow the `[[link]]` under the cursor, creating it if needed     |

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
- No backlinks, table-of-contents generation, or rename-with-link-update yet. These would be
  natural follow-ups (backlinks could shell out to `rg` over the vault root; a diary index could
  use `read-dir`).
- Link target names are used as-is for the filename (spaces and subdirectories included), matching
  VimWiki's default behavior — no slugification.

## Credits

- Inspired by [VimWiki](https://github.com/vimwiki/vimwiki).
- [Steel](https://github.com/mattwparas/steel) and its
  [`steel-event-system`](https://github.com/mattwparas/helix/tree/steel-event-system) Helix
  integration, by [mattwparas](https://github.com/mattwparas).
- Structure cross-checked against real third-party Steel plugins:
  [waddie/nrepl.hx](https://github.com/waddie/nrepl.hx) and
  [waddie/http.hx](https://github.com/waddie/http.hx).
