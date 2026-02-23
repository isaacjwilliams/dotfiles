#!/usr/bin/env bash

eval "$(mise activate bash)"

if command -v wt > /dev/null 2>&1; then
	eval "$(command wt config shell init bash)"
fi

if command -v zmx &> /dev/null; then
	eval "$(zmx completions bash)"
fi
