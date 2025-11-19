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
        continueFromHandler(req, res);
    }

    function continueFromHandler(req:Request, res:Response):Void {

        // Stop here if this request is already resolved
        // or is running an async operation
        if (req.resolved || req.asyncPending) return;

        // All good, let's move to next handler
        req.handlerIndex++;
        while (req.handlerIndex < requestHandlers.length) {
            final handler = requestHandlers[req.handlerIndex];

            // Run the handler
            handler(req, res);

            // After running the handler, if it is
            // either resolved or initiated an async operation,
            // stop there.
            if (req.resolved || req.asyncPending) return;

            // We can move to next handler
            req.handlerIndex++;
        }

        // Nothing resolved, no async pending: not found!
        notFound(req, res);

    }

    public extern inline overload function add(router:Router):Void {
        _addRouter(router);
    }

    public extern inline overload function add(staticHandler:Static):Void {
        _addStatic(staticHandler);
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

    function _addStatic(staticHandler:Static):Void {
        if (staticHandler.server == null) {
            @:privateAccess staticHandler.server = this;
            requestHandlers.push(staticHandler.handleRequest);
        }
        else if (staticHandler.server != this) {
            throw 'Cannot assign a static handler to multiple server instances';
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
