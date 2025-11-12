package serve;

#if php

import haxe.Json;
import php.NativeArray;
import php.Syntax;

using StringTools;

class PhpBackend implements Backend {

    public function new() {}

    public function start(server:Server):Void {

        // Headers
        final headers:Map<String,String> = new Map();
        for (key => val in (Syntax.code("getallheaders()"):NativeArray)) {
            headers.set(Utils.normalizeHeaderName(key), val);
        }

        // Default route params
        final params:Dynamic<String> = {};

        // Query string params
        final query:Dynamic<String> = {};
        for (key => val in (Syntax.code("$_GET"):NativeArray)) {
            Reflect.setField(query, key, val);
        }

        // Content type
        final contentType = headers.get('Content-Type').split(';')[0].rtrim();

        // Body parsing
        var body:Dynamic = null;
        if (contentType == 'application/json') {
            body = Json.parse(Syntax.code("file_get_contents('php://input')"));
        }
        else {
            body = {};
            for (key => val in (Syntax.code("$_POST"):NativeArray)) {
                Reflect.setField(body, key, val);
            }
        }

        // Request uri
        final uri:String = Syntax.code("$_SERVER[\"REQUEST_URI\"]").split('?')[0];

        // Request method
        final method:HttpMethod = switch (Syntax.code("$_SERVER[\"REQUEST_METHOD\"]"):String) {
            case "POST": POST;
            case "PUT": PUT;
            case "DELETE": DELETE;
            case _: GET;
        }

        // Full request object
        final req:Request = {
            server: server,
            uri: uri,
            method: method,
            params: params,
            query: query,
            body: body,
            headers: headers
        };

        // Initial response object
        final res:Response = {
            server: server
        };

        // Handle request
        server.handleRequest(req, res);

    }

    public function host():String {
        return Syntax.code("$_SERVER[\"SERVER_NAME\"]");
    }

    public function port():Int {
        return Syntax.code("intval($_SERVER[\"SERVER_PORT\"])");
    }

    public function responseStatus(response:Response, status:Int):Void {
        Syntax.code('http_response_code({0})', status);
    }

    public function responseHeader(response:Response, name:String, value:String):Void {
        Syntax.code('header({0})', '$name: $value');
    }

    public function responseText(response:Response, text:String):Void {
        Syntax.code('echo {0}', text);
    }

}

#end
