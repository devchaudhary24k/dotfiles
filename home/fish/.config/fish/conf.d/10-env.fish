if type -q nvim
    set -gx EDITOR nvim
    set -gx VISUAL nvim
else
    set -gx EDITOR vim
    set -gx VISUAL vim
end

fish_add_path ~/.local/bin ~/.cargo/bin ~/.local/share/pnpm ~/.npm-global/bin ~/go/bin ~/.deno/bin
