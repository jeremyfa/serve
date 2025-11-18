package serve;

import haxe.io.Path;
import haxe.io.Bytes;

using StringTools;

typedef StaticOptions = {
    ?index:String,        // Default file to serve for directories (default: "index.html")
    ?maxAge:Int,         // Cache control max-age in seconds (default: 0)
    ?etag:Bool,          // Enable/disable ETag generation (default: true)
    ?dotfiles:String,    // How to handle dotfiles: "allow", "deny", "ignore" (default: "ignore")
    ?extensions:Array<String> // File extensions to try when file not found
}

class Static {

    final uriPrefix:String;
    final root:String;
    final options:StaticOptions;
    public var server(default, null):Server;

    public function new(uriPrefix:String, root:String, ?options:StaticOptions) {
        // Normalize URI prefix
        this.uriPrefix = uriPrefix;
        if (!this.uriPrefix.startsWith('/')) {
            this.uriPrefix = '/' + this.uriPrefix;
        }
        // Remove trailing slash from prefix (except for root)
        if (this.uriPrefix.length > 1 && this.uriPrefix.endsWith('/')) {
            this.uriPrefix = this.uriPrefix.substring(0, this.uriPrefix.length - 1);
        }

        this.root = Path.normalize(root);

        this.options = {
            index: options?.index ?? "index.html",
            maxAge: options?.maxAge ?? 0,
            etag: options?.etag ?? true,
            dotfiles: options?.dotfiles ?? "ignore",
            extensions: options?.extensions ?? []
        };
    }

    public function handleRequest(req:Request, res:Response):Void {
        // Only handle GET and HEAD requests
        if (req.method != GET && req.method != HEAD) {
            return;
        }

        // Check if the request URI starts with our prefix
        if (!req.uri.startsWith(uriPrefix)) {
            return; // Not our request to handle
        }

        // Strip the prefix from the URI to get the file path
        var requestPath = req.uri.substring(uriPrefix.length);

        // If prefix was not root and we stripped everything, we have "/"
        if (requestPath == "" || requestPath == "/") {
            requestPath = "/";
        }

        // Ensure path starts with /
        if (!requestPath.startsWith("/")) {
            requestPath = "/" + requestPath;
        }

        // Check for directory traversal attempts
        if (requestPath.indexOf("..") != -1) {
            return; // Let next handler deal with it
        }

        // Remove leading slash for file system path
        if (requestPath.charAt(0) == "/") {
            requestPath = requestPath.substr(1);
        }

        // Construct full file path
        var filePath = Path.join([root, requestPath]);

        // Check dotfile handling
        if (options.dotfiles != "allow") {
            var filename = Path.withoutDirectory(filePath);
            if (filename.charAt(0) == ".") {
                if (options.dotfiles == "deny") {
                    res.status(403).text("Forbidden");
                    @:privateAccess req.routeResolved = true;
                    return;
                } else { // ignore
                    return; // Let next handler deal with it
                }
            }
        }

        // Try to serve the file
        if (tryServeFile(filePath, req, res)) {
            return;
        }

        // If it's a directory, try serving index file
        if (server.backend.isDirectory(filePath)) {
            var indexPath = Path.join([filePath, options.index]);
            if (tryServeFile(indexPath, req, res)) {
                return;
            }
        }

        // Try with extensions if provided
        for (ext in options.extensions) {
            var extPath = filePath + "." + ext;
            if (tryServeFile(extPath, req, res)) {
                return;
            }
        }

        // File not found, let next handler deal with it
    }

    function tryServeFile(filePath:String, req:Request, res:Response):Bool {
        if (!server.backend.fileExists(filePath)) {
            return false;
        }

        if (server.backend.isDirectory(filePath)) {
            return false;
        }

        // Get file extension and determine content type
        var ext = Path.extension(filePath).toLowerCase();
        var contentType = MimeTypes.getContentType(ext);

        // Set content type header
        res.header("Content-Type", contentType);

        // Set cache control
        if (options.maxAge > 0) {
            res.header("Cache-Control", "public, max-age=" + options.maxAge);
        } else {
            res.header("Cache-Control", "no-cache");
        }

        // Generate and set ETag if enabled
        if (options.etag) {
            var mtime = server.backend.getFileMTime(filePath);
            var etag = '"' + Std.string(mtime) + '"';
            res.header("ETag", etag);

            // Check If-None-Match header for conditional requests
            var ifNoneMatch = req.headers.get("If-None-Match");
            if (ifNoneMatch == etag) {
                res.status(304).text("");
                @:privateAccess req.routeResolved = true;
                return true;
            }
        }

        // Check if this is a binary file type
        if (isBinaryContent(contentType)) {
            // Read and send binary content
            var content = server.backend.readBinaryFile(filePath);
            res.binary(content);
        } else {
            // Read and send text content
            var content = server.backend.readFile(filePath);
            res.text(content);
        }

        @:privateAccess req.routeResolved = true;
        return true;
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