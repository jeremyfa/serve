package serve;

import haxe.Json;

@:structInit
class Response {

    public var backendItem:Any;

    public var server(default, null):Server;

    public var request:Request;

    public function new(server:Server, request:Request, ?backendItem:Any) {
        this.server = server;
        this.request = request;
        this.backendItem = backendItem;
    }

    public function status(status:Int):Response {
        server.backend.responseStatus(this, status);
        return this;
    }

    public function header(name:String, value:String):Response {
        server.backend.responseHeader(this, name, value);
        return this;
    }

    public function json(content:Dynamic):Response {
        header('Content-Type', 'application/json');
        text(Json.stringify(content));
        return this;
    }

    public function html(html:String):Response {
        header('Content-Type', 'text/html');
        server.backend.responseText(this, html);
        return this;
    }

    public function notFound():Response {
        status(404).text('Not Found');
        return this;
    }

    public function text(text:String):Response {
        server.backend.responseText(this, text);
        return this;
    }

    public function redirect(location:String):Void {
        status(302);
        header('Location', location);
        server.backend.responseText(this, '');
    }

    public function async(callback:(next:()->Void)->Void):Response {
        @:privateAccess request.asyncPending = true;

        final next = () -> {
            @:privateAccess request.asyncPending = false;
            @:privateAccess server.continueFromHandler(request, this, @:privateAccess request.nextHandlerIndex);
        };

        callback(next);
        return this;
    }

}
