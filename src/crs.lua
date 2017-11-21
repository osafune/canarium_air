--[[
------------------------------------------------------------------------------------
--  Canarium RPC Server                                                           --
------------------------------------------------------------------------------------
@author Shun OSAFUNE <s.osafune@j7system.jp>
@copyright The MIT License (MIT); (c) 2017 J-7SYSTEM WORKS LIMITED

  *Version release
    v0.1.1122   s.osafune@j7system.jp

  *Requirement FlashAir firmware version
    W4.00.01

  *Requirement Canarium Air version
    v0.1.1120 or later

--]]

require "/lua/canarium_air"
require "/lua/canarium_rpc"

do
  -- test query
  -- CHECK : EjQBj48
  -- CONF : MDkTtIBob3N0dGVzdF9vbGl2ZS5yYmY
  -- IORD : MDkG9xFVEAAAAA
  -- IOWR : MDkKfBBVEAAAAAAAAAE
  -- MEMWR : EjRG1hhVEAAAAD8-PTw7Ojk4NzY1NDMyMTAvLi0sKyopKCcmJSQjIiEgHx4dHBsaGRgXFhUUExIREA8ODQwLCgkIBwYFBAMCAQA
  -- MEMRD : MDkImxlVEAAAAABA
  -- LOAD : EjQZuSJVMAAAAC9sdWEvcGFjcm9tX29yZy5oZXg
  -- BLOAD : EjQUYyBVMAAAAHBhY3JvbV9vcmcuaGV4
  -- BSAVE : EjQgWSFVMAAAAAABOAAvbHVhL2JpbnNhdmVfaW1hZ2UuYmlu

  print("HTTP/1.1 200 OK\nConnection: close\nContent-Type: application/json; charset=utf-8")
  local json_str = cr.parse(arg[1])

  print("Content-Length: "..#json_str.."\n\n"..json_str)
end
