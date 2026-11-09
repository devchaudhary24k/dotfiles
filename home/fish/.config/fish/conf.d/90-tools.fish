# Zoxide: `z NAME` jumps to the folder you use most that matches NAME,
# `zi` picks one from a list.
if type -q zoxide
    zoxide init fish | source
end

# Starship draws the prompt (config: ~/.config/starship.toml).
if type -q starship
    starship init fish | source
end

# fzf key bindings:
#   Ctrl+R  search command history
#   Ctrl+T  insert a file path at the cursor (preview with bat)
#   Alt+C   cd into a folder below this one (preview with eza)
# fd lists the files, so hidden files are included and .gitignore is honoured.
if status is-interactive; and type -q fzf
    if type -q fd
        set -gx FZF_DEFAULT_COMMAND 'fd --type file --hidden --exclude .git'
        set -gx FZF_CTRL_T_COMMAND $FZF_DEFAULT_COMMAND
        set -gx FZF_ALT_C_COMMAND 'fd --type directory --hidden --exclude .git'
    end
    set -gx FZF_CTRL_T_OPTS "--preview 'bat --color=always --style=numbers --line-range=:300 {}'"
    set -gx FZF_ALT_C_OPTS "--preview 'eza --tree --level=2 --color=always --icons=always {}'"
    fzf --fish | source
end
