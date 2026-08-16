# Running the dev tools

`da_dev` is a development kit — object and animation editors, a freecam, a placement
gizmo. It's for *building* things, not for playing on. Like any editor, it belongs on
your development server and not on the one your players connect to.

So it ships **off by default**. One convar turns it on, which means you can keep a single
`[da]` folder and deploy it to both machines without maintaining two copies or
remembering to strip anything out.

`da_test` is the same kind of thing — a harness that drives the library and checks
results. Same advice: dev server only.

---

## Setup

**On your live server**, do nothing. `da_dev_enabled` defaults to `0`, and at that
setting the resource stops itself during startup. You'll see this in the console, which
is just it confirming it stayed out of the way:

```
[da_dev] da_dev_enabled is 0 - All da_dev kit permissions disabled. Set `setr da_dev_enabled 1` to enable.
```

**On your development server**, turn it on and say who can use it:

```cfg
setr da_dev_enabled 1
add_ace group.admin da_dev allow
```

That's the whole setup. Both files can stay in your `server.cfg` on either machine.

---

## The convar

| `da_dev_enabled` | What happens | Use it for |
|---|---|---|
| `0` (default) | The resource stops at startup and never loads | Live servers |
| `1` | Runs; each player needs the `da_dev` ACE | A dev server with other people on it |
| `2` | Runs; everyone on the server can use it | Your own local box |

At `0` the resource isn't running, so it's never sent to connecting clients — nothing to
load, nothing to open. That's what makes it safe to leave the `ensure` line in a shared
config.

## Granting access

At level `1`, nobody gets the tools until you say so. Access is granted with a standard
FiveM/RedM [ACE](https://docs.fivem.net/docs/server-manual/server-commands/#add_ace-principal-object-allowdeny):

```cfg
add_ace group.admin da_dev allow                  # anyone in group.admin
add_ace identifier.license:abc123 da_dev allow    # one specific person
```

Until that passes, the client doesn't register the dev modes at all, so the keybinds
simply do nothing. If you change ACEs while the server is up, run `da_dev_reauth` in the
console to re-check everyone without a restart.

Level `2` skips the check and allows everyone. It's there so you don't have to configure
ACE groups on a local box you're the only person connecting to.

Worth knowing: the ACE check gates client-side code, so treat it as "keeping the tools to
the right people on a dev server" rather than something to lean on with untrusted players
connected. That's what level `0` is for, and it's why it's the default.

---

## If it does end up running somewhere it shouldn't

Not a disaster, and worth knowing so you can size the problem correctly:

- Entities spawned through `da_lib` are **non-networked** by default, so props and peds
  someone spawns exist only on their own client. Other players don't see them and nothing
  persists after they disconnect.
- Freecam, teleport and attribute editing affect that player's own character.
- Scene export writes to that player's own UI, not to your server.

So the realistic worst case is one person messing about on their own screen — annoying,
not damaging, and it stops the moment you set the convar back to `0` and restart.

---

## Before you go live

- [ ] `da_dev_enabled` is `0` or absent
- [ ] Console shows the `da_dev` disabled line at startup
- [ ] `da_test` isn't `ensure`d
- [ ] No `add_ace ... da_dev allow` lines
- [ ] `setr debug 0` — debug logging is very verbose and you don't want it in production

---

Questions about any of this: the [da.dev Discord](https://discord.com/invite/JgteBpXGaA).
If something here doesn't behave the way it's described, please open an issue on
[da_dev](https://github.com/daggre/da_dev/issues).
