-- ─────────────────────────────────────────────────────────────────────────────
--  Quick Action Interactor — Metis 専用の TUI
--  Quick Action の履歴を Collapsed（要約1行）で一覧し、選ぶとその文脈を
--  引き継いだ新しい永続セッションへ昇格させる。panel.lua と同じ「出し入れ
--  できる浮動ウィンドウ」パターンを、専用の tmux セッションで独立させたもの。
-- ─────────────────────────────────────────────────────────────────────────────
local M = {}

local TITLE   = "Metis Interactor"
local SESSION = "metis-interactor"
local ANIM    = 0.10
local BUNDLE  = "com.mitchellh.ghostty"

local function screenFrame() return hs.screen.mainScreen():frame() end

local function shownFrame()
  local f = screenFrame()
  local w = math.floor(f.w * 0.5)
  local h = math.floor(f.h * 0.78)
  return hs.geometry.rect(f.x + (f.w - w) / 2, f.y + 8, w, h)
end

local function hiddenFrame()
  local t, f = shownFrame(), screenFrame()
  return hs.geometry.rect(t.x, f.y - t.h - 60, t.w, t.h)
end

local function findWindow()
  local app = hs.application.get(BUNDLE)
  if not app then return nil end
  for _, w in ipairs(app:allWindows()) do
    local t = w:title()
    if t and t:find(TITLE, 1, true) then return w end
  end
  return nil
end

-- metis-tui は終了すると exit するので、閉じたら次回また同じセッション名で
-- 起動し直す(再利用ではなく毎回フレッシュに開始する)。
local function spawn()
  local cmd = ("tmux new-session -A -s %s ~/.claude/bin/metis-tui"):format(SESSION)
  hs.task.new("/usr/bin/open", nil, {
    "-na", "Ghostty", "--args",
    "--title=" .. TITLE,
    "--initial-command=" .. cmd,
  }):start()
end

function M.toggle()
  local w = findWindow()
  if not w then spawn(); return end

  local onScreen = w:frame().y >= screenFrame().y - 5
  local focused  = hs.window.focusedWindow()
  local isFocused = focused ~= nil and focused:id() == w:id()

  if onScreen and isFocused then
    w:setFrame(hiddenFrame(), ANIM)
  else
    w:setFrame(shownFrame(), ANIM)
    w:raise(); w:focus()
  end
end

return M
