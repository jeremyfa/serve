package serve;

import haxe.Json;
import haxe.io.Bytes;

using StringTools;

@:allow(serve.Response)
class ResponseData {

    public var headers(default,null):Headers = new Headers();

    public var status(default,null):Int = 0;

    public var responseText(default,null):String = null;

    public var responseBinary(default,null):Bytes = null;

    public function new() {}

}

@:structInit
class Response {

    public final id:Int;

    public var backendItem:Any;

    public var complete(default, null):Bool;

    public var server(default, null):Server;

    public var request:Request;

    public var data(default,null):ResponseData = new ResponseData();

    var completeHandlers:Array<(req:Request, res:Response)->Void> = null;

    static var _nextResponseId:Int = 0;

    public function new(server:Server, request:Request, ?backendItem:Any) {
        this.id = _nextResponseId++;
        this.complete = false;
        this.server = server;
        this.request = request;
        this.backendItem = backendItem;
    }

    public function status(status:Int):Response {
        data.status = status;
        server.backend.responseStatus(this, status);
        @:privateAccess request.resolved = true;
        return this;
    }

    public function header(name:String, value:String):Response {
        if (complete) throw "Response already complete!";
        data.headers.add(name, value);
        return this;
    }

    public function notFound():Response {
        status(404).text('Not Found');
        return this;
    }

    public function json(content:Dynamic):Response {
        header('Content-Type', 'application/json');
        text(Json.stringify(content));
        return this;
    }

    public function html(html:String):Response {
        header('Content-Type', 'text/html');
        text(html);
        return this;
    }

    public function text(text:String):Response {
        if (complete) throw "Response already complete!";
        var bytes = haxe.io.Bytes.ofString(text);
        header('Content-Length', Std.string(bytes.length));
        data.responseText = text;
        finish();
        return this;
    }

    public function binary(data:Bytes):Response {
        if (complete) throw "Response already complete!";
        header('Content-Length', Std.string(data.length));
        this.data.responseBinary = data;
        finish();
        return this;
    }

    public function redirect(location:String):Void {
        if (complete) throw "Response already complete!";

        status(302);
        header('Location', location);
        data.responseText = '';
        finish();
        @:privateAccess request.resolved = true;
    }

    public function async(callback:(next:()->Void)->Void):Response {
        @:privateAccess request.asyncPending = true;

        final next = () -> {
            @:privateAccess request.asyncPending = false;
            @:privateAccess server.continueFromHandler(request, this);
        };

        callback(next);
        return this;
    }

    public function onComplete(handler:(req:Request, res:Response)->Void):Void {

        if (completeHandlers == null) {
            completeHandlers = [];
        }

        completeHandlers.push(handler);

    }

    function finish():Void {

        if (completeHandlers != null) {
            final handlers = completeHandlers;
            completeHandlers = null;
            for (i in 0...handlers.length) {
                final handler = handlers[i];
                handler(request, this);
            }
        }

        complete = true;
        @:privateAccess request.resolved = true;

        for (name => value in data.headers) {
            server.backend.responseHeader(this, name, value);
        }

        if (data.responseBinary != null) {
            server.backend.responseBinary(this, data.responseBinary);
        }

        if (data.responseText != null) {
            server.backend.responseText(this, data.responseText);
        }

    }

}
