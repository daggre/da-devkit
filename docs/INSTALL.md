# Install guide

## Requirements

- A running RedM server (FXServer, `rdr3` build)
- Nothing else. No framework, no database, no inventory system.

VORP is supported if you already use it — set `setr framework "VORP"`. Otherwise leave
it alone and the standalone implementation is used.

---

## Server owners: the zip

1. Download the latest `da-devkit-*.zip` from
   [Releases](https://github.com/daggre/da-devkit/releases).
2. Unzip it into your server's `resources/` directory. You get one folder named `[da]`.
   The square brackets are meaningful to FXServer — keep them.
3. Add one line to your `server.cfg`:

   ```cfg
   exec resources/[da]/da_resources.cfg
   ```

4. Restart the server.

Verify it worked: join, press **X**. The animation menu should appear bottom-right.

### Why a separate cfg

`[da]/da_resources.cfg` ships with the bundle and holds the `ensure` lines, the
`da_dev_enabled` convar and the logging level. Keeping them together means the load
order is correct out of the box, and upgrading is "replace the folder, re-check one
file" rather than diffing your `server.cfg`.

If you would rather inline it, copy its contents into `server.cfg` — nothing depends on
the `exec`.

### Load order

`da_log` and `da_lib` must start before anything that uses them. If you see
`Could not find dependency da_lib`, your `ensure` lines are out of order.

```cfg
ensure da_props     # no dependencies, order irrelevant
ensure da_log       # required
ensure da_lib       # required
ensure da_dev       # gated — see below
ensure da_anims
ensure da_game
```

---

## Developers: clone the repos

Each resource is an independent repository. Clone only what you need:

```bash
cd resources
mkdir "[da]" && cd "[da]"
git clone https://github.com/daggre/da_log.git
git clone https://github.com/daggre/da_lib.git
git clone https://github.com/daggre/da_dev.git
```

Or pull the whole set at once:

```bash
git clone https://github.com/daggre/da-devkit.git
da-devkit/tools/fetch-all.sh /path/to/server/resources
```

### Using the library in your own resource

Add the includes to your `fxmanifest.lua`. There is no `require` — FXServer pulls files
from other resources with the `@resource/path` syntax:

```lua
shared_scripts {
    '@da_log/log_sh.lua',
}

client_scripts {
    '@da_lib/features/mode/mode_cl.lua',
    '@da_lib/features/anim/anim_cl.lua',
    'client.lua',
}

dependencies {
    'da_log',
    'da_lib',
}
```

Then `log.info(...)`, `da_mode.register(...)` and `da_anim.ped(...)` are available as
globals in your resource. Each `da_lib` feature is a separate include — take only what
you use.

`da_lib`'s README lists every feature and its include path.

---

## Enabling the dev tools

`da_dev` **is** in the bundle, and is deny-by-default: at `da_dev_enabled 0` it stops
itself at boot and is never sent to connecting clients. That is what makes it safe to
ship in the same folder you deploy to production. Read [SECURITY.md](SECURITY.md)
first — the short version:

```cfg
setr da_dev_enabled 1
add_ace group.admin da_dev allow
```

Then press **Z** in game to open the dev tree.

If nothing happens, you are not authorized. Check the server console at startup for the
`da_dev` line, and confirm your identifier is in `group.admin`. On a solo local server
where you have no ACE groups set up, `setr da_dev_enabled 2` allows everyone — never
use that where players can connect.

---

## Troubleshooting

**`Could not find dependency da_lib`** — load order. `da_log` and `da_lib` first.

**Animation menu doesn't open on X** — check `da_anims` started without errors. If you
still have `da_xanims` running, stop it: both bind **X** and they will fight. The menu
only lists animations valid for your current state, so it can legitimately be empty
(mounted, swimming, in combat).

**A scenario is missing from the menu** — run `anims list` in the client console. It
shows every registered scenario and whether its `when` conditions pass right now.

**Dev tree doesn't open on Z** — authorization. See above.

**Nothing logs anything** — `setr debug 1` for debug-level output, or set a level at
runtime in the server console: `log set da_lib debug`.

**Props are invisible** — `da_props` is a stream-only resource. Stream files need a full
server restart, not `restart da_props`.
