-- ═════════════════════════════════════════════════════════════════════════════
--  cheatsheet — GitHub の "?" のような、押した瞬間に中央へ出る早見表
--    ⌘⌥/ で開閉。Esc かクリックで閉じる。
--  この環境は Hammerspoon・Ghostty・tmux・AeroSpace の4層にキーが分散している
--  ため、レイヤーごとに区切って一覧できるようにしてある。
-- ═════════════════════════════════════════════════════════════════════════════
local M = {}

local canvas, escHotkey

local SECTIONS = {
  {
    title = "Hammerspoon — セッション操作",
    rows = {
      { "⌘⌥P", "Claude 専用パネルの出し入れ" },
      { "⌘⌥J",      "次の「待ち」セッションへジャンプ（連打で巡回）" },
      { "⌘⌥F",      "今のセッションから非同期で枝分かれ（フォーカスを奪わない）" },
      { "⌘⌥H",      "セッション HUD の表示切替" },
    },
  },
  {
    title = "Hammerspoon — Quick Action",
    rows = {
      { "⌘⌥A", "選択テキストに即答（Sonnet 5・最速）" },
      { "⌘⌥⇧A", "深掘り（Opus）→ 専用パネルへ" },
      { "⌘⌥S", "コマンド生成 → 確認 → バックグラウンド実行" },
      { "⌘⌥X", "画面の指示を読み取り → 一括確認 → 新規ターミナルで連続実行" },
      { "⌘⌥V", "Shot: 画面を1枚撮って、それを見ながら質問に即答" },
      { "⌘⌥Q", "Metis パネル（Quick Action 結果の一元管理・自動で開閉）" },
      { "⌘⌥I", "Quick Action Interactor（専用TUI・履歴を選んで新セッションへ昇格）" },
    },
  },
  {
    title = "Hammerspoon — 脳内ステート / 画面観測",
    rows = {
      { "⌘⌥M", "今・次にやること・保留・ゴールを読み出す" },
      { "⌘⌥N", "一行メモを追加（分類は自動）" },
      { "⌘⌥C", "今の画面を記録して解析" },
      { "⌘⌥.", "読み上げを即停止" },
      { "⌘⌥/", "このチートシートの表示切替" },
      { "⌘⌥⌃R", "Hammerspoon の設定を再読み込み" },
    },
  },
  {
    title = "Ghostty",
    rows = {
      { "⌘ `",     "クイックターミナル（どのアプリからでも降りてくる）" },
      { "⌘D / ⌘⇧D", "右に分割 / 下に分割" },
      { "⌘⌥矢印",   "分割ペイン間を移動" },
      { "⌘⌃矢印",   "分割ペインをリサイズ" },
      { "⌘⇧Enter", "ペインをズーム" },
      { "⌘⇧F",     "ウィンドウを常に手前に固定" },
      { "⌘T",      "新規タブ" },
      { "⌘K",      "画面クリア" },
    },
  },
  {
    title = "tmux（プレフィックス ⌃A）",
    rows = {
      { "⌃A |  /  ⌃A -", "右に分割 / 下に分割" },
      { "⌃A h j k l",    "ペイン移動" },
      { "⌃A r",          "設定をリロード" },
      { "⌃A [",          "コピーモード（vi キー）" },
    },
  },
  {
    title = "AeroSpace",
    rows = {
      { "⌥1〜4",   "ワークスペース切替（編集/Claude群/ブラウザ/雑用）" },
      { "⌥⇧1〜4", "ウィンドウを別ワークスペースへ送る" },
      { "⌥Tab",   "直前のワークスペースへ戻る" },
      { "⌥H J K L", "フォーカス移動" },
      { "⌥F",      "全画面" },
      { "⌥R",      "リサイズモード（h/j/k/l → Enter）" },
    },
  },
  {
    title = "シェル（cw / cl / cj / cr / cfork）",
    rows = {
      { "cw <パス>",        "プロジェクト用セッションを作って入る" },
      { "cl / cq / cj",     "セッション一覧 / 待ちのみ表示 / 次の待ちへ移動" },
      { "cr <名前> <文>",   "画面を切り替えずに一言送る" },
      { "cfork <名前>",     "今の会話から枝分かれした新セッション" },
    },
  },
}

