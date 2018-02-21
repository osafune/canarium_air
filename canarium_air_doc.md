Canarium Air I/O
================

Canarium Air I/OはFlashAirからFPGAのコンフィグレーションおよびデバイスアクセスをするためのLuaライブラリです。   
このライブラリはCanarium RPCを併用してリモートプロシージャコール(RPC)を提供したり、FlashAirの他機能と組み合わせてIFTTTへ接続するなど、FPGAをIoTエッジデバイスとしてより扱いやすくすることを可能にします。


ライセンス
=========

[The MIT License (MIT)](https://opensource.org/licenses/MIT)  
Copyright (c) 2017,2018 J-7SYSTEM WORKS LIMITED.


対象環境
=======

- FlashAir W-04 ファームW4.00.01以降
- Intel FPGA (CycloneIV E, Cyclone10 LP, MAX10)
- QuartusPrime 17.0以降


使い方
=====

ピンアサイン
-----------

FlashAirのI/OとFPGAは以下のように接続します。

![schema](https://raw.githubusercontent.com/osafune/canarium_air/master/img/connection.png)

- FPGAのMSELピンはPSモードに設定しておきます。
- FlashAirの各ピンとFPGAの間には22～33Ωのダンピング抵抗を挟みます。
- `nCONFIG`, `nSTATUS`, `CONF_DONE`は10kΩでVCCにプルアップします。
- `DATA0(SCL)`, `USER I/O(SDA)`は2.2kΩでVCCにプルアップします。
- それ以外のピンは適宜処理してください。


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
ca.config{file="<RBFファイルのフルパス>"}

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

ca.version
----------

ライブラリのバージョンを取得します。

- 書式  
*string* ca.version()

- 記述例
```Lua
ver = ca.version()
```

- 引数  
なし

- 返値
  - `ver`  
  バージョン表記が *string* で返ります。


---
ca.progress
-----------

時間のかかる処理の際に、内部で進捗度を取得するために呼ばれます。  
この関数で進捗度を得るためにはユーザープログラム側で上書きする必要があります。

- 書式  
ca.progress( *string* `funcname`, *number* `...` )

- 記述例
```Lua
require "canarium_air"

ca.progress = function(funcname, ...)
  -- 進捗表示処理など
end
```

- 引数
  - `funcname`  
  内部でca.progressを呼び出している関数の識別名が *string* で格納されます。

  - `...`  
  進捗度が *number* で格納されます。値の範囲は `0` ~ `100` です。

- 返値  
なし

複数の処理ステージが存在する関数の場合、ステージ数分の引数が渡されることに注意してください。


-----
ca.config
---------

FPGAのコンフィグレーションを行います。
この関数は内部で `ca.progress("config", prog1, prog2)` を呼び出します。*prog1* はキャッシュファイル作成の進捗度、*prog2* はFPGAコンフィグレーションの進捗度を返します。

- 書式  
*boolean*,*string* ca.config( *table* `table` )

- 記述例
```Lua
res,mes = ca.config{file="/foo/bar.rbf"}
```

- 引数テーブル

| メンバ | タイプ | 指定 | 説明 |
|:---:|:---:|:---:|:---|
| `file` | *string* | 必須 | RBFファイル名を指定します。ファイル名はフルパスで設定します。 |
| `cache` | *boolean* | オプション | キャッシュファイルの使用を指示します。省略時は `true` です。 |

- 返値
  - `res`  
  コンフィグ成功時に `true`、失敗時に `false` を返します。

  - `mes`  
  失敗要因のメッセージを *string* で返します。


----
ca.open
-------

Qsysモジュールへのアクセスオブジェクトを取得します。

- 書式  
*table*,*string* ca.open( [*table* `table`] )

- 記述例
```Lua
avm,mes = ca.open()
```

- 引数テーブル

| メンバ | タイプ | 指定 | 説明 |
|:---:|:---:|:---:|:---|
| `devid` | *number* | オプション | スレーブアドレスを指定します。省略時は `0x55` です。 |
| `i2cfreq` | *number* | オプション | I2C通信速度を `100` または `400` で指定します。省略時は `400` です。 |

- 返値
  - `avm`  
  デバイスオープン成功時は *table*、失敗時は `nil` を返します。

  - `mes`  
  失敗要因のメッセージを *string* で返します。


---
*avm*:close
-----------

取得したアクセスオブジェクトを破棄し、クローズ処理を行います。

- 書式  
*avm*:close()

- 記述例
```Lua
avm,mes = ca.open()
  :
  :
avm:close()
```

- 引数  
なし

- 返値  
なし


----
*avm*:iord
----------

取得したアクセスオブジェクトでI/Oリードを行います。  
Qsys内部のアクセスは必ずバス幅(32bit単位)で行われ、ワード内でのアトミックな読み出しを保証します。

- 書式  
*number*,*string* *avm*:iord( *number* `addr` )

- 記述例
```Lua
avm = ca.open()
data,mes = avm:iord(0x10000000)
```

- 引数
  - `addr`  
  Qsys内部の読み出しアドレスを *number* で指定します。値は32bitの範囲の整数値で、32bitアラインメントされていなければなりません。

- 返値
  - `data`  
  成功時は読み出した値を *number* で返します。失敗時は `nil` を返します。

  - `mes`  
  失敗要因のメッセージを *string* で返します。


----
*avm*:iowr
----------

取得したアクセスオブジェクトでI/Oライトを行います。  
Qsys内部のアクセスは必ずバス幅(32bit単位)で行われ、ワード内でのアトミックな書き込みを保証します。

- 書式  
*boolean*,*string* *avm*:iowr( *number* `addr`, *number* `data` )

- 記述例
```Lua
avm = ca.open()
res,mes = avm:iowr(0x10000000, 1)
```

- 引数
  - `addr`  
  Qsys内部の書き込みアドレスを *number* で指定します。値は32bitの範囲の整数値で、32bitアラインメントされていなければなりません。

  - `data`  
  書き込みデータを *number* で指定します。値は32bitの範囲の整数値です。

- 返値
  - `res`  
  成功時は `true`、失敗時は `nil` を返します。

  - `mes`  
  失敗要因のメッセージを *string* で返します。


----
*avm*:memrd
-----------

取得したアクセスオブジェクトでメモリリードを行います。  

- 書式  
*string*,*string* *avm*:memrd( *number* `addr`, *number* `size` )

-記述例
```Lua
avm = ca.open()
rstr,mes = avm:memrd(0x10000000, 256)
```

- 引数
  - `addr`  
  Qsys内部の読み出し開始アドレスを *number* で指定します。値は32bitの範囲の整数値です。

  - `size`  
  読み出すバイトサイズを *number* で指定します。一度に指定可能な値はFlashAirのメモリリソースに左右されます。

- 返値
  - `rstr`  
  成功時は読み出したバイト列を *string* で返します。失敗時は `nil` を返します。

  - `mes`  
  失敗要因のメッセージを *string* で返します。


---
*avm*:memwr
-----------

取得したアクセスオブジェクトでメモリライトを行います。

- 書式  
*boolean*,*string* *avm*:memwr( *number* `addr`, *string* `wstr` )

- 記述例
```Lua
avm = ca.open()
res,mes = avm:iowr(0x10000000, "\x01\x02\x03\x04\x05\x06")
```

- 引数
  - `addr`  
  Qsys内部の書き込み先頭アドレスを *number* で指定します。値は32bitの範囲の整数値です。

  - `wstr`  
  書き込むバイト列を *string* で指定します。一度に指定可能な値はFlashAirのメモリリソースに左右されます。

- 返値
  - `res`  
  成功時は `true`、失敗時は `nil` を返します。

  - `mes`  
  失敗要因のメッセージを *string* で返します。


---
ca.binload
----------

取得したアクセスオブジェクトのメモリ空間にファイルイメージをロードします。  
この関数は内部で `ca.progress("binload", prog)` を呼び出します。

- 書式  
*boolean*,*string* ca.binload( *table* `avm`, *string* `file` [, *number* `addr`] )

- 記述例
```Lua
avm = ca.open()
res,mes = ca.binload(avm, "/foo/bar.bin", 0x2000)
```

またはアクセスオブジェクトのメソッドを利用して下記のようにも書けます。

```Lua
res,mes = avm:bload("/foo/bar.bin", 0x2000)
```

- 引数
  - `avm`  
  使用するアクセスオブジェクトを指定します。

  - `file`  
  ロードするファイルをフルパスで指定します。

  - `addr`  
  先頭メモリアドレスを *number* で指定します。省略時は `0` です。

- 返値
  - `res`  
  成功時は `true`、失敗時は `false` を返します。

  - `mes`  
  失敗要因のメッセージを *string* で返します。


---
ca.binsave
----------

取得したアクセスオブジェクトのメモリ空間からバイトイメージをファイルにセーブします。  
この関数は内部で `ca.progress("binsave", prog)` を呼び出します。

- 書式  
*boolean*,*string* ca.binsave( *table* `avm`, *string* `file`, *number* `size` [, *number* `addr`] )

- 記述例
```Lua
avm = ca.open()
res,mes = ca.binsave(avm, "/foo/bar.bin", 8192, 0x1000)
```

またはアクセスオブジェクトのメソッドを利用して下記のようにも書けます。

```Lua
res,mes = avm:bsave("/foo/bar.bin", 8192, 0x1000)
```

- 引数
  - `avm`  
  使用するアクセスオブジェクトを指定します。

  - `file`  
  セーブするファイルをフルパスで指定します。同名ファイルがあった場合は上書きされます。

  - `size`  
  保存するバイトサイズを *number* で指定します。

  - `addr`  
  開始メモリアドレスを *number* で指定します。省略時は `0` です。

- 返値
  - `res`  
  成功時は `true`、失敗時は `false` を返します。

  - `mes`  
  失敗要因のメッセージを *string* で返します。


---
ca.hexload
----------

取得したアクセスオブジェクトのメモリ空間にIntelHEXまたはS-record形式のファイルをロードします。  
この関数は内部で `ca.progress("hexload", prog)` を呼び出します。

- 書式  
*boolean*,*string* ca.hexload( *table* `avm`, *string* `file` [, *number* `offset`] )

- 記述例
```Lua
avm = ca.open()
res,mes = ca.hexload(avm, "/foo/bar.hex")
```

またはアクセスオブジェクトのメソッドを利用して下記のようにも書けます。

```Lua
res,mes = avm:load("/foo/bar.hex")
```

- 引数
  - `avm`  
  使用するアクセスオブジェクトを指定します。

  - `file`  
  ロードするIntelHEXまたはS-recordファイルをフルパスで指定します。フォーマットは自動認識されます。

  - `offset`  
  アドレスオフセットを *number* で指定します。省略時は `0` です。  
  この引数を省略した場合は、IntelHEXまたはS-recordファイルのアブソリュートアドレスでロードが行われます。

- 返値
  - `res`  
  成功時は `true`、失敗時は `false` を返します。

  - `mes`  
  失敗要因のメッセージを *string* で返します。


---

&copy; 2017,2018 J-7SYSTEM WORKS LIMITED
