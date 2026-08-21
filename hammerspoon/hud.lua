-- ─────────────────────────────────────────────────────────────────────────────
--  HUD: 走行中の Claude セッションを画面右上に半透明で常駐表示する。
--  音を聞かなくても状況が一目で分かるようにするのが目的。
-- ─────────────────────────────────────────────────────────────────────────────
local util = require("util")
local M = {}

local canvas, timer
local rows      = {}
local visible   = true
local lastSig   = nil          -- 直前の描画内容(状態/件数)。同じなら窓を作り直さない
local elapsedIdx = {}           -- 経過時間テキストだけを高頻度で書き換えるための要素番号
local POLL      = 1.5
local W, ROWH   = 300, 24
local PAD       = 10

local COLORS = {
  bg      = { red = 0.07, green = 0.08, blue = 0.15, alpha = 0.86 },
  border  = { red = 0.34, green = 0.37, blue = 0.54, alpha = 0.55 },
  waiting = { red = 0.97, green = 0.69, blue = 0.41, alpha = 1 },
  running = { red = 0.48, green = 0.64, blue = 0.97, alpha = 1 },
  done    = { red = 0.62, green = 0.81, blue = 0.42, alpha = 1 },
  idle    = { red = 0.55, green = 0.60, blue = 0.72, alpha = 1 },
  text    = { red = 0.75, green = 0.79, blue = 0.96, alpha = 1 },
  dim     = { red = 0.44, green = 0.48, blue = 0.62, alpha = 1 },
}

local LABEL = { waiting = "確認待ち", running = "実行中", done = "完了", idle = "待機" }
local ICON  = { waiting = "◆",       running = "●",     done = "✓",   idle = "·" }

local function human(sec)
  sec = tonumber(sec) or 0
  if sec < 60   then return string.format("%ds", sec) end
  if sec < 3600 then return string.format("%dm", sec // 60) end
  return string.format("%dh", sec // 3600)
end

local function parse(out)
  local list = {}
  for line in (out or ""):gmatch("[^\n]+") do
    local f = {}
    for field in (line .. "\t"):gmatch("([^\t]*)\t") do f[#f + 1] = field end
    if #f >= 6 then
      list[#list + 1] = { state = f[1], project = f[2], pane = f[4], elapsed = f[5] }
    end
  end
  return list
end

-- state/project/pane だけの署名。変化していなければウィンドウを作り直さない。
local function signature()
  local parts = {}
  for _, r in ipairs(rows) do
    parts[#parts + 1] = r.state .. "|" .. r.project .. "|" .. (r.pane or "")
  end
  return table.concat(parts, ";")
end

-- ウィンドウを丸ごと作り直す（行の増減・状態変化があったときだけ）
local function rebuild()
  if canvas then canvas:delete(); canvas = nil end
  elapsedIdx = {}
  if not visible or #rows == 0 then lastSig = signature(); return end

  local sf = hs.screen.mainScreen():frame()
  local h  = PAD * 2 + ROWH * #rows
  canvas = hs.canvas.new({ x = sf.x + sf.w - W - 14, y = sf.y + 14, w = W, h = h })

  canvas[1] = { type = "rectangle", action = "fill", fillColor = COLORS.bg,
                roundedRectRadii = { xRadius = 10, yRadius = 10 } }
  canvas[2] = { type = "rectangle", action = "stroke", strokeColor = COLORS.border,
                strokeWidth = 1, roundedRectRadii = { xRadius = 10, yRadius = 10 } }

  for i, r in ipairs(rows) do
    local y  = PAD + (i - 1) * ROWH
    local c  = COLORS[r.state] or COLORS.idle
    local function txt(s, x, w, color, size, align)
      canvas[#canvas + 1] = {
        type = "text", text = s, textColor = color, textSize = size or 12,
        textAlignment = align or "left", textFont = "Menlo",
        frame = { x = x, y = y + 3, w = w, h = ROWH },
      }
      return #canvas
    end
    txt(ICON[r.state] or "·", PAD, 16, c, 13)
    txt(r.project, PAD + 18, 150, COLORS.text, 12)
    txt(LABEL[r.state] or r.state, PAD + 170, 70, c, 11)
    elapsedIdx[i] = txt(human(r.elapsed), PAD + 240, W - PAD - 250, COLORS.dim, 11, "right")
  end

  canvas:level(hs.canvas.windowLevels.overlay)
  canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
  canvas:show()
  lastSig = signature()
end

-- 経過時間の文字列だけを書き換える（ウィンドウの作り直しをしない軽量パス）
local function refreshElapsedOnly()
  if not canvas then return end
  for i, r in ipairs(rows) do
    local idx = elapsedIdx[i]
    if idx then canvas[idx].text = human(r.elapsed) end
  end
end

local function render()
  local sig = signature()
  if sig == lastSig and ((canvas ~= nil) == (visible and #rows > 0)) then
    refreshElapsedOnly()      -- 中身は同じ。時間表示だけ更新して窓は触らない
  else
    rebuild()
  end
end

local function poll()
  util.capture("claude-sessions", {}, function(out)
    rows = parse(out)
    render()
  end)
end

function M.start()
  if timer then timer:stop() end
  timer = hs.timer.doEvery(POLL, poll)
  poll()
end

function M.toggle()
  visible = not visible
  if visible then poll() else render() end
  util.notify("Claude HUD", visible and "表示" or "非表示")
end

return M
