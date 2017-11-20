--[[
------------------------------------------------------------------------------------
--  Canarium Air RPC Server module                                                --
------------------------------------------------------------------------------------
  @author Shun OSAFUNE <s.osafune@j7system.jp>
  @copyright The MIT License (MIT); (c) 2017 J-7SYSTEM WORKS LIMITED

  *Version release
    v0.1.1120   s.osafune@j7system.jp

  *Requirement FlashAir firmware version
    W4.00.01

  *Requirement Canarium Air version
    v0.1.1120 or later

------------------------------------------------------------------------------------
-- The MIT License (MIT)
-- Copyright (c) 2017 J-7SYSTEM WORKS LIMITED
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

-- 外部メソッドショートカット
local band = require "bit32".band
local bor = require "bit32".bor
local bxor = require "bit32".bxor
local lshift = require "bit32".lshift
local extract = require "bit32".extract
local btest = require "bit32".btest
local schar = require "string".char
local sform = require "string".format


------------------------------------------------------------------------------------
-- テスト用ファンクション
------------------------------------------------------------------------------------

-- クエリを生成
function makequery(t)
  local _setavm = function(cmd, devid, addr)
    local s = schar(cmd, devid)
    for i=24,0,-8 do s = s .. schar(extract(addr, i, 8)) end
    return s
  end
  
  local pstr = ""
  local dev = t.devid or 0x55
  
  if t.cmd == "CONF" then
    pstr = schar(0x80) .. t.file

  elseif t.cmd == "FCONF" then
    pstr = schar(0x81) .. t.file

  elseif t.cmd == "CHECK" then
    pstr = schar(0x8f)

  elseif t.cmd == "IOWR" then
    if type(t.data) == "number" then
      pstr = _setavm(0x10, dev, t.addr) ..
        schar(extract(t.data, 0, 8), extract(t.data, 8, 8), extract(t.data, 16, 8), extract(t.data, 24, 8))
    else
      return nil,"invalid parameter"
    end
  
  elseif t.cmd == "IORD" then         
    pstr = _setavm(0x11, dev, t.addr)
  
  elseif t.cmd == "MEMWR" then
    if type(t.data) == "string" then
      pstr = _setavm(0x18, dev, t.addr) .. t.data
    else
      return nil,"invalid parameter"
    end
  
  elseif t.cmd == "MEMRD" then
    pstr = _setavm(0x19, dev, t.addr) ..
      schar(extract(t.size, 8, 8), extract(t.size, 0, 8))
  
  elseif t.cmd == "BLOAD" then
    pstr = _setavm(0x20, dev, t.addr) .. t.file
  
  elseif t.cmd == "BSAVE" then
    pstr = _setavm(0x21, dev, t.addr) .. 
      schar(extract(t.size, 24, 8), extract(t.size, 16, 8), extract(t.size, 8, 8), extract(t.size, 0, 8)) ..
      t.file
  
  elseif t.cmd == "LOAD" then
    pstr = _setavm(0x22, dev, t.addr) .. t.file
  
  else
    return nil,"invalid command"
  end
  
  if #pstr > 70 then return nil,"payload data too long" end
  
  local res = schar(extract(t.id, 8, 8), extract(t.id, 0, 8), #pstr, checkcode(pstr)) .. pstr
  --
  local s = "packet :"
  for _,b in ipairs{res:byte(1, -1)} do s = s .. string.format(" %02x",b) end
  print(s)
  --]]
  return b64enc(res)
end


------------------------------------------------------------------------------------
-- Base64url function (RFC4648)
------------------------------------------------------------------------------------

-- Base64urlへエンコード
local b64table = {
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P',
    'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f',
    'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v',
    'w', 'x', 'y', 'z', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '-', '_'}

function b64enc(d)
  local b64str = ""
  local n = 1
  local m = #d % 3

  while n+2 <= #d do
    local b0,b1,b2 = d:byte(n, n+2)
    local chunk = bor(lshift(b0, 16), lshift(b1, 8), b2)
    b64str = b64str .. b64table[extract(chunk, 18, 6) + 1] .. b64table[extract(chunk, 12, 6) + 1]
      .. b64table[extract(chunk, 6, 6) + 1] .. b64table[extract(chunk, 0, 6) + 1]

    n = n + 3
  end

  if m == 2 then
    local b0,b1 = d:byte(n, n+1)
    local chunk = bor(lshift(b0, 16), lshift(b1, 8))
    b64str = b64str .. b64table[extract(chunk, 18, 6) + 1] .. b64table[extract(chunk, 12, 6) + 1]
        .. b64table[extract(chunk, 6, 6) + 1]
  elseif m == 1 then
    local b0 = d:byte(n)
    local chunk = lshift(b0, 16)
    b64str = b64str .. b64table[extract(chunk, 18, 6) + 1] .. b64table[extract(chunk, 12, 6) + 1]
  end

  return b64str
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

function b64dec(s)
  local data = ""
  local n = 1
  local e = true
  
  s = s:gsub("%s+", "")
  local m = #s % 4
  if m == 2 then
    s = s .. "=="
  elseif m == 3 then
    s = s .. "="
  elseif m == 1 then
    return nil,"input data shortage"
  end

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
      data = data .. schar(extract(chunk, 16, 8))
      break
    elseif b3 == 0x3d then
      data = data .. schar(extract(chunk, 16, 8), extract(chunk, 8, 8))
      break
    else
      data = data .. schar(extract(chunk, 16, 8), extract(chunk, 8, 8), extract(chunk, 0, 8))
    end

    n = n + 4
  end

  if not e then return nil,"invalid character" end
  return data
end


------------------------------------------------------------------------------------
-- Canarium RPC function
------------------------------------------------------------------------------------

-- 共有メモリ書き込み
local shdmem = function(dstr)
  fa.sharedmemory("write", 256, #dstr+1, dstr.."\x00")
  --[[
  local str = fa.sharedmemory("read", 256, 100)
  print("json -> "..str)
  --]]
end

-- 進捗表示処理（ファンクションの待避とヘッダ部の設定）
local prog_func,prog_txt = nil,""

function setprog(key, id, cmd)
  if not key then
    if prog_func then
      ca.progress = prog_func
      prog_func = nil
      shdmem("")
    end
  else
    if not prog_func then
      prog_txt = sform('{"key":%5d,"id":%5d,"command":%3d,"progress":[', key, id, cmd)
      prog_func = ca.progress
    end
  end
end

-- データのチェックコード生成
function checkcode(d)
  local x = 0
  for _,b in ipairs{d:byte(1, -1)} do
    x = bxor(b, bor(lshift(x, 1), (btest(x, 0x80) and 1 or 0)))
  end

  return band(x, 0xff)
end


-- CONFコマンド、FCONFコマンド実行
function do_config(cstr)
  ca.progress = function(f, p1, p2)
    shdmem(prog_txt..sform("%3d,%3d]}", p1, p2))
  end

  return ca.config{
      file = cstr:sub(2, -1),
      cache = (cstr:byte(1, 1) == 0x80)
    }
end


-- IOWRコマンド実行
function do_iowr(cstr)
  ca.progress = function(f, p1)
    shdmem(prog_txt..sform("%3d]}", p1))
  end

  ca.progress("", 0)

  local res = nil
  local avm,mes = ca.open{devid = cstr:byte(2, 2)}
  if avm then
    res,mes = avm:iowr(
      bor(lshift(cstr:byte(3, 3), 24), lshift(cstr:byte(4, 4), 16), lshift(cstr:byte(5, 5), 8), cstr:byte(6, 6)),
      bor(lshift(cstr:byte(10, 10), 24), lshift(cstr:byte(9, 9), 16), lshift(cstr:byte(8, 8), 8), cstr:byte(7, 7))
    )
    avm:close()
  end

  if res then ca.progress("", 100) end
    
  return res,mes
end


-- IORDコマンド実行
function do_iord(cstr)
  ca.progress = function(f, p1)
    shdmem(prog_txt..sform("%3d]}", p1))
  end

  ca.progress("", 0)

  local res = nil
  local avm,mes = ca.open{devid = cstr:byte(2, 2)}
  if avm then
    res,mes = avm:iord(
      bor(lshift(cstr:byte(3, 3), 24), lshift(cstr:byte(4, 4), 16), lshift(cstr:byte(5, 5), 8), cstr:byte(6, 6))
    )
    avm:close()
  end

  if res then ca.progress("", 100) end
    
  return res,mes
end


-- MEMWRコマンド実行
function do_memwr(cstr)
  ca.progress = function(f, p1)
    shdmem(prog_txt..sform("%3d]}", p1))
  end

  ca.progress("", 0)

  local res = nil
  local avm,mes = ca.open{devid = cstr:byte(2, 2)}
  if avm then
    res,mes = avm:memwr(
      bor(lshift(cstr:byte(3, 3), 24), lshift(cstr:byte(4, 4), 16), lshift(cstr:byte(5, 5), 8), cstr:byte(6, 6)),
      cstr:sub(7, -1)
    )
    avm:close()
  end

  if res then ca.progress("", 100) end
    
  return res,mes
end


-- MEMRDコマンド実行
function do_memrd(cstr)
  ca.progress = function(f, p1)
    shdmem(prog_txt..sform("%3d]}", p1))
  end

  ca.progress("", 0)

  local res = nil
  local avm,mes = ca.open{devid = cstr:byte(2, 2)}
  if avm then
    res,mes = avm:memrd(
      bor(lshift(cstr:byte(3, 3), 24), lshift(cstr:byte(4, 4), 16), lshift(cstr:byte(5, 5), 8), cstr:byte(6, 6)),
      bor(lshift(cstr:byte(7, 7), 8), cstr:byte(8, 8))
    )
    avm:close()
  end

  if res then ca.progress("", 100) end
    
  return res,mes
end


-- BLOADコマンド実行
function do_bload(cstr)
  ca.progress = function(f, p1)
    shdmem(prog_txt..sform("%3d]}", p1))
  end

  local res = nil
  local avm,mes = ca.open{devid = cstr:byte(2, 2)}
  if avm then
    res,mes = avm:bload(
      cstr:sub(7, -1),
      bor(lshift(cstr:byte(3, 3), 24), lshift(cstr:byte(4, 4), 16), lshift(cstr:byte(5, 5), 8), cstr:byte(6, 6))
    )
    avm:close()
  end

  return res,mes
end


-- BSAVEコマンド実行
function do_bsave(cstr)
  ca.progress = function(f, p1)
    shdmem(prog_txt..sform("%3d]}", p1))
  end

  local res = nil
  local avm,mes = ca.open{devid = cstr:byte(2, 2)}
  if avm then
    res,mes = avm:bsave(
      cstr:sub(11, -1),
      bor(lshift(cstr:byte(7, 7), 24), lshift(cstr:byte(8, 8), 16), lshift(cstr:byte(9, 9), 8), cstr:byte(10, 10)),
      bor(lshift(cstr:byte(3, 3), 24), lshift(cstr:byte(4, 4), 16), lshift(cstr:byte(5, 5), 8), cstr:byte(6, 6))
    )
    avm:close()
  end

  return res,mes
end


-- LOADコマンド実行
function do_load(cstr)
  ca.progress = function(f, p1)
    shdmem(prog_txt..sform("%3d]}", p1))
  end

  local res = nil
  local avm,mes = ca.open{devid = cstr:byte(2, 2)}
  if avm then
    res,mes = avm:load(
      cstr:sub(7, -1),
      bor(lshift(cstr:byte(3, 3), 24), lshift(cstr:byte(4, 4), 16), lshift(cstr:byte(5, 5), 8), cstr:byte(6, 6))
    )
    avm:close()
  end

  return res,mes
end

