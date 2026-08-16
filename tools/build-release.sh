#!/usr/bin/env bash
# Build a bundle release: one zip containing a ready-to-drop [da] folder.
#
#   tools/build-release.sh 2026.08
#
# Clones each resource at its latest tag (or a pinned tag from resources.txt), strips
# git metadata and development files, and writes dist/da-devkit-<version>.zip.
#
# Requires: git, zip.

set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
    echo "usage: $0 <version>   e.g. $0 2026.08" >&2
    exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/build"
DIST="$ROOT/dist"
STAGE="$BUILD/[da]"
GH_ORG="${GH_ORG:-daggre}"

# Resources included in the bundle, in server.cfg load order.
# Pin a tag with "name@tag"; bare names take the newest tag on the default branch.
RESOURCES=(
    da_props
    da_log
    da_lib
    da_dev
    da_anims
    da_game
)

rm -rf "$BUILD"
mkdir -p "$STAGE" "$DIST"

echo "==> Building devkit bundle $VERSION"

MANIFEST=""

for entry in "${RESOURCES[@]}"; do
    name="${entry%@*}"
    pin=""
    [[ "$entry" == *@* ]] && pin="${entry#*@}"

    echo "--> $name"
    git clone --quiet "https://github.com/$GH_ORG/$name.git" "$STAGE/$name"

    if [[ -n "$pin" ]]; then
        tag="$pin"
    else
        tag="$(git -C "$STAGE/$name" describe --tags --abbrev=0 2>/dev/null || true)"
    fi

    if [[ -z "$tag" ]]; then
        echo "    !! no tag found — using default branch HEAD (untagged)" >&2
        tag="$(git -C "$STAGE/$name" rev-parse --short HEAD)"
    else
        git -C "$STAGE/$name" -c advice.detachedHead=false checkout --quiet "$tag"
    fi

    echo "    $tag"
    MANIFEST+="| \`$name\` | $tag |"$'\n'

    # Strip everything a server does not need to run the resource.
    rm -rf "$STAGE/$name/.git" \
           "$STAGE/$name/.github" \
           "$STAGE/$name/.scratch" \
           "$STAGE/$name/.claude" \
           "$STAGE/$name/tests" \
           "$STAGE/$name/CONTRIBUTING.md"
    find "$STAGE/$name" -name '.gitignore' -delete 2>/dev/null || true
done

# Ships as da_resources.cfg so `exec resources/[da]/da_resources.cfg` works as-is.
cp "$ROOT/da_resources.cfg.example" "$STAGE/da_resources.cfg"
cp "$ROOT/docs/SECURITY.md" "$STAGE/SECURITY.md"

cat > "$STAGE/README.txt" <<EOF
da devkit — bundle $VERSION

1. Move this [da] folder into your server's resources/ directory.
2. Add this one line to your server.cfg:

       exec resources/[da]/da_resources.cfg

3. Restart the server. Press X in game for the animation menu.

da_dev is included but DISABLED by default — it stops itself at boot and is never
sent to clients. Read SECURITY.md before turning it on.

https://github.com/$GH_ORG/da-devkit
EOF

# Release notes stub with the exact versions this bundle contains. Written only if the
# notes do not already exist — rebuilding a bundle must never discard notes you wrote by
# hand. Delete the file if you want it regenerated.
NOTES="$DIST/NOTES-$VERSION.md"
if [[ -f "$NOTES" ]]; then
    echo "==> keeping existing $(basename "$NOTES") (delete it to regenerate)"
    NOTES="/dev/null"
fi

cat > "$NOTES" <<EOF
## devkit bundle $VERSION

Download \`da-devkit-$VERSION.zip\`, unzip into \`resources/\`, then add one line to
your \`server.cfg\`:

\`\`\`cfg
exec resources/[da]/da_resources.cfg
\`\`\`

\`da_dev\` is included but disabled by default. See \`SECURITY.md\` in the bundle.

### Included

| Resource | Version |
|---|---|
$MANIFEST

### Notes

<!-- what changed since the last bundle -->
EOF

(cd "$BUILD" && zip -qr "$DIST/da-devkit-$VERSION.zip" "[da]")
rm -rf "$BUILD"

echo
echo "==> dist/da-devkit-$VERSION.zip"
echo "==> dist/NOTES-$VERSION.md  (fill in the Notes section before publishing)"
echo
echo "Publish with:"
echo "  gh release create $VERSION dist/da-devkit-$VERSION.zip \\"
echo "    --title \"devkit $VERSION\" --notes-file dist/NOTES-$VERSION.md"
