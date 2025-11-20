package serve;

#if cpp

import haxe.Json;
import haxe.Timer;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import sys.FileSystem;
import sys.io.File;
import sys.net.Host;
import sys.net.Socket;
import sys.thread.Deque;
import sys.thread.Thread;

using StringTools;

typedef CppPendingRequest = {
    clientSocket: Socket,
    method: String,
    uri: String,
    headers: Map<String,String>,
    body: Dynamic,
    rawBody: Dynamic,
    queryString: String,
    timestamp: Float
}

typedef CppResponseData = {
    status: Int,
    headers: Array<{name:String, value:String}>,
    content: StringBuf,
    binaryContent: Null<Bytes>  // Separate field for binary data
}

typedef CppAsyncCallback = {
    callback: ()->Void
}

enum CppFileOperation {
    FileExists(path:String, id:Int);
    IsDirectory(path:String, id:Int);
    ReadFile(path:String, id:Int);
    ReadBinaryFile(path:String, id:Int);
    GetFileMTime(path:String, id:Int);
    GetFileSize(path:String, id:Int);
}

typedef CppFileJob = {
    operation: CppFileOperation
}

class CppBackend implements Backend implements AsyncFileBackend {

    static inline var REQUEST_TIMEOUT_SECONDS:Float = 30.0;

    var serverSocket:Socket;
    var acceptThread:Thread;
    var fileIOThread:Thread;
    var requestQueue:Deque<CppPendingRequest>;
    var callbackQueue:Deque<CppAsyncCallback>;
    var fileJobQueue:Deque<CppFileJob>;
    var activeRequests:Map<Socket, Float>; // Socket -> timestamp
    var pendingFileJobs:Map<Int, Dynamic>; // Job ID -> callback
    var nextJobId:Int = 0;
    var serverHost:String;
    var serverPort:Int;
    var isRunning:Bool = true;

    public function new(?port:Int = 8080, ?host:String = "localhost") {
        this.serverPort = port;
        this.serverHost = host;
        this.requestQueue = new Deque();
        this.callbackQueue = new Deque();
        this.fileJobQueue = new Deque();
        this.activeRequests = new Map();
        this.pendingFileJobs = new Map();
    }

    public function start(server:Server):Void {
        // Setup server socket
        serverSocket = new Socket();

        // Listen on all interfaces (0.0.0.0) instead of just localhost
        // This ensures compatibility with clients that might use 127.0.0.1 or localhost
        var listenHost = serverHost; //(serverHost == "localhost" || serverHost == "127.0.0.1") ? "0.0.0.0" : serverHost;
        serverSocket.bind(new Host(listenHost), serverPort);
        serverSocket.listen(10);

        #if serve_debug
        trace('C++ Server listening on $serverHost:$serverPort' +
              (listenHost != serverHost ? ' (binding to $listenHost:$serverPort)' : ''));
        #end

        // Start accept thread for handling connections
        acceptThread = Thread.create(() -> {
            acceptLoop();
        });

        // Start file I/O thread for handling file operations
        fileIOThread = Thread.create(() -> {
            fileIOLoop();
        });

        // Process requests in main thread
        processRequestsLoop(server);
    }

    function acceptLoop():Void {
        #if serve_debug
        trace('Accept thread started');
        #end
        while (isRunning) {
            try {
                #if serve_debug
                trace('Waiting for connection...');
                #end
                // Accept new connection
                var client = serverSocket.accept();
                #if serve_debug
                trace('Connection accepted from client');
                #end

                // Parse HTTP request in accept thread to avoid blocking main thread
                var request = parseHttpRequest(client);
                #if serve_debug
                trace('Request parsed: ${request != null ? request.uri : "null"}');
                #end

                if (request != null) {
                    // Add to queue for main thread processing
                    requestQueue.add(request);
                    #if serve_debug
                    trace('Request added to queue');
                    #end
                } else {
                    // Invalid request, close connection
                    #if serve_debug
                    trace('Invalid request, closing connection');
                    #end
                    client.close();
                }
            } catch (e:Dynamic) {
                if (isRunning) {
                    #if serve_debug
                    trace('Accept error: $e');
                    #end
                }
            }
        }
        #if serve_debug
        trace('Accept thread ending');
        #end
    }

