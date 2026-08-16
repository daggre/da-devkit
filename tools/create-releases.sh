#!/usr/bin/env bash
# Create the GitHub Release pages for a tagged version.
#
#   tools/create-releases.sh 1.0.0 2026.08
#
# Arg 1 is the per-resource version (tag `v<version>`), arg 2 the bundle version
# (tag `<bundle>` on this repo, with the zip attached). Omit arg 2 to skip the bundle.
#
# Pushing a tag is not a release: the tag makes the build reproducible, the Release page
# is what people find and download. This turns each repo's CHANGELOG entry into that
# page so the notes and the changelog can never disagree.
#
# Idempotent — a repo that already has the release is skipped, so it is safe to re-run
# after fixing one that failed.
#
# Requires: gh (authenticated). Install with:
#   sudo apt install gh && gh auth login

set -uo pipefail

VERSION="${1:-}"
BUNDLE="${2:-}"

if [[ -z "$VERSION" ]]; then
    echo "usage: $0 <version> [bundle-version]   e.g. $0 1.0.0 2026.08" >&2
    exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESOURCES_DIR="${RESOURCES_DIR:-$ROOT/../resources/[da]}"
TAG="v$VERSION"

RESOURCES=(da_log da_lib da_anims da_props da_game da_dev)

if ! command -v gh >/dev/null; then
    echo "gh is not installed. Install it, then authenticate:" >&2
    echo "  sudo apt install gh && gh auth login" >&2
    exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
    echo "gh is installed but not authenticated. Run: gh auth login" >&2
    exit 1
fi

# Pull the section for this version out of a CHANGELOG: from its heading to the next one.
extract_notes() {
    awk -v ver="$1" '
        $0 ~ "^## \\[" ver "\\]" { grab = 1; next }
        grab && /^## / { exit }
        grab { print }
    ' "$2"
}

fail=0

for name in "${RESOURCES[@]}"; do
    repo="$RESOURCES_DIR/$name"

    if [[ ! -d "$repo/.git" ]]; then
        echo "!! $name — not a git repo at $repo, skipping"
        fail=1
        continue
    fi

    if gh release view "$TAG" --repo "daggre/$name" >/dev/null 2>&1; then
        echo "== $name — release $TAG already exists, skipping"
        continue
    fi

    if ! git -C "$repo" rev-parse "$TAG" >/dev/null 2>&1; then
        echo "!! $name — no local tag $TAG, skipping"
        fail=1
        continue
    fi

    notes_file="$(mktemp)"
    if [[ -f "$repo/CHANGELOG.md" ]]; then
        extract_notes "$VERSION" "$repo/CHANGELOG.md" > "$notes_file"
    fi
    if [[ ! -s "$notes_file" ]]; then
        echo "First stable release." > "$notes_file"
    fi

    echo "-> $name $TAG"
    if gh release create "$TAG" \
        --repo "daggre/$name" \
        --title "$TAG" \
        --notes-file "$notes_file"; then
        echo "   done"
    else
        echo "!! $name — release creation failed"
        fail=1
    fi
    rm -f "$notes_file"
done

# --- the bundle release on this repo -------------------------------------------------
if [[ -n "$BUNDLE" ]]; then
    zip="$ROOT/dist/da-devkit-$BUNDLE.zip"
    notes="$ROOT/dist/NOTES-$BUNDLE.md"

    if [[ ! -f "$zip" ]]; then
        echo "!! bundle — $zip not found. Run: tools/build-release.sh $BUNDLE"
        fail=1
    elif gh release view "$BUNDLE" --repo daggre/da-devkit >/dev/null 2>&1; then
        echo "== bundle — release $BUNDLE already exists, skipping"
    else
        # The bundle tag lives on this repo and may not exist yet.
        if ! git -C "$ROOT" rev-parse "$BUNDLE" >/dev/null 2>&1; then
            echo "-> tagging da-devkit $BUNDLE"
            git -C "$ROOT" tag -a "$BUNDLE" -m "devkit bundle $BUNDLE"
            git -C "$ROOT" push origin "$BUNDLE"
        fi

        echo "-> bundle $BUNDLE"
        if gh release create "$BUNDLE" "$zip" \
            --repo daggre/da-devkit \
            --title "devkit $BUNDLE" \
            --notes-file "$notes"; then
            echo "   done"
        else
            echo "!! bundle — release creation failed"
            fail=1
        fi
    fi
fi

echo
if [[ $fail -eq 0 ]]; then
    echo "All releases created."
else
    echo "Finished with errors — re-run to retry the ones that failed." >&2
fi
exit $fail
