package serve;

#if php

import haxe.Json;
import haxe.io.Bytes;
import php.NativeArray;
import php.Syntax;

using StringTools;

class PhpBackend implements Backend implements SyncFileBackend {

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
        var rawBody:Dynamic = Syntax.code("file_get_contents('php://input')");
        var body:Dynamic = null;
        if (contentType == 'application/json') {
            body = Json.parse(rawBody);
        }
        else {
            body = {};
            for (key => val in (Syntax.code("$_POST"):NativeArray)) {
                Reflect.setField(body, key, val);
            }
        }

        // Request uri
        var uri:String = Syntax.code("$_SERVER[\"REQUEST_URI\"]").split('?')[0];

        // Normalize URI: ensure it starts with / and is properly formatted
        if (!uri.startsWith('/')) {
            uri = '/' + uri;
        }

        // Normalize path to resolve . and .. segments
        uri = haxe.io.Path.normalize(uri);

        // Remove trailing slash (except for root)
        if (uri.length >= 2 && uri.endsWith('/')) {
            uri = uri.substring(0, uri.length - 1);
        }

        // Request method
        final method:HttpMethod = switch (Syntax.code("$_SERVER[\"REQUEST_METHOD\"]"):String) {
            case "POST": POST;
            case "PUT": PUT;
            case "DELETE": DELETE;
            case "HEAD": HEAD;
            case _: GET;
        }

        // Parse host and port from Host header
        var reqHost:String = host();
        var reqPort:Int = port();
        final hostHeader = headers.get('Host');
        if (hostHeader != null && hostHeader.length > 0) {
            final colonIdx = hostHeader.lastIndexOf(':');
            if (colonIdx > 0) {
                reqHost = hostHeader.substring(0, colonIdx);
                final portStr = hostHeader.substring(colonIdx + 1);
                final parsedPort = Std.parseInt(portStr);
                if (parsedPort != null) {
                    reqPort = parsedPort;
                }
            } else {
                reqHost = hostHeader;
            }
        }

        // Full request object
        final req:Request = {
            server: server,
            uri: uri,
            method: method,
            params: params,
            query: query,
            body: body,
            rawBody: rawBody,
            headers: headers,
            host: reqHost,
            port: reqPort
        };

        // Initial response object
        final res:Response = new Response(server, req);

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

    public function responseBinary(response:Response, data:Bytes):Void {
        // PHP echo can handle binary data directly
        Syntax.code('echo {0}', data.toString());
    }

    public function fileExists(path:String):Bool {
        return Syntax.code('file_exists({0})', path);
    }

    public function isDirectory(path:String):Bool {
        return Syntax.code('is_dir({0})', path);
    }

    public function readFile(path:String):String {
        return Syntax.code('file_get_contents({0})', path);
    }

    public function readBinaryFile(path:String):Bytes {
        var content:String = Syntax.code('file_get_contents({0})', path);
        return Bytes.ofString(content);
    }

    public function getFileMTime(path:String):Float {
        return Syntax.code('filemtime({0})', path);
    }

    public function getFileSize(path:String):Int {
        return Syntax.code('filesize({0})', path);
    }

    public function readBinaryFileRange(path:String, start:Int, end:Int):Bytes {
        var length = end - start + 1;
        var handle:Dynamic = Syntax.code('fopen({0}, "rb")', path);
        Syntax.code('fseek({0}, {1})', handle, start);
        var content:String = Syntax.code('fread({0}, {1})', handle, length);
        Syntax.code('fclose({0})', handle);
        return Bytes.ofString(content);
    }

}

#end
