# Open URL

A fast, keyboard-driven [Omarchy](https://omarchy.org/) shell plugin for opening
links in your default browser — with an automatically expiring **recency cache**
so the sites you actually use are only a few keystrokes away.

Summon it with `Ctrl+Shift+W`, type a URL or a fragment of one, press Enter.

```
┌ Open URL… ──────────────────────────┐
│  🌐 nonmirror.icu        just now   │
│  🌐 github.com           2h ago     │
│  🌐 archlinux.org        3d ago     │
└─────────────────────────────────────┘
```

## Features

- **Open any URL** — full links (`https://…`), bare hosts (`nonmirror.icu`),
  `www.` hosts, `localhost:port`, and IPv4 addresses. Scheme-less input is
  normalized to `https://`.
- **Live suggestions from a recency cache** — type `nonmirror` *or* `icu` and
  `nonmirror.icu` appears. Every whitespace-separated token must match the URL.
- **Most-recently-used first** — the link you opened last is always at the top.
- **Two-week TTL** — a link not opened through the plugin for 14 days is dropped
  from the cache automatically.
- **Zero-fork matching** — the cache is loaded into memory once at shell start;
  every keystroke is an in-process JavaScript scan. No `fzf`, no `zoxide`, no
  subprocess per query, and no disk I/O while typing.
- **Native text input** — a real `TextInput`, so selection, copy, and paste all
  behave normally.
- **Keyboard-first navigation** — `Alt+J` / `Alt+K` to move (arrow keys also
  work), `Enter` to open, `Esc` to clear then close, or click a row.

## Requirements

- [Omarchy](https://omarchy.org/)
- The `omarchy-shell` (Quickshell) host

## Installation

```bash
omarchy plugin add https://github.com/NonMirror/omarchy-open-url.git --enable --yes
```

Or install by hand:

1. Put this directory at `~/.config/omarchy/plugins/nonmirror.open-url/`.
2. `omarchy-shell shell rescanPlugins`
3. `omarchy plugin enable nonmirror.open-url`

## Keybinding

Add this to `~/.config/hypr/bindings.lua`, then run `hyprctl reload`:

```lua
-- Open URL: type or paste a link and open it in the default browser.
o.bind("CTRL + SHIFT + W", "Open URL", "omarchy-shell shell toggle nonmirror.open-url")
```

## Usage

1. Press `Ctrl+Shift+W`.
2. Start typing:
   - a full URL, e.g. `https://nonmirror.icu`
   - a bare host, e.g. `nonmirror.icu`
   - a fragment of a cached site, e.g. `nonmirror` or `icu`
3. Pick a row and press `Enter`.

When the text is a valid URL that is not already cached, an
**“Open link in default browser”** row is offered at the top. With an empty
query, your recent sites are listed.

Opening a link records it (or refreshes its timestamp) and moves it to the top
of the cache.

## Cache

| | |
|---|---|
| **Path** | `~/.local/state/omarchy/open-url-history.json` |
| **Format** | `[{"url": "https://nonmirror.icu", "accessed": 1789447069760}]` |
| **`accessed`** | epoch milliseconds of the last open through this plugin |
| **TTL** | 14 days |
| **Limit** | 500 entries, most-recently-used first |

- Aging is evaluated on open and on file change. The file is rewritten **only**
  when a link is opened or an entry expires — a plain open/close never writes.
- Writes are atomic (`FileView.atomicWrites`).
- The file is plain JSON; feel free to inspect or clear it.

## Configuration

Tunable properties live at the top of `OpenUrl.qml`:

| Property | Default | Meaning |
|---|---|---|
| `historyLimit` | `500` | maximum number of cached links |
| `matchLimit` | `50` | maximum suggestions kept in memory per query |
| `maxVisibleRows` | `6` | rows shown before the list scrolls |

The cache window is `TTL_MS` in `History.js` (default `14 * 24h`).

## Files

| File | Purpose |
|---|---|
| `manifest.json` | plugin manifest (`overlay` kind, `keepLoaded: true`) |
| `OpenUrl.qml` | overlay UI, state, and cache wiring |
| `Url.js` | URL recognition and normalization |
| `History.js` | cache parse / serialize / prune / record / match |

## Design notes

**Why not `zoxide` or `fzf`?** Both are excellent tools, but both cost a process
fork per query. This plugin runs inside the long-lived `omarchy-shell` process
and only ever searches a few hundred strings, so a linear scan in QML's own JS
engine is microseconds. The `FileView` reads the cache once at shell start, and
the file is written only when a link is opened or an entry ages out. The result:
no subprocesses, no per-keystroke disk access, and the overlay opens instantly.

## Development

`keepLoaded: true` keeps the overlay mounted between summons, so edits to the
QML/JS only take effect after `omarchy restart shell` (a plugin hot-reload does
not replace the kept instance).

`Url.js` and `History.js` are plain modules and can be exercised directly:

```bash
node -e 'const U = require("./Url.js"); console.log(U.normalizeUrl("nonmirror.icu"))'
```
