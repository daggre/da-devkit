# Dev tools on a live server

`da_dev` is a development kit. It gives whoever can open it freecam, teleport, entity
spawning, ped spawning, attribute editing, and scene manipulation. On a production
server in the hands of an ordinary player, that is a total loss of control.

`da_test` is the same category — it exists to drive the library and assert on results.

This page explains how the devkit keeps that from happening, so you can deploy the
*same* `[da]` folder to your development and production servers without maintaining
two copies.

---

## The short version

```cfg
# --- production server.cfg ---
setr da_dev_enabled 0        # or just omit it — 0 is the default
```

```cfg
# --- development server.cfg ---
setr da_dev_enabled 1
add_ace group.admin da_dev allow
```

Nothing else. `da_dev` and `da_test` can stay in your resources folder and stay in your
`server.cfg` on both machines.

---

## How it works

There are two layers, and they are not equally strong. Understand the difference.

### Layer 1 — the resource does not run at all (hard)

`da_dev_enabled` defaults to **0**. At server start, `da_dev`'s server script reads the
convar and, if it is not `1`, **stops the resource immediately**.

This is the layer that matters. A stopped resource is never sent to connecting clients:
they do not download the UI, do not receive the Lua, and have nothing to bypass. The
attack surface is zero, not "small."

```
[da_dev] disabled (da_dev_enabled is not 1) — stopping. Set `setr da_dev_enabled 1` to enable.
```

You will see that line in your production console every start. That is the system
working.

### Layer 2 — per-player authorization (soft)

When `da_dev_enabled` is `1`, the resource runs, but no player gets tools by default.
Each client asks the server for authorization on spawn, and the server answers with an
[ACE](https://docs.fivem.net/docs/server-manual/server-commands/#add_ace-principal-object-allowdeny)
check:

```cfg
add_ace group.admin da_dev allow          # everyone in group.admin
add_ace identifier.license:abc123 da_dev allow   # one specific person
```

Until that check passes, the client registers no modes and binds no keys. Pressing the
dev keybind does nothing.

**This layer is advisory, not a security boundary.** `da_dev` is client-side code. Once
a client has downloaded the resource, someone running a Lua injector can call into it
regardless of what the server said. Layer 2 stops honest users on a shared dev server
from stumbling into the tools. It does not stop an attacker.

**Do not rely on layer 2 in production. Use layer 1.**

### Why not make it server-authoritative?

It could be — every dev action could round-trip through the server for approval. That
is a large amount of machinery to protect a tool that has no business running on a
production server in the first place. The kill switch is the correct control here; the
ACE check is a convenience for dev servers with more than one person on them.

---

## What an unauthorized player can actually do

Worth knowing, in case you find `da_dev` running somewhere it shouldn't be:

- Entity spawning in `da_lib` defaults to **non-networked** (`network = false`), so
  objects and peds a client spawns are local to that client. They are not replicated to
  other players and do not persist.
- Freecam, teleport and attribute editing affect the offending player's own character,
  which on most servers is still cheating.
- The scene export path writes to that client's own UI, not to the server.

So the failure mode is "that player cheats," not "that player wrecks the server for
everyone." Bad, but recoverable. Still — turn it off in production.

---

## Checklist before you go live

- [ ] `da_dev_enabled` is `0` or absent in production `server.cfg`
- [ ] Production console shows the `[da_dev] disabled` line at startup
- [ ] `da_test` is not `ensure`d in production
- [ ] No `add_ace ... da_dev allow` lines in production `server.cfg`
- [ ] `setr debug 0` in production (debug logging is verbose and can leak internals)

---

## Reporting a problem

If you find a way for an unauthorized player to reach the dev tools while
`da_dev_enabled` is `0`, please open an issue on [da_dev](https://github.com/daggre/da_dev/issues)