    function fileIOLoop():Void {
        #if serve_debug
        trace('File I/O thread started');
        #end

        while (isRunning) {
            var job = fileJobQueue.pop(true); // Blocking pop
            if (job != null) {
                processFileJob(job);
            }
        }

        #if serve_debug
        trace('File I/O thread ending');
        #end
    }

    function processFileJob(job:CppFileJob):Void {
        switch (job.operation) {
            case FileExists(path, id):
                var exists = FileSystem.exists(path);
                callbackQueue.add({
                    callback: () -> {
                        var cb = pendingFileJobs.get(id);
                        if (cb != null) {
                            pendingFileJobs.remove(id);
                            (cb:((exists:Bool)->Void))(exists);
                        }
                    }
                });

            case IsDirectory(path, id):
                var isDir = false;
                try {
                    isDir = FileSystem.isDirectory(path);
                } catch (_:Dynamic) {}
                callbackQueue.add({
                    callback: () -> {
                        var cb = pendingFileJobs.get(id);
                        if (cb != null) {
                            pendingFileJobs.remove(id);
                            (cb:((isDir:Bool)->Void))(isDir);
                        }
                    }
                });

            case ReadFile(path, id):
                var err:Dynamic = null;
                var content:String = null;
                try {
                    content = File.getContent(path);
                } catch (e:Dynamic) {
                    err = e;
                }
                callbackQueue.add({
                    callback: () -> {
                        var cb = pendingFileJobs.get(id);
                        if (cb != null) {
                            pendingFileJobs.remove(id);
                            (cb:((error:Dynamic, content:String)->Void))(err, content);
                        }
                    }
                });

            case ReadBinaryFile(path, id):
                var err:Dynamic = null;
                var content:Bytes = null;
                try {
                    content = File.getBytes(path);
                } catch (e:Dynamic) {
                    err = e;
                }
                callbackQueue.add({
                    callback: () -> {
                        var cb = pendingFileJobs.get(id);
                        if (cb != null) {
                            pendingFileJobs.remove(id);
                            (cb:((error:Dynamic, content:Bytes)->Void))(err, content);
                        }
                    }
                });

            case GetFileMTime(path, id):
                var err:Dynamic = null;
                var mtime:Float = 0;
                try {
                    var stat = FileSystem.stat(path);
                    mtime = stat.mtime.getTime();
                } catch (e:Dynamic) {
                    err = e;
                }
                callbackQueue.add({
                    callback: () -> {
                        var cb = pendingFileJobs.get(id);
                        if (cb != null) {
                            pendingFileJobs.remove(id);
                            (cb:((error:Dynamic, mtime:Float)->Void))(err, mtime);
                        }
                    }
                });

            case GetFileSize(path, id):
                var err:Dynamic = null;
                var size:Int = 0;
                try {
                    var stat = FileSystem.stat(path);
                    size = stat.size;
                } catch (e:Dynamic) {
                    err = e;
                }
                callbackQueue.add({
                    callback: () -> {
                        var cb = pendingFileJobs.get(id);
                        if (cb != null) {
                            pendingFileJobs.remove(id);
                            (cb:((error:Dynamic, size:Int)->Void))(err, size);
                        }
                    }
                });
        }
    }

    function processRequestsLoop(server:Server):Void {
        #if serve_debug
        trace('Starting request processing loop');
        #end

        // Simple polling loop for processing requests
        while (isRunning) {
            // Process pending requests
            var request = requestQueue.pop(false); // Non-blocking pop
            if (request != null) {
                #if serve_debug
                trace('Processing request: ${request.uri}');
                #end
                processRequest(request, server);
            }

            // Process event loop
            Thread.current().events.progress();

            // Process pending callbacks from async operations
            var callback = callbackQueue.pop(false);
            while (callback != null) {
                callback.callback();
                callback = callbackQueue.pop(false);
            }

            // Check for timed-out requests periodically
            checkForTimeouts();

            // Sleep briefly if nothing to do
            if (request == null && callback == null) {
                Sys.sleep(0.001); // 1ms
            }
        }
    }

