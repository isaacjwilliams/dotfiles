# Dotfiles

Personal configuration managed with [chezmoi](https://www.chezmoi.io/) and
intended primarily for Fedora Linux.

## Bootstrap on Fedora

Install the minimum bootstrap packages, initialize the chezmoi source, install
Bash-it before applying (chezmoi manages files inside `~/.bash_it`), and then
apply the dotfiles:

```bash
sudo dnf install bash chezmoi git
chezmoi init https://github.com/isaacjwilliams/dotfiles.git
git clone --depth=1 https://github.com/Bash-it/bash-it.git ~/.bash_it
~/.bash_it/install.sh --no-modify-config
chezmoi apply
```

Most directly required Fedora packages are available from the Fedora repos:

```bash
sudo dnf install \
  bash-completion btop curl desktop-file-utils fd-find fontconfig gcc gcc-c++ \
  gh git-delta jq kitty make neovim ripgrep unzip wl-clipboard
```

These configured programs use upstream-recommended COPRs on Fedora:

```bash
sudo dnf install dnf5-plugins
sudo dnf copr enable dejan/lazygit
sudo dnf copr enable scottames/ghostty
sudo dnf copr enable jdxcode/mise
sudo dnf install ghostty lazygit mise
```

Install Zed with its official Linux installer:

```bash
curl -f https://zed.dev/install.sh | sh
```

Then install the tool versions declared in `~/.config/mise/config.toml`:

```bash
mise install
```

That Mise config installs Node.js, Ruby, Rust, LazyDocker, and the OpenAI Codex
CLI. The versions in the config are intentional pins except for Rust and Codex,
which currently follow `latest`.

## Managed configuration and dependencies

Paths below are destination paths in the home directory. A directory glob means
all files from that group that are present in the chezmoi source, not the entire
live directory.

| Managed path(s) | Configures | Direct dependencies and notes | Fedora / upstream source |
| --- | --- | --- | --- |
| `.chezmoiignore`, source `README.md` | chezmoi | `chezmoi`; Git for source history. The README and generated Neovim `lazyvim.json` are not applied to `$HOME`. | [Fedora chezmoi package](https://packages.fedoraproject.org/pkgs/chezmoi/chezmoi/), [chezmoi](https://www.chezmoi.io/) |
| `.bashrc`, `.bash_profile`, `.bash_it/aliases/*`, `.bash_it/custom/*` | Bash and Bash-it | Bash-it with the `bobby` theme; `git`; `mise`; Worktrunk (`wt`); `zmx`; Kitty remote control for the `za` helper; and `desktop-file-edit` from `desktop-file-utils`. Only custom Bash-it files are managed—the upstream installation is not. | Fedora `bash`, `bash-completion`, `git`, and `desktop-file-utils`; [Bash-it installation](https://bash-it.readthedocs.io/en/latest/installation/) |
| `.codex/rules/default.rules` | OpenAI Codex CLI | Codex is installed by Mise from `npm:@openai/codex`. The tracked Rails rules reference Bundler, RSpec, Rails, RuboCop, and the Semaphore CLI (`sem`). | [Codex CLI](https://learn.chatgpt.com/docs/codex/cli), [Semaphore CLI](https://docs.semaphoreci.com/EE/reference/semaphore-cli) |
| `.config/btop/btop.conf` | btop | No non-system dependency; it currently uses btop's default theme. | [Fedora btop package](https://packages.fedoraproject.org/pkgs/btop/), [btop](https://github.com/aristocratos/btop) |
| `.config/fontconfig/fonts.conf` | Fontconfig | Fontconfig and user fonts under `~/.local/share/fonts`; enables synthetic italic/bold and font rendering preferences. | Fedora `fontconfig`, [Fontconfig](https://www.freedesktop.org/wiki/Software/fontconfig/) |
| `.config/gh/config.yml` | GitHub CLI | `gh` and Git. Authentication in `hosts.yml` is intentionally not managed. | Fedora `gh`, [GitHub CLI](https://cli.github.com/) |
| `.config/ghostty/config.ghostty`, `.config/ghostty/themes/*` | Ghostty | The Tokyo Night theme is tracked locally, so no separate theme download is required. | [Ghostty Fedora installation](https://ghostty.org/docs/install/binary) |
| `.config/kitty/kitty.conf`, `.config/kitty/theme.conf`, `.config/kitty/themes/*` | Kitty | The active Catppuccin Mocha theme and symlink are tracked. Remote control is enabled for the Bash `za` helper. | Fedora `kitty`, [Kitty](https://sw.kovidgoyal.net/kitty/), [Catppuccin theme source](https://github.com/catppuccin/kitty) |
| `.config/lazygit/config.yml` | LazyGit | Git and `delta`; both configured pagers invoke `delta`. | [LazyGit Fedora/COPR instructions](https://github.com/jesseduffield/lazygit#fedora--amazon-linux-2023--centos-stream), [Fedora git-delta package](https://packages.fedoraproject.org/pkgs/rust-git-delta/git-delta/) |
| `.config/mise/config.toml` | Mise | Installs LazyDocker 0.24.3, Node.js 25.2.1, Ruby 3.4.2, latest Rust, and latest `@openai/codex`. Network access to the corresponding registries is required by `mise install`. | [Mise Fedora installation](https://mise.jdx.dev/installing-mise.html) |
| `.config/nvim/init.lua`, `.config/nvim/lazy-lock.json`, `.config/nvim/lua/plugins/*`, `.config/nvim/AGENTS.md` | Neovim with LazyVim | Git and GitHub SSH authentication for plugin clones; `ripgrep`, `fd`, a compiler/toolchain, `wl-clipboard`, and a Nerd Font. Ruby/TypeScript extras use the Ruby and Node toolchains from Mise; Rails testing uses Bundler/RSpec. `lazy.nvim` and Mason install editor plugins and language tooling. | Fedora `neovim`, `ripgrep`, `fd-find`, compiler packages, and `wl-clipboard`; [Neovim](https://neovim.io/), [LazyVim](https://www.lazyvim.org/), [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts) |
| `.config/worktrunk/config.toml` | Worktrunk (`wt`) | Git; Bash shell integration; Codex CLI and `jq` for generated commit messages. Project-specific approval and lock files are intentionally not managed. | [Worktrunk](https://worktrunk.dev/) |
| `.config/zed/keymap.json`, `.config/zed/settings.json` | Zed | Git; EnvyCodeR Nerd Font Mono; Ruby LSP and RuboCop from project bundles; ESLint from project Node dependencies; `npx` for Chrome DevTools MCP; the Zed registry `codex-acp` agent server; and project commands using Bundler, RSpec, Rails, RuboCop, and `sem`. | [Zed on Linux](https://zed.dev/docs/linux), [Nerd Fonts releases](https://github.com/ryanoasis/nerd-fonts/releases) |
| `.gitconfig` | Git | Neovim as editor and `delta` as pager/diff filter. | Fedora `git` and `git-delta`; [Git](https://git-scm.com/), [delta](https://github.com/dandavison/delta) |

## Additional installations

The following are referenced by managed config but are not Fedora base packages
or are intentionally installed outside DNF:

- [Worktrunk](https://worktrunk.dev/): `cargo install worktrunk`.
- [zmx](https://zmx.sh/): use the upstream Linux binary or build with Zig. Bash
  completion, prompt integration, and Kitty shortcuts are managed here.
- [Semaphore CLI](https://docs.semaphoreci.com/EE/reference/semaphore-cli): needed
  only for the tracked `sem` Codex/Zed project workflows; its auth config stays
  local.
- [EnvyCodeR Nerd Font](https://github.com/ryanoasis/nerd-fonts/releases): install
  it under `~/.local/share/fonts` and run `fc-cache -f` for the Zed font setting.

Ruby/Rails tools such as RSpec, RuboCop, Ruby LSP, and Rails should normally come
from each project's bundle rather than global Fedora gems. ESLint should
normally come from each project's Node dependencies.

## Deliberately not managed

This repo uses an allowlist approach. It does not copy whole application
directories merely because they live under `~/.config`.

- Credentials and identity material: `.netrc`, `.ssh`, `.gnupg`,
  `.bundle/config`, `.sem.yaml`, `.config/gh/hosts.yml`, `.config/ngrok`,
  `.papertrail.yml`, and application login/session databases.
- Upstream installations and vendored collections: most of `.bash_it`,
  `.config/kitty/kitty-themes`, Mise-installed runtimes, application binaries,
  and `node_modules`.
- Generated or machine-local state: caches, histories, logs, databases, browser
  profiles, desktop-environment state, Neovim's `nvim.log` and `lazyvim.json`,
  Worktrunk approval/lock files, and empty/default configs such as LazyDocker's
  current config.

Chezmoi's `private_` source-name prefix preserves restrictive file permissions;
it does **not** encrypt file contents. Authentication files are omitted rather
than committed in plaintext.

## Updating

Review and add individual files so the privacy boundary remains explicit:

```bash
chezmoi status
chezmoi diff
chezmoi add --secrets error ~/.config/example/config
chezmoi cd
git status
```
