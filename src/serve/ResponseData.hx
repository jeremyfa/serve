package serve;

import haxe.io.Bytes;

@:allow(serve.Response)
class ResponseData {

    public var headers(default,null):Headers = new Headers();

    public var status(default,null):Int = 200;

    public var responseText(default,null):String = null;

    public var responseBinary(default,null):Bytes = null;

    public function new() {}

}
