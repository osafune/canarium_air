Canarium Air
============

PERIDOT-AIRボード（開発中）で、FlashAirからFPGAのコンフィグレーションおよびデバイスアクセスをするためのLuaライブラリです。  

現状はお試しバージョンです。


ライセンス
=========

The MIT License  
Copyright (c) 2017 J-7SYSTEM WORKS LIMITED


対象環境
=======

- FlashAir W-04 ファームW4.00.01
- Intel FPGA (CycloneIV E, Cyclone10 LP, MAX10)
- QuartusPrime 17.0以降


使い方
=====

ピンアサイン
-----------

FlashAirのI/OとFPGAは以下のように接続します。

    CMD  <---> DATA0(SCL)
    DAT0 <-+-> DCLK
           +--> USER I/O(SDA)
    DAT1 ----> nCONFIG
    DAT2 <---- nSTATUS
    DAT3 <---- CONF_DONE

- FPGAのMSELピンはPSモードに設定しておきます。
- FlashAirの各ピンとFPGAの間には22～33Ωのダンピング抵抗を挟みます。
- `nCONFIG`, `nSTATUS`, `CONF_DONE`は10kΩでVCCにプルアップします。
- `DATA0(SCL)`, `USER I/O(SDA)`は2.2kΩでVCCにプルアップします。

FPGAプロジェクト
---------------

Qsysで"[Intel FPGA I2C Slave to Avalon -MM Master Bridge Core](https://www.altera.com/documentation/sfo1400787952932.html#iga1457384052773)"をインスタンスしたモジュールを作成します。
- `I2C Slave Address`は0x55をセットします。
- `Byte addressing mode`は4にセットします。
- `Number of Address Stealing bit`は0にセットします。
- `Enable Read only mode`はOFFにセットします。

SDA信号をUSER I/Oピンに、SCL信号をDATA0ピンにアサインします。  
デバイスコンフィグレーションの設定で、圧縮ビットストリーム、RBFファイルを生成するようにしてください。

FlashAir設定
------------

FlashAirのGPIOモードを使用します。`/SD_WLAN/CONFIG` ファイルに `IFMODE=1` を追加します。  
`canarium_air.lua` を任意のフォルダに格納し、ユーザーのLuaから 

```Lua
require "/<フォルダパス>/canarium_air"

-- FPGAのコンフィグレーション
ca.config{file="<RBFファイルの場所>"}

-- Qsysモジュールアクセス
avm = ca.open()
sysid = avm:iord(0x10000000)
avm:iowr(0x10000100, 1)
avm:close()
```

のように呼び出します。

---
関数リファレンス
==============

ca.version()
------------

ライブラリのバージョンを取得します。

- 書式
```Lua
ver = ca.version()
```

- 引数

なし

- 返値

`ver` : バージョンが *string* で返ります。

---
ca.progress(*`funcname`*, *`...`*)
------------------------------

時間のかかる処理の際に、内部で進捗度を取得するために呼ばれます。  
この関数で進捗度を得るためにはユーザープログラム側でオーバーライトする必要があります。

- 書式
```Lua
require "canarium_air"

ca.progress = function(funcname, ...)
  -- 進捗表示処理など
end
```

- 引数

`funcname` : 内部でca.progressを呼び出している関数の識別名が *string* で格納されます。

`...` : 進捗度が *number* で格納されます。値の範囲は `0~100` です。  

複数の処理ステージが存在する関数の場合、ステージ毎に進捗度が引数として渡されることに注意してください。


-----
ca.config(*`table`*)
------------------

FPGAのコンフィグレーションを行います。
この関数は内部で `ca.progress("config", prog1, prog2)` を呼び出します。

- 書式
```Lua
res,mes = ca.config{file="foot.rbf"}
```

- 引数テーブル

| メンバ | タイプ | 指定 | 説明 |
|:---:|:---:|:---:|:---|
| `file` | *string* | 必須 | RBFファイル名を指定します |
| `cache` | *boolean* | オプション | キャッシュファイルの使用を指示します。省略時 `true` |

- 返値

`res` : コンフィグ成功時に `true`、失敗時に `false` を返します。  
`mes` : 失敗要因のメッセージが *string* で返ります。

----
ca.open(*`table`*)
------------------

Qsysモジュールへのアクセスオブジェクトを取得します。

- 書式
```Lua
avm,mes = ca.open()
```

- 引数テーブル

| メンバ | タイプ | 指定 | 説明 |
|:---:|:---:|:---:|:---|
| `devid` | *number* | オプション | スレーブアドレスを指定します。省略時 `0x55` |
| `i2cfreq` | *number* | オプション | I2C通信速度を `100` または `400` で指定します。省略時 `400` |

- 返値

`avm` : デバイスオープン成功時は *table*、失敗時は `nil` が返ります。  
`mes` : 失敗要因のメッセージが *string* で返ります。  

---
*avm*:close()
-------------

取得したアクセスオブジェクトを破棄し、クローズ処理を行います。

- 書式
```Lua
avm,mes = ca.open()
  :
  :
avm:close()
```

- 返値

なし

----
*avm*:iord(*`addr`*)
--------------------

取得したアクセスオブジェクトでI/Oリードを行います。  
Qsys内部のアクセスは32bit単位で行われ、アトミックな読み出しを保証します。

- 書式
```Lua
avm = ca.open()
data,mes = avm:iord(0x10000000)
```

