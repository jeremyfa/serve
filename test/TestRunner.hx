import haxe.io.Bytes;
import js.node.Buffer;
import js.node.Fs;
import js.node.Http;

class TestRunner {
    static var testsPassed = 0;
    static var testsFailed = 0;
    static var currentBackend = "";
    static var useColors = true;

    // ANSI color codes (will be empty strings if colors are disabled)
    static var RESET = "";
    static var BOLD = "";
    static var RED = "";
    static var GREEN = "";
    static var YELLOW = "";
    static var BLUE = "";
    static var CYAN = "";
    static var GRAY = "";

    static function initColors() {
        // Check for --no-colors argument
        var args = js.Node.process.argv.slice(2);
        for (arg in args) {
            if (arg == "--no-colors") {
                useColors = false;
                return;
            }
        }

        // Check environment variables for color support
        var env = js.Node.process.env;

        // Check common environment variables that indicate color support
        var term = env.get("TERM");
        var colorTerm = env.get("COLORTERM");
        var forceColor = env.get("FORCE_COLOR");
        var noColor = env.get("NO_COLOR");
        var ciEnv = env.get("CI");

        // Disable colors if NO_COLOR is set (standard)
        if (noColor != null && noColor != "" && noColor != "0") {
            useColors = false;
            return;
        }

        // Force colors if FORCE_COLOR is set
        if (forceColor != null && forceColor != "" && forceColor != "0") {
            useColors = true;
        }
        // Check if terminal supports colors
        else if (term == null || term == "dumb") {
            useColors = false;
        }
        // Most CI environments support colors
        else if (ciEnv == "true" || ciEnv == "1") {
            useColors = true;
        }
        // Check for common color-supporting terminals
        else if (term != null && (term.indexOf("color") >= 0 ||
                                  term.indexOf("256") >= 0 ||
                                  term == "xterm" ||
                                  term == "screen" ||
                                  term == "vt100" ||
                                  term == "linux")) {
            useColors = true;
        }
        else if (colorTerm != null) {
            useColors = true;
        }
        else {
            // Default to true on most modern systems
            useColors = true;
        }

        // Set color codes if colors are enabled
        if (useColors) {
            RESET = "\x1b[0m";
            BOLD = "\x1b[1m";
            RED = "\x1b[31m";
            GREEN = "\x1b[32m";
            YELLOW = "\x1b[33m";
            BLUE = "\x1b[34m";
            CYAN = "\x1b[36m";
            GRAY = "\x1b[90m";
        }
    }

    static function main() {
        // Initialize color support
        initColors();

        // Get backend type from command line
        var args = js.Node.process.argv.slice(2);

        // Filter out --no-colors from args for processing
        var filteredArgs = [];
        for (arg in args) {
            if (arg != "--no-colors") {
                filteredArgs.push(arg);
            }
        }

        if (filteredArgs.length < 2) {
            Sys.println(RED + "Usage: TestRunner <backend> <port> [--no-colors]" + RESET);
            js.Node.process.exit(1);
        }

        currentBackend = filteredArgs[0];
        var port = Std.parseInt(filteredArgs[1]);
        var host = "localhost";

        Sys.println("\n" + CYAN + BOLD + "═══ Testing " + currentBackend.toUpperCase() + " backend on port " + port + " ═══" + RESET + "\n");

        // Run all tests sequentially
        runTests(host, port, () -> {
            // Report results
            Sys.println("\n" + CYAN + "═══ Test Results for " + currentBackend.toUpperCase() + " ═══" + RESET);

            // Only show counts that are non-zero
            if (testsPassed > 0) {
                Sys.println(GREEN + "  ✓ Passed: " + testsPassed + RESET);
            }
            if (testsFailed > 0) {
                Sys.println(RED + "  ✗ Failed: " + testsFailed + RESET);
            }
            Sys.println("");

            if (testsFailed > 0) {
                Sys.println(RED + BOLD + "  ✗ FAILURE: Some tests failed!" + RESET);
                js.Node.process.exit(1);
            } else {
                Sys.println(GREEN + BOLD + "  ✓ SUCCESS: All tests passed!" + RESET);
                js.Node.process.exit(0);
            }
        });
    }

