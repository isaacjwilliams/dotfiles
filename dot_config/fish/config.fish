source /usr/share/cachyos-fish-config/cachyos-config.fish

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end

# Keep this after the CachyOS config: that file calls `fish_add_path`, which
# prepends, so activating mise later is what keeps mise-managed tools ahead of
# ~/.local/bin on PATH.
mise activate fish | source

# Key bindings, cursor shapes and abbreviations live in conf.d/.