    function processRequest(pending:CppPendingRequest, server:Server):Void {
        try {
            // Parse query parameters
            var query:Dynamic = {};
            if (pending.queryString != null && pending.queryString != "") {
                query = Utils.parseQueryString(pending.queryString);
            }

            // Create Request object
            var req:Request = {
                server: server,
                uri: pending.uri,
                method: parseMethod(pending.method),
                params: {},
                query: query,
                body: pending.body,
                rawBody: pending.rawBody,
                headers: pending.headers,
                backendItem: pending.clientSocket
            };

            // Create Response object with buffer for accumulating response
            var responseData:CppResponseData = {
                status: 200,
                headers: [],
                content: new StringBuf(),
                binaryContent: null
            };

            var res = new Response(server, req, responseData);

            // Track the active request for timeout monitoring
            activeRequests.set(pending.clientSocket, pending.timestamp);

            // Handle the request
            server.handleRequest(req, res);

            // Response will be sent via responseText() when handler calls res.text() or similar

        } catch (e:Dynamic) {
            trace('Error processing request: $e');
            try {
                pending.clientSocket.close();
            } catch (_:Dynamic) {}
        }
    }

    function checkForTimeouts():Void {
        var currentTime = Sys.time();
        var timedOutSockets:Array<Socket> = [];

        // Find all timed-out sockets
        for (socket => timestamp in activeRequests) {
            if (currentTime - timestamp > REQUEST_TIMEOUT_SECONDS) {
                timedOutSockets.push(socket);
            }
        }

        // Close timed-out sockets
        for (socket in timedOutSockets) {
            #if serve_debug
            trace('Request timeout - closing socket');
            #end
            activeRequests.remove(socket);
            try {
                // Send a 504 Gateway Timeout response
                var timeoutResponse = 'HTTP/1.1 504 Gateway Timeout\r\n';
                timeoutResponse += 'Content-Type: text/plain\r\n';
                timeoutResponse += 'Content-Length: 15\r\n';
                timeoutResponse += '\r\n';
                timeoutResponse += 'Request Timeout';
                socket.output.writeString(timeoutResponse);
                socket.close();
            } catch (_:Dynamic) {
                // Socket may already be closed
            }
        }
    }

