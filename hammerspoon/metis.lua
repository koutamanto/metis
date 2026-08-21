-- ═════════════════════════════════════════════════════════════════════════════
--  Metis Panel — Quick Action の回答結果を一元管理するパネル
--
--  claude-quick / claude-macro は結果を待つ前に「pending」を即座に書き込む。
--  このパネルは新しい pending を検知した瞬間に自動で開き、「考え中…」を表示。
--  実測のレイテンシ自体は変わらないが、待ち時間をゼロに感じさせるのが狙い。
--  回答が来ると同じ枠がその場で埋まり、手動で閉じるまで／一定時間操作が
--  無いまま完了してから数秒後に自動で閉じる。⌘⌥Q でいつでも履歴を呼び出せる。
-- ═════════════════════════════════════════════════════════════════════════════
local util = require("util")
local M = {}

local canvas, timer
local entries    = {}
local lastSig    = nil
local pinned     = false        -- 手動で開いたときは自動で閉じない
local autoHideAt = nil
local POLL       = 0.4
local AUTO_HIDE_AFTER = 9        -- 全件 done/error になってから何秒で自動的に閉じるか

local W = 520
local PAD, ROWGAP = 20, 14

local MODE_LABEL = { ask = "Quick Ask", deep = "深掘り", snippet = "スニペット", macro = "マクロ", shot = "Shot" }
local STATUS = {
  pending    = { icon = "◌", color = { red = 0.97, green = 0.69, blue = 0.41, alpha = 1 }, label = "考え中…" },
  running    = { icon = "●", color = { red = 0.48, green = 0.64, blue = 0.97, alpha = 1 }, label = "実行中…" },
  confirming = { icon = "?", color = { red = 0.97, green = 0.69, blue = 0.41, alpha = 1 }, label = "確認待ち" },
  done       = { icon = "✓", color = { red = 0.62, green = 0.81, blue = 0.42, alpha = 1 }, label = "完了" },
  error      = { icon = "✕", color = { red = 0.94, green = 0.46, blue = 0.46, alpha = 1 }, label = "失敗" },
  cancelled  = { icon = "–", color = { red = 0.47, green = 0.51, blue = 0.65, alpha = 1 }, label = "キャンセル" },
}

local C = {
  bg     = { red = 0.05, green = 0.06, blue = 0.11, alpha = 0.97 },
  border = { red = 0.34, green = 0.37, blue = 0.54, alpha = 0.6 },
  head   = { red = 0.97, green = 0.69, blue = 0.41, alpha = 1 },
  prompt = { red = 0.80, green = 0.84, blue = 0.98, alpha = 1 },
  answer = { red = 0.62, green = 0.68, blue = 0.86, alpha = 1 },
  hint   = { red = 0.47, green = 0.51, blue = 0.65, alpha = 1 },
}

local function truncate(s, n)
  if not s then return "" end
  s = s:gsub("[\r\n]+", " ")
  if #s > n then return s:sub(1, n) .. "…" end
  return s
end

