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
        continueFromHandler(req, res, 0);
    }

    function continueFromHandler(req:Request, res:Response, startIndex:Int):Void {
        for (i in startIndex...requestHandlers.length) {
            // If async was triggered, save where to continue from
            if (@:privateAccess req.asyncPending) {
                @:privateAccess req.nextHandlerIndex = i;
                return; // Pause execution
            }

            final handler = requestHandlers[i];

            // Save next handler index in case async is called
            @:privateAccess req.nextHandlerIndex = i + 1;

            handler(req, res);

            if (@:privateAccess req.routeResolved) {
                return;
            }
        }

        // Only call notFound if we're not waiting for async
        if (!@:privateAccess req.asyncPending) {
            notFound(req, res);
        }
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
