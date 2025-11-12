import serve.Request;
import serve.Response;
import serve.Router;

class App extends Router {

    @get('/') function index(req:Request, res:Response) {

        res.json({
            hello: 'world'
        });

    }

}
