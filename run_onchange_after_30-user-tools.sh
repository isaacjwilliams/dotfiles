#!/usr/bin/env bash
#
# Everything pacman does not provide: the mise toolchain and the one upstream
# Git checkout that managed config points at.
#
# mise does most of the work. `mise install` reads the freshly applied
# ~/.config/mise/config.toml, and that file's `postinstall` hook then runs its
# own shell-integration, fish-plugins, and node-corepack tasks -- which is what
# bootstraps fisher, installs the fish plugins listed in ~/.config/fish/
# fish_plugins, and regenerates conf.d/zoxide.fish and the gh/wt completions.
# So this script does not duplicate any of that.

set -euo pipefail

# --- mise toolchain --------------------------------------------------------

if command -v mise >/dev/null 2>&1; then
    echo "==> mise install (this pulls Ruby, Node, Rust, Go, Postgres, ...)"
    # Not fatal: a single tool whose upstream is down should not fail the apply.
    mise install --yes || echo "!! mise install reported errors; run it again by hand" >&2
else
    echo "==> mise not installed; skipping toolchain"
fi

# --- Ghostty cursor shaders ------------------------------------------------
#
# ~/.config/ghostty/config.ghostty sets custom-shader to two files from this
# repository. It is an upstream checkout, not our content, so it is kept as a
# clone (and ignored in .chezmoiignore) rather than vendored into the source
# tree.

shaders_dir="${HOME}/.config/ghostty/shaders"
shaders_repo="https://github.com/sahaj-b/ghostty-cursor-shaders"

if [ -d "${shaders_dir}/.git" ]; then
    echo "==> ghostty shaders already cloned"
elif command -v git >/dev/null 2>&1; then
    echo "==> cloning ghostty cursor shaders"
    # An existing non-git directory would make the clone fail; leave it alone
    # and say so rather than deleting whatever is there.
    if [ -e "$shaders_dir" ]; then
        echo "!! $shaders_dir exists but is not a git checkout; leaving it" >&2
    else
        git clone --depth=1 "$shaders_repo" "$shaders_dir" ||
            echo "!! could not clone shaders; Ghostty will log a missing-shader warning" >&2
    fi
fi
