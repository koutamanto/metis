-- ═════════════════════════════════════════════════════════════════════════════
--  macro — 画面に映っている指示を読み取り、新規ターミナルで自動実行する
--  「新しいターミナルウィンドウを開き、指示を上から順にパタパタ実行する」を
--  1キーで行う。承認は緩め（確認ダイアログなし）だが、危険なコマンドは
--  claude-macro 側のフィルタで自動的に弾く。
-- ═════════════════════════════════════════════════════════════════════════════
local util = require("util")
local eye  = require("eye")
local M = {}

local HOME  = os.getenv("HOME")
local OUTDIR = HOME .. "/.claude/eye/macro"

function M.run()
  local ok, win, reason = eye.permitted()
  if not ok then
    util.notify("Claude マクロ", "この画面は除外対象のため実行しません（" .. (reason or "") .. "）")
    return
  end

  -- フォーカス中のウィンドウを撮る（「画面に映っている指示」＝手前のウィンドウ）
  local img = win and win:snapshot() or hs.screen.mainScreen():snapshot()
  if not img then
    util.notify("Claude マクロ", "画面を取得できませんでした")
    return
  end

  hs.fs.mkdir(OUTDIR)
  local path = string.format("%s/%s.jpg", OUTDIR, os.date("%Y%m%d-%H%M%S"))
  if not img:saveToFile(path, "JPEG") then
    util.notify("Claude マクロ", "画像の保存に失敗しました")
    return
  end

  util.notify("Claude マクロ", "指示を読み取っています…")
  util.run("claude-macro", { path })
end

return M
