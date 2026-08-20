# User-owned replacement for the CachyOS main Fish config. The optional
# notification plugin remains package-owned; personal behavior lives here.
if status is-interactive; and test -r /usr/share/cachyos-fish-config/conf.d/done.fish
    source /usr/share/cachyos-fish-config/conf.d/done.fish
end

function fish_greeting
    if type -q fastfetch
        fastfetch
    end
end

set -gx MANROFFOPT -c
set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"

# Preferences for the package-owned `done` notification plugin.
set -U __done_min_cmd_duration 10000
set -U __done_notification_urgency_level low

if test -f ~/.fish_profile
    source ~/.fish_profile
end

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

function history
    builtin history --show-time='%F %T ' $argv
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
