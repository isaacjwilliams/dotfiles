# Abbreviations.
#
# Unlike aliases, these expand in place as you type, so history and
# autosuggestions see the real command. Defined here (global scope) rather than
# with `abbr -a` at the prompt (universal scope) so the file is the source of
# truth and travels with the dotfiles.
#
# `%` marks where the cursor lands after expansion (--set-cursor).

status is-interactive; or exit 0

# --- git ------------------------------------------------------------------
abbr -a gs git status
abbr -a gd git diff
abbr -a gds git diff --staged
abbr -a ga git add
abbr -a gaa git add --all
abbr -a gc git commit
abbr -a gcm --set-cursor "git commit -m '%'"
abbr -a gca git commit --amend
abbr -a gco git checkout
abbr -a gsw git switch
abbr -a gb git branch
abbr -a gl git log --oneline --graph --decorate -20
abbr -a gp git push
abbr -a gpf git push --force-with-lease
abbr -a gpl git pull
abbr -a gst git stash
abbr -a gstp git stash pop

# --- worktrunk ------------------------------------------------------------
# `wt switch` and friends have real completions, so expanding to the bare
# subcommand and then tabbing is the fast path.
abbr -a wl wt list
abbr -a ws wt switch
abbr -a wsc wt switch -c
abbr -a wrm wt remove

# --- editors / TUIs -------------------------------------------------------
abbr -a v nvim
abbr -a v. nvim .
abbr -a lg lazygit
abbr -a lzd lazydocker

# --- mise -----------------------------------------------------------------
abbr -a mr mise run
abbr -a mi mise install
abbr -a mu mise use -g
abbr -a mx mise exec --
abbr -a mls mise ls

# --- chezmoi --------------------------------------------------------------
abbr -a cz chezmoi
abbr -a cza chezmoi apply
abbr -a cze chezmoi edit
abbr -a czd chezmoi diff
abbr -a czcd chezmoi cd

# --- ruby / rails ---------------------------------------------------------
abbr -a rs rails s
abbr -a rc rails c
abbr -a be bundle exec

# --- claude ---------------------------------------------------------------
abbr -a cl claude
abbr -a clr claude -r
abbr -a clc claude -c
abbr -a cln claude -n

# --- codex ----------------------------------------------------------------
abbr -a cx codex
