#!/usr/bin/env bash
#
# Give this machine its own ~/.config/hypr/monitors.lua on the first apply.
#
# `run_once_`: the file is machine-local and chezmoi-ignored, so it is written
# exactly once and then left alone -- re-running would clobber a layout the
# user has since adjusted. `hypr-monitors --force` is the way back.

set -euo pipefail

helper="${HOME}/.local/bin/hypr-monitors"

if [ ! -x "$helper" ]; then
    echo "==> ${helper} missing; skipping monitor setup" >&2
    exit 0
fi

echo "==> generating this machine's Hyprland monitor layout"
"$helper"
