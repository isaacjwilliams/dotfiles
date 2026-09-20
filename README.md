# Dotfiles

Personal configuration for **CachyOS** with Hyprland, managed with
[chezmoi](https://www.chezmoi.io/).

A fresh machine goes from a stock CachyOS install to this one with a chezmoi
init and a single apply. Packages, services, the login shell, and the mise
toolchain are all set up by scripts in this repository — there is no separate
bootstrap step to remember.

## Bootstrap a new CachyOS machine

Install CachyOS with the **Hyprland** desktop profile. That profile is the
baseline this repo builds on — see [Which packages are listed](#which-packages-are-listed).
Then:

```bash
sudo pacman -S --needed chezmoi git
chezmoi init --apply https://github.com/isaacjwilliams/dotfiles.git
```

That apply will:

1. Install the packages in `.chezmoidata/packages.toml` with `shelly`, repos
   first and then the AUR. It asks for your sudo password once, at the start,
   and then shows you each AUR PKGBUILD and waits for a yes before building
   it. Expect a couple of source builds.
2. Write the configuration files, and stub out the Noctalia theme files they
   include so nothing dangles before Noctalia's first run.
3. Enable the system services, add you to the `docker` and `realtime` groups,
   and make fish your login shell.
4. Run `mise install`, whose own postinstall hook bootstraps fisher, installs
   the fish plugins, and regenerates the generated fish completions.
5. Generate this machine's Hyprland monitor layout.

Then finish by hand:

```bash
sudo chwd -a          # GPU and other hardware drivers for *this* machine
reboot                # picks up the new login shell, groups, and greetd
```

After the reboot, sign in to the things that intentionally carry no credentials
here: `gh auth login`, 1Password, Dropbox, Chrome, Spotify, Tailscale
(`sudo tailscale up`), and `heroku login` / `stripe login` if you need them.

Switch the remote to SSH once `gh auth login` has set up a key:

```bash
chezmoi cd
git remote set-url origin git@github.com:isaacjwilliams/dotfiles.git
```

### Use the same username

Two keybinds in `hyprland-gui.lua` exec absolute paths — HyprMod writes them
that way and rewrites the file on every save, so they cannot usefully be
templated:

```
SUPER + Return      /home/isaac/.config/foot/new-window
SUPER + SHIFT + Q   /home/isaac/.local/bin/wsclose
```

Create the account on the new machine as `isaac` and they just work. Under any
other username, repoint those two binds in HyprMod after the first login.

### Which packages are listed

`.chezmoidata/packages.toml` is a *delta*, not an inventory. A CachyOS install
with the Hyprland profile already provides around 148 of the packages this
machine has explicitly installed — `hyprland`, `cachyos-hypr-noctalia`,
`noctalia-greeter`, `dolphin`, `kitty`, the pipewire and bluez stacks, the font
set, `shelly` itself. Repeating them here would be 148 lines that say nothing
about what was actually chosen, so the manifest lists only the ~25 that are.

The trade-off: **pick the wrong desktop profile and this manifest will not
correct it.** One package is listed despite being a CachyOS package for exactly
that reason — `cachyos-fish-config`, which the installer adds only when fish is
chosen as the shell, and whose `cachyos-config.fish` is sourced on the first
line of the tracked `config.fish`.

Also absent, because the installer decides them per machine: kernels, headers,
microcode, GPU drivers, the bootloader, and the filesystem and boot-splash
tooling that follows from them. Copying this machine's answers (NVIDIA, Intel,
Limine, Btrfs) onto different hardware would be wrong at best. `sudo chwd -a`
is the step that gets the right GPU driver.

### Why shelly

`shelly` handles repo, AUR and Flatpak packages through libalpm directly, and
CachyOS installs it as part of every profile — so unlike `paru` or `yay` there
is nothing to bootstrap before the package script can run. It is also what
installed the AUR packages on this machine.

`shelly backup --export` writes a manifest in almost the same shape as
`packages.toml`; it is a reasonable way to check what this file is missing,
though it exports the full explicit set rather than the delta.

On a fresh CachyOS install shelly's own directories can come out owned by
root, and an AUR build then cannot write the sources it just fetched. It
reports "Failed to download package sources" and `AurOperationFailed`, which
looks like a broken build toolchain — but a hand-run `makepkg` in any other
directory succeeds, the GUI fails identically, and a reboot changes nothing.
`shelly utility --fix-permissions` is the repair; the package script runs it
before building so a new machine does not have to discover this.

One sharp edge worth knowing: `-n/--no-confirm` does **not** mean yes to
everything. shelly defines it as *safe* automatic answers, so for "Build
packages from this PKGBUILD? (y/N)" it answers no and the install fails with
`AurOperationFailed`. The package script therefore passes `-n` only to the
repo install, and lets the AUR half prompt. A machine that has never used the
AUR through shelly also has a one-time risk warning to acknowledge first.

## Scripts

| Script | Runs | Does |
| --- | --- | --- |
| `run_onchange_before_10-packages.sh.tmpl` | when `.chezmoidata/packages.toml` changes | Installs missing repo and AUR packages with `shelly`. Works out what is missing first and exits without touching the package database when the answer is nothing, so the sync-and-upgrade it would otherwise do is not a surprise on every apply. Repo packages install unattended; AUR packages prompt. |
| `run_after_15-noctalia-stubs.sh` | every apply | Creates empty placeholders for the Noctalia theme files tracked config includes, when Noctalia has not rendered them yet. Silent once they exist. |
| `run_onchange_after_20-system.sh` | when its own unit/group list changes | Enables services, adds group memberships, sets fish as the login shell. |
| `run_onchange_after_25-login-keyring.sh` | when edited | Wires `pam_gnome_keyring` into `/etc/pam.d/greetd`, so the login keyring is unlocked at login instead of by a dialog afterwards. Backs the file up and validates the rewrite before installing it. |
| `run_onchange_after_30-user-tools.sh` | when edited | `mise install`, plus the Ghostty cursor-shader checkout. |
| `run_once_after_40-hypr-monitors.sh` | once per machine | Writes `~/.config/hypr/monitors.lua` from the monitors Hyprland can see. |

### The one file here that edits `/etc`

`run_onchange_after_25-login-keyring.sh` is the only script that touches system
configuration outside package installs, and what it touches is a PAM file — the
one file on the machine that can lock you out of your own login. It is written
to fail closed at every step: it exits early if the lines are already present,
builds the replacement in a temp file, diffs that against the original to prove
nothing but the two new lines changed, keeps a timestamped backup beside it, and
renames into place rather than writing over the original.

It is worth having because the symptom is otherwise baffling. A stock CachyOS
Hyprland install wires nothing into greetd to unlock the GNOME keyring, so the
login keyring stays locked through boot and the first thing that wants a secret
— 1Password, Dropbox, Chrome — raises an unlock dialog every single session.
The dialog is often KWallet's, because `kwalletd6` claims
`org.freedesktop.secrets` when gnome-keyring has not, which sends you off
trying to uninstall KWallet. You cannot: it arrives as a dependency of `kio`,
under Dolphin, under the desktop profile. Disabling it only hands the prompt
back to gnome-keyring. The keyring is the thing to fix, not the dialog.

If the prompt survives this on a machine that already had a login keyring, the
keyring's password is not the login password and PAM cannot open it. Delete
`~/.local/share/keyrings/login.keyring` and log in again to have it recreated.

## Monitors are per-machine

HyprMod owns `~/.config/hypr/hyprland-gui.lua` and rewrites it wholesale on
every save, monitor block included — so whichever machine last opened HyprMod
puts *its* outputs and refresh rates into this repository.

`hyprland.lua` therefore ends with `pcall(require, "monitors")`. That file is
generated per machine, is listed in `.chezmoiignore`, and never travels. Because
it loads last it wins over the stale block in `hyprland-gui.lua`.

```bash
hypr-monitors --force && hyprctl reload   # after changing displays
```

With no Hyprland session to query it falls back to Hyprland's catch-all rule
(every output, preferred mode, auto position), which works anywhere but is
probably not the layout you want — rerun it from inside the session.

## Managed configuration

Paths are destinations in `$HOME`. A directory glob means the files from that
group that are in the chezmoi source, not the whole live directory.

| Managed path(s) | Configures | Notes |
| --- | --- | --- |
| `.chezmoiignore`, `.chezmoidata/packages.toml`, source `README.md` | chezmoi | The package delta and the ignore list. Neither the README nor `.chezmoidata` is applied to `$HOME`. |
| `.config/fish/config.fish`, `conf.d/{abbreviations,vim,local-bin}.fish`, `functions/fish_{title,user_key_bindings}.fish`, `fish_plugins` | fish | Layers on `cachyos-fish-config`. Vi bindings with the emacs set still live, abbreviations as the source of truth for aliases, and the fzf.fish rebinding fix. `fish_plugins` is the fisher manifest; fisher itself and everything it installs are generated at bootstrap. |
| `.config/hypr/hyprland.lua`, `hyprland-gui.lua`, `xdph.conf`, `layouts/dev.layout` | Hyprland | `hyprland-gui.lua` is HyprMod's output; `hyprland.lua` holds only what HyprMod cannot round-trip (spring curves, Lua binds, gestures, groupbar geometry). `dev.layout` is read by `devlay`. |
| `.config/noctalia/config.toml` | Noctalia shell | The palette source. Every `noctalia.*` theme file it renders is ignored — see below. Until Noctalia has rendered them once, the tracked config that includes them points at nothing; `run_after_15-noctalia-stubs.sh` covers that gap. |
| `.config/uwsm/env` | Wayland session | `BROWSER`, Qt platform theme, cursor theme and size. Read by uwsm at login. |
| `.config/gtk-3.0/{settings.ini,gtk.css}`, `.config/gtk-4.0/gtk.css`, `.config/qt6ct/qt6ct.conf`, `.config/kdeglobals`, `.icons/default/index.theme` | GTK, Qt, KDE theming | adw-gtk3, Fusion/qt6ct, breeze icons, Bibata-Modern-Ice cursors. The `gtk.css` files are one `@import` of Noctalia's generated CSS. `kdeglobals` is mostly a cached copy of Noctalia's palette; it is tracked for `TerminalApplication` and `ColorScheme`, and re-importing it after a palette change is expected. |
| `.config/ghostty/config.ghostty` | Ghostty | Font size, opacity, blur, and two custom cursor shaders. The shaders are an upstream checkout, cloned at bootstrap rather than vendored. |
| `.config/kitty/kitty.conf`, `.config/alacritty/alacritty.toml`, `.config/foot/{foot.ini,new-window}` | Kitty, Alacritty, foot | All three include their Noctalia theme file. `new-window` asks the focused foot window to spawn in its own cwd. |
| `.config/zellij/config.kdl` | Zellij | `theme "noctalia"` resolves to the theme file Noctalia renders into `themes/`. Unlike the terminals, zellij gets no placeholder for that file: it starts fine when the theme is missing, but refuses to start on one that is empty or holds no theme node. |
| `.config/btop/btop.conf`, `.config/micro/settings.json`, `.config/satty/config.toml` | btop, micro, satty | |
| `.config/mise/config.toml` | mise | The whole non-distro toolchain plus the tasks that bootstrap it: `shell-integration`, `fish-plugins`, `node-corepack`, and the local Postgres cluster helpers. Its `postinstall` hook is what makes `mise install` enough. |
| `.config/nvim/init.lua`, `lazy-lock.json`, `lua/config/*`, `lua/plugins/*`, `AGENTS.md` | Neovim / LazyVim | `lazy.nvim` clones itself on first launch; Mason installs language tooling. Ruby and Node come from mise. |
| `.config/lazygit/config.yml`, `.config/gh/config.yml`, `.config/worktrunk/config.toml`, `.gitconfig` | Git tooling | delta as pager and diff filter. `gh`'s `hosts.yml` and worktrunk's approval/lock files are intentionally not managed. |
| `.config/dolphinrc`, `.config/mimeapps.list`, `.config/chrome-flags.conf`, `.config/autostart/*.desktop`, `.local/share/applications/claude-code-url-handler.desktop` | Desktop integration | Default applications, Chrome's keyring flag, 1Password and Dropbox autostart. The Claude Code URL handler is templated onto the mise shim so a `mise up claude` cannot leave it dangling. |
| `.local/bin/{devlay,wsclose,hypr-monitors}` | Hyprland helpers | `devlay` opens a layout of windows on an empty workspace; `wsclose` closes a workspace without force-killing shared-process clients; `hypr-monitors` writes the per-machine monitor file. |
| `.local/bin/keyring-doctor` | Diagnostic | Prints which secret store owns `org.freedesktop.secrets`, which one holds secrets, whether the login collection is locked, and the state of the PAM wiring. Read-only; nothing it runs can raise a prompt. |
| `.claude/*`, `.codex/skills/*` | Claude Code, Codex | Settings, statusline, MCP proxy, and skills — including `sync-chezmoi-dotfiles`, which is the procedure for importing live changes back into this repo. |

## Deliberately not managed

This repo is an allowlist. It does not copy whole application directories just
because they live under `~/.config`.

- **Credentials and identity.** `.ssh`, `.gnupg`, `.config/gh/hosts.yml`,
  `.codex/auth.json`, `.bundle/config`, `.sem.yaml`, 1Password/Chrome/Dropbox
  profiles and login databases. chezmoi's `private_` prefix preserves
  restrictive permissions — it does **not** encrypt. Secrets are omitted, not
  committed.
- **Noctalia's generated theme files.** Noctalia rewrites them from
  `.config/noctalia/config.toml` on every palette change. The wiring that
  references them is tracked; the color values are not. See `.chezmoiignore`.
- **Anything fisher or mise generates.** `.config/fish/completions`,
  `conf.d/{fzf,zoxide}.fish`, the `_fzf_*` and `wt` functions, and
  `fish_variables`. `fish_plugins` is the tracked manifest they come from.
- **Upstream checkouts.** `.config/ghostty/shaders`, `lazy.nvim` and its
  plugins, Mason's tooling, mise's installed runtimes.
- **Machine-local state.** `.config/hypr/monitors.lua`, caches, histories,
  browser profiles, `nvim`'s `lazyvim.json`, worktrunk approvals.

Ruby and Rails tooling (RSpec, RuboCop, Ruby LSP) should come from each
project's bundle, and ESLint from each project's Node dependencies, rather than
being installed globally.

## Updating

Add files individually so the privacy boundary stays explicit:

```bash
chezmoi status
chezmoi diff
chezmoi add --secrets error ~/.config/example/config
chezmoi cd && git status
```

`.codex/skills/sync-chezmoi-dotfiles` documents this loop in full.

To add a package, edit `.chezmoidata/packages.toml` and run `chezmoi apply`;
the change to the list is what makes the install script run again. `shelly
backup --export` lists everything explicitly installed, which is the quickest
way to spot something the manifest has not caught.
