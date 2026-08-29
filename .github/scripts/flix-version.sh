#!/usr/bin/env bash
#
# Prints the Flix version pinned in flix.toml, which is the one place it is
# recorded. Both workflows read it from here rather than naming a version.
#
# Run from the root of the repository.
#
set -euo pipefail

grep -E '^"?flix"?[[:space:]]*=' flix.toml \
    | head -n1 \
    | sed -E 's/.*"([^"]+)"[[:space:]]*$/\1/'
