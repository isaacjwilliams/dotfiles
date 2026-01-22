#!/usr/bin/env bash

. <(asdf completion bash)

if command -v wt >/dev/null 2>&1; then
  eval "$(command wt config shell init bash)"
fi
