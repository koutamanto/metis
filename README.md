# Metis

複数の [Claude Code](https://claude.com/claude-code) セッションと並行して作業するための、
macOS ターミナル環境一式。

Claude Code をどこからでも呼び出せるようにしつつ、その状態（実行中・確認待ち・完了）を
音声とパネルで把握し、画面の指示やスクリーンショットからワンキーで行動を起こせるように
することを目標にしている。

## 中身

| 層 | 何を提供するか |
|---|---|
| **シェル (zsh)** | eza/bat/fd/ripgrep/zoxide/atuin/fzf などモダン CLI への総入れ替え、tmux ベースのセッション管理コマンド (`cw` `cl` `cj` `cr` `cfork`) |
| **Ghostty** | Tokyo Night テーマ、クイックターミナル、分割・タブのキーバインド |
| **tmux** | Claude Code セッションの母艦。ウィンドウを閉じても死なない |
| **AeroSpace** | ワークスペース分離（エディタ / Claude 群 / ブラウザ / 雑用） |
| **Hammerspoon (Metis)** | 下記参照 |

## Metis とは

Hammerspoon 上に実装した、Claude Code の常駐アシスタント層。

- **セッションバス** — Claude Code のフック (`SessionStart` / `UserPromptSubmit` /
  `Notification` / `Stop` / `SessionEnd`) から状態を集約し、他の全機能がここを読む
- **読み上げ** — 裏で走っているセッションが完了・確認待ちになったときだけ音声で知らせる。
  見えているセッションは黙る（可視判定つき）
- **HUD** — 画面右上に半透明で全セッションの状態を常時表示
- **Quick Action** — 選択テキストや画面のスクリーンショットを Sonnet 5 に投げて即答させる
  (`⌘⌥A` 高速質問 / `⌘⌥⇧A` 深掘り / `⌘⌥S` コマンド生成・確認・実行 /
  `⌘⌥X` 画面の指示を読み取って一括確認後に実行 / `⌘⌥V` 画面を撮って質問)
- **Metis パネル** — Quick Action の結果を一元管理。トリガーした瞬間に「考え中」が
  出て、回答が来ると埋まる（体感速度重視。実測レイテンシそのものは変えていない）
- **Quick Action Interactor** — 専用 TUI。Quick Action の履歴を一覧し、選ぶとその
  文脈を引き継いだ新しい永続セッションへ昇格できる
- **脳内ステート (mind)** — 「今やっていること / 次にやること / 保留」を一行メモの
  蓄積から自動で再構成する。書く手間をゼロに近づけるのが狙い
- **画面観測 (eye)** — フォーカス中のウィンドウのみを対象にした撮影。パスワード管理・
  メッセージ・ビデオ会議アプリなどは既定で除外、無操作が続くと自動停止
- **ショートカット早見表** — `⌘⌥/` で全ホットキーを一覧表示

ホットキー一覧・使い方は [`claude/TUTORIAL.md`](claude/TUTORIAL.md) を参照。

## セットアップ

前提: [Homebrew](https://brew.sh)、[Claude Code CLI](https://claude.com/claude-code)、
macOS。

```sh
brew install eza bat fd ripgrep fzf zoxide starship delta tmux lazygit btop \
             tlrc jq yazi atuin direnv mise dust duf procs sd hyperfine gping \
             httpie ncdu tree
brew install --cask ghostty hammerspoon font-jetbrains-mono-nerd-font
brew tap nikitabobko/tap && brew install --cask nikitabobko/tap/aerospace
```

```sh
git clone <このリポジトリ> ~/metis-src
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

# Hammerspoon (Metis)
cp hammerspoon/*.lua ~/.hammerspoon/

# Claude Code 側
mkdir -p ~/.claude/bin ~/.claude/session-bus ~/.claude/metis ~/.claude/quick-log \
         ~/.claude/mind ~/.claude/eye/frames ~/.claude/eye/archive
cp claude/bin/* ~/.claude/bin/
chmod +x ~/.claude/bin/*
cp claude/config/*.json ~/.claude/
mv ~/.claude/settings.hooks.example.json ~/.claude/  # 参考用。settings.json には手でマージする
cp claude/TUTORIAL.md ~/.claude/
```

`~/.claude/settings.json` の `hooks` / `statusLine` に
`claude/config/settings.hooks.example.json` の内容をマージしてください
（既存の設定を上書きしないよう手動で統合するのを推奨します）。

Hammerspoon と AeroSpace は初回起動時に **システム設定 → プライバシーとセキュリティ →
アクセシビリティ**（Hammerspoon はさらに**画面収録**も）を有効化する必要があります。

## 注意点

- ホットキーは全て `⌘⌥` 系。macOS 標準の `⌘⌥Space`（Finder検索）や `⌘⌥D`（Dock表示切替）
  など予約済みの組み合わせを避けて設計してあるが、自分の環境の他アプリと衝突する場合は
  `hammerspoon/init.lua` の `MASH` / 各 `hs.hotkey.bind` を書き換えること
- 画面観測 (`eye.lua`) は既定で「フォーカス中のウィンドウのみ・除外リストあり」の
  セーフモード。除外対象は `claude/config/eye-config.json` の `deny_bundles` /
  `deny_title_patterns` で調整できる
- `⌘⌥S` のコマンド生成は既定で実行前に確認ダイアログを挟む
  （`claude/config/quick-config.json` の `confirm`）
- `~/.claude/session-bus/` `~/.claude/metis/` `~/.claude/mind/` `~/.claude/eye/frames|archive/`
  は実行時に生成される状態ファイルで、このリポジトリには含まれていない

## ライセンス

なし（All rights reserved）。個人の設定を公開しているものなので、参考にする分には
自由に見てもらって構いませんが、再配布・改変しての公開は想定していません。
