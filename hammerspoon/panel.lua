-- ─────────────────────────────────────────────────────────────────────────────
--  Claude 専用パネル: 画面上部から滑り出す常駐ターミナル
--  Ghostty の quick terminal (Cmd+`) は汎用シェル用に温存するため、
--  こちらは独立したウィンドウをタイトルで識別して出し入れする。
-- ─────────────────────────────────────────────────────────────────────────────
local M = {}

local TITLE   = "Claude Panel"
local SESSION = "claude-panel"
local ANIM    = 0.10
local BUNDLE  = "com.mitchellh.ghostty"

local function screenFrame() return hs.screen.mainScreen():frame() end

local function shownFrame()
  local f = screenFrame()
  local w = math.floor(f.w * 0.46)
  local h = math.floor(f.h * 0.74)
  return hs.geometry.rect(f.x + f.w - w - 12, f.y + 8, w, h)
end

local function hiddenFrame()
  local t, f = shownFrame(), screenFrame()
  return hs.geometry.rect(t.x, f.y - t.h - 60, t.w, t.h)   -- 画面上へ退避
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

-- パネルを新規生成する。中身は tmux セッションなので閉じても状態が残る。
local function spawn()
  local cmd = ("tmux new-session -A -s %s"):format(SESSION)
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
    w:setFrame(hiddenFrame(), ANIM)          -- 見えていて手前 → しまう
  else
    w:setFrame(shownFrame(), ANIM)           -- それ以外 → 出して前面へ
    w:raise(); w:focus()
  end
end

-- 深掘り結果などをパネルに前面表示させたいとき用
function M.show()
  local w = findWindow()
  if not w then spawn(); return end
  w:setFrame(shownFrame(), ANIM); w:raise(); w:focus()
end

return M