    function parseHttpRequest(client:Socket):CppPendingRequest {
        try {
            var input = client.input;

            // Read request line
            var requestLine = "";
            try {
                requestLine = input.readLine();
                #if serve_debug
                trace('Request line: "$requestLine"');
                #end
            } catch (e:Dynamic) {
                #if serve_debug
                trace('Failed to read request line: $e');
                #end
                throw e;
            }

            var parts = requestLine.split(" ");

            if (parts.length < 3) {
                #if serve_debug
                trace('Invalid request line - only ${parts.length} parts: [${parts.join(", ")}]');
                #end
                return null;
            }

            var method = parts[0];
            var fullUri = parts[1];
            var httpVersion = parts[2];
            #if serve_debug
            trace('Method: $method, URI: $fullUri, Version: $httpVersion');
            #end

            // Parse URI and query string
            var uri = fullUri;
            var queryString = "";
            var queryIndex = fullUri.indexOf("?");
            if (queryIndex >= 0) {
                uri = fullUri.substr(0, queryIndex);
                queryString = fullUri.substr(queryIndex + 1);
            }

            // Normalize URI
            if (!uri.startsWith("/")) {
                uri = "/" + uri;
            }
            uri = haxe.io.Path.normalize(uri);
            if (uri.length >= 2 && uri.endsWith("/")) {
                uri = uri.substring(0, uri.length - 1);
            }

            // Read headers
            var headers = new Map<String,String>();
            #if serve_debug
            var headerCount = 0;
            #end
            while (true) {
                var line = "";
                try {
                    line = input.readLine();
                } catch (e:Dynamic) {
                    #if serve_debug
                    trace('Failed to read header line after $headerCount headers: $e');
                    #end
                    throw e;
                }

                if (line == "") {
                    #if serve_debug
                    trace('Headers complete - read $headerCount headers');
                    #end
                    break; // Empty line marks end of headers
                }

                var colonIndex = line.indexOf(":");
                if (colonIndex > 0) {
                    var name = line.substr(0, colonIndex).trim();
                    var value = line.substr(colonIndex + 1).trim();
                    headers.set(Utils.normalizeHeaderName(name), value);
                    #if serve_debug
                    headerCount++;
                    trace('Header: $name = $value');
                    #end
                } else {
                    #if serve_debug
                    trace('Invalid header line: "$line"');
                    #end
                }
            }

            // Read body if present
            var body:Dynamic = null;
            var rawBody:Dynamic = null;
            if (method == "POST" || method == "PUT") {
                var contentLength = Std.parseInt(headers.get("Content-Length") ?? "0");
                if (contentLength > 0) {
                    var bodyBytes = Bytes.alloc(contentLength);
                    input.readBytes(bodyBytes, 0, contentLength);
                    var bodyStr = bodyBytes.toString();
                    rawBody = bodyStr;

                    var contentType = headers.get("Content-Type");
                    if (contentType != null) {
                        contentType = contentType.split(";")[0].trim();
                    }

                    if (contentType == "application/json") {
                        try {
                            body = Json.parse(bodyStr);
                        } catch (e:Dynamic) {
                            trace('Failed to parse JSON body: $e');
                            body = {};
                        }
                    } else if (contentType == "application/x-www-form-urlencoded") {
                        body = Utils.parseQueryString(bodyStr);
                    } else {
                        body = bodyStr;
                    }
                }
            }

            return {
                clientSocket: client,
                method: method,
                uri: uri,
                headers: headers,
                body: body,
                rawBody: rawBody,
                queryString: queryString,
                timestamp: Sys.time()
            };

        } catch (e:Dynamic) {
            #if serve_debug
            trace('Error parsing HTTP request: $e');
            // Try to see if we can get any partial info
            try {
                var available = client.input.readAll().toString();
                if (available.length > 0) {
                    trace('Remaining data in socket: "$available"');
                }
            } catch (_:Dynamic) {}
            #end
            return null;
        }
    }

    function sendResponse(client:Socket, responseData:CppResponseData):Void {
        try {
            var output = client.output;

            // Send status line
            var statusText = getStatusText(responseData.status);
            output.writeString('HTTP/1.1 ${responseData.status} $statusText\r\n');

            // Send headers
            for (header in responseData.headers) {
                output.writeString('${header.name}: ${header.value}\r\n');
            }

            // Determine if we have binary or text content
            var isBinary = responseData.binaryContent != null;
            var contentLength = 0;

            if (isBinary) {
                contentLength = responseData.binaryContent.length;
            } else {
                var content = responseData.content.toString();
                contentLength = Bytes.ofString(content).length; // Get byte length, not char length
            }

            // Ensure Content-Length is set if not already
            var hasContentLength = false;
            for (header in responseData.headers) {
                if (header.name.toLowerCase() == "content-length") {
                    hasContentLength = true;
                    break;
                }
            }
            if (!hasContentLength && contentLength > 0) {
                output.writeString('Content-Length: $contentLength\r\n');
            }

            // End headers
            output.writeString('\r\n');

            // Send body
            if (isBinary && responseData.binaryContent.length > 0) {
                // Write raw binary bytes
                output.writeBytes(responseData.binaryContent, 0, responseData.binaryContent.length);
            } else if (!isBinary) {
                var content = responseData.content.toString();
                if (content.length > 0) {
                    output.writeString(content);
                }
            }

            output.flush();
        } catch (e:Dynamic) {
            trace('Error sending response: $e');
        }
    }

