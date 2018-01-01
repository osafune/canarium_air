// Canarium RPC Client


var Canarium = function(option) {

    // Canarium RPC Clientのバージョン
    const crpc_version = "0.2.0101";

    // Canarium RPC サーバーのタイムアウト時間（デフォルト180秒）
    const xhr_timeout = 180 * 1000;

    // FlashAirの共有メモリ読み出しCGI
    const cgi_getprogress = "/command.cgi?op=130&ADDR=512&LEN=100";

    // RPCサーバーのURLを保存する変数
    let cors_host = "";
    let rpc_server = "/crs.lua";


    //------------------------------------------------------------------------
    // Base64url function
    //------------------------------------------------------------------------

    // Base54url 変換テーブル
    const base64url_list = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";

    // Base64urlのエンコード
    const b64enc = (bin) => {
        let bin_arr = new Uint8Array(bin);
        let str = "";
        let i = 0,
            p = -6,
            a = 0,
            v = 0,
            c;

        while ((i < bin_arr.byteLength) || (p > -6)) {
            if (p < 0) {
                if (i < bin_arr.byteLength) {
                    c = bin_arr[i++];
                    v += 8;
                } else {
                    c = 0;
                }
                a = ((a & 255) << 8) | (c & 255);
                p += 8;
            }
            str += base64url_list.charAt((v > 0) ? (a >> p) & 63 : 64);
            p -= 6;
            v -= 6;
        }

        return str;
    };

    // Base64urlのデコード
    const b64dec = (str) => {
        let res = new Array(); // 速度重視
        let p = -8,
            a = 0,
            c;

        for (let i = 0; i < str.length; i++) {
            if ((c = base64url_list.indexOf(str.charAt(i))) < 0) continue;

            a = (a << 6) | (c & 63);
            if ((p += 6) >= 0) {
                res.push((a >> p) & 0xff);
                a &= 63;
                p -= 8;
            }
        }

        let bin = new ArrayBuffer(res.length);
        let bin_arr = new Uint8Array(bin);
        for (let i = 0; i < res.length; i++) bin_arr[i] = res[i]; //速度重視

        return bin;
    };

    // バイトをHEX文字列に変換
    const toHexstr = (bin) => {
        const toHex = (d, n) => ("0000000" + d.toString(16).toUpperCase()).substr(-n);

        let bin_arr = new Uint8Array(bin);
        let s = "";
        bin_arr.forEach((v) => { s += (' ' + toHex(v, 2)); });

        return s;
    };


    //------------------------------------------------------------------------
    // Canarium RPC local function
    //------------------------------------------------------------------------

    // メソッドで使うローカル関数
    const _push_word32 = (p, d) => {
        p.push((d >> 24) & 0xff);
        p.push((d >> 16) & 0xff);
        p.push((d >> 8) & 0xff);
        p.push((d >> 0) & 0xff);
    };

    const _push_word16 = (p, d) => {
        p.push((d >> 8) & 0xff);
        p.push((d >> 0) & 0xff);
    };

    const _push_str = (p, str) => {
        for (let i = 0; i < str.length; i++) p.push(str.charCodeAt(i));
    };

    const _array_avm = (cmd, devid, addr) => {
        let p = [];
        p.push(cmd);
        p.push(devid & 0xff);
        _push_word32(p, addr);

        return p;
    };


    // CHECKメソッドパケット作成
    const _mm_check = (params) => {
        let p = [];
        p.push(0x01);

        return p;
    };

    // CONFメソッドパケット作成
    const _mm_conf = (params) => {
        let p = [];
        p.push((params.cache === false) ? 0x09 : 0x08);
        _push_str(p, params.file);

        return p;
    };

    // FCONFメソッドパケット作成
    const _mm_fconf = (params) => {
        let p = [];
        p.push(0x09);
        _push_str(p, params.file);

        return p;
    };

    // IOWRメソッドパケット作成
    const _mm_iowr = (params) => {
        let p = _array_avm(0x10, params.devid, params.address);
        _push_word32(p, params.data);

        return p;
    };

    // IORDメソッドパケット作成
    const _mm_iord = (params) => {
        return _array_avm(0x11, params.devid, params.address);
    };

    // MEMWRメソッドパケット作成
    const _mm_memwr = (params) => {
        let p = _array_avm(0x18, params.devid, params.address);

        let data_obj = (typeof(params.data) === "string") ? b64dec(params.data) : params.data;
        let data_arr = new Uint8Array(data_obj);
        if (data_arr.byteLength > 64) return null;

        data_arr.forEach((v) => { p.push(v); });

        return p;
    };

    // MEMRDメソッドパケット作成
    const _mm_memrd = (params) => {
        if (params.size > 256) return null;

        let p = _array_avm(0x19, params.devid, params.address);
        _push_word16(p, params.size);

        return p;
    };
    // MEMRDメソッドのポスト処理
    const _mm_memrd_post = (res) => b64dec(res);

    // BLOADメソッドパケット作成
    const _mm_bload = (params) => {
        let p = _array_avm(0x20, params.devid, params.address);
        _push_str(p, params.file);

        return p;
    };

    // BSAVEメソッドパケット作成
    const _mm_bsave = (params) => {
        let p = _array_avm(0x21, params.devid, params.address);
        _push_word32(p, params.size);
        _push_str(p, params.file);

        return p;
    };

    // LOADメソッドパケット作成
    const _mm_load = (params) => {
        let p = _array_avm(0x22, params.devid, params.offset);
        _push_str(p, params.file);

        return p;
    };


    //------------------------------------------------------------------------
    // Canarium RPC function
    //------------------------------------------------------------------------

    // RPCエラーラベル
    const ERROR_JSON = { code: -32700, message: "Parse error" };
    const ERROR_METHOD = { code: -32601, message: "Method not found" };
    const ERROR_PARAM = { code: -32602, message: "Invalid params" };

    // デフォルトのポスト処理
    const _post_default = (res) => res;

    // メソッドテーブル
    let method = {
        VER: { pfunc: _post_default },
        CHECK: { qfunc: _mm_check, pfunc: _post_default },
        CONF: { qfunc: _mm_conf, pfunc: _post_default },
        FCONF: { qfunc: _mm_fconf, pfunc: _post_default },
        IOWR: { qfunc: _mm_iowr, pfunc: _post_default },
        IORD: { qfunc: _mm_iord, pfunc: _post_default },
        MEMWR: { qfunc: _mm_memwr, pfunc: _post_default },
        MEMRD: { qfunc: _mm_memrd, pfunc: _mm_memrd_post },
        BLOAD: { qfunc: _mm_bload, pfunc: _post_default },
        BSAVE: { qfunc: _mm_bsave, pfunc: _post_default },
        LOAD: { qfunc: _mm_load, pfunc: _post_default }
    };

    // メソッド追加と削除
    const addmethod = (name, qfunc, pfunc) => {
        if (typeof(name) !== "string" || (qfunc && typeof(qfunc) !== "function")) return false;

        if (qfunc) {
            method[name] = {
                qfunc: qfunc,
                pfunc: (typeof(pfunc) === "function") ? pfunc : _post_default
            };
        } else {
            delete method[name];
        }

        console.log(method);
        return true;
    };


    // オブジェクトからCanarium RPCクエリを取得
    let auto_id_number = 1; // 自動で割り振るID番号

    const getquery = (t) => {

        // パラメータのチェックと成形　//
        if (typeof(t.id) === "number") {
            if (t.id >= 0 && t.id <= 65535) auto_id_number = t.id;
            else return ERROR_JSON;
        } else {
            t.id = auto_id_number;
        }
        auto_id_number = (auto_id_number >= 65535) ? 0 : auto_id_number + 1;

        if (!t.method) return ERROR_JSON;

        let params = Object.assign({}, t.params);
        params.devid = (t.params && typeof(t.params.devid) === "number") ? t.params.devid : 0x55;
        params.address = (t.params && typeof(t.params.address) === "number") ? t.params.address : 0;
        params.offset = (t.params && typeof(t.params.offset) === "number") ? t.params.offset : params.address;

        // ペイロード生成 //
        if (t.method === "VER") return "";
        if (!method[t.method]) return ERROR_METHOD;

        let payload = method[t.method].qfunc(params);
        if (!payload || payload.length > 70) return ERROR_PARAM;

        // パケット生成 //
        let bin = new ArrayBuffer(payload.length + 4);
        let bin_arr = new Uint8Array(bin);

        bin_arr[0] = (t.id >> 8) & 0xff;
        bin_arr[1] = (t.id >> 0) & 0xff;
        bin_arr[2] = payload.length;

        let xsum = 0;
        payload.forEach((v, i) => {
            xsum = (v ^ ((xsum << 1) | ((xsum & 0x80) ? 1 : 0))) & 0xff;
            bin_arr[i + 4] = v;
        });
        bin_arr[3] = xsum;

        console.log("packet :" + toHexstr(bin));
        return b64enc(bin);
    };


    // Canarium RPCの呼び出し
    const crpc_call = (t, prog_callback, prog_time) => {
        return new Promise((resolve, reject) => {

            // 進捗度コールバック処理
            let rpc_busy = true;
            const call_progress = (id, callback, nexttime) => {
                if (rpc_busy) {
                    const xhr = new XMLHttpRequest();
                    xhr.open("GET", cors_host + cgi_getprogress);
                    xhr.onerror = () => {
                        console.error("commang.cgi request error.");
                    };
                    xhr.onload = () => {
                        if (xhr.responseText) callback(id, JSON.parse(xhr.responseText));
                        setTimeout(() => {
                            call_progress(id, callback, nexttime);
                        }, nexttime);
                    };
                    xhr.send();
                }
            };

            // RPCリクエスト処理
            let ot = (typeof(t) === "string") ? JSON.parse(t) : t;
            let query = (typeof(t) === "string" && ot.jsonrpc !== "2.0") ? ERROR_JSON : getquery(ot);

            if (typeof(query) === "string") {
                console.log("JSON-RPC --> ", ot);

                const xhr = new XMLHttpRequest();
                xhr.open("GET", cors_host + rpc_server + "?" + query);
                xhr.timeout = xhr_timeout;
                xhr.ontimeout = () => {
                    console.error("RPC call timed out.");
                    rpc_busy = false;
                    reject(new Error(xhr.statusText));
                };
                xhr.onerror = () => {
                    console.error("RPC call request error.");
                    rpc_busy = false;
                    reject(new Error(xhr.statusText));
                };
                xhr.onload = () => {
                    let res = xhr.responseText;
                    console.log("JSON-RPC <-- ", JSON.parse(res));

                    if (typeof(t) !== "string") {
                        res = JSON.parse(res);
                        if (res.result) res.result = method[ot.method].pfunc(res.result);
                    }

                    rpc_busy = false;
                    resolve(res);
                };
                xhr.send();

                let nexttime = (typeof(prog_time) !== "number") ? 500 : (prog_time < 100) ? 100 : prog_time;
                if (typeof(prog_callback) === "function") {
                    setTimeout(() => {
                        call_progress(ot.id, prog_callback, nexttime);
                    }, nexttime);
                }

            } else {
                const res = {
                    jsonrpc: "2.0",
                    error: query,
                    id: ot.id
                };

                rpc_busy = false;
                resolve((typeof(t) === "string") ? JSON.stringify(res) : res);
            }
        });
    };


    //------------------------------------------------------------------------
    // Constructor
    //------------------------------------------------------------------------

    this.version = () => crpc_version;
    this.settings = (host, rpc) => {
        cors_host = host;
        rpc_server = rpc;
    };

    this.addmethod = addmethod;
    this.call = crpc_call;

    this.encode = b64enc;
    this.decode = b64dec;
    this.query = getquery;

    this.dbglog = toHexstr;
};