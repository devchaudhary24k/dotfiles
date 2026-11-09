if not status is-interactive
    return
end

# Navigation
alias home='cd ~'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'

# Files
alias cat='bat'
alias less='less -R'
alias ls='eza -al --color=always --group-directories-first --icons=always'
alias la='eza -a --color=always --group-directories-first --icons=always'
alias ll='eza -l --color=always --group-directories-first --icons=always'
alias lt='eza -aT --color=always --group-directories-first --icons=always'
alias l.="eza -a | grep -e '^\\.'"
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias grep='grep --color=auto'
# GNU grep warns that egrep and fgrep are obsolete; these call grep directly.
alias egrep='grep -E --color=auto'
alias fgrep='grep -F --color=auto'
alias tarnow='tar -acf '
# tar works out the compression itself, so this unpacks .gz, .xz, .zst, ...
alias untar='tar -xvf '
alias wget='wget -c '
alias tb='nc termbin.com 9999'

# System
alias cls='clear'
alias ping='ping -c 10'
alias openports='ss -tulpen'
alias mountedinfo='df -hT'
alias topcpu='ps -eo pcpu,pid,user,args --sort=-pcpu | head -11'
alias psmem='ps aux --sort=-%mem'
alias psmem10='ps aux --sort=-%mem | head -11'
alias hw='hwinfo --short'
alias ff='fastfetch'
alias bt='btop'
# Per-app GPU use on both GPUs: which program renders on NVIDIA vs AMD.
alias gpu='nvtop'
alias jctl='journalctl -p 3 -xb'

# Packages. `mirror` and `cleanup` are functions in ../functions/.
alias update='yay -Syu'
alias fixpacman='sudo rm /var/lib/pacman/db.lck'
alias grubup='sudo grub-mkconfig -o /boot/grub/grub.cfg'
alias big="expac -H M '%m\\t%n' | sort -h | nl"
alias rip="expac --timefmt='%Y-%m-%d %T' '%l\\t%n %v' | sort | tail -200 | nl"
alias gitpkg="pacman -Q | grep -i '\\-git' | wc -l"
# Pick packages with fzf, then install (yayf) or remove (yayr) them. xargs -o
# gives yay the terminal back, so it can ask its questions; without it yay
# reads end-of-file and gives up.
alias yayf="yay -Slq | fzf --multi --preview 'yay -Sii {1}' --preview-window=down:75% | xargs -ro yay -S"
alias yayr="yay -Qq | fzf --multi --preview 'yay -Qi {1}' --preview-window=down:75% | xargs -ro yay -Rns"
alias apt='man pacman'
alias apt-get='man pacman'

# Frequent Git commands expand in place, so shell history shows the full command.
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