    function parseMethod(method:String):HttpMethod {
        return switch(method) {
            case "POST": POST;
            case "PUT": PUT;
            case "DELETE": DELETE;
            case "HEAD": HEAD;
            default: GET;
        };
    }

    function getStatusText(status:Int):String {
        return switch(status) {
            case 200: "OK";
            case 201: "Created";
            case 304: "Not Modified";
            case 302: "Found";
            case 400: "Bad Request";
            case 401: "Unauthorized";
            case 403: "Forbidden";
            case 404: "Not Found";
            case 500: "Internal Server Error";
            default: "Unknown";
        };
    }

    // Backend interface implementation

    public function host():String {
        return serverHost;
    }

    public function port():Int {
        return serverPort;
    }

    public function responseStatus(response:Response, status:Int):Void {
        var responseData:CppResponseData = cast response.backendItem;
        responseData.status = status;
    }

    public function responseHeader(response:Response, name:String, value:String):Void {
        var responseData:CppResponseData = cast response.backendItem;
        responseData.headers.push({name: name, value: value});
    }

    public function responseText(response:Response, text:String):Void {
        var responseData:CppResponseData = cast response.backendItem;
        responseData.content.add(text);

        // Get the client socket from the request
        var req = response.request;

        // Always send the response when responseText is called
        if (req.backendItem != null) {
            var clientSocket:Socket = cast req.backendItem;

            // Remove from active requests since we're sending the response
            activeRequests.remove(clientSocket);

            sendResponse(clientSocket, responseData);
            try {
                clientSocket.close();
            } catch (_:Dynamic) {}
        }
    }

    public function responseBinary(response:Response, data:Bytes):Void {
        var responseData:CppResponseData = cast response.backendItem;
        responseData.binaryContent = data; // Store raw bytes, not converted string

        // Get the client socket from the request
        var req = response.request;

        // Always send the response when responseBinary is called
        if (req.backendItem != null) {
            var clientSocket:Socket = cast req.backendItem;

            // Remove from active requests since we're sending the response
            activeRequests.remove(clientSocket);

            sendResponse(clientSocket, responseData);
            try {
                clientSocket.close();
            } catch (_:Dynamic) {}
        }
    }

    // AsyncFileBackend implementation

    public function fileExistsAsync(path:String, callback:(exists:Bool)->Void):Void {
        var jobId = nextJobId++;
        pendingFileJobs.set(jobId, callback);
        fileJobQueue.add({
            operation: FileExists(path, jobId)
        });
    }

    public function isDirectoryAsync(path:String, callback:(isDir:Bool)->Void):Void {
        var jobId = nextJobId++;
        pendingFileJobs.set(jobId, callback);
        fileJobQueue.add({
            operation: IsDirectory(path, jobId)
        });
    }

    public function readFileAsync(path:String, callback:(error:Dynamic, content:String)->Void):Void {
        var jobId = nextJobId++;
        pendingFileJobs.set(jobId, callback);
        fileJobQueue.add({
            operation: ReadFile(path, jobId)
        });
    }

    public function readBinaryFileAsync(path:String, callback:(error:Dynamic, content:Bytes)->Void):Void {
        var jobId = nextJobId++;
        pendingFileJobs.set(jobId, callback);
        fileJobQueue.add({
            operation: ReadBinaryFile(path, jobId)
        });
    }

    public function getFileMTimeAsync(path:String, callback:(error:Dynamic, mtime:Float)->Void):Void {
        var jobId = nextJobId++;
        pendingFileJobs.set(jobId, callback);
        fileJobQueue.add({
            operation: GetFileMTime(path, jobId)
        });
    }

    public function getFileSizeAsync(path:String, callback:(error:Dynamic, size:Int)->Void):Void {
        var jobId = nextJobId++;
        pendingFileJobs.set(jobId, callback);
        fileJobQueue.add({
            operation: GetFileSize(path, jobId)
        });
    }

    public function stop():Void {
        isRunning = false;
        try {
            serverSocket.close();
        } catch (_:Dynamic) {}
    }
}

#end