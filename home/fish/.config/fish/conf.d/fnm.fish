# fnm: Node version manager. --use-on-cd switches Node to a project's
# .nvmrc or .node-version when you cd into it.
#
# Pacman puts fnm in /usr/bin; fnm's own install script puts it in
# ~/.local/share/fnm, which is not on PATH by default.
if test -x "$HOME/.local/share/fnm/fnm"
    fish_add_path --path --move "$HOME/.local/share/fnm"
end

if type -q fnm
    fnm env --use-on-cd --shell fish | source
end
