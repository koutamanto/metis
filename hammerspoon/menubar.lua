-- ═════════════════════════════════════════════════════════════════════════════
--  メニューバー制御 — Metis（拡張人工知能インターフェイス）の状態表示と呼び出し口
--  「今どのモードで動いているか」が常に見える状態を保つのが目的。
-- ═════════════════════════════════════════════════════════════════════════════
local util  = require("util")
local eye   = require("eye")
local mind  = require("mind")
local hud   = require("hud")
local macro      = require("macro")
local shot       = require("shot")
local metis      = require("metis")
local interactor = require("interactor")
local cheatsheet = require("cheatsheet")
local M = {}

local bar
local ICON = { safe = "◉", direct = "◎", off = "○" }
local NAME = { safe = "セーフ", direct = "ダイレクト", off = "停止" }

local function voiceEnabled()
  local ok, d = pcall(hs.json.read, os.getenv("HOME") .. "/.claude/voice-config.json")
  return (ok and d and d.enabled) and true or false
end

local function setVoice(on)
  local path = os.getenv("HOME") .. "/.claude/voice-config.json"
  local ok, d = pcall(hs.json.read, path)
  d = (ok and d) or {}
  d.enabled = on
  pcall(hs.json.write, d, path, true, true)
  util.notify("読み上げ", on and "有効にしました" or "無効にしました")
end

local function refreshTitle()
  if not bar then return end
  local st = eye.status()
  local mark = ICON[st.mode] or "?"
  if st.blocked then mark = mark .. "✕"          -- 除外対象を見ている
  elseif st.paused then mark = mark .. "·" end   -- 無操作で一時停止中
  bar:setTitle(mark)
end

local function menu()
  local st = eye.status()
  local detail
  if st.mode == "off" then          detail = "停止中"
  elseif st.blocked then            detail = "撮影しません — " .. st.blocked
  elseif st.paused then             detail = string.format("無操作 %d 秒 — 一時停止中", st.idle)
  else                              detail = string.format("観測中（未解析 %d 枚）", st.frames) end

  return {
    { title = "Metis", disabled = true },
    { title = detail, disabled = true },
    { title = "-" },
    { title = "Metis パネルを開く         ⌘⌥Q", fn = function() metis.toggle() end },
    { title = "Quick Action Interactor    ⌘⌥I", fn = function() interactor.toggle() end },
    { title = "今のセッションから枝分かれ  ⌘⌥F", fn = function() util.run("claude-fork-here", {}) end },
    { title = "-" },
    { title = "セーフモード（フォーカス中のウィンドウのみ）",
      checked = st.mode == "safe",   fn = function() eye.setMode("safe") end },
    { title = "ダイレクトモード（全画面）",
      checked = st.mode == "direct", fn = function() eye.setMode("direct") end },
    { title = "観測を停止",
      checked = st.mode == "off",    fn = function() eye.setMode("off") end },
    { title = "-" },
    { title = "今の画面を記録して解析    ⌘⌥C", fn = function() eye.captureNow() end },
    { title = "画面の指示を読み取って実行  ⌘⌥X", fn = function() macro.run() end },
    { title = "Shot（画面を撮って質問）    ⌘⌥V", fn = function() shot.run() end },
    { title = "脳内ステートを開く        ⌘⌥M", fn = function() mind.toggle() end },
    { title = "メモを追加                ⌘⌥N", fn = function() mind.note() end },
    { title = "-" },
    { title = "セッション HUD の表示切替  ⌘⌥H", fn = function() hud.toggle() end },
    { title = "読み上げ", checked = voiceEnabled(),
      fn = function() setVoice(not voiceEnabled()) end },
    { title = "読み上げを今すぐ止める     ⌘⌥.", fn = function() util.run("claude-shush", {}) end },
    { title = "-" },
    { title = "撮影済みフレームを今すぐ消す", fn = function()
        util.run("claude-eye-purge", {}, function()
          util.notify("画面観測", "保存済みのフレームを削除しました")
        end)
      end },
    { title = "ショートカット早見表        ⌘⌥/", fn = function() cheatsheet.toggle() end },
    { title = "設定を再読み込み           ⌘⌥⌃R", fn = function() hs.reload() end },
  }
end

function M.start()
  if bar then bar:delete() end
  bar = hs.menubar.new()
  bar:setMenu(menu)
  refreshTitle()
  hs.timer.doEvery(5, refreshTitle)
  eye.onChange = refreshTitle
end

return M
