function rm --description 'Move files and directories to the FreeDesktop Trash'
    # Never change rm semantics inside non-interactive Fish scripts.
    if not status is-interactive
        command rm $argv
        return $status
    end

    if not type -q trash-put
        printf 'rm: trash-put is unavailable; install the trash-cli package\n' >&2
        printf 'rm: permanent deletion remains available as: command rm ...\n' >&2
        return 127
    end

    set -l trash_options
    set -l operands
    set -l parsing_options true

    for argument in $argv
        if test "$parsing_options" = false
            set -a operands "$argument"
            continue
        end

        switch "$argument"
            case --
                set parsing_options false
            case -r -R --recursive
                # trash-put handles directories without a recursive flag.
            case -f --force
                if not contains -- -f $trash_options
                    set -a trash_options -f
                end
            case '-*'
                if string match --quiet --regex '^-[rRf]+$' -- "$argument"
                    if string match --quiet '*f*' -- "$argument"; and not contains -- -f $trash_options
                        set -a trash_options -f
                    end
                else
                    printf 'rm: unsupported option for Trash: %s\n' "$argument" >&2
                    printf 'rm: use `command rm` only when permanent deletion is intentional\n' >&2
                    return 2
                end
            case '*'
                set -a operands "$argument"
        end
    end

    if test (count $operands) -eq 0
        printf 'rm: missing operand\n' >&2
        return 2
    end

    for operand in $operands
        set -l resolved (command realpath -m -- "$operand" 2>/dev/null)
        if test "$resolved" = /; or test "$resolved" = "$HOME"; or test "$resolved" = "$PWD"
            printf 'rm: refusing protected path: %s\n' "$operand" >&2
            return 2
        end
    end

    command trash-put $trash_options -- $operands
end
