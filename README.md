# Serve

A lightweight, cross-platform HTTP server library for Haxe with built-in routing support. Compiles to PHP and Node.js with zero dependencies.

## Installation

```bash
# From Haxelib
haxelib install serve

# From Git (latest)
haxelib git serve https://github.com/jeremyfa/serve.git
```

## Quick Start

```haxe
// Main.hx
import serve.*;

class Main {
    static function main() {
        var server = new Server(
            #if php
            new PhpBackend()
            #elseif nodejs
            new NodeJsBackend(3000, "localhost")
            #end
        );

        server.add(new MyRouter());
        server.start();
    }
}

// MyRouter.hx
class MyRouter extends serve.Router {
    @get('/')
    function index(req:Request, res:Response) {
        res.json({message: "Hello, World!"});
    }
}
```

## Routing

Define routes using metadata annotations on methods in a Router class:

```haxe
class UserRouter extends serve.Router {
    @get('/users')
    function listUsers(req:Request, res:Response) {
        res.json({users: []});
    }

    @get('/users/$id')
    function getUser(req:Request, res:Response) {
        var userId = req.params.id;
        res.json({id: userId, name: "User " + userId});
    }

    @post('/users')
    function createUser(req:Request, res:Response) {
        var name = req.body.name;  // JSON body auto-parsed
        res.status(201).json({id: 123, name: name});
    }

    @put('/users/$id')
    function updateUser(req:Request, res:Response) {
        res.json({success: true});
    }

    @delete('/users/$id')
    function deleteUser(req:Request, res:Response) {
        res.status(204).text("");
    }
}
```

### Route Parameters

Use `$paramName` syntax in routes. Parameters are available in `req.params`:

```haxe
@get('/posts/$postId/comments/$commentId')
function getComment(req:Request, res:Response) {
    var postId = req.params.postId;
    var commentId = req.params.commentId;
    // ...
}
```

## API Reference

### Request

| Property | Type | Description |
|----------|------|-------------|
| `uri` | String | Request path (without query string) |
| `method` | HttpMethod | GET, POST, PUT, DELETE |
| `params` | Dynamic | Route parameters |
| `query` | Dynamic | Query string parameters |
| `body` | Dynamic | Parsed request body (JSON/form) |
| `headers` | Map<String,String> | HTTP headers (normalized to Title-Case) |

### Response

| Method | Description |
|--------|-------------|
| `status(code:Int)` | Set HTTP status code |
| `header(name:String, value:String)` | Set response header |
| `json(data:Dynamic)` | Send JSON response |
| `html(content:String)` | Send HTML response |
| `text(content:String)` | Send plain text |
| `redirect(url:String)` | Send 302 redirect |
| `notFound()` | Send 404 response |

All methods return `Response` for chaining, except terminal methods (json, html, text, redirect).

## Platform Usage

### PHP

```bash
# Build
haxe build-php.hxml

# Run with built-in server
php -S localhost:8000 -t out/php/

# Deploy to any PHP host (Apache, Nginx + PHP-FPM, etc.)
```

### Node.js

```bash
# Build
haxe build-nodejs.hxml

# Run
node out/nodejs/server.js

# Or with PM2
pm2 start out/nodejs/server.js
```

## Examples

### Complete REST API

```haxe
class ProductAPI extends serve.Router {
    var products = new Map<String, Dynamic>();

    @get('/api/products')
    function list(req:Request, res:Response) {
        var page = req.query.page != null ? Std.parseInt(req.query.page) : 1;
        var limit = req.query.limit != null ? Std.parseInt(req.query.limit) : 10;

        res.json({
            page: page,
            items: [for (p in products) p],
            total: products.count()
        });
    }

    @get('/api/products/$id')
    function get(req:Request, res:Response) {
        var product = products.get(req.params.id);
        if (product != null) {
            res.json(product);
        } else {
            res.notFound();
        }
    }

    @post('/api/products')
    function create(req:Request, res:Response) {
        var id = Std.string(Date.now().getTime());
        products.set(id, {
            id: id,
            name: req.body.name,
            price: req.body.price
        });
        res.status(201)
           .header("Location", '/api/products/$id')
           .json({id: id});
    }
}
```

### Multiple Routers

```haxe
var server = new Server(backend);

// Add routers in order - first match wins
server.add(new AuthRouter());     // Authentication endpoints
server.add(new ApiRouter());      // API routes
server.add(new AdminRouter());    // Admin panel
server.add(new PublicRouter());   // Public pages

server.start();
```

### Custom Request Handler

```haxe
// Add middleware-like functionality
server.add(function(req:Request, res:Response) {
    // Log all requests
    trace('${req.method} ${req.uri}');

    // Add CORS headers
    res.header("Access-Control-Allow-Origin", "*")
       .header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE");

    // Don't mark route as resolved - continues synchronously to next handler
});

// Add routers after middleware
server.add(new ApiRouter());
```

## Architecture

### Backend Interface Pattern

Serve abstracts platform differences behind a `Backend` interface, allowing the same router code to run on different platforms:

```haxe
// Your code works everywhere
class MyRouter extends Router {
    @get('/hello')
    function hello(req:Request, res:Response) {
        res.json({platform: #if php "PHP" #else "Node.js" #end});
    }
}
```

### Compile-Time Route Generation

Routes are generated at compile-time using Haxe macros, reducing runtime overhead.

### Creating Custom Backends

Implement the `Backend` interface to support new platforms:

```haxe
class MyBackend implements Backend {
    var serverHost:String = "localhost";
    var serverPort:Int = 3000;

    public function new(?port:Int = 3000, ?host:String = "localhost") {
        this.serverPort = port;
        this.serverHost = host;
    }

    public function start(server:Server):Void {
        // Start listening for requests
    }

    public function host():String {
        return serverHost;
    }

    public function port():Int {
        return serverPort;
    }

    public function responseStatus(response:Response, status:Int):Void {
        // Set HTTP status
    }

    public function responseHeader(response:Response, name:String, value:String):Void {
        // Set response header
    }

    public function responseText(response:Response, text:String):Void {
        // Send response body
    }
}
```

## Current Limitations

Serve focuses on core HTTP routing. Not included: sessions, auth, static files, templates, WebSockets, file uploads, HTTPS/TLS, rate limiting, compression, or custom error pages.

Custom request handlers used as middleware are currently executed synchronously, preventing them to perform async operation before a route is resolved. This will be improved in a future version.

## License

MIT License - see [LICENSE](LICENSE) file for details.