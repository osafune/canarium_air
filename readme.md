Canarium Air
============

Canarium Airパッケージは、FlashAir W-04を利用してIntel FPGAにWebインターフェースを提供します。
![about](https://raw.githubusercontent.com/osafune/canarium_air/master/img/canarium_summary.png = 500x)  

このパッケージライブラリで提供する機能は‥‥
1. FPGAのコンフィグレーション機能  
オンボードのコンフィグレーションROMは不要、書き換えの手間を省きます。  
クライアント側からの手動コンフィグレーションや、サーバーアクセスによる自律的なアップデートなどが簡単に実現できます。  

2. FPGA内部のデータアクセス機能  
Qsysモジュール内部へのI/Oアクセス、メモリアクセスの他、メモリイメージのロード・セーブの機能を提供します。  
Luaスクリプトを使って自動的なセットアップやバッチ処理、他のWebサービスへの連携などが実現できます。

3. リモートプロシジャコール(RPC)機能  
クライアント側からはJSON-RPC形式のアクセスを提供します。


また、全てのコンテンツファイルをFlashAirに格納して運用することができるので、外部に接続のないネットワーク上でもWebのリッチUI・リッチライブラリを使うことができます。  

FlashAirそのものの機能でもあるIoT Hubも同時に使うことができるので、大量のセンサーからの情報をFPGAで処理してWebサービスへ連携する、FPGAエッジコンピューティングを実現します。  
![exsample](https://raw.githubusercontent.com/osafune/canarium_air/master/img/canarium_ifttt.png = 500x)

現状はお試しバージョンです。

対象環境
=======

- FlashAir W-04 ファームW4.00.01
- Intel FPGA (CycloneIV E, Cyclone10 LP, MAX10)
- QuartusPrime 17.0以降

- ターゲットとするユーザー
  - Intel FPGAのプロジェクトビルドおよび、Intel FPGAハードウェア設計の経験がある人
  - FlashAirを使ったハードウェアを作った経験のある人
  - プログラミング言語としてLuaが使える人


ドキュメントなど
===============

Canarium RPC Client
-------------------

- まだ

Canarium RPC Server
-------------------

- [Canarium RPC v0.1.1124](canarium_rpc_doc.md)


Canarium Air I/O
----------------

- [Canarium Air I/O v0.1.1120](canarium_rpc_doc.md)


ライセンス
=========

[The MIT License (MIT)](https://opensource.org/licenses/MIT)  
Copyright (c) 2017 J-7SYSTEM WORKS LIMITED
