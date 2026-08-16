# Releasing

Notes for the maintainer. If you have never cut a release before, this is the whole
process — it is smaller than it looks.

---

## What a "release" actually is

Three things, and only the third one matters to users:

1. A **version number** in `fxmanifest.lua`.
2. A **git tag** on the commit that has that version.
3. A **GitHub Release** — a page with notes and a downloadable zip.

A server owner never clones anything. They click the zip. Everything below exists to
produce that zip.

---

## Version numbers

Use [semantic versioning](https://semver.org): `MAJOR.MINOR.PATCH`.

- **PATCH** (`1.0.0` → `1.0.1`) — bug fix, nothing else changed.
- **MINOR** (`1.0.0` → `1.1.0`) — new feature, existing setups keep working.
- **MAJOR** (`1.0.0` → `2.0.0`) — you broke something. Config changed, an export was
  renamed, a keybind moved.

### On going 1.0

`0.x` tells a server owner "this will break my server." That signal is wrong for code
that has run in production for months, and it is the single loudest thing turning
people away right now. `1.0.0` does not mean perfect. It means **"I will tell you when
I break compatibility."** That is the only promise it makes.

### Released — 2026-08-15

| Resource | Was | Released as |
|---|---|---|
| `da_lib` | 0.11 | **1.0.0** |
| `da_log` | 0.1.0 | **1.0.0** |
| `da_dev` | 0.0.1 | **1.0.0** |
| `da_anims` | 0.1 | **1.0.0** |
| `da_game` | — | **1.0.0** |
| `da_props` | — | **1.0.0** |

### Deliberately not released

| Resource | Why |
|---|---|
| `da_xanims` | **Deprecated.** `da_anims` replaces it. No further work; no version bump. Its README points at the migration notes. |
| `da_xinteracts` | Still moving |
| `da_audit`, `da_test` | Internal tooling, not ready to support |
| `da_farming`, `da_tack`, `da_wardrobe` | Early |
| `da_ranching`, `da_bankrob` | Unmaintained since 2024 |

Leaving these unversioned is a feature, not an omission: an unversioned repo makes no
promise, and a `0.9.0` tag on something you are not ready to support invites issues you
do not want. Version them when you are ready to stand behind them.

---

## Cutting a release, one resource

From inside the resource repo:

```bash
# 1. Set the version in fxmanifest.lua to match the tag you are about to make.
#    version '1.0.0'

# 2. Commit it.
git add fxmanifest.lua CHANGELOG.md
git commit -m "release: v1.0.0"

# 3. Tag it. The leading v is the convention; be consistent.
git tag -a v1.0.0 -m "v1.0.0"

# 4. Push the commit and the tag.
git push origin main --follow-tags
```

Then create the GitHub Release. Pushing the tag is not enough — the tag makes the
release reproducible, the Release *page* is what users actually see and download.

```bash
gh release create v1.0.0 --title "v1.0.0" --notes-file CHANGELOG.md
```

The `gh` CLI is not installed on this machine. Either install it
(`sudo apt install gh && gh auth login`), or do it on the web:
**repo → Releases → Draft a new release → pick the tag → paste the CHANGELOG entry →
publish**.

GitHub attaches source zips automatically. For a single resource that is enough — the
zip unpacks to `da_lib-1.0.0/`, which the user renames to `da_lib`. Slightly annoying,
which is why the bundle below exists.

---

## Cutting the bundle release

The bundle is what the README points at, and what most people will actually download:
one zip containing a ready-to-drop `[da]` folder, no renaming, no git.

```bash
tools/build-release.sh 2026.08
```

That clones each resource at its latest tag, strips `.git` and development files, and
writes `dist/da-devkit-2026.08.zip` containing a single `[da]/` directory.

Then:

```bash
gh release create 2026.08 dist/da-devkit-2026.08.zip \
  --title "devkit 2026.08" --notes-file dist/NOTES-2026.08.md
```

### Why the bundle uses a date, not semver

The individual resources are semver'd against their own APIs. The bundle is a snapshot
of "these versions, known to work together" — a date (`2026.08`) says that honestly
where a version number would imply a compatibility promise the bundle cannot make.

---

## CHANGELOG

Every resource gets a `CHANGELOG.md`. Newest first. Keep it short — this is for someone
deciding whether to upgrade, not a commit log.

```markdown
# Changelog

## [1.1.0] - 2026-09-01
### Added
- Prop attachment offsets in the animation editor

### Fixed
- Freecam no longer eats input after closing the menu

## [1.0.0] - 2026-08-15
First stable release.
```

Breaking changes get their own heading and say what to do:

```markdown
### Breaking
- `da_lib:registerMode` now requires `priority`. Add `priority = 50` to existing calls.
```

---

## Release checklist

- [ ] `CHANGELOG.md` updated
- [ ] `version` in `fxmanifest.lua` matches the tag
- [ ] `dependencies` in `fxmanifest.lua` are accurate
- [ ] README install section still correct
- [ ] Resource starts clean on a server with `setr debug 0`
- [ ] Tag pushed, GitHub Release published
- [ ] If this changes anything a user touches — bundle rebuilt

---

## Cadence

Do not release on a schedule. Release when something is worth downloading. A repo with
four releases across a year reads as maintained; a repo with forty reads as churn, and
a repo with none reads as abandoned regardless of how much you commit.

Cut the bundle when the set meaningfully moves — expect roughly quarterly.