    static function runTests(host:String, port:Int, callback:()->Void) {
        var tests = [
            testConnectivity,
            testApiRoutes,
            testHttpMethods,
            testStaticHTML,
            testBinaryImage,
            testHeaders,
            test404,
            testConcurrentRequests
        ];

        function runNext(index:Int) {
            if (index >= tests.length) {
                callback();
                return;
            }

            tests[index](host, port, () -> {
                runNext(index + 1);
            });
        }

        runNext(0);
    }

    static function test(name:String, condition:Bool, ?message:String) {
        if (condition) {
            Sys.println(GREEN + "  ✓ " + name + RESET);
            testsPassed++;
        } else {
            Sys.println(RED + "  ✗ " + name + RESET + (message != null ? GRAY + " (" + message + ")" + RESET : ""));
            testsFailed++;
        }
    }

    static function httpRequest(host:String, port:Int, path:String, method:String, ?body:String, ?headers:Dynamic, callback:(content:String, status:Int, responseHeaders:Dynamic)->Void) {
        var options:Dynamic = {
            hostname: host,
            port: port,
            path: path,
            method: method
        };

        if (headers != null) {
            options.headers = headers;
        } else if (body != null) {
            // Default headers for JSON requests
            options.headers = {
                'Content-Type': 'application/json',
                'Content-Length': body.length
            };
        }

        var req = Http.request(options, (res) -> {
            var data = "";
            res.on('data', (chunk) -> {
                data += chunk;
            });
            res.on('end', () -> {
                callback(data, res.statusCode, res.headers);
            });
        });

        req.on('error', (e) -> {
            callback("", 0, null);
        });

        if (body != null) {
            req.write(body);
        }
        req.end();
    }

    static function httpGetString(host:String, port:Int, path:String, callback:(content:String, status:Int)->Void) {
        httpRequest(host, port, path, 'GET', null, null, (content, status, headers) -> {
            callback(content, status);
        });
    }

    static function httpGetBytes(host:String, port:Int, path:String, callback:(bytes:Bytes, status:Int)->Void) {
        var options = {
            hostname: host,
            port: port,
            path: path,
            method: 'GET'
        };

        var req = Http.request(options, (res) -> {
            var chunks:Array<Buffer> = [];
            res.on('data', (chunk:Buffer) -> {
                chunks.push(chunk);
            });
            res.on('end', () -> {
                var buffer = Buffer.concat(chunks);
                var bytes = Bytes.ofData(cast buffer);
                callback(bytes, res.statusCode);
            });
        });

        req.on('error', (e) -> {
            callback(null, 0);
        });

        req.end();
    }

    static function testConnectivity(host:String, port:Int, done:()->Void) {
        Sys.println("\n" + BLUE + BOLD + "▶ Testing Connectivity" + RESET);
        httpGetString(host, port, "/", (content, status) -> {
            test("Server responds", content.length > 0);
            done();
        });
    }

    static function testApiRoutes(host:String, port:Int, done:()->Void) {
        Sys.println("\n" + BLUE + BOLD + "▶ Testing API Routes (GET)" + RESET);

        // Test /api/test
        httpGetString(host, port, "/api/test", (content, status) -> {
            try {
                var json = haxe.Json.parse(content);
                test("/api/test returns JSON", json.message == "This is a dynamic API endpoint");
                test("/api/test includes timestamp", json.timestamp != null);
            } catch (e:Dynamic) {
                test("/api/test returns JSON", false, Std.string(e));
            }

            // Test /api/users/:id
            httpGetString(host, port, "/api/users/123", (content, status) -> {
                try {
                    var json = haxe.Json.parse(content);
                    test("/api/users/123 returns correct ID", json.id == "123");
                    test("/api/users/123 returns name", json.name == "User 123");
                    test("/api/users/123 returns email", json.email == "user123@example.com");
                } catch (e:Dynamic) {
                    test("/api/users/123", false, Std.string(e));
                }
                done();
            });
        });
    }

