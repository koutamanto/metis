# ─── mkdir して cd ───────────────────────────────────────────────────────────
mkcd() { mkdir -p "$1" && cd "$1"; }

# ─── 何でも展開する ──────────────────────────────────────────────────────────
extract() {
  [[ -f "$1" ]] || { echo "extract: '$1' が見つかりません" >&2; return 1; }
  case "$1" in
    *.tar.bz2|*.tbz2) tar xjf "$1"   ;;
    *.tar.gz|*.tgz)   tar xzf "$1"   ;;
    *.tar.xz)         tar xJf "$1"   ;;
    *.tar)            tar xf  "$1"   ;;
    *.bz2)            bunzip2 "$1"   ;;
    *.gz)             gunzip  "$1"   ;;
    *.zip)            unzip   "$1"   ;;
    *.7z)             7z x    "$1"   ;;
    *.rar)            unrar x "$1"   ;;
    *.Z)              uncompress "$1";;
    *) echo "extract: '$1' は未対応の形式です" >&2; return 1 ;;
  esac
}

# ─── fzf: ファイルをプレビュー付きで選んで開く ───────────────────────────────
fe() {
  local file
  file=$(fzf --preview 'bat --style=numbers --color=always --line-range :300 {} 2>/dev/null || cat {}') || return
  ${EDITOR:-vim} "$file"
}

# ─── fzf: git ブランチを選んで切り替え ───────────────────────────────────────
fbr() {
  local branch
  branch=$(git branch -a --sort=-committerdate --format='%(refname:short)' \
    | fzf --preview 'git log --oneline --color=always -20 {}') || return
  git switch "${branch#origin/}"
}

# ─── fzf: git コミットを選んで詳細表示 ───────────────────────────────────────
fshow() {
  local commit
  commit=$(git log --oneline --color=always -200 \
    | fzf --ansi --preview 'git show --color=always $(echo {} | cut -d" " -f1)') || return
  git show "$(echo "$commit" | cut -d' ' -f1)"
}

# ─── fzf: プロセスを選んで kill ──────────────────────────────────────────────
fkill() {
  local pid
  pid=$(command ps -ef | sed 1d | fzf -m --header='kill するプロセスを選択 (Tab で複数選択)' | awk '{print $2}') || return
  [[ -n "$pid" ]] && echo "$pid" | xargs kill -${1:-9}
}

# ─── fzf: Homebrew パッケージを検索してインストール ─────────────────────────
fbrew() {
  local pkg
  pkg=$(brew formulae | fzf -m --preview 'brew info {}') || return
  [[ -n "$pkg" ]] && echo "$pkg" | xargs brew install
}

# ─── ポートを使っているプロセスを調べる / 落とす ────────────────────────────
port() { lsof -iTCP:"$1" -sTCP:LISTEN -P -n; }
killport() { lsof -tiTCP:"$1" -sTCP:LISTEN | xargs -r kill -9 && echo "port $1 を解放しました"; }

# ─── カレントディレクトリの一時 HTTP サーバ ─────────────────────────────────
serve() { local p="${1:-8000}"; echo "http://localhost:$p"; python3 -m http.server "$p"; }

# ─── バックアップコピー ──────────────────────────────────────────────────────
bak() { command cp -a "$1" "$1.bak-$(date +%Y%m%d-%H%M%S)" && echo "→ $1.bak-$(date +%Y%m%d-%H%M%S)"; }

# ─── git リポジトリのルートへ移動 ────────────────────────────────────────────
groot() { cd "$(git rev-parse --show-toplevel 2>/dev/null)" || echo "git リポジトリ外です" >&2; }

# ─── weather / cheatsheet ────────────────────────────────────────────────────
weather() { curl -s "wttr.in/${1:-Tokyo}?lang=ja&m"; }
cheat()   { curl -s "cheat.sh/$1"; }

# ─── ディレクトリのサイズを大きい順に ────────────────────────────────────────
big() { command du -sh "${1:-.}"/* 2>/dev/null | sort -rh | head -"${2:-15}"; }
