#!/usr/bin/env bash
#
# Unlock the GNOME keyring at login, so nothing has to ask for it afterwards.
#
# On a stock CachyOS Hyprland install nothing wires pam_gnome_keyring into
# greetd. The login keyring therefore stays locked after boot, and the first
# thing that wants a secret -- 1Password, Dropbox, Chrome -- raises an unlock
# dialog. It often looks like KWallet asking, because kwalletd6 will happily
# claim org.freedesktop.secrets when gnome-keyring has not.
#
# These two lines are what fix it. The auth line has to come after the module
# that actually reads the password (system-local-login -> system-auth ->
# pam_unix), because it works by catching the authtok that module collected;
# the session line goes last, once there is a session to start the daemon in.
#
# Not reproduced from the tower: an explicit `session required pam_systemd.so`.
# system-login already carries `-session optional pam_systemd.so`, so it is
# redundant there, and `required` on a login path is a worse default than the
# optional one it duplicates.
#
# `run_onchange_` rather than `run_once_`: a greetd update can ship a .pacnew
# and someone can take it, and this should notice and put the lines back.
#
# This edits a PAM file, which is the one file on the machine that can lock you
# out of your own login. So: never touch a file that already has the lines,
# build the replacement in a temp file, refuse to install anything that lost
# content along the way, keep a timestamped backup next to the original, and
# put it in place with a rename rather than a write.

set -euo pipefail

pam_file=/etc/pam.d/greetd
pam_module=/usr/lib/security/pam_gnome_keyring.so

if [ ! -f "$pam_file" ]; then
    echo "==> no $pam_file; skipping keyring setup"
    exit 0
fi

if [ ! -e "$pam_module" ]; then
    echo "==> gnome-keyring's PAM module is not installed; skipping keyring setup"
    exit 0
fi

if grep -q 'pam_gnome_keyring\.so' "$pam_file"; then
    echo "==> login keyring already unlocked by PAM"
    exit 0
fi

echo "==> wiring the GNOME keyring into greetd's PAM stack"
echo "    sudo is needed to edit $pam_file"
sudo -v

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

# Insert after the *last* auth line, and append the session line at the end.
if ! awk '
    /^[[:space:]]*auth[[:space:]]/ { auth_lines[++n] = NR }
    { lines[NR] = $0 }
    END {
        last_auth = (n > 0) ? auth_lines[n] : 0
        if (last_auth == 0)
            exit 1
        for (i = 1; i <= NR; i++) {
            print lines[i]
            if (i == last_auth)
                print "auth       optional     pam_gnome_keyring.so"
        }
        print "session    optional     pam_gnome_keyring.so auto_start"
    }
' "$pam_file" > "$tmp"; then
    echo "    !! $pam_file has no auth lines; leaving it alone" >&2
    exit 0
fi

# Every original line must still be there, plus exactly the two new ones.
# Anything else means awk did something unexpected, and an unexpected PAM file
# is not worth the risk of a login you cannot complete.
#
# The original goes through awk too, only to normalize it. awk always
# terminates its last line; a hand-edited PAM file missing its final newline
# otherwise reads as a mismatch here, and the machine that most needs the fix
# silently never gets it.
added=$(grep -c 'pam_gnome_keyring\.so' "$tmp" || true)
if [ "$added" -ne 2 ] ||
    ! diff <(grep -v 'pam_gnome_keyring\.so' "$tmp") <(awk '{ print }' "$pam_file") >/dev/null; then
    echo "    !! rewrite did not come out clean; leaving $pam_file alone" >&2
    exit 0
fi

backup="${pam_file}.bak.chezmoi.$(date +%Y%m%d%H%M%S)"
sudo cp -a "$pam_file" "$backup"
echo "    backed up to $backup"

# Rename into place so the file is never momentarily half-written.
sudo install -m 0644 -o root -g root "$tmp" "${pam_file}.chezmoi-new"
sudo mv "${pam_file}.chezmoi-new" "$pam_file"
echo "    done; takes effect at the next login"
