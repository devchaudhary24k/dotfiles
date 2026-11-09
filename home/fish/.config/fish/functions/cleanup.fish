function cleanup --description 'Remove packages nothing depends on any more'
    set -l orphans (pacman -Qtdq)
    if test (count $orphans) -eq 0
        printf 'No orphaned packages.\n'
        return 0
    end
    sudo pacman -Rns $orphans
end
