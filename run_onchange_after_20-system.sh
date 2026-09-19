#!/usr/bin/env bash
#
# System-level setup that installing packages does not do on its own: enabling
# the units those packages ship, putting the user in the groups they need, and
# making fish the login shell.
#
# `run_onchange_` keyed on the lists below, so adding a unit here re-runs it.
# Everything is idempotent, so a spurious re-run is harmless.
#
# Deliberately absent: limine-snapper-sync and intel_lpmd. Both are tied to
# this machine's bootloader and CPU; see .chezmoidata/packages.toml.

set -euo pipefail

if ! command -v systemctl >/dev/null 2>&1; then
    echo "==> no systemd; skipping system setup"
    exit 0
fi

system_units=(
    ananicy-cpp.service      # CachyOS process-priority daemon
    avahi-daemon.service     # mDNS, paired with nss-mdns
    bluetooth.service
    docker.service
    greetd.service           # login manager; runs noctalia-greeter
    NetworkManager.service
    tailscaled.service
    ufw.service
    cachyos-rate-mirrors.timer
    fstrim.timer
    snapper-cleanup.timer
)

echo "==> sudo is needed for services, groups, and the login shell"
sudo -v

for unit in "${system_units[@]}"; do
    # `list-unit-files` exits 0 and prints nothing for a unit that does not
    # exist, so the output is what has to be tested. A unit whose package
    # failed to install should not abort the rest.
    if [ -z "$(systemctl list-unit-files --no-legend "$unit" 2>/dev/null)" ]; then
        echo "    $unit not installed; skipping"
        continue
    fi
    if systemctl is-enabled --quiet "$unit" 2>/dev/null; then
        echo "    $unit already enabled"
        continue
    fi
    echo "    enabling $unit"
    sudo systemctl enable "$unit" || echo "    !! could not enable $unit" >&2
done

# Group membership. `docker` is what lets the CLI reach the daemon without
# sudo; `realtime` is what realtime-privileges exists to grant. Both only take
# effect on the next login.
for group in docker realtime; do
    getent group "$group" >/dev/null 2>&1 || continue
    if id -nG "$USER" | tr ' ' '\n' | grep -qx "$group"; then
        echo "    already in group $group"
        continue
    fi
    echo "    adding $USER to group $group"
    sudo usermod -aG "$group" "$USER"
    echo "       (log out and back in for this to take effect)"
done

# Login shell. ~/.config/fish is managed here, so the shell that reads it
# should be the one the machine logs into.
fish_path=$(command -v fish || true)
if [ -n "$fish_path" ] && [ "$(getent passwd "$USER" | cut -d: -f7)" != "$fish_path" ]; then
    echo "==> setting login shell to $fish_path"
    sudo chsh -s "$fish_path" "$USER"
fi
