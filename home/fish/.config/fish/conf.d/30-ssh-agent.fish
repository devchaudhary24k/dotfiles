# Use the ssh-agent that systemd runs for your user, so a key added once with
# ssh-add works in every terminal until you log out. Turn the agent on once:
#
#   systemctl --user enable --now ssh-agent.socket
#
# An agent that is already reachable, such as one forwarded with `ssh -A`,
# is left alone.
if not test -S "$SSH_AUTH_SOCK"
    set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"
end
