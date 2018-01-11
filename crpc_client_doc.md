Canarium RPC Client
===================

Canarium RPCはFlashAirを使ってFPGAリソースへのアクセスを提供するリモートプロシージャコール(RPC)ライブラリです。  
`crpc_client.js` では、ブラウザ側にJSON-RPCのクライアントAPIを提供します。サーバー側は[Canarium RPC Server](canarium_rpc_doc.md)を参照してください。  

<img src="https://raw.githubusercontent.com/osafune/canarium_air/master/img/canarium_stack.png" width="370" height="600">


ライセンス
==========

[The MIT License (MIT)](https://opensource.org/licenses/MIT)  
Copyright (c) 2017,2018 J-7SYSTEM WORKS LIMITED.


対象環境
========

- FlashAir W-04 ファームW4.00.01以降
- Canarium RPC v0.2.0111以降


使い方
======

1. ブラウザ側で `crpc_client.js` を読み込みます。
```html
<head>
   <script type="text/javascript" src="crpc_client.js"></script>
      :
</head>
```

2. スクリプト内で　`CanariumRPC_Clinet()` オブジェクトを生成してアクセスを行います。
```javascript
const crpc = new CanariumRPC_Clinet();

const fpga_config = async() => {
  let res;

  // FPGAのコンフィグレーションを実行 
  res = await crpc.CONF("olive_std_top.rbf");
  if (!res.result) return res.error;
  console.log("FPGA configured");

  // sysIDを読み出す
  res = await crpc.IORD(0x10000000);
  if (!res.result) return res.error;
  console.log("systemid = 0x" + ("0000000" + res.result.toString(16).toUpperCase()).substr(-8));

  return null;
};

fpga_config();
```

---
APIリファレンス
==============

*string* CanariumRPC_Client.version()
-------------------------------------

Canarium RPC Clientのバージョンを取得します。

- 書式例
```javascript
let ver = crpc.version();
```

- 引数

なし

- 返値
  - *string*  
  バージョンを返します。


---
*boolean* CanariumRPC_Client.addmethod(*string `name`*, *function `qfunc`* [, *function `pfunc`*] )
---------------------------------------------------------------------------------------------------

RPCサーバー側に追加したユーザーメソッドに対応するクエリを発行するRPCメソッドの追加を行います。 

- 書式例
```javascript
let res = crpc.addmethod("USER", (params) => {
  let p = [];
  p.push(0x40);  // ユーザーメソッドに割り当てるコード
  p.push(params.byteA); // 任意のパラメータ
  p.push(params.byteB);
  return p;
});
```

- 引数
  - *string* `name`  
  追加するRPCメソッド名を指定します。既に同じ名前のメソッドがある場合は後から指定したものに更新されます。  

  - *function* `qfunc`
  クエリを組み立てる関数を指定します。関数は `Array function(Object)` の形式で指定します。  
  引数として、JSON-RPC呼び出し時の `params` オブジェクトが渡されます。  
  返値のArrayオブジェクトの各要素はバイト値を格納します。Arrayの先頭要素はRPCメソッドの識別番号を入れなければなりません。指定出来る範囲は `0x00` ～ `0x7f` です。また `0x00` ～ `0x2f` は組み込み用に予約されています。

  - (option) *function* `pfunc`  
  JSON-RPCのレスポンスに対してポスト処理が必要な場合に指定します。

- 返値
  - *boolean*  
  関数の処理結果を返します。成功の場合は `true` 、失敗の場合は `false` です。


---
*boolean* CanariumRPC_Client.delmethod(*string `name`*)
-------------------------------------------------------

`CanariumRPC_Client.addmethod()` で追加したRPCメソッドの削除を行います。 

- 書式例
```javascript
let res = crpc.delmethod("USER");
```

- 引数
  - *string* `name`  
  削除するRPCメソッド名を指定します。

- 返値
  - *boolean*  
  関数の処理結果を返します。成功の場合は `true` 、失敗の場合は `false` です。


---
*string* CanariumRPC_Client.encode(*ArrayBuffer `bin`*)
-------------------------------------------------------

バイナリデータをBase64Urlでエンコードします。

- 書式例
```javascript
let b64_str = crpc.encode(bin);
```

- 引数
  - *ArrayBuffer* `bin`  
  エンコードするバイナリデータを指定します。

- 返値
  - *string*  
  エンコードした結果を返します。


---
*ArrayBuffer* CanariumRPC_Client.decode(*string `b64_str`*)
-----------------------------------------------------------

Base64Urlでエンコードされた文字列をバイナリデータへ復元します。

- 書式例
```javascript
let bin = crpc.decode(b64_str);
```

- 引数
  - *string* `b64_str`  
  デコードするBase64Url文字列を指定します。

- 返値
  - *ArrayBuffer*  
  デコードした結果を返します。


---
*Promise* CanariumRPC_Client.settings(*string `host`*, *string `server`*)
-------------------------------------------------------------------------

RPCサーバーのホストや場所を指定します。  
このメソッドが呼ばれると、Canarium RPCクライアントはサーバーへの接続を試み、クライアント設定を自動的に行います。

- 書式例
```javascript
let res = await crpc.settings("", "/crs.lua");
```

- 引数
  - *string* `host`  
  クロスオリジン通信を行う場合に、RPCサーバーのドメイン名を指定します。ページ配信元もFlashAirの場合は空文字("")を指定します。  
  FlashAirの制約により、クロスオリジン通信では `upload.cgi` や `command.cgi` を利用したメソッドは全てエラーが返ることに注意してください。

  - *string* `server`
  RPCサーバー名を指定します。セッション管理を行う場合、ここでセッションサーバーから発行されたサーバー名を指定します。

- 返値
  - *Promise*  
  非同期実行の完了、または中止をPromiseオブジェクトで返します。  
  正常に終了した場合はJSON-RPCのレスポンスデータを格納したオブジェクトを返します。rejectは通信エラーが発生した場合のみ行われ、RPCサーバーがエラーを返した場合、メソッドとしては正常終了の扱いになることに注意してください。


---
*Promise* CanariumRPC_Client.call(*object `jsonrpc`* [, *function `callback`* [, *number `period`* ]])
------------------------------------------------------------------------------------------------------

RPCサーバーに対してメソッドを発行します。

- 書式例
```javascript
let res = await crpc.call({
  method: "CONF",
  params: {
    file: "sample.rbf"
  }
});
```

- 引数
  - *object* `jsonrpc`  
  RPCサーバーへリクエストする内容をオブジェクトとして指定します。プロパティのうち、`method` と `params` は必須です。それ以外のプロパティは省略可能です。  
  詳細は[RPCメソッドリファレンス](#rpcメソッドリファレンス)を参照してください。

  - (option) *function* `callback`  
  RPCメソッドの進捗ステータスを取得する場合に指定します。関数は `function(Number, Object)` の形式で指定します。
  `Number` には呼び出したRPCメソッドのIDが返ります。`Object` には進捗ステータスのオブジェクトが返ります。  
  詳細は[進捗ステータスコールバック](#進捗ステータスコールバック)を参照してください。

  - (option) *number* `period`  
  `callback` を呼び出す周期をミリ秒で指定します。  
  最低値は `100` で、省略した場合は `500` となります。値は整数値を指定しなければなりません。

- 返値
  - *Promise*  
  非同期実行の完了、または中止をPromiseオブジェクトで返します。  
  正常に終了した場合はJSON-RPCのレスポンスデータを格納したオブジェクトを返します。rejectは通信エラーが発生した場合のみ行われ、RPCサーバーがエラーを返した場合、メソッドとしては正常終了の扱いになることに注意してください。


---
RPCメソッドリファレンス
=====================

ファイルについて
---------------

RPCメソッドで指定するファイルはFlashAir側のストレージに格納されているものに限ります。  
必要なファイルは予めカードに保存しておくか、FlashAir用のツール（あるいは `upload.cgi` ）でファイルを転送してください。  
同様にクエリの結果として書き出されるファイルはFlashAirのストレージに保存されます。必要に応じてクライアント側にダウンロードしてください。

ファイルパスは次のような書き方ができます。

    *カレントフォルダのファイルを指定
      "testfile2.bin"
      "./testfile3.hex"
    
    *カレントフォルダ以下の子フォルダを指定
      "test/romdata.srec"

    *ファイルをフルパスで指定（サーバー側で許可されている場合のみ）
      "/foo/bar/testfile1.rbf"


ファイル名、ファイルパス共に日本語を含む多バイト長文字は使用できません。


RPCメソッドレスポンス
-------------------

RPCメソッドのレスポンスはJSON-RPCに則ったオブジェクトで返されます。

- 正常レスポンス

```
{
  jsonrpc: "2.0",
  result: <boolean> or <number> or <ArrayBuffer> or <object>,
  id: <number>
}
```

- エラーレスポンス

```
{
  jsonrpc: "2.0",
  error: {
    code: <number>,
    message: <string>
  },
  id: <number>
}
```

- プロパティ
  - `jsonrpc`  
  *string* で `"2.0"` の固定値が入ります。

  - `id`  
  RPCメソッドでリクエストしたID値が *number* で入ります。

  - `result`  
  正常終了の場合に結果が入ります。 *boolean*、*number* (32bit整数値)、*ArrayBuffer*、*object* 等が格納されます。

  - `error`  
  エラーの場合は、`result` の代わりにこのプロパティを返します。
    - `code` : エラーコードが *number* で入ります。値はJSON-RPCに準拠します。
    - `message` : エラーメッセージがある場合は *string* で入ります。

- エラーコード  
  - パースエラー  
  `error : {code: -32700, message: "Parse error"}`  
  サーバーがクエリをデコードできなかった、または不正なパケット形式を検出した場合に返されます。  

  - メソッド呼び出しエラー  
  `error : {code: -32601, message: "Method not found"}`  
  RPCメソッドが存在しない場合に返されます。

  - メソッド実行時エラー  
  `error : {code: -32000, message: <エラーメッセージ>}`  
  RPCメソッドの実行が失敗した場合に返されます。`message` にはRPCサーバーで返されるメッセージが *string* で入ります。


RPCメソッドとFPGAの状態
----------------------

下記のRPCメソッドはFPGAがコンフィグレーションされ、かつそのデザインにAvalon-MMブリッジが組み込まれている場合にのみ有効な動作を行います。

- [IOWRメソッド](#iowrメソッド)
- [IORDメソッド](#iordメソッド)
- [MEMWRメソッド](#memwrメソッド)
- [MEMRDメソッド](#memrdメソッド)
- [BLOADメソッド](#bloadメソッド)
- [BSAVEメソッド](#bsaveメソッド)
- [LOADメソッド](#loadメソッド)


---
VERメソッド
----------

RPCサーバーのバージョンを取得します。

- RPC呼び出しオブジェクト
```
{
  method: "VER"
}
```

- シンタクスシュガー  
*Promise* `CanariumRPC_Client.RPCVER()`

- リクエストプロパティ
  なし

- レスポンスプロパティ
  - `result`  
  RPCサーバーのバージョン情報を *object* で返します。
    - `rpc_version` : Canarium RPCのバージョンが *string* で入ります。
    - `lib_version` : Canarium Air I/Oのバージョンが *string* で入ります。
    - `fa_version` : FlashAirのファームウェアバージョンが *string* で入ります。


---
CHECKメソッド
------------

FPGAがコンフィグレーション済みかどうかをチェックします。

- RPC呼び出しオブジェクト
```
{
  method: "CHECK",
  id: <number>
}
```

- シンタクスシュガー  
*Promise* `CanariumRPC_Client.CHECK()`

- リクエストプロパティ
  - (option) `id`  
  RPC呼び出しのID値を `0` ~ `65535` の範囲で指定します。省略した場合は自動的に連番が付与されます。  
  シンタクスシュガーではidプロパティは常に省略されます。

- レスポンスプロパティ
  - `result`  
  FPGAの状態を *number* で返します。
    - `1` : コンフィグレーションされている
    - `0` : 未コンフィグレーション状態


---
IOWRメソッド
-----------

Qsysモジュール（FPGA内部ロジックコア）のペリフェラルレジスタにデータを書き込みます。  
IOWRメソッドは、Avalon-MMのメモリバス（Qsysモジュール内部メモリ空間）で32bitワード単位のアトミックなライトアクセスを保証します。

- RPC呼び出しオブジェクト
```
{
  method: "IOWR",
  params: {
    address: <number>,
    data: <number>
  },
  id: <number>
}
```

- シンタクスシュガー  
*Promise* `CanariumRPC_Client.IOWR(address, data)`

- リクエストプロパティ
  - `params`  
    - `address`  
    書き込み先アドレスを32bitの整数値で指定します。アドレス値は32bitのワード境界に整列していなければなりません。

    - `data`  
    書き込む値を32bitの整数値で指定します。

  - (option) `id`  
  RPC呼び出しのID値を `0` ~ `65535` の範囲で指定します。省略した場合は自動的に連番が付与されます。  
  シンタクスシュガーではidプロパティは常に省略されます。

- レスポンスプロパティ
  - `result`  
  完了で `true` を返します。


---
IORDメソッド
-----------

Qsysモジュール（FPGA内部ロジックコア）のペリフェラルレジスタからデータを読み出します。  
IORDメソッドは、Avalon-MMのメモリバス（Qsysモジュール内部メモリ空間）で32bitワード単位のアトミックなリードアクセスを保証します。

- RPC呼び出しオブジェクト
```
{
  method: "IORD",
  params: {
    address: <number>
  },
  id: <number>
}
```

- シンタクスシュガー  
*Promise* `CanariumRPC_Client.IORD(address)`

- リクエストプロパティ
  - `params`  
    - `address`  
    読み出しアドレスを32bitの整数値で指定します。アドレス値は32bitのワード境界に整列していなければなりません。

  - (option) `id`  
  RPC呼び出しのID値を `0` ~ `65535` の範囲で指定します。省略した場合は自動的に連番が付与されます。  
  シンタクスシュガーではidプロパティは常に省略されます。

- レスポンスプロパティ
  - `result`  
  読み出した値を *number* (32bit符号無し整数)で返します。


---
MEMWRメソッド
------------

Qsysモジュール（FPGA内部ロジックコア）の任意のメモリアドレスにバイトデータ列を書き込みます。

- RPC呼び出しオブジェクト
```
{
  method: "MEMWR",
  params: {
    address: <number>,
    data: <ArrayBuffer>
  },
  id: <number>
}
```

- シンタクスシュガー  
*Promise* `CanariumRPC_Client.MEMWR(address, data)`

- リクエストプロパティ
  - `params`  
    - `address`  
    書き込み先頭アドレスを32bitの整数値で指定します。

    - `data`  
    書き込むデータバイト列を *ArrayBuffer* で指定します。指定可能なデータ長は最大64バイトです。

  - (option) `id`  
  RPC呼び出しのID値を `0` ~ `65535` の範囲で指定します。省略した場合は自動的に連番が付与されます。  
  シンタクスシュガーではidプロパティは常に省略されます。

- レスポンスプロパティ
  - `result`  
  完了で `true` を返します。


---
MEMRDメソッド
------------

Qsysモジュール（FPGA内部ロジックコア）の任意のメモリアドレスからバイトデータ列を読み出します。

- RPC呼び出しオブジェクト
```
{
  method: "MEMRD",
  params: {
    address: <number>,
    size: <number>
  },
  id: <number>
}
```

- シンタクスシュガー  
*Promise* `CanariumRPC_Client.MEMRD(address, size)`

- リクエストプロパティ
  - `params`  
    - `address`  
    読み出し先頭アドレスを32bitの整数値で指定します。

    - `size`  
    読み出すバイト数を2バイトで指定します。指定可能な範囲は `1` ～　`256`です。

  - (option) `id`  
  RPC呼び出しのID値を `0` ~ `65535` の範囲で指定します。省略した場合は自動的に連番が付与されます。  
  シンタクスシュガーではidプロパティは常に省略されます。

- レスポンスプロパティ
  - `result`  
  読み出したデータバイト列を *ArrayBuffer* で返します。


---
CONFメソッド
-----------

FPGAのコンフィグレーションを行います。  
既に生成されたキャッシュファイルが存在する場合はそれを利用して、短縮コンフィグレーションを行います。  
このメソッドでは[進捗ステータスコールバック](#進捗ステータスコールバック)が使用可能です。メソッド完了またはエラー発生までレスポンスが返らないため、タイムアウト時間に注意してください。

- RPC呼び出しオブジェクト
```
{
  method: "CONF",
  params: {
    file: <string>,
    cache: <boolean>
  },
  id: <number>
}
```

- シンタクスシュガー  
*Promise* `CanariumRPC_Client.CONF(file [, callback])`

- リクエストプロパティ
  - `params`  
    - `file`  
    コンフィグレーションするRBFファイル名を指定します。

    - (option) `cache`  
    キャッシュファイルを使用するかどうかを指定します。  
    省略した場合は `true` になります。`false` を指定した場合は[FCONFメソッド](#fconfメソッド)と等価です。  
    シンタクスシュガーでは常に省略されます。

  - (option) `id`  
  RPC呼び出しのID値を `0` ~ `65535` の範囲で指定します。省略した場合は自動的に連番が付与されます。  
  シンタクスシュガーではidプロパティは常に省略されます。

- レスポンスプロパティ
  - `result`  
  完了で `true` を返します。

- 進捗ステータスプロパティ
  - `progress`  
    - `[0]` : キャッシュファイル作成の進捗度が `0` ～ `100` で入ります。
    - `[1]` : コンフィグレーションの進捗度が `0` ～ `100` で入ります。


---
FCONFメソッド
------------

FPGAのコンフィグレーションを行います。  
既にキャッシュファイルが存在する場合でも、指定のコンフィグレーションファイルでキャッシュファイルを再生成して、FPGAコンフィグレーションを行います。  
このメソッドでは[進捗ステータスコールバック](#進捗ステータスコールバック)が使用可能です。メソッド完了またはエラー発生までレスポンスが返らないため、タイムアウト時間に注意してください。

- RPC呼び出しオブジェクト
```
{
  method: "FCONF",
  params: {
    file: <string>,
  },
  id: <number>
}
```

- シンタクスシュガー  
*Promise* `CanariumRPC_Client.FCONF(file [, callback])`

- リクエストプロパティ
  - `params`  
    - `file`  
    コンフィグレーションするRBFファイル名を指定します。

  - (option) `id`  
  RPC呼び出しのID値を `0` ~ `65535` の範囲で指定します。省略した場合は自動的に連番が付与されます。  
  シンタクスシュガーではidプロパティは常に省略されます。

- レスポンスプロパティ
  - `result`  
  完了で `true` を返します。

- 進捗ステータスプロパティ
  - `progress`  
    - `[0]` : キャッシュファイル作成の進捗度が `0` ～ `100` で入ります。
    - `[1]` : コンフィグレーションの進捗度が `0` ～ `100` で入ります。


---
BLOADメソッド
------------

Qsysモジュール（FPGA内部ロジックコア）の任意のメモリアドレスにファイルイメージをロードします。  
このメソッドでは[進捗ステータスコールバック](#進捗ステータスコールバック)が使用可能です。メソッド完了またはエラー発生までレスポンスが返らないため、タイムアウト時間に注意してください。

- RPC呼び出しオブジェクト
```
{
  method: "BLOAD",
  params: {
    file: <string>,
    address: <number>
  },
  id: <number>
}
```

- シンタクスシュガー  
*Promise* `CanariumRPC_Client.BLOAD(file, address [, callback])`

- リクエストプロパティ
  - `params`  
    - `file`  
    ロードするファイル名を指定します。

    - `address`  
    書き込み先頭アドレスを32bitの整数値で指定します。

  - (option) `id`  
  RPC呼び出しのID値を `0` ~ `65535` の範囲で指定します。省略した場合は自動的に連番が付与されます。  
  シンタクスシュガーではidプロパティは常に省略されます。

- レスポンスプロパティ
  - `result`  
  完了で `true` を返します。

- 進捗ステータスプロパティ
  - `progress`  
    - `[0]` : ロードの進捗度が `0` ～ `100` で入ります。


---
BSAVEメソッド
------------

Qsysモジュール（FPGA内部ロジックコア）の任意アドレスのメモリイメージをファイルに保存します。  
このメソッドでは[進捗ステータスコールバック](#進捗ステータスコールバック)が使用可能です。メソッド完了またはエラー発生までレスポンスが返らないため、タイムアウト時間に注意してください。


- RPC呼び出しオブジェクト
```
{
  method: "BSAVE",
  params: {
    file: <string>,
    address: <number>,
    size: <number>,
  },
  id: <number>
}
```

- シンタクスシュガー  
*Promise* `CanariumRPC_Client.BSAVE(file, address, size [, callback])`

- リクエストプロパティ
  - `params`  
    - `file`  
    保存先のファイル名を指定します。同名のファイルが既に存在していた場合は上書きされます。

    - `address`  
    読み出し先頭アドレスを32bitの整数値で指定します。

    - `size`  
    保存するメモリイメージのバイトサイズを指定します。

  - (option) `id`  
  RPC呼び出しのID値を `0` ~ `65535` の範囲で指定します。省略した場合は自動的に連番が付与されます。  
  シンタクスシュガーではidプロパティは常に省略されます。

- レスポンスプロパティ
  - `result`  
  完了で `true` を返します。

- 進捗ステータスプロパティ
  - `progress`  
    - `[0]` : セーブの進捗度が `0` ～ `100` で入ります。


---
LOADメソッド
-----------

Qsysモジュール（FPGA内部ロジックコア）のメモリアドレス空間に、IntelHEX形式またはモトローラS-record形式のROMデータファイルをロードします。  
このメソッドでは[進捗ステータスコールバック](#進捗ステータスコールバック)が使用可能です。メソッド完了またはエラー発生までレスポンスが返らないため、タイムアウト時間に注意してください。

- RPC呼び出しオブジェクト
```
{
  method: "LOAD",
  params: {
    file: <string>,
    offset: <number>
  },
  id: <number>
}
```

- シンタクスシュガー  
*Promise* `CanariumRPC_Client.LOAD(file [, offset [, callback]])`

- リクエストプロパティ
  - `params`  
    - `file`  
    ロードするファイル名を指定します。IntelHEX/S-recordのフォーマットは自動で認識されます。

    - (option) `offset`  
    オフセットアドレスを32bitの整数値で指定します。  
    この値とROMデータファイルのアドレス値を加算したアドレスへ書き込みが行われます。`0` を指定した場合、ROMデータファイルのアブソリュートアドレスとなります。  
    省略した場合は `0` が指定されます。

  - (option) `id`  
  RPC呼び出しのID値を `0` ~ `65535` の範囲で指定します。省略した場合は自動的に連番が付与されます。  
  シンタクスシュガーではidプロパティは常に省略されます。

- レスポンスプロパティ
  - `result`  
  完了で `true` を返します。

- 進捗ステータスプロパティ
  - `progress`  
    - `[0]` : ロードの進捗度が `0` ～ `100` で入ります。


---
進捗ステータスコールバック
------------------------

`CanariumRPC_Client.call()` ではRPCサーバーからのレスポンスが返ってくるまで処理が待たされるため、処理に時間のかかるものについてはコールバックを利用して進捗ステータスを取得することができます。  
進捗ステータスを取得できるメソッドについては[RPCメソッドリファレンス](#rpcメソッドリファレンス)を参照してください。  

- 記述例
```javascript
const get_progress = (id, res) => {
  if (id == res.id) {
    console.log("Progress = " + res.progress[1] + "%");
  }
};

let res = await crpc.call({
    method: "CONF",
    params: { file: "sample.rbf" }
  },
  get_progress
);
if (res.result) console.log("FPGA Configured.");
```

- `res` オブジェクトのプロパティ
  - `key`  
  RPCサーバーで任意に割り振られたメソッド実行ナンバーが入ります。 
 
  - `id`  
  実行中のメソッドのid番号が入ります。

  - `cmd`  
  メソッドの識別番号（ペイロードの最初の１バイト）が入ります。

  - `progress`  
  メソッド内の進捗が配列として入ります。値は `0` ～ `100` の範囲でパーセンテージを示します。    
  ほとんどのクエリでは１つの要素の配列となりますが、内部で複数の実行ステージを持つ場合は、それぞれのステージの進捗が入ります。

- `id` と `res.id` の違い  
第一引数の `id` はRPCメソッドでリクエストしたID値が入り、`res.id` に入る値は現在のRPCサーバーで実行されているメソッドのID値が入ります。  
複数あるいはキューイングされたRPC呼び出しが行われていた場合、`CanariumRPC_Client.call()` で呼び出したRPCメソッドと、その時点でRPCサーバーで実行されているRPCメソッドが一致しない場合があることに注意が必要です。

- 異なるドメインから運用する場合の注意  
進捗ステータス取得はFlashAirの `command.cgi` を利用しているため、クロスオリジンHTTPリクエストではエラーが返ります。


---

&copy; 2017,2018 J-7SYSTEM WORKS LIMITED
