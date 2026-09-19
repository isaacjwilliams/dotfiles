function fish_user_key_bindings
    # Shift+Enter: accept the autosuggestion *and* run it.
    # (Right arrow / ctrl-f / End still accept without running.)
    bind shift-enter accept-autosuggestion execute
    bind --mode insert shift-enter accept-autosuggestion execute

    # The CachyOS config binds ! and $ for bash-style history expansion, but
    # only in the default mode -- which under vi bindings is *normal* mode.
    # That shadows vi's $ (end-of-line) and does nothing while you type.
    # Move both to insert mode, where they actually belong.
    if functions -q __history_previous_command
        bind --erase -- !
        bind --erase -- '$'
        bind --mode insert -- ! __history_previous_command
        bind --mode insert -- '$' __history_previous_command_arguments
    end

    # fzf.fish binds from its own conf.d file, which runs *before* conf.d/vim.fish
    # sets $fish_key_bindings. That triggers a full rebind and drops the plugin's
    # bindings, so re-apply them here -- this function is the last thing the
    # rebind calls.
    #
    # Default sequences: ctrl-alt-f files, ctrl-alt-l git log, ctrl-alt-s git
    # status, ctrl-r history, ctrl-alt-p processes. Variables are moved off
    # ctrl-v so fish's own clipboard paste keeps that key.
    if functions -q fzf_configure_bindings
        fzf_configure_bindings --variables=ctrl-alt-v
    end
end
