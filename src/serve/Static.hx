package serve;

import haxe.io.Bytes;
import haxe.io.Path;

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
                    return;
                } else { // ignore
                    return; // Let next handler deal with it
                }
            }
        }

        // Branch based on backend type
        if (Std.isOfType(server.backend, AsyncFileBackend)) {
            handleRequestAsync(req, res, filePath);
        } else if (Std.isOfType(server.backend, SyncFileBackend)) {
            handleRequestSync(req, res, filePath);
        } else {
            // Backend doesn't support file operations
            return;
        }
    }

    function handleRequestSync(req:Request, res:Response, filePath:String):Void {
        var syncBackend:SyncFileBackend = cast server.backend;

        // Try to serve the file
        if (tryServeFileSync(filePath, req, res, syncBackend)) {
            return;
        }

        // If it's a directory, try serving index file
        if (syncBackend.isDirectory(filePath)) {
            var indexPath = Path.join([filePath, options.index]);
            if (tryServeFileSync(indexPath, req, res, syncBackend)) {
                return;
            }
        }

        // Try with extensions if provided
        for (ext in options.extensions) {
            var extPath = filePath + "." + ext;
            if (tryServeFileSync(extPath, req, res, syncBackend)) {
                return;
            }
        }

        // File not found, let next handler deal with it
    }

    function handleRequestAsync(req:Request, res:Response, filePath:String):Void {
        var asyncBackend:AsyncFileBackend = cast server.backend;

        res.async(next -> {
            tryServeFileAsync(filePath, req, res, asyncBackend, (served) -> {
                if (served) {
                    // File was served successfully, call next to complete
                    next();
                    return;
                }

                // Check if it's a directory
                asyncBackend.isDirectoryAsync(filePath, (isDir) -> {
                    if (isDir) {
                        // Try serving index file
                        var indexPath = Path.join([filePath, options.index]);
                        tryServeFileAsync(indexPath, req, res, asyncBackend, (served) -> {
                            if (served) {
                                // Index file served, call next
                                next();
                            } else {
                                // Index not found, try extensions
                                tryExtensionsAsync(filePath, req, res, asyncBackend, 0, next);
                            }
                        });
                    } else {
                        // Not a directory, try extensions
                        tryExtensionsAsync(filePath, req, res, asyncBackend, 0, next);
                    }
                });
            });
        });
    }

    function tryExtensionsAsync(filePath:String, req:Request, res:Response, backend:AsyncFileBackend, index:Int, next:()->Void):Void {
        if (index >= options.extensions.length) {
            // No more extensions to try
            next(); // Continue to next handler
            return;
        }

        var extPath = filePath + "." + options.extensions[index];
        tryServeFileAsync(extPath, req, res, backend, (served) -> {
            if (served) {
                // File served successfully with extension
                next();
            } else {
                // Try next extension
                tryExtensionsAsync(filePath, req, res, backend, index + 1, next);
            }
        });
    }

    function tryServeFileSync(filePath:String, req:Request, res:Response, backend:SyncFileBackend):Bool {
        if (!backend.fileExists(filePath)) {
            return false;
        }

        if (backend.isDirectory(filePath)) {
            return false;
        }

        // Get file extension and determine content type
        var ext = Path.extension(filePath).toLowerCase();
        var contentType = MimeTypes.getContentType(ext);

        // Get file size for range support
        var fileSize = backend.getFileSize(filePath);

        // Set content type header
        res.header("Content-Type", contentType);

        // Indicate range request support
        res.header("Accept-Ranges", "bytes");

        // Set cache control
        if (options.maxAge > 0) {
            res.header("Cache-Control", "public, max-age=" + options.maxAge);
        } else {
            res.header("Cache-Control", "no-cache");
        }

        // Generate and set ETag if enabled
        if (options.etag) {
            var mtime = backend.getFileMTime(filePath);
            var etag = '"' + Std.string(mtime) + '"';
            res.header("ETag", etag);

            // Check If-None-Match header for conditional requests
            var ifNoneMatch = req.headers.get("If-None-Match");
            if (ifNoneMatch == etag) {
                res.status(304).text("");
                return true;
            }
        }

        // Check for Range header
        var rangeHeader = req.headers.get("Range");
        var range = parseRangeHeader(rangeHeader, fileSize);

        // If Range header exists but is invalid, return 416
        if (rangeHeader != null && range == null) {
            res.status(416);
            res.header("Content-Range", "bytes */" + fileSize);
            res.text("");
            return true;
        }

        // For HEAD requests, only send headers, not the body
        if (req.method == HEAD) {
            if (range != null) {
                res.status(206);
                res.header("Content-Range", "bytes " + range.start + "-" + range.end + "/" + fileSize);
                res.header("Content-Length", Std.string(range.end - range.start + 1));
            } else {
                res.header("Content-Length", Std.string(fileSize));
            }
            res.text(""); // Send empty body for HEAD requests
        } else if (range != null) {
            // Serve partial content
            res.status(206);
            res.header("Content-Range", "bytes " + range.start + "-" + range.end + "/" + fileSize);
            var content = backend.readBinaryFileRange(filePath, range.start, range.end);
            res.binary(content);
        } else {
            // Serve full file
            if (isBinaryContent(contentType)) {
                var content = backend.readBinaryFile(filePath);
                res.binary(content);
            } else {
                var content = backend.readFile(filePath);
                res.text(content);
            }
        }

        return true;
    }

    function tryServeFileAsync(filePath:String, req:Request, res:Response, backend:AsyncFileBackend,
                                callback:(served:Bool)->Void):Void {
        backend.fileExistsAsync(filePath, (exists) -> {
            if (!exists) {
                callback(false);
                return;
            }

            backend.isDirectoryAsync(filePath, (isDir) -> {
                if (isDir) {
                    callback(false);
                    return;
                }

                // Get file extension and determine content type
                var ext = Path.extension(filePath).toLowerCase();
                var contentType = MimeTypes.getContentType(ext);

                // Set content type header
                res.header("Content-Type", contentType);

                // Indicate range request support
                res.header("Accept-Ranges", "bytes");

                // Set cache control
                if (options.maxAge > 0) {
                    res.header("Cache-Control", "public, max-age=" + options.maxAge);
                } else {
                    res.header("Cache-Control", "no-cache");
                }

                // Handle ETag if enabled
                if (options.etag) {
                    backend.getFileMTimeAsync(filePath, (err, mtime) -> {
                        if (err == null) {
                            var etag = '"' + Std.string(mtime) + '"';
                            res.header("ETag", etag);

                            // Check If-None-Match header for conditional requests
                            var ifNoneMatch = req.headers.get("If-None-Match");
                            if (ifNoneMatch == etag) {
                                res.status(304).text("");
                                callback(true);
                                return;
                            }
                        }

                        // Serve the file content
                        serveFileContentAsync(filePath, res, req, backend, contentType, callback);
                    });
                } else {
                    // Serve without ETag
                    serveFileContentAsync(filePath, res, req, backend, contentType, callback);
                }
            });
        });
    }

    function serveFileContentAsync(filePath:String, res:Response, req:Request, backend:AsyncFileBackend, contentType:String, callback:(served:Bool)->Void):Void {
        // Get file size first (needed for range support)
        backend.getFileSizeAsync(filePath, (err, fileSize) -> {
            if (err != null) {
                callback(false);
                return;
            }

            // Check for Range header
            var rangeHeader = req.headers.get("Range");
            var range = parseRangeHeader(rangeHeader, fileSize);

            // If Range header exists but is invalid, return 416
            if (rangeHeader != null && range == null) {
                res.status(416);
                res.header("Content-Range", "bytes */" + fileSize);
                res.text("");
                callback(true);
                return;
            }

            // For HEAD requests, only send headers, not the body
            if (req.method == HEAD) {
                if (range != null) {
                    res.status(206);
                    res.header("Content-Range", "bytes " + range.start + "-" + range.end + "/" + fileSize);
                    res.header("Content-Length", Std.string(range.end - range.start + 1));
                } else {
                    res.header("Content-Length", Std.string(fileSize));
                }
                res.text(""); // Send empty body for HEAD requests
                callback(true);
            } else if (range != null) {
                // Serve partial content
                res.status(206);
                res.header("Content-Range", "bytes " + range.start + "-" + range.end + "/" + fileSize);
                backend.readBinaryFileRangeAsync(filePath, range.start, range.end, (err, content) -> {
                    if (err != null) {
                        callback(false);
                    } else {
                        res.binary(content);
                        callback(true);
                    }
                });
            } else {
                // Serve full file
                if (isBinaryContent(contentType)) {
                    backend.readBinaryFileAsync(filePath, (err, content) -> {
                        if (err != null) {
                            callback(false);
                        } else {
                            res.binary(content);
                            callback(true);
                        }
                    });
                } else {
                    backend.readFileAsync(filePath, (err, content) -> {
                        if (err != null) {
                            callback(false);
                        } else {
                            res.text(content);
                            callback(true);
                        }
                    });
                }
            }
        });
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

    // Parse Range header and return start/end positions
    // Returns null if invalid or unsupported format
    function parseRangeHeader(rangeHeader:String, fileSize:Int):Null<{start:Int, end:Int}> {
        if (rangeHeader == null || !rangeHeader.startsWith("bytes=")) {
            return null;
        }

        var rangeSpec = rangeHeader.substring(6); // Remove "bytes="

        // Check for multiple ranges (not supported)
        if (rangeSpec.indexOf(",") != -1) {
            return null;
        }

        var dashIdx = rangeSpec.indexOf("-");
        if (dashIdx == -1) {
            return null;
        }

        var startStr = rangeSpec.substring(0, dashIdx);
        var endStr = rangeSpec.substring(dashIdx + 1);

        var start:Int;
        var end:Int;

        if (startStr == "") {
            // Suffix range: bytes=-500 means last 500 bytes
            var suffixLength:Null<Int> = Std.parseInt(endStr);
            if (suffixLength == null || suffixLength <= 0) {
                return null;
            }
            start = fileSize - suffixLength;
            if (start < 0) start = 0;
            end = fileSize - 1;
        } else {
            var parsedStart:Null<Int> = Std.parseInt(startStr);
            if (parsedStart == null || parsedStart < 0) {
                return null;
            }
            start = parsedStart;

            if (endStr == "") {
                // Open-ended range: bytes=500- means from byte 500 to end
                end = fileSize - 1;
            } else {
                var parsedEnd:Null<Int> = Std.parseInt(endStr);
                if (parsedEnd == null) {
                    return null;
                }
                end = parsedEnd;
            }
        }

        // Validate range
        if (start > end || start >= fileSize) {
            return null;
        }

        // Clamp end to file size
        if (end >= fileSize) {
            end = fileSize - 1;
        }

        return {start: start, end: end};
    }
}