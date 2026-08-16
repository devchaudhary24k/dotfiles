alias home='cd ~'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

alias cls='clear'
alias ping='ping -c 10'
alias less='less -R'

alias openports='ss -tulpen'
alias mountedinfo='df -hT'
alias topcpu='/bin/ps -eo pcpu,pid,user,args | sort -k 1 -r | head -10'

if status is-interactive
    # Frequent Git commands expand in-place, preserving readable shell history.
    abbr --add --global gst 'git status --short --branch'
    abbr --add --global ga 'git add'
    abbr --add --global gap 'git add --patch'
    abbr --add --global gd 'git diff'
    abbr --add --global gds 'git diff --staged'
    abbr --add --global gc 'git commit'
    abbr --add --global gca 'git commit --amend'
    abbr --add --global gsw 'git switch'
    abbr --add --global gb 'git branch'
    abbr --add --global gl 'git lg'
    abbr --add --global gp 'git push'
    abbr --add --global gpl 'git pull'
    abbr --add --global gpf 'git pf'
end

alias yayf="yay -Slq | fzf --multi --preview 'yay -Sii {1}' --preview-window=down:75% | xargs -r yay -S"
alias yayr="yay -Qq | fzf --multi --preview 'yay -Qi {1}' --preview-window=down:75% | xargs -r yay -Rns"
