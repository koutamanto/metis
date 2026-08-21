-- ─────────────────────────────────────────────────────────────────────────────
--  Quick Action: 選択テキストを Claude に渡す
--  実体は ~/.claude/bin/claude-quick（右クリックメニューと共通）
-- ─────────────────────────────────────────────────────────────────────────────
local util  = require("util")
local panel = require("panel")
local M = {}

-- 選択テキストを取得する。選択が無ければクリップボードの内容を使う。
-- 取得した回答は claude-quick 側がクリップボードへ入れるため、ここでは復元しない。
local function selection()
  local before = hs.pasteboard.getContents()
  hs.eventtap.keyStroke({ "cmd" }, "c", 0)
  hs.timer.usleep(200000)                      -- コピー完了を待つ
  local after = hs.pasteboard.getContents()
  if after and after ~= "" then return after end
  return before or ""
end

local function dispatch(mode, label)
  local text = selection()
  if text == nil or text:gsub("%s", "") == "" then
    util.notify("Claude Quick", "テキストが選択されていません")
    return
  end
  util.notify(label, "送信しました…")
  util.run("claude-quick", { mode, text })
end

function M.ask()     dispatch("ask",     "Claude に聞く（高速）") end
function M.snippet() dispatch("snippet", "Claude コマンド生成")   end

function M.deep()
  dispatch("deep", "Claude 深掘り")
  panel.show()
end

function M.shush() util.run("claude-shush", {}) end

return M
