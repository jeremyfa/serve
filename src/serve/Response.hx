package serve;

import haxe.Json;
import haxe.io.Bytes;

using StringTools;

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

    public function binary(data:Bytes):Response {
        server.backend.responseBinary(this, data);
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

    public function sendFile(filePath:String):Response {
        // Check which type of backend we have
        if (Std.isOfType(server.backend, SyncFileBackend)) {
            var syncBackend:SyncFileBackend = cast server.backend;

            if (!syncBackend.fileExists(filePath)) {
                return notFound();
            }

            if (syncBackend.isDirectory(filePath)) {
                return notFound();
            }

            // Get file extension and determine content type
            var ext = haxe.io.Path.extension(filePath).toLowerCase();
            var contentType = MimeTypes.getContentType(ext);

            // Set content type header
            header('Content-Type', contentType);

            // Check if this is a binary file type
            if (isBinaryContent(contentType)) {
                // Read and send binary content
                var content = syncBackend.readBinaryFile(filePath);
                binary(content);
            } else {
                // Read and send text content
                var content = syncBackend.readFile(filePath);
                text(content);
            }
        } else if (Std.isOfType(server.backend, AsyncFileBackend)) {
            // For async backend, we need to use async operations
            // This is more complex and should ideally be handled through Static handler
            // For now, throw an error to indicate async file operations should use Static
            throw "sendFile() with async backend not implemented. Use Static handler for async file serving.";
        } else {
            return notFound();
        }

        return this;
    }

    function isBinaryContent(contentType:String):Bool {
        // Text-based content types
        if (contentType.startsWith("text/")) return false;
        if (contentType == "application/json") return false;
        if (contentType == "application/javascript") return false;
        if (contentType == "application/xml") return false;
        if (contentType.endsWith("+xml")) return false;
        if (contentType.endsWith("+json")) return false;

        // Everything else is considered binary
        return true;
    }

}
