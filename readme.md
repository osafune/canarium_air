Canarium Air
============

Canarium Airパッケージは、FlashAir W-04を利用してIntel FPGAにWebインターフェースを提供します。  

<img src="https://raw.githubusercontent.com/osafune/canarium_air/master/img/canarium_summary.png" width="750" height="336">

このパッケージライブラリで提供する機能は‥‥
1. **FPGAのコンフィグレーション機能**  
オンボードのコンフィグレーションROMは不要、書き換えの手間を省きます。  
クライアント側からの手動コンフィグレーションや、サーバーアクセスによる自律的なアップデートなどが簡単に実現できます。  

2. **FPGA内部のデータアクセス機能**  
Qsysモジュール内部へのI/Oアクセス、メモリアクセスの他、メモリイメージのロード・セーブの機能を提供します。  
Luaスクリプトを使って自動的なセットアップやバッチ処理、他のWebサービスへの連携などが実現できます。

3. **リモートプロシジャコール(RPC)機能**  
クライアント側からはJSON-RPC形式のアクセスを提供します。  
ユーザー側で任意のメソッドを追加することもできます。

全てのコンテンツファイルをFlashAirに格納して運用することができるので、外部に接続のないネットワーク上でもWebのリッチUI・リッチライブラリを使うことができます。  
インストールに特別なツールは使いません。全ファイルをFlashAirへコピーすればすぐに使うことができます。  


また、Canarium Airパッケージと[IFTTT Webhooks](https://ifttt.com/maker_webhooks)を組み合わせれば、例えば大量のセンサーからの情報をFPGAで処理してWebサービスへと連携するような、FPGAエッジコンピューティングをとてもコンパクトに実現できます。  

<img src="https://raw.githubusercontent.com/osafune/canarium_air/master/img/canarium_ifttt.png" width="750" height="370">

※ Canarium Air は [PERIDOT Project](https://github.com/osafune/peridot_newgen) の一環として製作しています。


対象環境
=======

※ 現状はお試しバージョンです。ライブラリの構成やインターフェース等は**予告なく変更される**ことがあります。

- FlashAir W-04 ファーム W4.00.03 以降
- Intel FPGA (CycloneIV E, Cyclone10 LP, MAX10)
- QuartusPrime 17.1 以降

- ターゲットとするユーザー
  - Intel FPGAのプロジェクトビルドおよび、Intel FPGAハードウェア設計の経験がある人
  - FlashAirを使ったハードウェアを作った経験のある人
  - プログラミング言語としてLuaやJavaScriptが使える人


ドキュメントなど
===============

Canarium RPC Client
-------------------

- [Cabarium RPC Client v0.3.0726](crpc_client_doc.md)


Canarium RPC Server
-------------------

- [Canarium RPC Server v0.3.0726](canarium_rpc_doc.md)


Canarium Air I/O
----------------

- [Canarium Air I/O v0.3.0726](canarium_air_doc.md)


ライセンス
=========

[The MIT License (MIT)](https://opensource.org/licenses/MIT)  
Copyright (c) 2017-2019 J-7SYSTEM WORKS LIMITED.
