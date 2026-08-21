-- ═════════════════════════════════════════════════════════════════════════════
--  eye — 画面観測エンジン
--
--  safe   : フォーカス中のウィンドウだけを撮る。起点はフォーカス切替。
--           背面のウィンドウは一切写らないため、既定はこちら。
--  direct : 全画面を一定間隔で撮る。明示的な禁止対象以外は写り込みを許容する。
--  off    : 停止。
--
--  いずれのモードでも、無操作が続いている間は撮影も解析も行わない。
-- ═════════════════════════════════════════════════════════════════════════════
local util = require("util")
local M = {}

local HOME    = os.getenv("HOME")
local EYE     = HOME .. "/.claude/eye"
local FRAMES  = EYE .. "/frames"
local CFGPATH = HOME .. "/.claude/eye-config.json"

local cfg          = {}
local mode         = "safe"
local frameCount   = 0
local lastAnalyze  = os.time()
local lastCapture  = 0
local windowFilter, heartbeat, analyzeTimer, debounceTimer
local lastActivity = os.time()
local activityTap

M.onChange = nil          -- メニューバーへ状態変化を伝えるためのフック

-- ─── 設定 ────────────────────────────────────────────────────────────────────
local function loadConfig()
  local ok, data = pcall(hs.json.read, CFGPATH)
  cfg = (ok and data) or {}
  cfg.idle_seconds          = cfg.idle_seconds          or 45
  cfg.direct_interval       = cfg.direct_interval       or 10
  cfg.safe_heartbeat        = cfg.safe_heartbeat        or 90
  cfg.capture_width         = cfg.capture_width         or 1280
  cfg.analyze_after_frames  = cfg.analyze_after_frames  or 6
  cfg.analyze_after_seconds = cfg.analyze_after_seconds or 300
  cfg.max_frames            = cfg.max_frames            or 60
  cfg.deny_bundles          = cfg.deny_bundles          or {}
  cfg.deny_title_patterns   = cfg.deny_title_patterns   or {}
  mode = cfg.mode or "safe"
end

local function saveMode(newMode)
  mode = newMode
  cfg.mode = newMode
  pcall(hs.json.write, cfg, CFGPATH, true, true)
  if M.onChange then M.onChange() end
end

-- ─── 無操作の検出 ────────────────────────────────────────────────────────────
-- hs.host.idleTime() が使えればそれを、無ければ自前のイベント監視で代替する。
local hasHostIdle = (hs.host ~= nil and type(hs.host.idleTime) == "function")

local function idleSeconds()
  if hasHostIdle then
    local ok, v = pcall(hs.host.idleTime)
    if ok and v then return v end
  end
  return os.time() - lastActivity
end

local function startActivityTap()
  if hasHostIdle or activityTap then return end
  local t = hs.eventtap.event.types
  activityTap = hs.eventtap.new(
    { t.mouseMoved, t.keyDown, t.leftMouseDown, t.rightMouseDown, t.scrollWheel },
    function() lastActivity = os.time(); return false end)
  activityTap:start()
end

-- ─── 撮ってよい状況か ────────────────────────────────────────────────────────
local function contains(haystack, needle)
  return haystack:lower():find(needle:lower(), 1, true) ~= nil
end

-- 戻り値: 許可されているか, 対象ウィンドウ, 拒否理由
local function permitted()
  local app = hs.application.frontmostApplication()
  if not app then return false, nil, "最前面のアプリを取得できません" end

  local bid = app:bundleID() or ""
  for _, deny in ipairs(cfg.deny_bundles) do
    if bid == deny then return false, nil, "除外アプリ: " .. (app:name() or bid) end
  end

  local win = hs.window.focusedWindow()
  local title = (win and win:title()) or ""
  for _, pat in ipairs(cfg.deny_title_patterns) do
    if contains(title, pat) then return false, nil, "除外タイトル: " .. pat end
  end

  return true, win, nil
end

