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

alias gst='git status'
alias gl='git log --oneline --graph --decorate'
alias gp='git push'
alias gpl='git pull'
alias yayf="yay -Slq | fzf --multi --preview 'yay -Sii {1}' --preview-window=down:75% | xargs -r yay -S"
alias yayr="yay -Qq | fzf --multi --preview 'yay -Qi {1}' --preview-window=down:75% | xargs -r yay -Rns"
