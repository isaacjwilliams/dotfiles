function fish_title --description 'Show worktree or full path, followed by the command'
    set -l location "$PWD"
    set -l worktree (command git rev-parse --show-toplevel 2>/dev/null)
    if test -n "$worktree"
        set location (path basename -- "$worktree")
    end

    set -l running_command fish
    if set -q argv[1]; and test -n "$argv[1]"
        set running_command "$argv[1]"
    end

    printf '%s: %s\n' "$location" "$running_command"
end
