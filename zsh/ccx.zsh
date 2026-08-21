# ccx — Claude Code を権限スキップで起動するラッパー
# 使い方: ccx [-v|--verbose] [-s|--speed fast|medium|slow|<model>] <指示...>
#   -v, --verbose : ヘッドレスのまま実行過程をストリーム出力 (stream-json)
#                   省略時はヘッドレス(-p)で最終結果のみ出力
#   -s, --speed   : モデルの速度を指定 (fast=haiku / medium=sonnet / slow=opus)
#                   生のモデルID/エイリアスもそのまま渡せる
# 例: ccx -s fast コードを整形して
#     ccx -v -s slow 大規模リファクタを設計して
ccx() {
  emulate -L zsh
  local verbose=0
  local model=""
  local -a rest

  # speed 名 → モデルへの変換
  _ccx_speed_to_model() {
    case "$1" in
      fast)       print -r -- haiku ;;
      medium|mid) print -r -- sonnet ;;
      slow)       print -r -- opus ;;
      *)          print -r -- "$1" ;;  # 生のモデルID/エイリアスはそのまま
    esac
  }

  while (( $# )); do
    case "$1" in
      -v|--verbose)
        verbose=1
        shift
        ;;
      -s|--speed)
        if [[ -z "$2" || "$2" == -* ]]; then
          echo "ccx: -s/--speed には fast|medium|slow を指定してください" >&2
          return 1
        fi
        model="$(_ccx_speed_to_model "$2")"
        shift 2
        ;;
      --speed=*)
        model="$(_ccx_speed_to_model "${1#*=}")"
        shift
        ;;
      --)
        shift
        rest+=("$@")
        break
        ;;
      *)
        rest+=("$1")
        shift
        ;;
    esac
  done

  local prompt="${rest[*]}"
  if [[ -z "$prompt" ]]; then
    echo "ccx: 指示を入力してください  例: ccx -s fast コードを整形して" >&2
    return 1
  fi

  local -a cmd=(claude --dangerously-skip-permissions)
  [[ -n "$model" ]] && cmd+=(--model "$model")

  if (( verbose )); then
    # ヘッドレスのまま実行過程をストリーム出力 (stream-json は --verbose が必須)
    cmd+=(-p --verbose --output-format stream-json "$prompt")
    if (( $+commands[jq] )); then
      setopt local_options pipe_fail   # claude の終了コードをパイプ越しに保持
      "${cmd[@]}" | jq -r '
        if .type == "assistant" then
          ( .message.content[]?
            | if   .type == "text"     then .text
              elif .type == "tool_use" then "› \(.name): \((.input | tostring)[0:160])"
              else empty end )
        elif .type == "result" then
          "\n— done (\((.duration_ms // 0) / 1000 | floor)s, $\(.total_cost_usd // 0))"
        else empty end
      '
    else
      "${cmd[@]}"   # jq が無ければ素の stream-json をそのまま
    fi
  else
    cmd+=(-p "$prompt")  # ヘッドレス。最終結果のみ出力
    "${cmd[@]}"
  fi
}
