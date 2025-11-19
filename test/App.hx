import serve.Request;
import serve.Response;
import serve.Router;

class App extends Router {

    @get('/api/test') function apiTest(req:Request, res:Response) {

        res.json({
            message: 'This is a dynamic API endpoint',
            timestamp: Date.now().getTime()
        });

    }

    @get('/api/users/$id') function getUser(req:Request, res:Response) {

        res.json({
            id: req.params.id,
            name: 'User ' + req.params.id,
            email: 'user' + req.params.id + '@example.com'
        });

    }

    @post('/api/users') function createUser(req:Request, res:Response) {
        // Parse the request body (assuming JSON)
        var body = req.body;

        // Validate required fields
        if (body == null || body.name == null || body.email == null) {
            res.status(400).json({
                error: 'Missing required fields: name and email'
            });
            return;
        }

        // Simulate user creation with generated ID
        var newUserId = Std.string(Math.floor(Math.random() * 10000));

        res.status(201).json({
            id: newUserId,
            name: body.name,
            email: body.email,
            created: Date.now().toString()
        });
    }

    @put('/api/users/$id') function updateUser(req:Request, res:Response) {
        var userId = req.params.id;
        var body = req.body;

        if (body == null) {
            res.status(400).json({
                error: 'Request body is required'
            });
            return;
        }

        // Simulate user update
        res.json({
            id: userId,
            name: body.name != null ? body.name : 'User ' + userId,
            email: body.email != null ? body.email : 'user' + userId + '@example.com',
            updated: Date.now().toString()
        });
    }

    @delete('/api/users/$id') function deleteUser(req:Request, res:Response) {
        var userId = req.params.id;

        // Simulate user deletion
        res.json({
            success: true,
            deleted: userId,
            timestamp: Date.now().toString()
        });
    }

    @get('/api/test-array') function testArray(req:Request, res:Response) {
        // Test endpoint for array parameter handling
        // Example: /api/test-array?name[]=jim&name[]=jam&tag=test
        res.json({
            query: req.query,
            // Show specific fields to validate array handling
            names: req.query.name,
            tag: req.query.tag
        });
    }

}
