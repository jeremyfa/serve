package serve;

#if nodejs

import haxe.Json;
import haxe.io.Bytes;
import js.node.Buffer;
import js.node.Fs;
import js.node.Http;
import js.node.http.IncomingMessage;
import js.node.http.Server as NodeServer;
import js.node.http.ServerResponse;
import js.node.url.URL;

using StringTools;

class NodeJsBackend implements Backend implements AsyncFileBackend {

    var nodeServer:NodeServer;
    var serverHost:String = "localhost";
    var serverPort:Int = 3000;

    public function new(?port:Int = 3000, ?host:String = "localhost") {
        this.serverPort = port;
        this.serverHost = host;
    }

    public function start(server:Server):Void {

        // Create HTTP server
        nodeServer = Http.createServer(function(req:IncomingMessage, res:ServerResponse) {
            handleNodeRequest(req, res, server);
        });

        #if serve_debug
        // Add error and connection event handlers for debugging
        nodeServer.on('connection', function(socket:Dynamic) {
            trace('New connection from: ${socket.remoteAddress}:${socket.remotePort}');

            socket.on('error', function(err:Dynamic):Void {
                trace('Socket error: $err');
            });

            socket.on('close', function():Void {
                trace('Socket closed');
            });
        });
        #end

        nodeServer.on('error', function(err:Dynamic) {
            trace('Server error: $err');
        });

        // Start listening
        // Listen on all interfaces (0.0.0.0) instead of just localhost
        // This ensures compatibility with clients that might use 127.0.0.1 or localhost
        var listenHost = (serverHost == "localhost" || serverHost == "127.0.0.1") ? "0.0.0.0" : serverHost;
        nodeServer.listen(serverPort, listenHost, function() {
            #if serve_debug
            trace('Server running at http://$serverHost:$serverPort/ (listening on $listenHost:$serverPort)');
            #end
        });
    }

    function handleNodeRequest(nodeReq:IncomingMessage, nodeRes:ServerResponse, server:Server):Void {

        // Parse URL using the newer URL API
        final fullUrl = 'http://$serverHost:$serverPort${nodeReq.url}';
        final parsedUrl = new URL(fullUrl);
        var uri = parsedUrl.pathname;

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

        // Parse headers
        final headers:Map<String,String> = new Map();
        for (key in Reflect.fields(nodeReq.headers)) {
            var value = Reflect.field(nodeReq.headers, key);
            // Node.js headers can be strings or arrays; we'll take the first value if array
            if (Std.isOfType(value, Array)) {
                value = cast(value, Array<Dynamic>)[0];
            }
            headers.set(Utils.normalizeHeaderName(key), Std.string(value));
        }

        // Parse query parameters using custom parser for array support
        final query:Dynamic<String> = {};
        var queryString = parsedUrl.search;
        if (queryString != null && queryString.length > 0) {
            // Remove leading '?' if present
            if (queryString.charAt(0) == '?') {
                queryString = queryString.substring(1);
            }
            // Use Utils.parseQueryString to properly handle array notation
            var parsedQuery = Utils.parseQueryString(queryString);
            // Copy parsed fields to query object
            for (field in Reflect.fields(parsedQuery)) {
                Reflect.setField(query, field, Reflect.field(parsedQuery, field));
            }
        }

        // Parse method
        final method:HttpMethod = switch (nodeReq.method) {
            case "POST": POST;
            case "PUT": PUT;
            case "DELETE": DELETE;
            case "HEAD": HEAD;
            case _: GET;
        }

        // Default route params
        final params:Dynamic<String> = {};

        // Get content type
        var contentType = headers.get('Content-Type');
        if (contentType != null) {
            contentType = contentType.split(';')[0].rtrim();
        }

        // Collect body data
        var bodyData = "";

        nodeReq.on('data', function(chunk:Buffer) {
            bodyData += chunk.toString();
        });

        nodeReq.on('end', function() {
            // Parse body
            var body:Dynamic = null;

            if (method == POST || method == PUT) {
                if (bodyData.length > 0) {
                    if (contentType == 'application/json') {
                        try {
                            body = Json.parse(bodyData);
                        }
                        catch (e:Dynamic) {
                            trace('Failed to parse JSON body: $e');
                            body = {};
                        }
                    }
                    else if (contentType == 'application/x-www-form-urlencoded') {
                        // Parse URL-encoded form data
                        body = Utils.parseQueryString(bodyData);
                    }
                    else {
                        // For other content types, leave body as empty object to match PHP backend behavior
                        body = {};
                    }
                } else {
                    body = {};
                }
            }

            // Create request object
            final req:Request = {
                server: server,
                uri: uri,
                method: method,
                params: params,
                query: query,
                body: body,
                rawBody: bodyData,
                headers: headers,
                backendItem: nodeReq
            };

            // Create response object
            final res:Response = new Response(server, req, nodeRes);

            // Handle the request
            server.handleRequest(req, res);
        });

        nodeReq.on('error', function(err) {
            nodeRes.statusCode = 400;
            nodeRes.end('Bad Request');
        });
    }

    public function host():String {
        return serverHost;
    }

    public function port():Int {
        return serverPort;
    }

    public function responseStatus(response:Response, status:Int):Void {
        var nodeRes:ServerResponse = cast response.backendItem;
        nodeRes.statusCode = status;
    }

    public function responseHeader(response:Response, name:String, value:String):Void {
        var nodeRes:ServerResponse = cast response.backendItem;
        nodeRes.setHeader(name, value);
    }

    public function responseText(response:Response, text:String):Void {
        var nodeRes:ServerResponse = cast response.backendItem;
        nodeRes.end(text);
    }

    public function responseBinary(response:Response, data:Bytes):Void {
        var nodeRes:ServerResponse = cast response.backendItem;
        // Convert Bytes to Buffer and send
        var buffer = Buffer.from(data.getData());
        nodeRes.end(buffer);
    }

    public function fileExistsAsync(path:String, callback:(exists:Bool)->Void):Void {
        Fs.access(path, (err) -> {
            callback(err == null);
        });
    }

    public function isDirectoryAsync(path:String, callback:(isDir:Bool)->Void):Void {
        Fs.stat(path, (err, stats) -> {
            if (err != null) {
                callback(false);
            } else {
                callback(stats.isDirectory());
            }
        });
    }

    public function readFileAsync(path:String, callback:(error:Dynamic, content:String)->Void):Void {
        Fs.readFile(path, {encoding: 'utf8'}, callback);
    }

    public function readBinaryFileAsync(path:String, callback:(error:Dynamic, content:Bytes)->Void):Void {
        Fs.readFile(path, (err, buffer) -> {
            if (err != null) {
                callback(err, null);
            } else {
                callback(null, buffer.hxToBytes());
            }
        });
    }

    public function getFileMTimeAsync(path:String, callback:(error:Dynamic, mtime:Float)->Void):Void {
        Fs.stat(path, (err, stats) -> {
            if (err != null) {
                callback(err, 0);
            } else {
                callback(null, stats.mtime.getTime());
            }
        });
    }

    public function getFileSizeAsync(path:String, callback:(error:Dynamic, size:Int)->Void):Void {
        Fs.stat(path, (err, stats) -> {
            if (err != null) {
                callback(err, 0);
            } else {
                callback(null, Std.int(stats.size));
            }
        });
    }

}

#end