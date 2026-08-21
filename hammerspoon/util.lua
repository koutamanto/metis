-- 共通ユーティリティ: ~/.claude/bin のスクリプトを非同期で叩く
local M = {}

M.BIN = os.getenv("HOME") .. "/.claude/bin"

-- スクリプトを非同期実行する。cb(exitCode, stdout, stderr) は省略可。
function M.run(script, args, cb)
  local t = hs.task.new(M.BIN .. "/" .. script, cb, args or {})
  if t then t:start() end
  return t
end

-- 標準出力を文字列で受け取りたいとき用
function M.capture(script, args, cb)
  return M.run(script, args, function(code, out, err)
    cb(out or "", code, err)
  end)
end

function M.notify(title, text)
  hs.notify.new({ title = title, informativeText = text, withdrawAfter = 5 }):send()
end

return M
