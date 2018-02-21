--[[
------------------------------------------------------------------------------------
--  Canarium Air RPC Server module                                                --
------------------------------------------------------------------------------------
  @author Shun OSAFUNE <s.osafune@j7system.jp>
  @copyright The MIT License (MIT); (c) 2017,2018 J-7SYSTEM WORKS LIMITED.

  *Version release
    v0.2.0221   s.osafune@j7system.jp

  *Requirement FlashAir firmware version
    W4.00.01+

  *Requirement Canarium Air version
    v0.2.0101 or later

------------------------------------------------------------------------------------
-- The MIT License (MIT)
-- Copyright (c) 2017,2018 J-7SYSTEM WORKS LIMITED.
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of
-- this software and associated documentation files (the "Software"), to deal in
-- the Software without restriction, including without limitation the rights to
-- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
-- of the Software, and to permit persons to whom the Software is furnished to do
-- so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
------------------------------------------------------------------------------------
--]]

-- 外部モジュール
local lines = require "io".lines
local band = require "bit32".band
local bor = require "bit32".bor
local bxor = require "bit32".bxor
local lshift = require "bit32".lshift
local extract = require "bit32".extract
local btest = require "bit32".btest
local schar = require "string".char
local sform = require "string".format
local concat = require "table".concat
local rand = require "math".random
local shdmem = require "fa".sharedmemory
local sdioreg = require "fa".ReadStatusReg
local jsonenc = require "cjson".encode

-- モジュールオブジェクト
cr = {}

-- バージョン
function cr.version() return "0.2.0219" end

-- デバッグ表示メソッド（必要があれば外部で定義する）
function cr.dbgprint(...) end


------------------------------------------------------------------------------------
-- Base64url function (RFC4648)
------------------------------------------------------------------------------------

-- Base64urlへエンコード
local b64table = {
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P',
    'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f',
    'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v',
    'w', 'x', 'y', 'z', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '-', '_'}

