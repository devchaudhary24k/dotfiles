function extract --description 'Unpack an archive: tar.*, zip, rar, 7z, iso, cpio, ...'
    # bsdtar (libarchive, already installed with pacman) reads nearly every
    # archive format, RAR5 included, so no unrar or 7z package is needed.
    if test (count $argv) -lt 1; or test (count $argv) -gt 2
        printf 'usage: extract ARCHIVE [DESTINATION]\n' >&2
        return 2
    end

    set -l destination .
    if test (count $argv) -eq 2
        set destination $argv[2]
        mkdir -p -- $destination; or return
    end

    bsdtar -xvf $argv[1] -C $destination
end
