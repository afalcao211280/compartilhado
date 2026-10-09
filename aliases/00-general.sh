#!/usr/bin/env bash

alias ll='ls -alFh'
alias la='ls -A'
alias lt='ls -alFh --color=auto | head -50'

lsize() { du -sh "$@" 2>/dev/null || du -sh .; }

alias ..='cd ..'
alias ...='cd ../..'
alias -- -='cd -'
alias home='cd ~'

fdir()  { find . -type d -name "*$1*" 2>/dev/null | head -20; }
ffile() { find . -type f -name "*$1*" 2>/dev/null | head -20; }
ftext() { grep -rn "$1" . --include="*.${2:-*}" 2>/dev/null | head -30; }

alias gi='grep -i --color=auto'
alias grepip='grep -Eo "([0-9]{1,3}\.){3}[0-9]{1,3}"'

alias jsonpp='python3 -m json.tool 2>/dev/null || jq .'
alias headers='curl -sI'

alias myip='curl -s ifconfig.me 2>/dev/null || echo "unavailable"'
alias weather='curl -s wttr.in/?F 2>/dev/null | head -20 || echo "unavailable"'
alias timestamp='date +%s'
alias pathsort='tr ":" "\n" | sort'

mkcd() { mkdir -p "$1" && cd "$1"; }

extract() {
  if [[ -f "$1" ]]; then
    case "$1" in
      *.tar.bz2)   tar xjf "$1" ;;
      *.tar.gz)    tar xzf "$1" ;;
      *.tar.xz)    tar xJf "$1" ;;
      *.bz2)       bunzip2 "$1" ;;
      *.rar)       unrar x "$1" ;;
      *.gz)        gunzip "$1" ;;
      *.tar)       tar xf "$1" ;;
      *.tbz2)      tar xjf "$1" ;;
      *.tgz)       tar xzf "$1" ;;
      *.zip)       unzip "$1" ;;
      *.Z)         uncompress "$1" ;;
      *.7z)        7z x "$1" ;;
      *)           echo "Unknown archive format: $1" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}