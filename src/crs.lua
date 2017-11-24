--[[
------------------------------------------------------------------------------------
--  Canarium RPC Server                                                           --
------------------------------------------------------------------------------------
@author Shun OSAFUNE <s.osafune@j7system.jp>
@copyright The MIT License (MIT); (c) 2017 J-7SYSTEM WORKS LIMITED

  *Version release
    v0.1.1124   s.osafune@j7system.jp

  *Requirement FlashAir firmware version
    W4.00.01

  *Requirement Canarium Air version
    v0.1.1120 or later

--]]

-- 格納したフォルダに修正
require "/lua/canarium_air"
require "/lua/canarium_rpc"

-- カレントフォルダをルート以外にする場合に追加
--cr.setpath("/foo/bar")

do
  print("HTTP/1.1 200 OK\nAccess-Control-Allow-Origin: *\nContent-Type: application/json; charset=utf-8")

  local json_str = cr.parse(arg[1])

  print("Content-Length: "..#json_str.."\n\n"..json_str)
end
