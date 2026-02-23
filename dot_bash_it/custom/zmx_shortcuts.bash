#!/usr/bin/env bash

zs() {
	if [[ $# -ne 1 ]]; then
		echo "Usage: zs <session-prefix>" >&2
		return 1
	fi

	export ZMX_SESSION_PREFIX="$1."
}

za() {
	if [[ $# -lt 1 ]]; then
		echo "Usage: za <name> [args...]" >&2
		return 1
	fi

	local name="$1"
	local title
	local display_prefix
	shift

	if [[ -n "${ZMX_SESSION_PREFIX:-}" ]]; then
		display_prefix="${ZMX_SESSION_PREFIX%.}"
		title="${display_prefix}: ${name}"
	else
		title="${name}"
	fi

	kitty @ set-window-title "$title"
	zmx a "$name" "$@"
}
