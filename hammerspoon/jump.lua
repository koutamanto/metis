-- 次の「待ち」セッションへジャンプする（連打で巡回）
local util = require("util")
local M = {}

function M.nextWaiting()
  util.run("claude-jump", { "--next-waiting" }, function(code, out, err)
    if code ~= 0 then
      util.notify("Claude", "待ち状態のセッションはありません")
    else
      local app = hs.application.get("com.mitchellh.ghostty")
      if app then app:activate() end
    end
  end)
end

return M
