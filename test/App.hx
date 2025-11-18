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

}
