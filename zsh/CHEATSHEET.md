# ターミナル環境チートシート

## Ghostty ショートカット
| キー | 動作 |
|---|---|
| `Cmd + ` ` | クイックターミナル (画面上から降りてくる / 全アプリ横断) |
| `Cmd + D` / `Cmd + Shift + D` | 右に分割 / 下に分割 |
| `Cmd + Opt + ←→↑↓` | 分割ペイン間を移動 |
| `Cmd + Ctrl + ←→↑↓` | 分割ペインをリサイズ |
| `Cmd + Shift + Enter` | ペインをズーム (全画面トグル) |
| `Cmd + T` / `Cmd + Shift + ←→` | 新規タブ / タブ移動 |
| `Cmd + K` | 画面クリア |
| `Cmd + Shift + ,` | 設定をリロード |

## fzf
| キー | 動作 |
|---|---|
| `Ctrl + T` | ファイル検索して挿入 (bat プレビュー付き) |
| `Alt + C` | ディレクトリ検索して cd (ツリープレビュー付き) |
| `Ctrl + R` | atuin の履歴検索 (全ディレクトリ横断・fuzzy) |
| `Ctrl + /` | fzf 内でプレビュー表示トグル |
| `**` + `Tab` | 任意のコマンドの引数を fzf 補完 (例: `vim **<Tab>`) |

## zsh キーバインド
| キー | 動作 |
|---|---|
| `↑` / `↓` | 入力中の文字列に前方一致する履歴を検索 |
| `→` / `Opt + M` | autosuggestion の候補を確定 |
| `Opt + ←→` | 単語単位で移動 |
| `Opt + Backspace` | 単語単位で削除 |
| `Ctrl + X` `Ctrl + E` | 現在のコマンドをエディタで編集 |

## コマンド置き換え
| 元 | 新 | 備考 |
|---|---|---|
| `ls` | eza | `l` `ll` `la` `lt`(ツリー) `lsize` `lnew` |
| `cat` | bat | `catp` でページャあり / `rawcat` で素の cat |
| `find` | fd | `rawfind` で素の find |
| `grep` | ripgrep | `rawgrep` で素の grep |
| `cd` | zoxide | よく行く場所を学習。`cd 部分文字列` でジャンプ |
| `du` / `df` | dust / duf | |
| `ps` / `top` | procs / btop | |
| `git diff` | delta | 行番号・シンタックスハイライト付き |
| `man` | bat 経由 | 色付き |

## 自作関数
| コマンド | 動作 |
|---|---|
| `mkcd <dir>` | mkdir して cd |
| `extract <file>` | zip/tar/gz/7z など何でも展開 |
| `fe` | fzf でファイルを選んでエディタで開く |
| `fbr` | fzf で git ブランチを選んで切り替え |
| `fshow` | fzf で git コミットを選んで表示 |
| `fkill` | fzf でプロセスを選んで kill |
| `fbrew` | fzf で Homebrew パッケージを検索してインストール |
| `port <n>` / `killport <n>` | ポート使用プロセスの確認 / 強制終了 |
| `serve [port]` | カレントディレクトリを HTTP 配信 |
| `bak <file>` | タイムスタンプ付きバックアップ |
| `groot` | git リポジトリのルートへ移動 |
| `big [dir] [n]` | サイズの大きい順に一覧 |
| `weather [都市]` / `cheat <cmd>` | 天気 / チートシート |
| `ccx [-v] [-s fast\|medium\|slow] <指示>` | Claude Code ラッパー (既存) |

## その他
- `lg` … lazygit (TUI で git 操作)
- `yazi` … TUI ファイルマネージャ
- `tldr <cmd>` … コマンドの実用例だけを表示
- `tmux` … プレフィックスは `Ctrl+a`。`|` `-` で分割、`Ctrl+a r` で設定リロード
- `reload` … zsh を再起動して設定を反映
- `brewup` … Homebrew を一括更新 + 掃除

## 注意
- 旧 `rg`(= rails generate) は ripgrep と衝突するため **`rgen`** に改名しました。
- `rm` `cp` `mv` は `-i` 付き (上書き前に確認)。
