--[[
------------------------------------------------------------------------------------
--  Canarium Air                                                                  --
--    PERIDOT-AIR configuration & Avalon-MM access library                        --
------------------------------------------------------------------------------------
  @author Shun OSAFUNE <s.osafune@j7system.jp>
  @copyright The MIT License (MIT); (c) 2017 J-7SYSTEM WORKS LIMITED

  *Version release
    v0.1.1120   s.osafune@j7system.jp

  *Requirement FlashAir firmware version
    W4.00.01

  *FlashAir I/O connection
    CMD  <---> DATA0(SCL)
    DAT0 <-+-> DCLK
           +--> USER I/O(SDA)
    DAT1 ----> nCONFIG
    DAT2 <---- nSTATUS
    DAT3 <---- CONF_DONE

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

-- 外部モジュール
local pio = require "fa".pio
local spi = require "fa".spi
local i2c = require "fa".i2c
local remove = require "fa".remove
local open = require "io".open
local schar = require "string".char
local btest = require "bit32".btest
local bor = require "bit32".bor
local extract = require "bit32".extract
local lshift = require "bit32".lshift

-- モジュールオブジェクト
ca = {}

-- バージョン
function ca.version() return "0.1.1120" end

-- 進捗表示（必要な場合は外部で定義する）
function ca.progress(funcname, ...) end

-- fa.i2cの正常レスポンス
local _r_OK = "OK\n" --<Measures for W4.00.01>--

------------------------------------------------------------------------------------
-- AvalonMMバスアクセス
------------------------------------------------------------------------------------
-- avmオブジェクトの内容
--   avm.devid : デバイスID
--   avm.i2cfreq : I2Cの通信速度
--   avm.rdsplit : memrdのバースト長
--   avm.wrsplit : memwrのバースト長
--   avm.addrbst : アドレスバイト開始位置(24,16,8,0)
--   avm.close() : クローズメソッド
--   avm.iord() : I/Oリードメソッド
--   avm.iowr() : I/Oライトメソッド
--   avm.memrd() : メモリリードメソッド
--   avm.memwr() : メモリライトメソッド

-- デバイスリソーステーブル
local _devindex = {}

-- I2Cバスオープン：共通
local _busopen = function(avm)
  return (_devindex[avm.devid] and i2c{mode="init", freq=avm.i2cfreq} == _r_OK)
end

-- I2Cデバイスオープン：共通
local _devopen = function(avm, addr)
  local res = i2c{mode="start", address=avm.devid, direction="write"}
  if res ~= _r_OK then
    i2c{mode="stop"}
    return false,"device start error / "..res
  end

  res = true
  local t = {mode="write", data=0}
  for i=avm.addrbst,0,-8 do
    t.data = extract(addr, i, 8)
    if i2c(t) ~= _r_OK then res = false; break end
  end
  if not res then
    i2c{mode="stop"}
    return false,"address write error"
  end

  return true
end

-- AVMデバイスクローズメソッド
local _avm_close = function(self)
  _devindex[self.devid] = nil
  return true
end

-- AvalonMM I/Oリードメソッド
local _avm_iord = function(self, addr)
  if not _busopen(self) then return nil,"device is not open" end
  if type(addr) ~= "number" then return nil,"parameter error" end
  if btest(addr, 0x3) then return nil,"invalid addressing" end

  local res,mes = _devopen(self, addr)
  if not res then return nil,mes end

  if i2c{mode="restart", address=self.devid, direction="read"} ~= _r_OK then
    i2c{mode="stop"}
    return nil,"device restart error"
  end

  local res,b0,b1,b2,b3 = i2c{mode="read", bytes=4, type="binary"}
  i2c{mode="stop"}
  if res ~= _r_OK then return nil,"I/O read error" end

  return bor(lshift(b3, 24), lshift(b2, 16), lshift(b1, 8), b0)
end

-- AvalonMM I/Oライトメソッド
local _avm_iowr = function(self, addr, wdat)
  if not _busopen(self) then return nil,"device is not open" end
  if type(addr) ~= "number" or type(wdat) ~= "number" then return nil,"parameter error" end
  if btest(addr, 0x3) then return nil,"invalid addressing" end

  local res,mes = _devopen(self, addr)
  if not res then return nil,mes end

  local t = {mode="write", data=0}
  for i=0,24,8 do  --<Measures for W4.00.01>--
    t.data = extract(wdat, i, 8)
    if i2c(t) ~= _r_OK then res = false; break end
  end
  i2c{mode="stop"}
  if not res then return nil,"I/O write error" end

  return true
end

-- AvalonMM メモリリードメソッド
local _avm_memrd = function(self, addr, size)
  if not _busopen(self) then return nil,"device is not open" end
  if type(addr) ~= "number" or type(size) ~= "number" then return nil,"parameter error" end
  if size < 1 then return "" end

  local t_stop = {mode="stop"}
  local t_read = {mode="read", bytes=0, type="binary"}
  local _strread = function(r, ...)
    i2c(t_stop)
    if r ~= _r_OK then return nil,"memory read error" end
    return schar(...)
  end

  local res,mes = _devopen(self, addr)
  if not res then return nil,mes end
  i2c(t_stop)

  local rstr = ""

  while size > 0 do
    if i2c{mode="start", address=self.devid, direction="read"} ~= _r_OK then
      i2c(t_stop)
      res,mes = nil,"device current start error"
      break
    end

    local len = size
    if len > self.rdsplit then len = self.rdsplit end
    t_read.bytes = len
    res,mes = _strread(i2c(t_read)) --<Measures for W4.00.01>--
    if not res then break end
    --[[
    local str = string.format("READ addr %08x :", addr)
    for _,b in ipairs{res:byte(1, -1)} do str = str .. string.format(" %02x", b) end
    print(str.." ("..#res.."bytes)")
    addr = addr + len
    --]]

    rstr = rstr .. res
    size = size - len
  end

  if not res then return nil,mes end

  return rstr
end

-- AvalonMM メモリライトメソッド
local _avm_memwr = function(self, addr, wstr)
  if not _busopen(self) then return nil,"device is not open" end
  if type(addr) ~= "number" or type(wstr) ~= "string" then return nil,"parameter error" end
  if #wstr < 1 then return true end

  local t_stop = {mode="stop"}
  local t_write = {mode="write", data=0}
  local _strwrite = function(a, s)
    --[[
    local str = string.format("WRITE addr %08x :", a)
    for _,b in ipairs{s:byte(1, -1)} do str = str .. string.format(" %02x", b) end
    print(str.." ("..#s.."bytes)")
    --]]
    local r,m = _devopen(self, a)
    if not r then return nil,m end

    for _,b in ipairs{s:byte(1, -1)} do --<Measures for W4.00.01>--
      t_write.data = b
      if i2c(t_write) ~= _r_OK then r = nil; break end
    end
    i2c(t_stop)

    if not r then return nil,"memory write error" end

    return true
  end

  local size = #wstr
  local n = 1
  local res,mes = true,nil

  -- 4バイト境界に揃っていない先頭部分の処理
  local aa = addr % 4
  if aa ~= 0 then
    for i=aa,3 do
      res,mes = _strwrite(addr, wstr:sub(n, n))
      if not res then break end

      n = n + 1
      addr = addr + 1
      size = size - 1
    end

    if not res then return nil,mes end
  end

  -- 4バイト境界転送
  local es = size % 4
  if es ~= 0 then
    size = size - es
  end
  while size > 0 do
    local len = size
    if len > self.wrsplit then len = self.wrsplit end

    res,mes = _strwrite(addr, wstr:sub(n, n+len-1))
    if not res then break end

    n = n + len
    addr = addr + len
    size = size - len
  end

  -- 4バイト境界に揃っていない後端部分の処理
  if res and es ~= 0 then
    for i=1,es do
      res,mes = _strwrite(addr, wstr:sub(n, n))
      if not res then break end

      n = n + 1
      addr = addr + 1
    end
  end

  if not res then return nil,mes end
  return true
end


-- AvalonMMデバイスのオープンとオブジェクトインスタンス
function ca.open(t)
  if pio(0x00, 0x00) == 0 then return nil,"GPIO is not ready" end

  local _,d = pio(0x00, 0x00)
  if not btest(d, 0x10) then return nil,"device is not configured" end

  -- ローカルパラメータ設定
  local dev = 0x55
  local freq = 400
  local adb = 4
  local rds = 16
  local wrs = 256
  if t and type(t) == "table" then
    -- t.devid : I2CデバイスIDの指定(デフォルト0x55)
    if type(t.devid)=="number" then
      if t.devid >= 0x00 and t.devid <= 0x7f then
        dev = t.devid
      else
        return nil,"invalid device ID"
      end
    end

    -- t.i2cfreq : I2Cの通信速度(100または400、デフォルト400)
    if type(t.i2cfreq) == "number" and (t.i2cfreq == 100 or t.i2cfreq == 400) then
      freq = t.i2cfreq
    end

    -- t.addrbytes : デバイスのアドレスバイト数(1,2,3,4のいずれか、デフォルト4)
    if type(t.addrbytes) == "number" and t.addrbytes >= 1 and t.addrbytes <= 4 then
      adb = t.addrbytes
    end

    -- t.rdsplit : リードデータバースト長(4以上で4の倍数を指定、デフォルト16)
    if type(t.rdsplit) == "number" and t.rdsplit >= 4 and t.rdsplit % 4 == 0 then
      rds = t.rdsplit
    end

    -- t.wrsplit : ライトデータバースト長(4以上で4の倍数を指定、デフォルト256)
    if type(t.wrsplit) == "number" and t.wrsplit >= 4 and t.wrsplit % 4 == 0 then
      wrs = t.wrsplit
    end
  end

  if _devindex[dev] then return nil,"device is used by other" end
  _devindex[dev] = true

  return {
      devid = dev,
      i2cfreq = freq,
      addrbst = (adb - 1) * 8,
      rdsplit = rds,
      wrsplit = wrs,
      close = _avm_close,
      iord = _avm_iord,
      iowr = _avm_iowr,
      memrd = _avm_memrd,
      memwr = _avm_memwr,
      bload = ca.binload,
      bsave = ca.binsave,
      load = ca.hexload
    }
end

-- AvalonMMイニシャライズ
function ca.avminit()
  i2c{mode="deinit"}
  pio(0x00, 0x00)
  _devindex = {}
end


------------------------------------------------------------------------------------
-- FPGAコンフィグレーション
------------------------------------------------------------------------------------

function ca.config(t)
  if pio(0x00, 0x00) == 0 then return false,"GPIO is not ready" end

  -- 引数無しの場合はコンフィグレーション状態を返す
  if not t then
    local _,d = pio(0x00, 0x00)
    return btest(d, 0x10)
  end

  -- ローカルパラメータ設定
  if type(t) ~= "table" then return false,"parameter error" end

  -- t.file : コンフィグレーションするRBFファイル名(必須)
  local fname = t.file

  -- t.cache : キャッシュファイルの使用(trueか非ゼロ、デフォルトtrue)
  local usecache = true
  if type(t.cache) ~= "nil" and (not t.cache or t.cache == 0) then usecache = false end

  -- t.timeout : タイムアウト時間(ms単位で10以上を指定、デフォルト10)
  local timeout = 10
  if type(t.timeout) == "number" and t.timeout > 10 then timeout = t.timeout end

  -- t.retry : リトライ回数(0以上を指定、デフォルト3)
  local trynumber = 3
  if type(t.retry) == "number" and t.retry >= 0 then trynumber = t.retry + 1 end


  -- RBFキャッシュファイル作成
  local _makecache = function(fn)
    local f = open(fn, "rb")
    if not f then return false,"rbf file open failed" end

    local fo = open(fn..".cache", "wb")
    if not fo then
      f:close()
      return false,"cache file open failed"
    end

    local rt = {}
    for i=0,255 do
      rt[i] = bor(
          (btest(i, 0x01) and 0x80 or 0x00),
          (btest(i, 0x02) and 0x40 or 0x00),
          (btest(i, 0x04) and 0x20 or 0x00),
          (btest(i, 0x08) and 0x10 or 0x00),
          (btest(i, 0x10) and 0x08 or 0x00),
          (btest(i, 0x20) and 0x04 or 0x00),
          (btest(i, 0x40) and 0x02 or 0x00),
          (btest(i, 0x80) and 0x01 or 0x00))
    end

    local fs = f:seek("end")
    f:seek("set")
    local sz = 100 / ((fs < 1) and 1 or fs)

    while true do
      local ln = f:read(256)
      if not ln then break end

      local rd = ""
      for _,b in ipairs{ln:byte(1, -1)} do rd = rd .. schar(rt[b]) end
      fo:write(rd)

      ca.progress("config", f:seek()*sz, 0)
    end
    f:close()
    fo:close()

    local mt = lfs.attributes(fn, "modification")
    lfs.touch(fn..".cache", mt, mt)

    return true
  end

  -- コンフィグレーション実行
  local _doconfig = function(f, to)
    local fs = f:seek("end")
    f:seek("set")
    local sz = 100 / ((fs < 1) and 1 or fs)

    local c = false
    for n=1,to do
      local _,d = pio(0x07, 0x00)
      sleep(1)
      if not btest(d, 0x18) then c = true; break end
    end
    if not c then return false end

    c = false
    for n=1,to do
      local _,d = pio(0x07, 0x04)
      sleep(1)
      if btest(d, 0x08) then c = true; break end
    end
    if not c then return false end

    while true do
      local ln = f:read(256)
      if not ln then break end

      for _,b in ipairs{ln:byte(1, -1)} do spi("write", b) end --<Measures for W4.00.01>--

      ca.progress("config", 100, f:seek()*sz)
    end

    local _,d = pio(0x07, 0x07)
    return btest(d, 0x10)
  end


  -- コンフィグメイン処理
  ca.progress("config", 0, 0)
  ca.avminit()

  if lfs.attributes(fname, "modification") ~= lfs.attributes(fname..".cache", "modification") then
    usecache = false
  end

  local fconf = open(fname..".cache", "rb")
  if not usecache or not fconf then
    local res,mes = _makecache(fname)
    if not res then return false,mes end

    fconf = open(fname..".cache", "rb")
  end

  spi("mode", 0)
  spi("bit", 8)
  spi("cs", 1)
  spi("init", 1)
  pio(0x07, 0x04)

  local res = false
  for n=1,trynumber do
    if _doconfig(fconf, timeout) then res = true; break end
    pio(0x07, 0x04)
  end
  pio(0x00, 0x1f)
  pio(0x00, 0x00)

  fconf:close()
  if not res then
    remove(fname..".cache")
    return false,"configuration failed"
  end

  ca.progress("config", 100, 100)
  return true
end


------------------------------------------------------------------------------------
-- AvalonMMメモリユーティリティ
------------------------------------------------------------------------------------

-- バイナリデータロード : ファイルを指定のアドレスに読み込む
function ca.binload(avm, fname, offset)
  if type(offset) ~= "number" then offset = 0 end

  ca.progress("binload", 0)

  local fbin = open(fname, "rb")
  if not fbin then return false,"file open failed" end
  local fs = fbin:seek("end")
  fbin:seek("set")

  local sz = 100 / ((fs < 1) and 1 or fs)
  local res = true
  local mes

  local aa = offset % 4
  if aa ~= 0 then
    local len = 4 - aa
    local data = fbin:read(len)
    if data then
      res,mes = avm:memwr(offset, data)
      if res then offset = offset + #data end
    end
  end
  if res then
    while true do
      local data = fbin:read(256)
      if not data then break end

      res,mes = avm:memwr(offset, data)
      if not res then break end
      offset = offset + #data

      ca.progress("binload", fbin:seek()*sz)
    end
  end
  fbin:close()

  if not res then return false,mes end

  ca.progress("binload", 100)
  return true
end


-- バイナリデータセーブ : 指定のメモリエリアをファイルに書き出す
function ca.binsave(avm, fname, size, offset)
  if not(type(size) == "number" and size > 0) then return false,"parameter error" end
  if type(offset) ~= "number" then offset = 0 end

  ca.progress("binsave", 0)

  local fbin = open(fname, "wb")
  if not fbin then return false,"file open failed" end

  local sz = 100 / size
  local res,mes

  while size > 0 do
    local len = size
    if len > 256 then len = 256 end

    res,mes = avm:memrd(offset, len)
    if not res then break end
    fbin:write(res)

    size = size - len
    offset = offset + len
    ca.progress("binsave", 100-size*sz)
  end
  fbin:close()

  if not res then return false,mes end

  ca.progress("binsave", 100)
  return true
end


-- ROMデータロード : IntelHEXまたはモトローラSファイルをメモリに読み込む
function ca.hexload(avm, fname, offset)
  if type(offset) ~= "number" then offset = 0 end

  ca.progress("hexload", 0)

  -- インテルHEXの一行をデコード
  local ext_addr = 0
  local _dec_ihex = function(ln)
    local b = ln:sub(2, 3)
    if not b then return false,"byte count error" end

    local count = tonumber(b, 16)
    if not count then return false,"invalid charactors" end

    if #ln < count*2+11 then return false,"data record shortage" end

    local addr = tonumber(ln:sub(4, 7), 16)
    local rtype = tonumber(ln:sub(8, 9), 16)
    if not(addr and rtype) then return false,"invalid charactors" end

    local sum = count + extract(addr, 8, 8) + extract(addr, 0, 8) + rtype
    local data = ""

    if rtype == 2 or rtype == 4 then
      local ea = tonumber(ln:sub(10, 13), 16)
      if not ea then return false,"invalid charactors" end

      sum = sum + extract(ea, 8, 8) + extract(ea, 0, 8)
      if rtype == 2 then
        ext_addr = lshift(ea, 4)  -- 拡張セグメントアドレス
      else
        ext_addr = lshift(ea, 16) -- 拡張リニアアドレス
      end

    elseif rtype == 0 then        -- データレコード
      local n = 10
      local c = true
      for i=1,count do
        local b = tonumber(ln:sub(n, n+1), 16)
        if not b then c = false; break end
        data = data .. schar(b)
        sum = sum + b
        n = n + 2
      end
      if not c then return false,"invalid charactors" end

    else
      return true   -- それ以外のレコードはスキップ
    end

    local b = tonumber(ln:sub(count*2+10, count*2+11), 16)
    if not b then return false,"invalid charactors" end

    if btest(sum+b, 0xff) then return false,"checksum error" end

    if rtype ~= 0 then return true end
    return avm:memwr(offset+ext_addr+addr, data)
  end

  -- モトローラSフォーマットの一行をデコード
  local _dec_srec = function(ln)
    local b = ln:sub(2, 2)
    local c = ln:sub(3, 4)
    if not(b and c) then return false,"record type error" end

    local rtype = tonumber(b)
    local count = tonumber(c, 16)
    if not(rtype and count) then return false,"invalid charactors" end

    if #ln < count*2+4 then return false,"data record shortage" end

    local n,m
    local addr = 0
    local sum = count
    local data = ""

    if rtype == 1 then
      addr = tonumber(ln:sub(5, 8), 16)   -- S1レコード
      n = 9
      m = count - 3
    elseif rtype == 2 then
      addr = tonumber(ln:sub(5, 10), 16)  -- S2レコード
      n = 11
      m = count - 4
    elseif rtype == 3 then
      addr = tonumber(ln:sub(5, 12), 16)  -- S3レコード
      n = 13
      m = count - 5
    else
      return true   -- それ以外のレコードはスキップ
    end
    if not addr then return false,"invalid charactors" end

    for i=0,24,8 do sum = sum + extract(addr, i, 8) end

    local c = true
    for i=1,m do
      local b = tonumber(ln:sub(n, n+1), 16)
      if not b then c = false; break end
      data = data .. schar(b)
      sum = sum + b
      n = n + 2
    end
    local b = tonumber(ln:sub(n, n+1), 16)
    if not b then c = false end
    if not c then return false,"invalid charactors" end

    if btest(sum+b+1, 0xff) then return false,"checksum error" end

    return avm:memwr(offset+addr, data)
  end

  local fhex = open(fname, "r")
  if not fhex then return false,"file open failed" end
  local fs = fhex:seek("end")
  fhex:seek("set")

  local sz = 100 / ((fs<1) and 1 or fs)
  local res = true
  local mes
  local lnumber = 1

  while true do
    local ln = fhex:read()
    if not ln then break end

    local c = ln:sub(1, 1)
    if c==":" then
      res,mes = _dec_ihex(ln)
    elseif c=="S" then
      res,mes = _dec_srec(ln)
    end
    if not res then break end

    lnumber = lnumber + 1
    ca.progress("hexload", fhex:seek()*sz)
  end
  fhex:close()

  if not res then return false,mes.." (line:"..lnumber..")" end

  ca.progress("hexload", 100)
  return true
end


return ca
