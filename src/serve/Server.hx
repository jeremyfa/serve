package serve;

class Server {

    public final backend:Backend;

    public final requestHandlers:Array<(req:Request, res:Response)->Void>;

    public final host:String;

    public final port:Int;

    public function new(backend:Backend) {
        this.backend = backend;
        this.requestHandlers = [];
        this.host = backend.host();
        this.port = backend.port();
    }

    public function handleRequest(req:Request, res:Response):Void {

        for (i in 0...requestHandlers.length) {
            final handler = requestHandlers[i];
            handler(req, res);
            if (@:privateAccess req.routeResolved) {
                return;
            }
        }

        notFound(req, res);

    }

    public extern inline overload function add(router:Router):Void {
        _addRouter(router);
    }

    public extern inline overload function add(handleRequest:(req:Request, res:Response)->Void):Void {
        _addRequestHandler(handleRequest);
    }

    function _addRouter(router:Router):Void {
        if (router.server == null) {
            @:privateAccess router.server = this;
            requestHandlers.push(router.handleRequest);
        }
        else if (router.server != this) {
            throw 'Cannot assign a router to multiple server instances';
        }
    }

    function _addRequestHandler(handleRequest:(req:Request, res:Response)->Void):Void {
        requestHandlers.push(handleRequest);
    }

    public function start():Void {
        backend.start(this);
    }

    public function notFound(req:Request, res:Response):Void {
        res.status(404).text('Not Found');
    }

}
