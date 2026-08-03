#!/usr/bin/env bash

disable_xdg_autostart() {
	local name="$1"
	local destination="$HOME/.config/autostart/$name"

	mkdir -p "$HOME/.config/autostart"
	if [[ ! -e "$destination" ]]; then
		cp "/etc/xdg/autostart/$name" "$destination"
	fi
	desktop-file-edit \
		--set-key=Hidden \
		--set-value=true \
		"$destination"
}
