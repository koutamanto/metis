# Metis

複数の [Claude Code](https://claude.com/claude-code) セッションを並行運用するための、
macOS 向けターミナル環境一式である。

Claude Code のセッションをどこからでも呼び出せる状態に保ちつつ、各セッションの状態
（実行中・確認待ち・完了）を音声とパネルで把握できるようにし、さらに画面上の指示や
スクリーンショットを起点に単一のキー操作で行動を開始できることを目的として構築した。

## 構成

| 層 | 提供する機能 |
|---|---|
| **シェル (zsh)** | eza / bat / fd / ripgrep / zoxide / atuin / fzf 等によるモダン CLI への置き換え、および tmux を母艦とするセッション管理コマンド群（`cw` `cl` `cj` `cr` `cfork`） |
| **Ghostty** | Tokyo Night テーマ、クイックターミナル、分割・タブに関するキーバインド |
| **tmux** | Claude Code セッションの実行基盤。ウィンドウを閉じてもセッションは継続する |
| **AeroSpace** | ワークスペースの分離（エディタ／Claude セッション群／ブラウザ／その他） |
| **Hammerspoon（Metis）** | 下記を参照 |

## Metis について

Hammerspoon 上に実装した、Claude Code のための常駐アシスタント層である。

- **セッションバス** — Claude Code のフック（`SessionStart` / `UserPromptSubmit` /
  `Notification` / `Stop` / `SessionEnd`）から状態を集約する。他の全機能はこのバスを
  参照して動作する
- **読み上げ** — バックグラウンドで実行中のセッションが完了、または確認待ちの状態に
  遷移した場合にのみ音声で通知する。可視状態にあるセッションについては通知を抑制する
- **HUD** — 画面右上に半透明のオーバーレイとして、全セッションの状態を常時表示する
- **Quick Action** — 選択テキストまたは画面のスクリーンショットを Sonnet 5 に送信し、
  即時応答を得る。用途に応じて以下のキー操作を用意している
  - `⌘⌥A` — 高速質問
  - `⌘⌥⇧A` — 深掘り（Opus）
  - `⌘⌥S` — コマンド生成・内容確認・実行
  - `⌘⌥X` — 画面上の指示を読み取り、一括確認の上で実行
  - `⌘⌥V` — 画面を撮影した上で質問
- **Metis パネル** — Quick Action の結果を一元的に表示する。操作を実行した時点で
  即座に「処理中」の表示を出し、応答が届き次第内容を更新する構成とすることで、実際の
  応答速度は変えずに体感上の待ち時間を短縮している
- **Quick Action Interactor** — 専用の TUI。Quick Action の実行履歴を一覧表示し、
  任意の履歴を選択することで、その文脈を引き継いだ新規の永続セッションへ移行できる
- **脳内ステート（mind）** — 断片的な一行メモの蓄積から、「現在の作業内容」「次に
  行うべきこと」「保留事項」を自動的に再構成する。記録に要する手間を最小化することを
  重視した設計としている
- **画面観測（eye）** — 既定では、フォーカスの当たっているウィンドウのみを対象として
  撮影を行う。パスワード管理・メッセージング・ビデオ会議等のアプリケーションは既定で
  除外対象とし、一定時間操作が無い場合は自動的に停止する
- **ショートカット一覧** — `⌘⌥/` により、登録済みの全ホットキーを一覧表示する

ホットキーの詳細および使用方法については [`claude/TUTORIAL.md`](claude/TUTORIAL.md)
を参照されたい。

## セットアップ

### 前提条件

- macOS
- [Homebrew](https://brew.sh)
- [Claude Code CLI](https://claude.com/claude-code)

### 依存パッケージのインストール

```sh
brew install eza bat fd ripgrep fzf zoxide starship delta tmux lazygit btop \
             tlrc jq yazi atuin direnv mise dust duf procs sd hyperfine gping \
             httpie ncdu tree
brew install --cask ghostty hammerspoon font-jetbrains-mono-nerd-font
brew tap nikitabobko/tap && brew install --cask nikitabobko/tap/aerospace
```

### 配置

```sh
git clone <このリポジトリの URL> ~/metis-src
cd ~/metis-src

# シェル
cp zsh/zshrc ~/.zshrc
mkdir -p ~/.config/zsh/completions
cp zsh/*.zsh ~/.config/zsh/
cp zsh/completions/_ngrok ~/.config/zsh/completions/

# Ghostty / tmux / AeroSpace / bat
mkdir -p ~/.config/ghostty ~/.config/aerospace ~/.config/bat
cp ghostty/config ~/.config/ghostty/config
cp tmux/tmux.conf ~/.tmux.conf
cp aerospace/aerospace.toml ~/.config/aerospace/aerospace.toml
cp bat/config ~/.config/bat/config

# Hammerspoon（Metis）
cp hammerspoon/*.lua ~/.hammerspoon/

# Claude Code
mkdir -p ~/.claude/bin ~/.claude/session-bus ~/.claude/metis ~/.claude/quick-log \
         ~/.claude/mind ~/.claude/eye/frames ~/.claude/eye/archive
cp claude/bin/* ~/.claude/bin/
chmod +x ~/.claude/bin/*
cp claude/config/*.json ~/.claude/
cp claude/TUTORIAL.md ~/.claude/
```

`~/.claude/settings.json` の `hooks` および `statusLine` の項目に、
`claude/config/settings.hooks.example.json` の内容を統合する。既存の設定を上書き
しないよう、手動でのマージを推奨する。

Hammerspoon および AeroSpace は、初回起動時に「システム設定 → プライバシーとセキュリ
ティ → アクセシビリティ」での許可が必要である。Hammerspoon については、これに加えて
「画面収録」の許可も必要となる。

## 注意事項

- ホットキーはすべて `⌘⌥` を基本とする組み合わせで構成している。macOS 標準の
  `⌘⌥Space`（Finder 検索）や `⌘⌥D`（Dock 表示切替）等、予約済みの組み合わせとは
  重複しないよう設計しているが、使用中の他アプリケーションと競合する場合は
  `hammerspoon/init.lua` 内の `MASH` および各 `hs.hotkey.bind` の定義を変更されたい
- 画面観測機能（`eye.lua`）は、既定で「フォーカス中のウィンドウのみを対象とし、
  除外リストを適用する」セーフモードで動作する。除外対象の設定は
  `claude/config/eye-config.json` の `deny_bundles` および `deny_title_patterns` で
  調整できる
- `⌘⌥S` によるコマンド生成では、既定で実行前に確認ダイアログを表示する構成として
  いる（設定は `claude/config/quick-config.json` の `confirm` を参照）
- `~/.claude/session-bus/` `~/.claude/metis/` `~/.claude/mind/`
  `~/.claude/eye/frames|archive/` は実行時に生成される状態ファイルの格納先であり、
  本リポジトリには含めていない

## ライセンス

指定なし（All rights reserved）。個人の設定を公開する目的で作成したものであり、
内容を参考にすることは差し支えないが、再配布および改変を伴う公開は想定していない。
