--[[
------------------------------------------------------------------------------------
--  Canarium Air RPC Server                                                       --
------------------------------------------------------------------------------------
@author Shun OSAFUNE <s.osafune@j7system.jp>
@copyright The MIT License (MIT); (c) 2017 J-7SYSTEM WORKS LIMITED

  *Version release
    v0.1.1121   s.osafune@j7system.jp

  *Requirement FlashAir firmware version
    W4.00.01

  *Requirement Canarium Air version
    v0.1.1120 or later

--]]

require "/lua/canarium_air"
require "/lua/canarium_rpc"
--_dbg_print = function(...) print(...) end

do
  _dbg_print("HTTP/1.1 200 OK\n\n*** Canarium RPC test mode ***\n")
  
  -- test query

  -- CHECK : EjQBj48
  -- CONF : EjQTtIBob3N0dGVzdF9vbGl2ZS5yYmY
  -- IORD : EjQG9xFVEAAAAA
  -- IOWR : EjQKVRBVEAABAAEAAAA
  -- MEMWR : EjRG1hhVEAAAAD8-PTw7Ojk4NzY1NDMyMTAvLi0sKyopKCcmJSQjIiEgHx4dHBsaGRgXFhUUExIREA8ODQwLCgkIBwYFBAMCAQA
  -- MEMRD : EjQImxlVEAAAAABA
  -- LOAD : EjQZuSJVMAAAAC9sdWEvcGFjcm9tX29yZy5oZXg
  -- BLOAD : EjQUYyBVMAAAAHBhY3JvbV9vcmcuaGV4
  -- BSAVE : EjQgWSFVMAAAAAABOAAvbHVhL2JpbnNhdmVfaW1hZ2UuYmlu

  local query = arg[1]
  --if not query then query = q end

  print("HTTP/1.1 200 OK\nConnection: close\nContent-Type: application/json")

  local res,id,mes,ecode = parse_command(query)

  local json_str
  if res then
    json_str = cjson.encode{jsonrpc="2.0", result=res, id=id}
  else
    json_str = cjson.encode{jsonrpc="2.0", error={code=ecode, message=mes}, id=id}
  end

  print("Content-Length: "..#json_str.."\n\n"..json_str)
end
