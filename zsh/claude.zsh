# ═════════════════════════════════════════════════════════════════════════════
#  Claude Code を tmux で常駐運用するためのコマンド群
#    cw  … プロジェクト用セッションを作って入る
#    cl  … 走行中セッションを一覧して移動
#    cq  … 「待ち」のセッションだけ表示
#    cr  … ウィンドウを切り替えずに一言送る
#    cj  … 次の「待ち」へジャンプ
# ═════════════════════════════════════════════════════════════════════════════

# tmux のセッション名に使える形へ整える（. と : は使えない）
_cc_sessname() { print -r -- "${1//[.:[:space:]]/-}" }

# ─── cw: プロジェクト用 tmux セッションを作成/再利用して claude を起動 ──────
cw() {
  emulate -L zsh
  local target="${1:-$PWD}" dir name
  if [[ -d "$target" ]]; then
    dir="${target:A}"
  elif [[ -d "$HOME/dev/$target" ]]; then
    dir="$HOME/dev/$target"
  else
    print -u2 "cw: ディレクトリが見つかりません: $target"
    return 1
  fi
  name="$(_cc_sessname "${dir:t}")"

  if ! tmux has-session -t "=$name" 2>/dev/null; then
    tmux new-session -d -s "$name" -c "$dir" 2>/dev/null || {
      print -u2 "cw: tmux セッションを作成できませんでした"; return 1; }
    # ウィンドウを閉じても claude が残るよう、tmux 側で起動する
    tmux send-keys -t "$name" "claude ${*[2,-1]}" C-m
  fi

  if [[ -n "$TMUX" ]]; then
    tmux switch-client -t "=$name"
  else
    tmux attach-session -t "=$name"
  fi
}

# ─── 一覧の1行を人間向けに整形する（cl と cq で共用） ───────────────────────
_cc_fmt() {
  awk -F'\t' '
    function human(s) {
      if (s < 60)   return sprintf("%ds", s)
      if (s < 3600) return sprintf("%dm%02ds", s/60, s%60)
      return sprintf("%dh%02dm", s/3600, (s%3600)/60)
    }
    {
      icon = ($1=="waiting") ? "◆" : ($1=="running") ? "●" : ($1=="done") ? "✓" : "·"
      label= ($1=="waiting") ? "確認待ち" : ($1=="running") ? "実行中" : ($1=="done") ? "完了" : "待機"
      printf "%s %-20s %-8s %-7s %s\t%s\n", icon, $2, label, human($5), $3, $4
    }'
}

# ─── cl: 走行中セッションを fzf で選んで移動 ────────────────────────────────
cl() {
  emulate -L zsh
  local rows sel pane
  rows="$($HOME/.claude/bin/claude-sessions)"
  if [[ -z "$rows" ]]; then print "走行中の Claude セッションはありません"; return 0; fi
  sel="$(print -r -- "$rows" | _cc_fmt \
        | fzf --ansi --with-nth=1 --delimiter='\t' --height=40% \
              --header='移動先のセッションを選択' --prompt='claude ❯ ')" || return 0
  pane="${sel##*$'\t'}"
  [[ -n "$pane" && "$pane" != "-" ]] || { print -u2 "このセッションは tmux 外で動いています"; return 1; }
  "$HOME/.claude/bin/claude-jump" "$pane"
}

# ─── cq: 「待ち」のセッションだけ表示 ───────────────────────────────────────
cq() {
  emulate -L zsh
  local rows
  rows="$($HOME/.claude/bin/claude-sessions --waiting)"
  if [[ -z "$rows" ]]; then print "待ち状態のセッションはありません"; return 0; fi
  print -r -- "$rows" | _cc_fmt | cut -f1
}

# ─── cj: 次の「待ち」セッションへジャンプ ───────────────────────────────────
cj() { "$HOME/.claude/bin/claude-jump" --next-waiting; }

# ─── cr: ウィンドウを切り替えずに指定セッションへ一言送る ───────────────────
#   使い方: cr <プロジェクト名|ペインID> <送りたいテキスト...>
cr() {
  emulate -L zsh
  local key="${1:-}"; shift 2>/dev/null
  local text="$*"
  if [[ -z "$key" || -z "$text" ]]; then
    print -u2 "使い方: cr <プロジェクト名|ペインID> <テキスト>"
    return 1
  fi
  local pane
  if [[ "$key" == %* ]]; then
    pane="$key"
  else
    pane="$($HOME/.claude/bin/claude-sessions | awk -F'\t' -v k="$key" '$2==k && $4!="-"{print $4; exit}')"
  fi
  [[ -n "$pane" ]] || { print -u2 "cr: 送信先が見つかりません: $key"; return 1; }
  # -l でリテラル送信（テキスト中のキー名が解釈されるのを防ぐ）
  tmux send-keys -t "$pane" -l "$text" && tmux send-keys -t "$pane" C-m
  print "→ $key へ送信しました"
}

