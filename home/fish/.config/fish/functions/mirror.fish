function mirror --description 'Rank pacman mirrors by download speed'
    # With the CachyOS repos added, cachyos-rate-mirrors ranks both Arch's and
    # CachyOS's mirror lists. On plain Arch, reflector ranks Arch's.
    if type -q cachyos-rate-mirrors
        sudo cachyos-rate-mirrors
    else if type -q reflector
        sudo reflector --country IN,SG --protocol https --age 12 --latest 20 \
            --sort rate --save /etc/pacman.d/mirrorlist
    else
        printf 'mirror: install reflector (pacman -S reflector)\n' >&2
        return 127
    end
end
