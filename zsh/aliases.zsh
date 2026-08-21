# ─── ls / eza ────────────────────────────────────────────────────────────────
if (( $+commands[eza] )); then
  alias ls='eza --group-directories-first --icons=auto'
  alias l='eza -lbF --git --group-directories-first --icons=auto'
  alias ll='eza -lbGF --git --group-directories-first --icons=auto'
  alias la='eza -labF --git --group-directories-first --icons=auto'
  alias lt='eza --tree --level=2 --group-directories-first --icons=auto'
  alias ltt='eza --tree --level=3 --group-directories-first --icons=auto'
  alias lsize='eza -lbF --sort=size --reverse --icons=auto'
  alias lnew='eza -lbF --sort=modified --reverse --icons=auto'
else
  alias ls='ls -G'
  alias ll='ls -lh'
  alias la='ls -lha'
fi

# ─── cat / bat ───────────────────────────────────────────────────────────────
if (( $+commands[bat] )); then
  alias cat='bat --paging=never'
  alias catp='bat'          # ページャあり
  alias rawcat='command cat'
fi

# ─── find / grep ─────────────────────────────────────────────────────────────
(( $+commands[fd] )) && alias find='fd'
(( $+commands[rg] )) && alias grep='rg'
alias rawfind='command find'
alias rawgrep='command grep'

# ─── その他モダン置き換え ────────────────────────────────────────────────────
(( $+commands[dust] ))  && alias du='dust'
(( $+commands[duf] ))   && alias df='duf'
(( $+commands[procs] )) && alias ps='procs'
(( $+commands[btop] ))  && alias top='btop' && alias htop='btop'
(( $+commands[tldr] ))  && alias help='tldr'

# ─── ナビゲーション ──────────────────────────────────────────────────────────
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'
alias dl='cd ~/Downloads'
alias dt='cd ~/Desktop'
alias dev='cd ~/dev 2>/dev/null || cd ~'

# ─── git ─────────────────────────────────────────────────────────────────────
alias g='git'
alias gs='git status -sb'
alias ga='git add'
alias gaa='git add -A'
alias gc='git commit -v'
alias gca='git commit -v --amend'
alias gco='git checkout'
alias gsw='git switch'
alias gb='git branch'
alias gd='git diff'
alias gds='git diff --staged'
alias gp='git push'
alias gpl='git pull --rebase'
alias gl="git log --graph --pretty=format:'%C(auto)%h%d %s %C(dim)(%cr) <%an>' --abbrev-commit -20"
alias gla="git log --graph --pretty=format:'%C(auto)%h%d %s %C(dim)(%cr) <%an>' --abbrev-commit --all"
alias gst='git stash'
alias gstp='git stash pop'
(( $+commands[lazygit] )) && alias lg='lazygit'

# ─── Ruby / Rails ────────────────────────────────────────────────────────────
alias be='bundle exec'
alias rc='bundle exec rails console'
alias rs='bundle exec rails server'
alias rgen='bundle exec rails generate'   # 旧 `rg` は ripgrep と衝突するため改名
alias rdm='bundle exec rails db:migrate'
alias rdr='bundle exec rails db:rollback'
alias rt='bundle exec rspec'

# ─── ネットワーク / システム ─────────────────────────────────────────────────
alias myip='curl -s https://ifconfig.me && echo'
alias localip="ipconfig getifaddr en0"
alias ports='lsof -iTCP -sTCP:LISTEN -P -n'
alias path='echo $PATH | tr ":" "\n"'
alias reload='exec zsh'
alias zshrc='${EDITOR:-vim} ~/.zshrc'
alias starshiprc='${EDITOR:-vim} ~/.config/starship.toml'
alias ghosttyrc='${EDITOR:-vim} ~/.config/ghostty/config'

# ─── macOS 便利 ──────────────────────────────────────────────────────────────
alias o='open'
alias oo='open .'
alias showfiles='defaults write com.apple.finder AppleShowAllFiles YES && killall Finder'
alias hidefiles='defaults write com.apple.finder AppleShowAllFiles NO && killall Finder'
alias flushdns='sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder'
alias brewup='brew update && brew upgrade && brew cleanup && brew doctor'

# ─── 安全策 ──────────────────────────────────────────────────────────────────
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias mkdir='mkdir -p'

# ─── ESP-IDF ─────────────────────────────────────────────────────────────────
alias get_idf='. $HOME/esp/esp-idf/export.sh'
