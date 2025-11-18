import serve.Request;
import serve.Response;
import serve.Router;
import serve.Server;
import serve.PhpBackend;
import haxe.Timer;

class AsyncExample extends Router {

    static function main() {
        #if php
        final backend = new PhpBackend();
        final server = new Server(backend);

        // Add async auth middleware
        server.add((req:Request, res:Response) -> {
            trace('Auth middleware start');

            // Check for auth token in headers
            final token = req.headers.get("Authorization");
            if (token != null && StringTools.startsWith(token, "Bearer ")) {
                res.async(next -> {
                    // Simulate async token validation
                    // In real app, this would be a database lookup or API call
                    Timer.delay(() -> {
                        trace('Auth validation complete');
                        // Add user to request
                        Reflect.setField(req, "user", {
                            id: 123,
                            name: "John Doe",
                            email: "john@example.com"
                        });
                        next(); // Continue to next handler
                    }, 100);
                });
            }
            // If no token, continues automatically
        });

        // Add logging middleware (synchronous)
        server.add((req:Request, res:Response) -> {
            trace('Logger: ${req.method} ${req.uri}');
            final user = Reflect.field(req, "user");
            if (user != null) {
                trace('Authenticated user: ${user.name}');
            }
        });

        // Add router with endpoints
        server.add(new AsyncExample());

        trace('Starting server on ${server.host}:${server.port}');
        server.start();
        #end
    }

    @get('/')
    function index(req:Request, res:Response) {
        res.json({
            message: 'Welcome to async-enabled server!',
            endpoints: [
                '/public - Public endpoint',
                '/profile - Protected endpoint (requires Authorization header)',
                '/async-data - Endpoint with async data fetching'
            ]
        });
    }

    @get('/public')
    function publicEndpoint(req:Request, res:Response) {
        res.json({
            message: 'This is a public endpoint',
            timestamp: Date.now().toString()
        });
    }

    @get('/profile')
    function getProfile(req:Request, res:Response) {
        final user = Reflect.field(req, "user");
        if (user != null) {
            res.json({
                success: true,
                profile: user
            });
        } else {
            res.status(401).json({
                error: 'Unauthorized',
                message: 'Please provide Authorization: Bearer <token> header'
            });
        }
    }

    @get('/async-data')
    function asyncData(req:Request, res:Response) {
        trace('Starting async data fetch...');

        res.async(next -> {
            // Simulate fetching data from multiple sources
            Timer.delay(() -> {
                trace('Data fetched!');

                // After async operation, send response
                res.json({
                    data: [
                        { id: 1, value: 'Item 1' },
                        { id: 2, value: 'Item 2' },
                        { id: 3, value: 'Item 3' }
                    ],
                    fetchedAt: Date.now().toString()
                });

                // Note: we don't call next() here because we're sending a response
                // The route is resolved
                @:privateAccess req.routeResolved = true;
            }, 200);
        });
    }

    @post('/data')
    function createData(req:Request, res:Response) {
        res.async(next -> {
            // Simulate async database insert
            Timer.delay(() -> {
                res.status(201).json({
                    success: true,
                    message: 'Data created',
                    id: Math.floor(Math.random() * 1000),
                    data: req.body
                });
                @:privateAccess req.routeResolved = true;
            }, 150);
        });
    }
}