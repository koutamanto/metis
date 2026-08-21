-- ═════════════════════════════════════════════════════════════════════════════
--  Shot — 画面を1枚撮って、それを見ながら質問に即答する
--    ⌘⌥V: フォーカス中のウィンドウを撮影 → 質問を一言入力 → Metis パネルへ
--  eye.lua と同じ除外リストに従う（パスワード管理・メッセージ等は撮らない）。
-- ═════════════════════════════════════════════════════════════════════════════
local util = require("util")
local eye  = require("eye")
local M = {}

local HOME   = os.getenv("HOME")
local OUTDIR = HOME .. "/.claude/metis/shots"

function M.run()
  local ok, win, reason = eye.permitted()
  if not ok then
    util.notify("Shot", "この画面は除外対象のため撮影しません（" .. (reason or "") .. "）")
    return
  end

  local img = win and win:snapshot() or hs.screen.mainScreen():snapshot()
  if not img then
    util.notify("Shot", "画面を取得できませんでした")
    return
  end

  hs.fs.mkdir(OUTDIR)
  local path = string.format("%s/%s.jpg", OUTDIR, os.date("%Y%m%d-%H%M%S"))
  if not img:saveToFile(path, "JPEG") then
    util.notify("Shot", "画像の保存に失敗しました")
    return
  end

  local button, question = hs.dialog.textPrompt(
    "Shot — 何について聞きますか？", "空のままでも構いません（画面の説明を求めます）",
    "", "質問する", "キャンセル")

  if button ~= "質問する" then
    os.remove(path)
    return
  end

  util.notify("Shot", "考え中…")
  util.run("claude-quick", { "shot", path, question or "" })
end

return M