local function signature()
  local parts = {}
  for _, e in ipairs(entries) do
    parts[#parts + 1] = e.id .. "|" .. e.status .. "|" .. #(e.answer or "")
  end
  return table.concat(parts, ";")
end

local function measure(entries2)
  local h = PAD * 2 + 26        -- タイトル分
  for _, e in ipairs(entries2) do
    h = h + 20                  -- 状態行
    h = h + 18                  -- プロンプト行
    if e.answer and e.answer ~= "" then h = h + 18 * math.min(3, math.ceil(#e.answer / 70)) end
    h = h + ROWGAP
  end
  return h
end

local function rebuild()
  if canvas then canvas:delete(); canvas = nil end
  if #entries == 0 then lastSig = signature(); return end

  local sf = hs.screen.mainScreen():frame()
  local h = math.min(measure(entries), sf.h - 80)
  canvas = hs.canvas.new({ x = sf.x + sf.w - W - 16, y = sf.y + 16, w = W, h = h })

  canvas[1] = { type = "rectangle", action = "fill", fillColor = C.bg,
                roundedRectRadii = { xRadius = 14, yRadius = 14 } }
  canvas[2] = { type = "rectangle", action = "stroke", strokeColor = C.border,
                strokeWidth = 1, roundedRectRadii = { xRadius = 14, yRadius = 14 } }
  canvas[3] = { type = "text", text = "Metis — Quick Action", textColor = C.head, textSize = 14,
                textFont = "HelveticaNeue-Bold", frame = { x = PAD, y = 12, w = W - PAD * 2, h = 20 } }

  local y = 40
  for _, e in ipairs(entries) do
    local st = STATUS[e.status] or STATUS.pending
    canvas[#canvas + 1] = {
      type = "text", text = st.icon .. "  " .. (MODE_LABEL[e.mode] or e.mode) .. " — " .. st.label,
      textColor = st.color, textSize = 12, textFont = "HelveticaNeue-Bold",
      frame = { x = PAD, y = y, w = W - PAD * 2, h = 18 },
    }
    y = y + 20
    canvas[#canvas + 1] = {
      type = "text", text = truncate(e.prompt, 90), textColor = C.prompt, textSize = 12,
      textFont = "HelveticaNeue", frame = { x = PAD, y = y, w = W - PAD * 2, h = 18 },
    }
    y = y + 18
    if e.answer and e.answer ~= "" then
      canvas[#canvas + 1] = {
        type = "text", text = truncate(e.answer, 210), textColor = C.answer, textSize = 12,
        textFont = "Menlo", frame = { x = PAD, y = y, w = W - PAD * 2, h = 54 },
      }
      y = y + 18 * math.min(3, math.ceil(#e.answer / 70))
    end
    y = y + ROWGAP
  end

  canvas[#canvas + 1] = {
    type = "text", text = "⌘⌥Q で開閉 ・ Esc または外側クリックで閉じる", textColor = C.hint, textSize = 10,
    textFont = "HelveticaNeue", frame = { x = PAD, y = h - 20, w = W - PAD * 2, h = 14 },
  }

  canvas:level(hs.canvas.windowLevels.overlay)
  canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
  canvas:clickActivating(false)
  canvas:mouseCallback(function() M.close() end)
  canvas:canvasMouseEvents(true, false, false, false)
  canvas:show(0.08)
  lastSig = signature()
end

function M.close()
  if canvas then canvas:delete(); canvas = nil end
  pinned = false
  autoHideAt = nil
end

local function allSettled()
  for _, e in ipairs(entries) do
    if e.status == "pending" or e.status == "running" or e.status == "confirming" then return false end
  end
  return true
end

local function poll()
  util.capture("metis-recent", { "6" }, function(out)
    local ok, decoded = pcall(hs.json.decode, out)
    if not ok or type(decoded) ~= "table" then return end

    local hadPending = false
    for _, e in ipairs(entries) do
      if e.status == "pending" or e.status == "running" then hadPending = true end
    end

    entries = decoded
    local sig = signature()

    local nowHasPending = false
    for _, e in ipairs(entries) do
      if e.status == "pending" or e.status == "running" then nowHasPending = true end
    end

    -- 内容が前回と同じでも、「⌘⌥Q で開こうとしている(pinned=true だが未表示)」ときは
    -- 素通りしてはいけない。ここを早期 return してしまうと手動トグルが無反応になる。
    local needsForceOpen = pinned and not canvas
    if sig == lastSig and not needsForceOpen then
      -- 何も変わっていない。全て決着していて自動オープンでもなければウィンドウは触らない。
      if canvas and not pinned and allSettled() and autoHideAt and hs.timer.secondsSinceEpoch() > autoHideAt then
        M.close()
      end
      return
    end

    -- 新規の pending を検知したら、閉じていても自動で開く（ここが「即座に見える」の要）
    if nowHasPending and not hadPending and not canvas then
      pinned = false
    end

    if canvas or (nowHasPending and not hadPending) or pinned then
      rebuild()
    else
      lastSig = sig
    end

    if allSettled() and canvas and not pinned then
      autoHideAt = hs.timer.secondsSinceEpoch() + AUTO_HIDE_AFTER
    else
      autoHideAt = nil
    end
  end)
end

function M.start()
  if timer then timer:stop() end
  timer = hs.timer.doEvery(POLL, poll)
  poll()
end

-- ⌘⌥Q: 手動トグル。開くときは pin して自動クローズを止める（履歴をゆっくり読める）
function M.toggle()
  if canvas then M.close(); return end
  pinned = true
  poll()
end

return M
