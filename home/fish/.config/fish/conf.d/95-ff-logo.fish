# The animated fastfetch logo (~/.local/bin/ff-logo, from the fastfetch package
# in the dotfiles). fish_greeting calls __ff_logo_start; the logo then keeps
# animating while the first prompt sits idle, and stops, leaving the still
# logo, as soon as anything could move the screen under it.
#
# Turn it off: set -U fastfetch_anim 0     (back on: set -e fastfetch_anim)

status is-interactive; or return

function __ff_logo_start --description 'fastfetch, then animate its logo'
    __ff_logo_stop
    if test "$fastfetch_anim" = 0; or not command -q ff-logo
        fastfetch
        return
    end
    set -l pid_file (path resolve -- $XDG_RUNTIME_DIR)/ff-logo-$fish_pid.pid
    command rm -f -- $pid_file
    # fastfetch runs from fish itself (not from ff-logo) so it reports fish
    # as the shell and the real terminal.
    set -l row (command ff-logo row)
    fastfetch
    string match -qr '^\d+$' -- $row; and command ff-logo play $row
    if test -r $pid_file
        read -g __ff_logo_pid <$pid_file
        command rm -f -- $pid_file
        set -e __ff_logo_prompted
    end
end

function __ff_logo_stop --description 'Stop the logo animation, leaving the still logo'
    set -q __ff_logo_pid; or return 0
    set -l pid $__ff_logo_pid
    set -e __ff_logo_pid
    # Only signal the process if that ID still belongs to ff-logo.
    test -r /proc/$pid/cmdline; or return 0
    string match -q '*ff-logo*' -- (string split0 </proc/$pid/cmdline); or return 0
    command kill -TERM $pid 2>/dev/null; or return 0
    # Give it a moment to put the still logo back before anything else draws.
    for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20
        command kill -0 $pid 2>/dev/null; or break
        sleep 0.01
    end
end

# Anything that can move or clear the screen stops it.
function __ff_logo_on_preexec --on-event fish_preexec
    __ff_logo_stop
end

function __ff_logo_on_prompt --on-event fish_prompt
    set -q __ff_logo_pid; or return
    # The first prompt is drawn right after fastfetch; any later one (Enter on
    # an empty line, a repaint) means the screen may have moved.
    if set -q __ff_logo_prompted
        __ff_logo_stop
    else
        set -g __ff_logo_prompted 1
    end
end

function __ff_logo_on_resize --on-signal WINCH
    __ff_logo_stop
end

function __ff_logo_on_exit --on-event fish_exit
    __ff_logo_stop
end

# Keys that open a list below the prompt or clear the screen. Each stops the
# animation first, then does its usual job. fzf's keys are wrapped only when
# fzf's bindings are loaded (conf.d/90-tools.fish runs before this file).
for mode in default insert
    bind -M $mode tab __ff_logo_stop complete
    bind -M $mode ctrl-l __ff_logo_stop clear-screen
    functions -q fzf_complete; and bind -M $mode shift-tab __ff_logo_stop fzf_complete
    functions -q fzf-history-widget; and bind -M $mode ctrl-r __ff_logo_stop fzf-history-widget
    functions -q fzf-file-widget; and bind -M $mode ctrl-t __ff_logo_stop fzf-file-widget
    functions -q fzf-cd-widget; and bind -M $mode alt-c __ff_logo_stop fzf-cd-widget
end
