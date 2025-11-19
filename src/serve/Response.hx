package serve;

import haxe.Json;
import haxe.io.Bytes;

using StringTools;

@:structInit
class Response {

    public final id:Int;

    public var backendItem:Any;

    public var sent(default, null):Bool;

    public var server(default, null):Server;

    public var request:Request;

    static var _nextResponseId:Int = 0;

    public function new(server:Server, request:Request, ?backendItem:Any) {
        this.id = _nextResponseId++;
        this.sent = false;
        this.server = server;
        this.request = request;
        this.backendItem = backendItem;
    }

    public function status(status:Int):Response {
        server.backend.responseStatus(this, status);
        @:privateAccess request.resolved = true;
        return this;
    }

    public function header(name:String, value:String):Response {
        if (sent) throw "Response already sent!";

        server.backend.responseHeader(this, name, value);
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
        if (sent) throw "Response already sent!";

        // Set Content-Length header for proper HTTP response
        var bytes = haxe.io.Bytes.ofString(text);
        header('Content-Length', Std.string(bytes.length));
        server.backend.responseText(this, text);
        sent = true;
        @:privateAccess request.resolved = true;
        return this;
    }

    public function binary(data:Bytes):Response {
        if (sent) throw "Response already sent!";

        // Set Content-Length header for proper HTTP response
        header('Content-Length', Std.string(data.length));
        server.backend.responseBinary(this, data);
        sent = true;
        @:privateAccess request.resolved = true;
        return this;
    }

    public function redirect(location:String):Void {
        if (sent) throw "Response already sent!";

        status(302);
        header('Location', location);
        server.backend.responseText(this, '');
        sent = true;
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

}
