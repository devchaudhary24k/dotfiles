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
    alias cat='bat'

    alias ls='eza -al --color=always --group-directories-first --icons=always'
    alias la='eza -a --color=always --group-directories-first --icons=always'
    alias ll='eza -l --color=always --group-directories-first --icons=always'
    alias lt='eza -aT --color=always --group-directories-first --icons=always'
    alias l.="eza -a | grep -e '^\\.'"

    alias grubup='sudo grub-mkconfig -o /boot/grub/grub.cfg'
    alias fixpacman='sudo rm /var/lib/pacman/db.lck'
    alias tarnow='tar -acf '
    alias untar='tar -zxvf '
    alias wget='wget -c '
    alias psmem='ps auxf | sort -nr -k 4'
    alias psmem10='ps auxf | sort -nr -k 4 | head -10'
    alias ......='cd ../../../../..'
    alias dir='dir --color=auto'
    alias vdir='vdir --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
    alias hw='hwinfo --short'
    alias big="expac -H M '%m\\t%n' | sort -h | nl"
    alias gitpkg="pacman -Q | grep -i '\\-git' | wc -l"
    alias update='sudo cachyos-rate-mirrors && sudo pacman -Syu'
    alias mirror='sudo cachyos-rate-mirrors'
    alias apt='man pacman'
    alias apt-get='man pacman'
    alias tb='nc termbin.com 9999'
    alias cleanup='sudo pacman -Rns (pacman -Qtdq)'
    alias jctl='journalctl -p 3 -xb'
    alias rip="expac --timefmt='%Y-%m-%d %T' '%l\\t%n %v' | sort | tail -200 | nl"

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
