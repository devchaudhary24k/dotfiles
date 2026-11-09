function rm --description 'Move files to the Trash instead of deleting them'
    # Scripts keep the real rm. Only commands typed at the prompt go to the
    # Trash. Delete permanently from the prompt with: command rm ...
    if not status is-interactive
        command rm $argv
        return
    end

    if not type -q trash-put
        printf 'rm: trash-put not found; install trash-cli\n' >&2
        printf 'rm: to delete permanently, run: command rm ...\n' >&2
        return 127
    end

    # trash-put takes rm's -r, -R, -f, -d, -i and -v itself. What it does not
    # do is refuse to trash /, your home folder or the folder you are in.
    set -l options_done false
    for argument in $argv
        if test $options_done = false
            if test "$argument" = --
                set options_done true
                continue
            end
            string match --quiet -- '-*' $argument; and continue
        end

        if contains -- (path resolve -- $argument) / $HOME $PWD
            printf 'rm: refusing to trash %s\n' $argument >&2
            return 2
        end
    end

    trash-put $argv
end
