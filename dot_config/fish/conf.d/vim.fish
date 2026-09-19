# Vi editing mode.
#
# Lives in conf.d rather than config.fish so the key-binding setup is one
# self-contained unit. Load order is safe: conf.d runs before config.fish (and
# therefore before the CachyOS config's `bind ! ...`), but fish applies the
# binding set lazily at reader init -- after every config file has run -- so
# fish_user_key_bindings still gets the last word. Verified with `bind`.

status is-interactive; or exit 0

# Vi bindings, with the emacs bindings still available in every mode.
set -g fish_key_bindings fish_hybrid_key_bindings

# Cursor shape per vi mode. Ghostty's default is a bar, so `external` keeps
# that shape for anything fish hands off to.
set -g fish_cursor_default block
set -g fish_cursor_insert line
set -g fish_cursor_replace_one underscore
set -g fish_cursor_replace underscore
set -g fish_cursor_visual block
set -g fish_cursor_external line
fish_vi_cursor
