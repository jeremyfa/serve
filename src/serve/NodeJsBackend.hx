package serve;

#if nodejs

import haxe.Json;
import haxe.io.Bytes;
import js.node.Buffer;
import js.node.Http;
import js.node.Querystring;
import js.node.http.IncomingMessage;
import js.node.http.Server as NodeServer;
import js.node.http.ServerResponse;
import js.node.url.URL;

using StringTools;

class NodeJsBackend implements Backend {

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

        // Start listening
        nodeServer.listen(serverPort, serverHost, function() {
            trace('Server running at http://$serverHost:$serverPort/');
        });
    }

    function handleNodeRequest(nodeReq:IncomingMessage, nodeRes:ServerResponse, server:Server):Void {

        // Parse URL using the newer URL API
        final fullUrl = 'http://$serverHost:$serverPort${nodeReq.url}';
        final parsedUrl = new URL(fullUrl);
        final uri = parsedUrl.pathname;

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

        // Parse query parameters from URL searchParams
        final query:Dynamic<String> = {};
        parsedUrl.searchParams.forEach(function(value, key) {
            Reflect.setField(query, key, value);
        });

        // Parse method
        final method:HttpMethod = switch (nodeReq.method) {
            case "POST": POST;
            case "PUT": PUT;
            case "DELETE": DELETE;
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
                        body = {};
                        var parsed = Querystring.parse(bodyData);
                        for (key in Reflect.fields(parsed)) {
                            Reflect.setField(body, key, Reflect.field(parsed, key));
                        }
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
                headers: headers,
                backendItem: nodeReq
            };

            // Create response object
            final res:Response = {
                server: server,
                backendItem: nodeRes
            };

            // Handle the request
            server.handleRequest(req, res);
        });

        nodeReq.on('error', function(err) {
            trace('Request error: $err');
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

}

#end