local C = {
  bg     = { red = 0.05, green = 0.06, blue = 0.11, alpha = 0.97 },
  border = { red = 0.34, green = 0.37, blue = 0.54, alpha = 0.6 },
  head   = { red = 0.97, green = 0.69, blue = 0.41, alpha = 1 },
  key    = { red = 0.48, green = 0.78, blue = 0.97, alpha = 1 },
  desc   = { red = 0.80, green = 0.84, blue = 0.98, alpha = 1 },
  hint   = { red = 0.47, green = 0.51, blue = 0.65, alpha = 1 },
}

local COL_W, ROWH, PAD, TOP = 430, 20, 24, 46

function M.close()
  if canvas then canvas:delete(); canvas = nil end
  if escHotkey then escHotkey:delete(); escHotkey = nil end
end

-- セクションを2列に振り分ける（上から詰めた高さができるだけ均等になるように）
local function splitColumns()
  local heights = { 0, 0 }
  local cols = { {}, {} }
  for _, sec in ipairs(SECTIONS) do
    local h = 26 + #sec.rows * ROWH + 12
    local target = (heights[1] <= heights[2]) and 1 or 2
    table.insert(cols[target], sec)
    heights[target] = heights[target] + h
  end
  return cols, math.max(heights[1], heights[2])
end

local function drawColumnAt(x, sections, yOffset)
  local y = yOffset
  for _, sec in ipairs(sections) do
    canvas[#canvas + 1] = {
      type = "text", text = sec.title, textColor = C.head, textSize = 13,
      textFont = "HelveticaNeue-Bold", frame = { x = x, y = y, w = COL_W, h = 20 },
    }
    y = y + 26
    for _, row in ipairs(sec.rows) do
      canvas[#canvas + 1] = {
        type = "text", text = row[1], textColor = C.key, textSize = 12,
        textFont = "Menlo", frame = { x = x, y = y, w = 130, h = ROWH },
      }
      canvas[#canvas + 1] = {
        type = "text", text = row[2], textColor = C.desc, textSize = 12,
        textFont = "HelveticaNeue", frame = { x = x + 136, y = y, w = COL_W - 136, h = ROWH },
      }
      y = y + ROWH
    end
    y = y + 12
  end
end

local function draw()
  M.close()
  local sf = hs.screen.mainScreen():frame()
  local cols, colH = splitColumns()
  local w = PAD * 3 + COL_W * 2
  local h = math.min(colH + PAD + TOP + 24, sf.h - 60)

  canvas = hs.canvas.new({ x = sf.x + (sf.w - w) / 2, y = sf.y + (sf.h - h) / 2, w = w, h = h })
  canvas[1] = { type = "rectangle", action = "fill", fillColor = C.bg,
                roundedRectRadii = { xRadius = 16, yRadius = 16 } }
  canvas[2] = { type = "rectangle", action = "stroke", strokeColor = C.border,
                strokeWidth = 1, roundedRectRadii = { xRadius = 16, yRadius = 16 } }
  canvas[3] = {
    type = "text", text = "ショートカット早見表", textColor = C.desc, textSize = 16,
    textFont = "HelveticaNeue-Bold", frame = { x = PAD, y = 14, w = w - PAD * 2, h = 22 },
  }

  drawColumnAt(PAD, cols[1], TOP)
  drawColumnAt(PAD * 2 + COL_W, cols[2], TOP)

  canvas[#canvas + 1] = {
    type = "text", text = "Esc または外側クリックで閉じる", textColor = C.hint, textSize = 10,
    textFont = "HelveticaNeue", frame = { x = PAD, y = h - 22, w = w - PAD * 2, h = 16 },
  }

  canvas:level(hs.canvas.windowLevels.modalPanel)
  canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
  canvas:clickActivating(false)
  canvas:mouseCallback(function() M.close() end)
  canvas:canvasMouseEvents(true, false, false, false)
  canvas:show(0.08)

  escHotkey = hs.hotkey.bind({}, "escape", M.close)
end

function M.toggle()
  if canvas then M.close(); return end
  draw()
end

return M
