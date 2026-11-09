function fish_greeting
    type -q fastfetch; or return
    # fastfetch at once, then its logo keeps animating while the prompt is
    # idle (conf.d/95-ff-logo.fish; off with `set -U fastfetch_anim 0`).
    __ff_logo_start
end

set -gx MANROFFOPT -c
set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"

# Settings for the `done` plugin (AUR: fish-done), which sends a desktop
# notification when a command that ran 10 seconds or more finishes while the
# terminal is in the background. Without the plugin these do nothing.
set -g __done_min_cmd_duration 10000
set -g __done_notification_urgency_level low

# Interactive !! and !$ expansion.
function __history_previous_command
    switch (commandline -t)
        case '!'
            commandline -t $history[1]
            commandline -f repaint
        case '*'
            commandline -i '!'
    end
end

function __history_previous_command_arguments
    switch (commandline -t)
        case '!'
            commandline -t ''
            commandline -f history-token-search-backward
        case '*'
            commandline -i '$'
    end
end

if status is-interactive
    if test "$fish_key_bindings" = fish_vi_key_bindings
        bind -M insert ! __history_previous_command
        bind -M insert '$' __history_previous_command_arguments
    else
        bind ! __history_previous_command
        bind '$' __history_previous_command_arguments
    end
end

# Show timestamps when listing or searching history. Other subcommands
# (delete, merge, clear, ...) do not accept --show-time.
function history --wraps history
    if test (count $argv) -eq 0; or test "$argv[1]" = search; or string match --quiet -- '-*' $argv[1]
        builtin history --show-time='%F %T ' $argv
    else
        builtin history $argv
    end
end

function backup --argument-names filename
    if test -z "$filename"
        printf 'usage: backup FILE\n' >&2
        return 2
    end
    command cp -- "$filename" "$filename.bak"
end

function copy
    if test (count $argv) -eq 2; and test -d "$argv[1]"
        set -l from (string trim --right --chars=/ -- "$argv[1]")
        command cp -r -- "$from" "$argv[2]"
    else
        command cp $argv
    end
end
