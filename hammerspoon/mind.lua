-- ═════════════════════════════════════════════════════════════════════════════
--  mind — 脳内ステートのオーバーレイ
--    Cmd+Opt+M : 今 / 次にやること / 保留 を一画面で読み出す
--    Cmd+Opt+N : 一行メモを放り込む（分類は AI が後でやる）
-- ═════════════════════════════════════════════════════════════════════════════
local util = require("util")
local M = {}

local canvas, escHotkey
local W, MAXH = 560, 520

local C = {
  bg     = { red = 0.06, green = 0.07, blue = 0.13, alpha = 0.95 },
  border = { red = 0.34, green = 0.37, blue = 0.54, alpha = 0.6 },
  head   = { red = 0.48, green = 0.64, blue = 0.97, alpha = 1 },
  text   = { red = 0.80, green = 0.84, blue = 0.98, alpha = 1 },
  accent = { red = 0.97, green = 0.69, blue = 0.41, alpha = 1 },
  dim    = { red = 0.47, green = 0.51, blue = 0.65, alpha = 1 },
}

function M.close()
  if canvas then canvas:delete(); canvas = nil end
  if escHotkey then escHotkey:delete(); escHotkey = nil end
end

local function draw(state)
  M.close()
  local sf = hs.screen.mainScreen():frame()

  -- 先に行を組み立ててから高さを決める
  local lines = {}
  local function add(text, color, size, gap)
    lines[#lines + 1] = { text = text, color = color, size = size or 13, gap = gap or 0 }
  end

  add("今", C.head, 12, 0)
  add(state.now ~= "" and state.now or "（まだ把握できていません）", C.text, 15, 2)

  add("次にやること", C.head, 12, 14)
  if #state.next == 0 then add("（なし）", C.dim, 13, 2)
  else for _, v in ipairs(state.next) do add("▸ " .. v, C.accent, 13, 2) end end

  add("保留・気になっていること", C.head, 12, 14)
  if #state.parked == 0 then add("（なし）", C.dim, 13, 2)
  else for _, v in ipairs(state.parked) do add("・" .. v, C.dim, 12, 2) end end

  if state.goals and #state.goals > 0 then
    add("ゴール", C.head, 12, 14)
    for _, v in ipairs(state.goals) do add("◎ " .. v, C.text, 13, 2) end
  end

  add(state.updated ~= "" and ("最終更新 " .. state.updated) or "", C.dim, 10, 16)

  local PAD, y = 22, 22
  local h = PAD
  for _, l in ipairs(lines) do h = h + l.gap + l.size + 7 end
  h = math.min(h + PAD, MAXH)

  canvas = hs.canvas.new({ x = sf.x + (sf.w - W) / 2, y = sf.y + (sf.h - h) / 3, w = W, h = h })
  canvas[1] = { type = "rectangle", action = "fill", fillColor = C.bg,
                roundedRectRadii = { xRadius = 14, yRadius = 14 } }
  canvas[2] = { type = "rectangle", action = "stroke", strokeColor = C.border,
                strokeWidth = 1, roundedRectRadii = { xRadius = 14, yRadius = 14 } }

  for _, l in ipairs(lines) do
    y = y + l.gap
    if l.text ~= "" then
      canvas[#canvas + 1] = {
        type = "text", text = l.text, textColor = l.color, textSize = l.size,
        textFont = "HelveticaNeue", frame = { x = PAD, y = y, w = W - PAD * 2, h = l.size + 8 },
      }
    end
    y = y + l.size + 7
  end

  canvas:level(hs.canvas.windowLevels.modalPanel)
  canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
  canvas:clickActivating(false)
  canvas:mouseCallback(function() M.close() end)
  canvas:canvasMouseEvents(true, false, false, false)
  canvas:show(0.08)

  escHotkey = hs.hotkey.bind({}, "escape", M.close)
end

local function parse(out)
  local ok, d = pcall(hs.json.decode, out)
  if not ok or type(d) ~= "table" then
    return { now = "", next = {}, parked = {}, goals = {}, updated = "" }
  end
  local goals = {}
  if type(d.goals) == "table" then
    for k, v in pairs(d.goals) do goals[#goals + 1] = k .. ": " .. tostring(v) end
  end
  local updated = ""
  if type(d.updated_at) == "number" and d.updated_at > 0 then
    updated = os.date("%m/%d %H:%M", d.updated_at)
  end
  return {
    now = d.now or "", next = d.next or {}, parked = d.parked or {},
    goals = goals, updated = updated,
  }
end

function M.toggle()
  if canvas then M.close(); return end
  util.capture("mind", { "json" }, function(out) draw(parse(out)) end)
end

-- 一行メモ。書いた直後に再構成を走らせるので、放り込むだけでよい。
function M.note()
  local button, text = hs.dialog.textPrompt(
    "メモを記録", "分類は不要です。思いついたまま書いてください。", "", "記録", "キャンセル")
  if button ~= "記録" or not text or text:gsub("%s", "") == "" then return end
  util.run("mind", { "note", text }, function()
    util.run("mind", { "sync" }, function()
      util.notify("脳内ステート", "記録して整理しました")
    end)
  end)
end

-- 定期的に再構成する（完全自動運用）
function M.startAutoSync(intervalSeconds)
  hs.timer.doEvery(intervalSeconds or 900, function()
    util.run("mind", { "sync" })
  end)
end

return M
