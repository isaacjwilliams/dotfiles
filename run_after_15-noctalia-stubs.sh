#!/usr/bin/env bash
#
# Create empty placeholders for the Noctalia theme files that tracked config
# includes, when Noctalia has not generated them yet.
#
# Noctalia renders these from ~/.config/noctalia/config.toml, so they are
# machine state and .chezmoiignore leaves them out of the repo. But the config
# that *references* them is tracked, and on a fresh machine that reference
# dangles until Noctalia runs for the first time. foot is the sharp edge:
# a missing `include=` is fatal, it exits 230 and will not start at all --
# on the terminal SUPER + Return is bound to. kitty, btop, ghostty, qt6ct and
# GTK only warn, and alacritty does not even do that, but an empty file costs
# nothing and makes the whole class of failure go away.
#
# Plain `run_` rather than `run_once_`/`run_onchange_`: this is a self-healing
# guard, and it should still fix things on an apply years from now. It is a
# handful of existence tests and stays silent when there is nothing to do.
#
# Noctalia overwrites these the moment it renders a palette. Nothing here tries
# to guess at colors -- an empty file means "no overrides", so each application
# falls back to its own defaults and looks unstyled rather than wrong.
#
# Not listed: .config/hypr/noctalia.lua and .config/nvim/lua/matugen.lua. Both
# are Lua modules whose callers already pcall the require, and an empty .lua
# would load as `true` and break the call that follows.
#
# Also not listed: .config/zellij/themes/noctalia.kdl, which inverts the rule
# this script is built on -- for zellij the missing file is the safe state and
# the stub is the fatal one. It tolerates `theme "noctalia"` resolving to
# nothing and falls back to its own palette, but every file under themes/ must
# parse as KDL *and* contain a theme node. Empty, `# `-commented (not a KDL
# comment at all) and `// `-commented placeholders each abort startup with a
# parse error, which is the very failure this script exists to prevent.

set -euo pipefail

stubs=(
    "${HOME}/.config/foot/themes/noctalia"            # fatal if missing
    "${HOME}/.config/kitty/themes/noctalia.conf"
    "${HOME}/.config/alacritty/themes/noctalia.toml"
    "${HOME}/.config/ghostty/themes/noctalia"
    "${HOME}/.config/btop/themes/noctalia.theme"
    "${HOME}/.config/qt6ct/colors/noctalia.conf"
    "${HOME}/.config/gtk-3.0/noctalia.css"
    "${HOME}/.config/gtk-4.0/noctalia.css"
)

created=0
for stub in "${stubs[@]}"; do
    [ -e "$stub" ] && continue
    mkdir -p "$(dirname "$stub")"
    case "$stub" in
        *.css) printf '/* Placeholder until Noctalia generates this. */\n' > "$stub" ;;
        *)     printf '# Placeholder until Noctalia generates this.\n' > "$stub" ;;
    esac
    created=$((created + 1))
done

if [ "$created" -gt 0 ]; then
    echo "==> created ${created} Noctalia theme placeholder(s); they are replaced"
    echo "    the first time Noctalia renders a palette"
fi
