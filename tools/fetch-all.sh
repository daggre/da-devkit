#!/usr/bin/env bash
# Clone every devkit resource into a [da] folder, for development.
#
#   tools/fetch-all.sh /path/to/server/resources
#
# Server owners do not need this — use the release zip instead. This is for working on
# the resources themselves: each one stays an independent git repo on its default
# branch, so you can commit and push per resource.

set -euo pipefail

TARGET="${1:-.}"
GH_ORG="${GH_ORG:-daggre}"
DEST="$TARGET/[da]"

# The released set, plus the unreleased ones a contributor may want to work on.
# da_xanims is deprecated (da_anims replaces it) and deliberately not listed.
RESOURCES=(
    da_props
    da_log
    da_lib
    da_dev
    da_anims
    da_game

    # unreleased — still moving, no version, no support
    da_audit
    da_test
    da_xinteracts
)

mkdir -p "$DEST"
echo "==> Cloning into $DEST"

for name in "${RESOURCES[@]}"; do
    if [[ -d "$DEST/$name/.git" ]]; then
        echo "--> $name (exists, pulling)"
        git -C "$DEST/$name" pull --quiet --ff-only || echo "    !! pull failed, leaving as-is"
    else
        echo "--> $name"
        git clone --quiet "https://github.com/$GH_ORG/$name.git" "$DEST/$name"
    fi
done

echo
echo "Done. Copy da_resources.cfg.example to $DEST/da_resources.cfg, then add"
echo "to your server.cfg:"
echo
echo "  exec resources/[da]/da_resources.cfg"
echo
echo "da_dev is off by default. To enable on a development server:"
echo "  setr da_dev_enabled 1"
echo "  add_ace group.admin da_dev allow"