-- ─── フレームを1枚保存する ───────────────────────────────────────────────────
local function prune()
  local files = {}
  for f in hs.fs.dir(FRAMES) do
    if f:match("%.jpg$") then files[#files + 1] = f end
  end
  if #files <= cfg.max_frames then return end
  table.sort(files)
  for i = 1, #files - cfg.max_frames do
    os.remove(FRAMES .. "/" .. files[i])
  end
end

local function capture(reason)
  if mode == "off" then return end
  if idleSeconds() > cfg.idle_seconds then return end       -- 無操作なら撮らない
  if os.time() - lastCapture < 2 then return end            -- 連写を防ぐ

  local ok, win = permitted()
  if not ok then return end

  local img
  if mode == "safe" then
    if not win then return end
    img = win:snapshot()                                    -- そのウィンドウだけ
  else
    img = hs.screen.mainScreen():snapshot()                 -- 全画面
  end
  if not img then return end

  local size = img:size()
  if size and size.w and size.w > cfg.capture_width then
    img = img:setSize({ w = cfg.capture_width,
                        h = math.floor(size.h * cfg.capture_width / size.w) })
  end

  local path = string.format("%s/%s-%s.jpg", FRAMES, os.date("%Y%m%d-%H%M%S"), reason)
  if img:saveToFile(path, "JPEG") then
    lastCapture = os.time()
    frameCount  = frameCount + 1
    prune()
  end
end

-- ─── 解析のトリガー ──────────────────────────────────────────────────────────
local function maybeAnalyze()
  if mode == "off" then return end
  if idleSeconds() > cfg.idle_seconds then return end       -- 無操作中は解析しない
  local elapsed = os.time() - lastAnalyze
  if frameCount < cfg.analyze_after_frames and elapsed < cfg.analyze_after_seconds then
    return
  end
  if frameCount == 0 then return end
  frameCount  = 0
  lastAnalyze = os.time()
  util.run("claude-eye-analyze", {})
end

-- ─── 起動・停止 ──────────────────────────────────────────────────────────────
local function stopWatchers()
  if windowFilter  then windowFilter:unsubscribeAll(); windowFilter = nil end
  if heartbeat     then heartbeat:stop();     heartbeat = nil end
  if analyzeTimer  then analyzeTimer:stop();  analyzeTimer = nil end
  if debounceTimer then debounceTimer:stop(); debounceTimer = nil end
end

local function startWatchers()
  stopWatchers()
  if mode == "off" then return end
  startActivityTap()

  -- フォーカス切替が主トリガー。ウィンドウが落ち着くまで少し待ってから撮る。
  windowFilter = hs.window.filter.new(nil)
  windowFilter:subscribe(hs.window.filter.windowFocused, function()
    if debounceTimer then debounceTimer:stop() end
    debounceTimer = hs.timer.doAfter(1.2, function() capture("focus") end)
  end)

  -- 同じウィンドウで作業し続けている間も、間隔を空けて拾う
  local interval = (mode == "direct") and cfg.direct_interval or cfg.safe_heartbeat
  heartbeat = hs.timer.doEvery(interval, function() capture("tick") end)

  analyzeTimer = hs.timer.doEvery(30, maybeAnalyze)
end

-- ─── 公開 API ────────────────────────────────────────────────────────────────
function M.start()
  loadConfig()
  hs.fs.mkdir(EYE); hs.fs.mkdir(FRAMES)
  startWatchers()
end

function M.setMode(newMode)
  saveMode(newMode)
  startWatchers()
  util.notify("画面観測", ({
    safe   = "セーフモード（フォーカス中のウィンドウのみ）",
    direct = "ダイレクトモード（全画面）",
    off    = "停止しました",
  })[newMode] or newMode)
end

function M.mode() return mode end

function M.status()
  local idle = math.floor(idleSeconds())
  local ok, _, reason = permitted()
  return {
    mode = mode, idle = idle, frames = frameCount,
    blocked = (not ok) and reason or nil,
    paused = idle > cfg.idle_seconds,
  }
end

-- 明示的に「今」を撮って即解析する（ホットキー用）
function M.captureNow()
  local ok, _, reason = permitted()
  if not ok then util.notify("画面観測", "この画面は除外対象です（" .. (reason or "") .. "）"); return end
  lastCapture = 0
  lastActivity = os.time()
  capture("manual")
  frameCount = 0
  lastAnalyze = os.time()
  util.run("claude-eye-analyze", {})
  util.notify("画面観測", "今の画面を記録して解析しています")
end

-- macro.lua など他モジュールから除外判定を再利用できるようにする
M.permitted = permitted

return M