    static function testHttpMethods(host:String, port:Int, done:()->Void) {
        Sys.println("\n" + BLUE + BOLD + "▶ Testing HTTP Methods (POST/PUT/DELETE/HEAD)" + RESET);

        // Test POST /api/users
        var postBody = haxe.Json.stringify({
            name: "John Doe",
            email: "john@example.com"
        });

        httpRequest(host, port, "/api/users", "POST", postBody, null, (content, status, headers) -> {
            try {
                var json = haxe.Json.parse(content);
                test("POST /api/users returns 201", status == 201);
                test("POST creates user with name", json.name == "John Doe");
                test("POST creates user with email", json.email == "john@example.com");
                test("POST returns generated ID", json.id != null);
                test("POST returns created timestamp", json.created != null);

                var createdUserId = json.id;

                // Test PUT /api/users/:id
                var putBody = haxe.Json.stringify({
                    name: "Jane Doe",
                    email: "jane@example.com"
                });

                httpRequest(host, port, "/api/users/" + createdUserId, "PUT", putBody, null, (content, status, headers) -> {
                    try {
                        var json = haxe.Json.parse(content);
                        test("PUT /api/users/:id returns 200", status == 200);
                        test("PUT updates user name", json.name == "Jane Doe");
                        test("PUT updates user email", json.email == "jane@example.com");
                        test("PUT returns updated timestamp", json.updated != null);

                        // Test DELETE /api/users/:id
                        httpRequest(host, port, "/api/users/" + createdUserId, "DELETE", null, null, (content, status, headers) -> {
                            try {
                                var json = haxe.Json.parse(content);
                                test("DELETE /api/users/:id returns 200", status == 200);
                                test("DELETE returns success", json.success == true);
                                test("DELETE confirms deleted ID", json.deleted == createdUserId);

                                // Test HEAD on static file
                                httpRequest(host, port, "/test.html", "HEAD", null, null, (content, status, headers) -> {
                                    test("HEAD /test.html returns 200", status == 200);
                                    test("HEAD returns empty body", content == "" || content.length == 0);
                                    test("HEAD includes Content-Length header", headers != null && Reflect.field(headers, "content-length") != null);

                                    // Test POST with missing fields (validation)
                                    var invalidBody = haxe.Json.stringify({
                                        name: "Missing Email"
                                    });

                                    httpRequest(host, port, "/api/users", "POST", invalidBody, null, (content, status, headers) -> {
                                        try {
                                            var json = haxe.Json.parse(content);
                                            test("POST with missing fields returns 400", status == 400);
                                            test("POST returns error message", json.error != null);
                                        } catch (e:Dynamic) {
                                            test("POST validation", false, Std.string(e));
                                        }
                                        done();
                                    });
                                });
                            } catch (e:Dynamic) {
                                test("DELETE /api/users/:id", false, Std.string(e));
                                done();
                            }
                        });
                    } catch (e:Dynamic) {
                        test("PUT /api/users/:id", false, Std.string(e));
                        done();
                    }
                });
            } catch (e:Dynamic) {
                test("POST /api/users", false, Std.string(e));
                done();
            }
        });
    }

    static function testStaticHTML(host:String, port:Int, done:()->Void) {
        Sys.println("\n" + BLUE + BOLD + "▶ Testing Static HTML" + RESET);

        httpGetString(host, port, "/test.html", (content, status) -> {
            test("test.html returns 200", status == 200);
            test("test.html contains expected content", content.indexOf("<h1>Serve Test Page</h1>") >= 0);
            test("test.html is complete HTML document",
                content.indexOf("<!DOCTYPE html>") >= 0 &&
                content.indexOf("</html>") >= 0);
            done();
        });
    }