# ═════════════════════════════════════════════════════════════════════════════
#  セッションの枝分かれ
#    croot        … 今のセッションを「根」として記録する
#    cfork <名前> … 根から枝分かれした新しいセッションを tmux 内に作る
#    ctut         … チュートリアル用の枝を作って入る
#  枝は根の会話内容をすべて引き継ぐので、前提の説明が要らない。
# ═════════════════════════════════════════════════════════════════════════════

_cc_root_file="$HOME/.claude/.fork-root"

# 今いる Claude Code セッションを根として記録
croot() {
  emulate -L zsh
  if [[ -n "${CLAUDE_CODE_SESSION_ID:-}" ]]; then
    print -r -- "$CLAUDE_CODE_SESSION_ID" > "$_cc_root_file"
    print "根として記録しました: $CLAUDE_CODE_SESSION_ID"
  else
    print -u2 "croot: Claude Code セッションの中で実行してください"
    return 1
  fi
}

# 根の session id を求める（引数 > 環境変数 > 記録 > fzf で選択）
_cc_resolve_root() {
  emulate -L zsh
  local r="${1:-}"
  [[ -n "$r" ]] && { print -r -- "$r"; return 0 }
  [[ -n "${CLAUDE_CODE_SESSION_ID:-}" ]] && { print -r -- "$CLAUDE_CODE_SESSION_ID"; return 0 }
  [[ -s "$_cc_root_file" ]] && { print -r -- "$(<"$_cc_root_file")"; return 0 }

  local pick
  pick="$(ls -t "$HOME"/.claude/projects/*/*.jsonl 2>/dev/null \
    | head -40 \
    | while read -r f; do
        print -r -- "$(date -r "$f" '+%m/%d %H:%M')\t${f:h:t}\t${f:t:r}"
      done \
    | fzf --delimiter='\t' --with-nth=1,2 --height=40% \
          --header='枝分かれの根にするセッションを選択' --prompt='root ❯ ')" || return 1
  print -r -- "${pick##*$'\t'}"
}

# 根から枝分かれした新しいセッションを tmux 内に作る
#   cfork <名前> [初期プロンプト...]
cfork() {
  emulate -L zsh
  local name="${1:-}"; shift 2>/dev/null
  [[ -n "$name" ]] || { print -u2 "使い方: cfork <名前> [初期プロンプト]"; return 1 }
  name="$(_cc_sessname "$name")"

  local root; root="$(_cc_resolve_root)" || return 1
  [[ -n "$root" ]] || { print -u2 "cfork: 根のセッションを特定できませんでした"; return 1 }

  if ! tmux has-session -t "=$name" 2>/dev/null; then
    tmux new-session -d -s "$name" -c "$PWD" || return 1
    tmux send-keys -t "$name" "claude --resume $root --fork-session" C-m
    # プロンプトが立ち上がるのを待ってから最初の指示を流し込む
    if (( $# )); then
      local prompt="$*"
      ( sleep 6; tmux send-keys -t "$name" -l "$prompt"; sleep 0.4
        tmux send-keys -t "$name" C-m ) &!
    fi
    print "根 $root から枝「$name」を作りました"
  else
    print "既存の枝「$name」に入ります"
  fi

  if [[ -n "$TMUX" ]]; then tmux switch-client -t "=$name"
  else                      tmux attach-session -t "=$name"; fi
}

# チュートリアル用の枝
ctut() {
  emulate -L zsh
  cfork tutorial "あなたはこれから、この会話で一緒に構築した作業環境の家庭教師です。\
~/.claude/TUTORIAL.md を読み、そこに書かれた順序で私に手を動かさせながら進めてください。\
一度に1ステップだけ提示し、私が実際に試して結果を報告するまで次に進まないでください。\
可能なものは、あなた自身がコマンドを実行して成功を確認してから次へ進めてください。まず STEP 0 から始めてください。"
}