- 引数

`addr` : Qsys内部の読み出しアドレスを *number* で指定します。値は32bitの範囲の整数値で、32bitアラインメントされていなければなりません。

- 返値

`data` : 成功時は読み出した値が *number* で返ります。失敗時は `nil` が返ります。  
`mes` : 失敗要因のメッセージが *string* で返ります。  

----
*avm*:iowr(*`addr`*, *`data`*)
------------------------------

取得したアクセスオブジェクトでI/Oライトを行います。  
Qsys内部のアクセスは32bit単位で行われ、アトミックな書き込みを保証します。

- 書式
```Lua
avm = ca.open()
res,mes = avm:iowr(0x10000000, 1)
```

- 引数

`addr` : Qsys内部の書き込みアドレスを *number* で指定します。値は32bitの範囲の整数値で、32bitアラインメントされていなければなりません。

`data` : 書き込みデータを *number* で指定します。値は32bitの範囲の整数値です。

- 返値

`res` : 成功時は `true`、失敗時は `nil` が返ります。  
`mes` : 失敗要因のメッセージが *string* で返ります。  

----
*avm*:memrd(*`addr`*, *`size`*)
-------------------------------

取得したアクセスオブジェクトでメモリリードを行います。  

- 書式
```Lua
avm = ca.open()
rstr,mes = avm:memrd(0x10000000, 256)
```

- 引数

`addr` : Qsys内部の読み出し開始アドレスを *number* で指定します。値は32bitの範囲の整数値です。

`size` : 読み出すバイトサイズを *number* で指定します。一度に指定可能な値はFlashAirのメモリリソースに左右されます。

- 返値

`rstr` : 成功時は読み出したバイト列が *string* で返ります。失敗時は `nil` が返ります。  
`mes` : 失敗要因のメッセージが *string* で返ります。  

---
*avm*:memwr(*`addr`*, *`wstr`*)
-------------------------------

取得したアクセスオブジェクトでメモリライトを行います。

- 書式
```Lua
avm = ca.open()
wstr = "\x01\x02\x03\x04\x05\x06"
res,mes = avm:iowr(0x10000000, wstr)
```

- 引数

`addr` : Qsys内部の書き込み先頭アドレスを *number* で指定します。値は32bitの範囲の整数値です。

`wstr` : 書き込むバイト列を *string* で指定します。一度に指定可能な値はFlashAirのメモリリソースに左右されます。

- 返値

`res` : 成功時は `true`、失敗時は `nil` が返ります。  
`mes` : 失敗要因のメッセージが *string* で返ります。  

---
ca.binload(*`avm`*, *`file`*, *`offset`*)
---------------------------------

取得したアクセスオブジェクトのメモリ空間にファイルイメージをロードします。  
この関数は内部で `ca.progress("binload", prog)` を呼び出します。

- 書式
```Lua
avm = ca.open()
res,mes = ca.binload(avm, "bar.bin")
```

またはavmメソッドを利用して下記のようにも書けます。

```Lua
res,mes = avm:bload("bar.bin")
```

- 引数

`avm` : 使用するアクセスオブジェクトを指定します。

`file` : ロードするファイルを指定します。

`offset` : オフセットアドレスを *string* で指定します。省略時は `0`

- 返値

`res` : 成功時は `true`、失敗時は `false` が返ります。  
`mes` : 失敗要因のメッセージが *string* で返ります。  

---
ca.binsave(*`avm`*, *`file`*, *`size`*, *`offset`*)
---------------------------------

取得したアクセスオブジェクトのメモリ空間からバイトイメージをファイルにセーブします。  
この関数は内部で `ca.progress("binsave", prog)` を呼び出します。

- 書式
```Lua
avm = ca.open()
res,mes = ca.binsave(avm, "bar.bin", 8192, 0x1000)
```

またはavmメソッドを利用して下記のようにも書けます。

```Lua
res,mes = avm:bsave("bar.bin", 8192, 0x1000)
```

- 引数

`avm` : 使用するアクセスオブジェクトを指定します。

`file` : セーブするファイルを指定します。同名ファイルがあった場合は上書きされます。

`size` : 保存するバイトサイズを *number* で指定します。

`offset` : 開始オフセットアドレスを *string* で指定します。省略時は `0`

- 返値

`res` : 成功時は `true`、失敗時は `false` が返ります。  
`mes` : 失敗要因のメッセージが *string* で返ります。  

---
ca.hexload(*`avm`*, *`file`*, *`offset`*)
---------------------------------

取得したアクセスオブジェクトのメモリ空間にIntelHEXまたはS-record形式のファイルをロードします。  
この関数は内部で `ca.progress("hexload", prog)` を呼び出します。

- 書式
```Lua
avm = ca.open()
res,mes = ca.hexload(avm, "foo.hex")
```

またはavmメソッドを利用して下記のようにも書けます。

```Lua
res,mes = avm:load("foo.hex")
```

- 引数

`avm` : 使用するアクセスオブジェクトを指定します。

`file` : ロードするIntelHEXまたはS-recordファイルを指定します。フォーマットは自動認識されます。

`offset` : オフセットアドレスを *string* で指定します。省略時は `0`

- 返値

`res` : 成功時は `true`、失敗時は `false` が返ります。  
`mes` : 失敗要因のメッセージが *string* で返ります。  

---

&copy; 2017 J-7SYSTEM WORKS LIMITED