function cr.b64enc(d)
  local b64str = {}
  local n = 1
  local m = #d % 3

  while n+2 <= #d do
    local b0,b1,b2 = d:byte(n, n+2)
    local chunk = bor(lshift(b0, 16), lshift(b1, 8), b2)
    b64str[#b64str + 1] = b64table[extract(chunk, 18, 6) + 1] .. b64table[extract(chunk, 12, 6) + 1]
      .. b64table[extract(chunk, 6, 6) + 1] .. b64table[extract(chunk, 0, 6) + 1]

    n = n + 3
  end

  if m == 2 then
    local b0,b1 = d:byte(n, n+1)
    local chunk = bor(lshift(b0, 16), lshift(b1, 8))
    b64str[#b64str + 1] = b64table[extract(chunk, 18, 6) + 1] .. b64table[extract(chunk, 12, 6) + 1]
      .. b64table[extract(chunk, 6, 6) + 1]
  elseif m == 1 then
    local b0 = d:byte(n)
    local chunk = lshift(b0, 16)
    b64str[#b64str + 1] = b64table[extract(chunk, 18, 6) + 1] .. b64table[extract(chunk, 12, 6) + 1]
  end

  return concat(b64str)
end


-- Base64urlをデコード
local rb64table = {
          nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
     nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
     nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,0x3e, nil, nil,
    0x34,0x35,0x36,0x37,0x38,0x39,0x3a,0x3b,0x3c,0x3d, nil, nil, nil,0x00, nil, nil,
     nil,0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0a,0x0b,0x0c,0x0d,0x0e,
    0x0f,0x10,0x11,0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19, nil, nil, nil, nil,0x3f,
     nil,0x1a,0x1b,0x1c,0x1d,0x1e,0x1f,0x20,0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,
    0x29,0x2a,0x2b,0x2c,0x2d,0x2e,0x2f,0x30,0x31,0x32,0x33, nil, nil, nil, nil, nil}

function cr.b64dec(s)
  s = s:gsub("%s+", "")
  local m = #s % 4
  if m == 2 then
    s = s .. "=="
  elseif m == 3 then
    s = s .. "="
  elseif m == 1 then
    return nil,"input data shortage"
  end

  local data = {}
  local n = 1
  local e = true

  while n+3 <= #s do
    local b0,b1,b2,b3 = s:byte(n, n+3)
    local c0 = rb64table[b0]
    local c1 = rb64table[b1]
    local c2 = rb64table[b2]
    local c3 = rb64table[b3]
    if not(c0 and c1 and c2 and c3) then e = false; break end

    local chunk = bor(lshift(c0, 18), lshift(c1, 12), lshift(c2, 6), c3)
    if b2 == 0x3d then
      if b3 ~= 0x3d then e = false; break end
      data[#data + 1] = schar(extract(chunk, 16, 8))
      break
    elseif b3 == 0x3d then
      data[#data + 1] = schar(extract(chunk, 16, 8), extract(chunk, 8, 8))
      break
    else
      data[#data + 1] = schar(extract(chunk, 16, 8), extract(chunk, 8, 8), extract(chunk, 0, 8))
    end

    n = n + 4
  end

  if not e then return nil,"invalid character" end
  return concat(data)
end


------------------------------------------------------------------------------------
-- Canarium RPC local function
------------------------------------------------------------------------------------

-- 進捗表示処理（ファンクションの待避とヘッダ部の設定）
local prog_func,prog_txt = nil,""
local smem_begin = 512    -- 進捗情報を書き込む先頭バイト位置
local smem_length = 100   -- 進捗情報取得サイズ

local _setprog = function(key, id, cmd)
  if not key then
    if prog_func then
      ca.progress = prog_func
      prog_func = nil
      shdmem("write", smem_begin, 1, "\x00")
    end
  else
    if not prog_func then
      prog_txt = sform('{"key":%d,"id":%d,"cmd":%d,"progress":[', key, id, cmd)
      prog_func = ca.progress
    end
  end
end

local _update = function(f, ...) cr.update(...) end

-- カレントファイルパス変換
local ena_abspath = false;
local cur_path = arg[0]:match(".+/")

local _getpath = function(fn)
  if fn:sub(1, 1) ~= "/" then
    if fn:sub(1, 2) == "./" then fn = fn:sub(3, -1) end
    fn = cur_path .. fn
  elseif not ena_abspath then
    fn = ""
  end

  return fn
end

-- CONFIG情報取得
local _get_faconfig = function()
  local conf = {}
  for ln in lines("/SD_WLAN/CONFIG") do
    local k,v = ln:match("([^,]+)=([^,]+)%c+")
    if k ~= nil and v ~= nil then conf[k] = v end
  end

  local reg = sdioreg()
  conf["MAC_ADDRESS"] = reg:sub((0x530 - 0x500) * 2 + 1, (0x530 - 0x500 + 6) * 2)

  return conf;
end

-- バイト列から32bitワードを取得
local _get_word32 = function(s, n)
  return bor(lshift(s:byte(n, n), 24), lshift(s:byte(n+1, n+1), 16), lshift(s:byte(n+2, n+2), 8), s:byte(n+3, n+3))
end

-- バイト列から16bitワードを取得
local _get_word16 = function(s, n)
  return bor(lshift(s:byte(n, n), 8), s:byte(n+1, n+1))
end

-- データのチェックコード生成
local _checkcode = function (d)
  local x = 0
  for i=1,#d do
    x = bxor(d:byte(i), bor(lshift(x, 1), (btest(x, 0x80) and 1 or 0)))
  end
  return band(x, 0xff)
end

-- VERメソッド実行
local _do_version = function()
  local config = _get_faconfig()

  return {
    rpc_version = cr.version(),
    lib_version = ca.version(),
    fa_version = config["VERSION"],
    fa_product = config["PRODUCT"],
    fa_vendor = config["VENDOR"],
    copyright = "(c)2017,2018 J-7SYSTEM WORKS LIMITED."
  }
end

-- CHECKメソッド実行
local _do_check = function(cstr)
  cr.dbgprint("> check")

  return (ca.config() and 1 or 0)
end

-- STATメソッド実行
local _do_status = function(cstr)
  cr.dbgprint("> stat")

  local config = _get_faconfig()

  return {
    current_path = cr.setpath(),
    absolute_access = ena_abspath,
    progjson_begin = smem_begin,
    progjson_length = smem_length,
    file_upload = (config["UPLOAD"] == "1"),
    cid = config["CID"],
    appinfo = config["APPINFO"],
    netname = config["APPNAME"] or "flashair",
    mac_address = config["MAC_ADDRESS"],
    timezone = tonumber(config["TIMEZONE"], 10) or 0
  }
end

-- CONFメソッド実行
local _do_config = function(cstr)
  cr.dbgprint("> config")

  ca.progress = _update

  return ca.config{file = _getpath(cstr:sub(2, -1))}
end

-- FCONFメソッド実行
local _do_fconfig = function(cstr)
  cr.dbgprint("> fconfig")

  ca.progress = _update

  return ca.config{file = _getpath(cstr:sub(2, -1)), cache = false}
end


-- IOWRメソッド実行
local _do_iowr = function(cstr)
  cr.dbgprint("> iowr")

  ca.progress = _update
  ca.progress("", 0)

  local res = nil
  local avm,mes = ca.open{devid = cstr:byte(2, 2)}
  if avm then
    res,mes = avm:iowr(_get_word32(cstr, 3), _get_word32(cstr, 7))
    avm:close()
  end

  if res then ca.progress("", 100) end

  return res,mes
end

-- IORDメソッド実行
local _do_iord = function(cstr)
  cr.dbgprint("> iord")

  ca.progress = _update
  ca.progress("", 0)

  local res = nil
  local avm,mes = ca.open{devid = cstr:byte(2, 2)}
  if avm then
    res,mes = avm:iord(_get_word32(cstr, 3))
    avm:close()
  end

  if res then
    ca.progress("", 100)
    cr.dbgprint(sform(">  data : 0x%08x", res))
  end

  return res,mes
end

-- MEMWRメソッド実行
local _do_memwr = function(cstr)
  cr.dbgprint("> memwr")

  ca.progress = _update
  ca.progress("", 0)

  local res = nil
  local avm,mes = ca.open{devid = cstr:byte(2, 2)}
  if avm then
    res,mes = avm:memwr(_get_word32(cstr, 3), cstr:sub(7, -1))
    avm:close()
  end

  if res then ca.progress("", 100) end

  return res,mes
end

-- MEMRDメソッド実行
local _do_memrd = function(cstr)
  cr.dbgprint("> memrd")

  ca.progress = _update
  ca.progress("", 0)

  local res = nil
  local avm,mes = ca.open{devid = cstr:byte(2, 2)}
  if avm then
    res,mes = avm:memrd(_get_word32(cstr, 3), _get_word16(cstr, 7))
    avm:close()
  end

  if res then
    ca.progress("", 100)
    --
    local s = ">  data :"
    for i=1,#res do s = s .. sform(" %02x", res:byte(i)) end
    cr.dbgprint(s.." ("..#res.."bytes)")
    --]]
    res = cr.b64enc(res)
  end

  return res,mes
end


-- BLOADメソッド実行
local _do_bload = function(cstr)
  cr.dbgprint("> bload")

  ca.progress = _update

  local res = nil
  local avm,mes = ca.open{devid = cstr:byte(2, 2)}
  if avm then
    res,mes = avm:bload(_getpath(cstr:sub(7, -1)), _get_word32(cstr, 3))
    avm:close()
  end

  return res,mes
end

-- BSAVEメソッド実行
local _do_bsave = function(cstr)
  cr.dbgprint("> bsave")

  ca.progress = _update

  local res = nil
  local avm,mes = ca.open{devid = cstr:byte(2, 2)}
  if avm then
    res,mes = avm:bsave(_getpath(cstr:sub(11, -1)), _get_word32(cstr, 7), _get_word32(cstr, 3))
    avm:close()
  end

  return res,mes
end

-- LOADメソッド実行
local _do_load = function(cstr)
  cr.dbgprint("> load")

  ca.progress = _update

  local res = nil
  local avm,mes = ca.open{devid = cstr:byte(2, 2)}
  if avm then
    res,mes = avm:load(_getpath(cstr:sub(7, -1)), _get_word32(cstr, 3))
    avm:close()
  end

  return res,mes
end


------------------------------------------------------------------------------------
-- Canarium RPC command parser
------------------------------------------------------------------------------------

-- メソッドテーブルの設定
local method = {
    [0x01] = {func = _do_check, name = "CHECK"},
    [0x02] = {func = _do_status, name = "STAT"},
    [0x08] = {func = _do_config, name = "CONF"},
    [0x09] = {func = _do_fconfig, name = "FCONF"},
    [0x10] = {func = _do_iowr, name = "IOWR"},
    [0x11] = {func = _do_iord, name = "IORD"},
    [0x18] = {func = _do_memwr, name = "MEMWR"},
    [0x19] = {func = _do_memrd, name = "MEMRD"},
    [0x20] = {func = _do_bload, name = "BLOAD"},
    [0x21] = {func = _do_bsave, name = "BSAVE"},
    [0x22] = {func = _do_load, name = "LOAD"}
}
local _no_method = function() return nil,"Method not found",-32601 end
setmetatable(method, {__index = function() return {func = _no_method, name = ""} end})

-- ユーザーメソッドの設定・削除
function cr.setmethod(name, cmd, func)
  local res = false
  local key
  for k,v in pairs(method) do
    if name == v.name then key = k end
  end

  if type(cmd) == "number" and (cmd >= 0x00 and cmd <= 0x7f) and type(func) == "function" then
    if key then method[key] = nil end
    method[cmd] = {func = func, name = name}
    res = true
  elseif type(cmd) == "nil" and key then
    method[key] = nil
    res = true
  end

  return res
end


-- 進捗表示のアップデート
function cr.update(...)
  if not prog_func then return end

  local s = ""
  for i,v in ipairs({...}) do
    if i == 1 then
      s = s .. sform("%d", v)
    else
      s = s .. sform(",%d", v)
    end
  end
  s = prog_txt .. s .. "]}\x00"

  shdmem("write", smem_begin, #s, s)
  if #s > smem_length then smem_length = #s end
  --[[
  local str = shdmem("read", smem_begin, smem_length)
  cr.dbgprint("> shdmem : "..str)
  --]]
end


-- カレントパスの設定
function cr.setpath(path, ena_abs)
  if type(path) == "string" then
    if path:sub(1, 1) ~= "/" then
      if path:sub(1, 2) == "./" then path = path:sub(3, -1) end
      path = cur_path .. path
    end
    if path:sub(-1) ~= "/" then path = path .. "/" end
    cur_path = path

    ena_abspath = (type(ena_abs) == "boolean" and ena_abs) and true or false;    
  end

  return cur_path
end


-- メソッドのパース
function cr.parse(query)
  local _do_method = function(q)
    if not q then return _do_version() end

    local rp = cr.b64dec(q)

    -- query decode error
    if not rp then return nil,nil,"Parse error",-32700 end
    -- query packet error
    if #rp < 5 then return nil,nil,"Parse error",-32700 end

    local id = _get_word16(rp, 1)
    local dlen = rp:byte(3, 3)
    local ckey = rp:byte(4, 4)

    -- query data error
    if not(#rp == dlen+4 and ckey == _checkcode(rp:sub(5, -1))) then return nil,id,"Parse error",-32700 end

    --[[
    local s = "> decode :"
    for i=1,#rp do s = s .. sform(" %02x", rp:byte(i)) end
    cr.dbgprint(s)
    --]]

    -- メソッド実行
    local key = rand(65535)
    local cmd = rp:byte(5, 5)
    local cstr = rp:sub(5, -1)

    _setprog(key, id, cmd)

    local res,mes,ecode = method[cmd].func(cstr)
    ecode = ecnode or -32000

    _setprog()

    if not res then return res,id,mes,ecode end
    return res,id
  end

  -- クエリのパースと実行
  local res,id,mes,ecode = _do_method(query)

  local t = {jsonrpc="2.0", id=id}
  if res then t.result = res else t.error = {code=ecode, message=mes} end

  return jsonenc(t)
end


------------------------------------------------------------------------------------
-- テスト用ファンクション
------------------------------------------------------------------------------------

-- クエリを生成
function cr.makequery(t)
  local _setavm = function(cmd, devid, addr)
    local s = schar(cmd, devid)
    for i=24,0,-8 do s = s .. schar(extract(addr, i, 8)) end
    return s
  end

  local pstr = ""
  local dev = t.devid or 0x55

  local cmd,name
  for k,v in pairs(method) do
    if v.name == t.cmd then
      name = v.name
      cmd = k
    end
  end
  if not name then return nil,"invalid command" end

  if name == "VER" or name == "CHECK" or name == "STAT"then
    pstr = schar(cmd)

  elseif name == "CONF" or name == "FCONF" then
    pstr = schar(cmd) .. t.file

  elseif name == "IOWR" then
    if type(t.data) == "number" then
      pstr = _setavm(cmd, dev, t.addr) ..
        schar(extract(t.data, 24, 8), extract(t.data, 16, 8), extract(t.data, 8, 8), extract(t.data, 0, 8))
    else
      return nil,"invalid parameter"
    end

  elseif name == "IORD" then
    pstr = _setavm(cmd, dev, t.addr)

  elseif name == "MEMWR" then
    if type(t.data) == "string" then
      pstr = _setavm(cmd, dev, t.addr) .. t.data
    else
      return nil,"invalid parameter"
    end

  elseif name == "MEMRD" then
    pstr = _setavm(cmd, dev, t.addr) ..
      schar(extract(t.size, 8, 8), extract(t.size, 0, 8))

  elseif name == "BLOAD" then
    pstr = _setavm(cmd, dev, t.addr) .. t.file

  elseif name == "BSAVE" then
    pstr = _setavm(cmd, dev, t.addr) ..
      schar(extract(t.size, 24, 8), extract(t.size, 16, 8), extract(t.size, 8, 8), extract(t.size, 0, 8)) ..
      t.file

  elseif name == "LOAD" then
    local addr = (type(t.addr) == "number") and t.addr or 0
    pstr = _setavm(cmd, dev, addr) .. t.file

  else
    local param = (type(t.param) == "string") and t.param or ""
    pstr = schar(cmd) .. param

  end

  if #pstr > 70 then return nil,"payload data too long" end

  local res = schar(extract(t.id, 8, 8), extract(t.id, 0, 8), #pstr, _checkcode(pstr)) .. pstr
  --[[
  local s = "packet :"
  for i=1,#res do s = s .. sform(" %02x", res:byte(i)) end
  cr.dbgprint(s)
  --]]
  return cr.b64enc(res)
end


return cr
