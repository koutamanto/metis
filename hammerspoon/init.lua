-- ═════════════════════════════════════════════════════════════════════════════
--  Hammerspoon — 並行作業のためのホットキー群
--  設定を変えたら ⌘⌥⌃R でリロード
-- ═════════════════════════════════════════════════════════════════════════════
package.path = os.getenv("HOME") .. "/.hammerspoon/?.lua;" .. package.path

require("hs.ipc")   -- `hs -c '...'` からリモート診断できるようにする

hs.console.clearConsole()
hs.window.animationDuration = 0.10

local util    = require("util")
local panel   = require("panel")
local hud     = require("hud")
local jump    = require("jump")
local quick   = require("quick")
local eye     = require("eye")
local mind    = require("mind")
local macro      = require("macro")
local shot       = require("shot")
local metis      = require("metis")
local interactor = require("interactor")
local cheatsheet = require("cheatsheet")
local menubar    = require("menubar")

local MASH = { "cmd", "alt" }

-- ─── セッション操作 ──────────────────────────────────────────────────────────
hs.hotkey.bind(MASH, "p",     panel.toggle)      -- Claude 専用パネルの出し入れ
-- ⌘⌥Space は macOS 標準の「Finder検索ウィンドウを表示」と衝突するため ⌘⌥P に変更
hs.hotkey.bind(MASH, "j",     jump.nextWaiting)  -- 次の「待ち」へジャンプ
hs.hotkey.bind(MASH, "f",     function() util.run("claude-fork-here", {}) end)  -- 今のセッションから非同期で枝分かれ
hs.hotkey.bind(MASH, "h",     hud.toggle)        -- セッション HUD の表示切替

-- ─── Quick Action ────────────────────────────────────────────────────────────
hs.hotkey.bind(MASH, "a",     quick.ask)         -- 高速質問 (Sonnet 5)
hs.hotkey.bind({ "cmd", "alt", "shift" }, "a", quick.deep)  -- 深掘り (Opus) — ask の強化版という位置づけ
-- ⌘⌥D は macOS 標準の「Dock の表示/非表示切替」と衝突するため ⌘⌥⇧A に変更
hs.hotkey.bind(MASH, "s",     quick.snippet)     -- コマンド生成 → 確認 → 実行
hs.hotkey.bind(MASH, "x",     macro.run)         -- 画面の指示を読み取り→一括確認→新規ターミナルで連続実行
hs.hotkey.bind(MASH, "v",     shot.run)          -- Shot: 画面を撮って見ながら質問
hs.hotkey.bind(MASH, "q",     metis.toggle)      -- Metis パネル（Quick Action 結果の一元管理）
hs.hotkey.bind(MASH, "i",     interactor.toggle) -- Quick Action Interactor（専用TUI・履歴から新セッションへ昇格）

-- ─── 脳内ステート ────────────────────────────────────────────────────────────
hs.hotkey.bind(MASH, "m",     mind.toggle)       -- 今 / 次 / 保留 を読み出す
hs.hotkey.bind(MASH, "n",     mind.note)         -- 一行メモ
hs.hotkey.bind(MASH, "c",     function() eye.captureNow() end)  -- 今の画面を記録

-- ─── その他 ──────────────────────────────────────────────────────────────────
hs.hotkey.bind(MASH, ".",     quick.shush)       -- 読み上げを即停止
hs.hotkey.bind(MASH, "/",     cheatsheet.toggle) -- ショートカット早見表

hs.hotkey.bind({ "cmd", "alt", "ctrl" }, "r", function()
  hs.notify.new({ title = "Hammerspoon", informativeText = "設定を再読み込みしました" }):send()
  hs.reload()
end)

-- ─── 常駐開始 ────────────────────────────────────────────────────────────────
hud.start()
eye.start()
mind.startAutoSync(900)     -- 15分ごとに脳内ステートを再構成
metis.start()
menubar.start()

hs.notify.new({
  title = "Metis",
  informativeText = "拡張人工知能インターフェイスを起動しました（画面観測: " .. eye.mode() .. "）",
}):send()