    static function testBinaryImage(host:String, port:Int, done:()->Void) {
        Sys.println("\n" + BLUE + BOLD + "▶ Testing Binary Image" + RESET);

        // Read original file using Node.js fs
        Fs.readFile("test/assets/haxe-logo.png", (err, data) -> {
            if (err != null) {
                test("Read original file", false, Std.string(err));
                done();
                return;
            }

            var originalBytes = Bytes.ofData(cast data);
            var originalSize = originalBytes.length;
            test("Original haxe-logo.png is 8571 bytes", originalSize == 8571);

            // Download from server
            httpGetBytes(host, port, "/haxe-logo.png", (downloadedBytes, status) -> {
                test("haxe-logo.png returns 200", status == 200);

                if (downloadedBytes != null) {
                    test("Downloaded size matches original (8571 bytes)",
                        downloadedBytes.length == originalSize,
                        "Got " + downloadedBytes.length + " bytes instead of " + originalSize);

                    // Byte-by-byte comparison
                    var bytesMatch = true;
                    var firstMismatch = -1;
                    if (downloadedBytes.length == originalSize) {
                        for (i in 0...originalSize) {
                            if (downloadedBytes.get(i) != originalBytes.get(i)) {
                                bytesMatch = false;
                                firstMismatch = i;
                                break;
                            }
                        }
                    } else {
                        bytesMatch = false;
                    }

                    test("Binary content matches exactly (byte-by-byte)",
                        bytesMatch,
                        bytesMatch ? null : "First mismatch at byte " + firstMismatch);

                    // Calculate simple checksum for additional verification
                    var originalChecksum = 0;
                    var downloadedChecksum = 0;
                    for (i in 0...originalSize) {
                        originalChecksum += originalBytes.get(i);
                    }
                    for (i in 0...downloadedBytes.length) {
                        downloadedChecksum += downloadedBytes.get(i);
                    }

                    test("Checksum matches",
                        originalChecksum == downloadedChecksum,
                        "Original: " + originalChecksum + ", Downloaded: " + downloadedChecksum);

                } else {
                    test("Downloaded bytes received", false, "No bytes received");
                }
                done();
            });
        });
    }

    static function testHeaders(host:String, port:Int, done:()->Void) {
        Sys.println("\n" + BLUE + BOLD + "▶ Testing HTTP Headers" + RESET);

        httpGetString(host, port, "/test.html", (content, status) -> {
            test("Response includes content", content.length > 0);
            test("HTML response seems valid", content.indexOf("DOCTYPE") >= 0 || content.indexOf("<html") >= 0);
            done();
        });
    }

    static function test404(host:String, port:Int, done:()->Void) {
        Sys.println("\n" + BLUE + BOLD + "▶ Testing 404 Errors" + RESET);

        httpGetString(host, port, "/nonexistent.file", (content, status) -> {
            test("Non-existent file returns 404", status == 404);
            done();
        });
    }

    static function testConcurrentRequests(host:String, port:Int, done:()->Void) {
        Sys.println("\n" + BLUE + BOLD + "▶ Testing Concurrent Requests" + RESET);

        var completed = 0;
        var errors = 0;
        var total = 5;
        var pending = total;

        for (i in 0...total) {
            httpGetString(host, port, "/api/users/" + i, (content, status) -> {
                try {
                    var json = haxe.Json.parse(content);
                    if (json.id == Std.string(i)) {
                        completed++;
                    } else {
                        errors++;
                    }
                } catch (e:Dynamic) {
                    errors++;
                }

                pending--;
                if (pending == 0) {
                    test("All concurrent requests completed", completed == total,
                        "Completed: " + completed + "/" + total + ", Errors: " + errors);
                    done();
                }
            });
        }
    }
}