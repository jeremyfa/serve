package serve;

#if (!completion && !display && !macro)
@:autoBuild(serve.RouterMacro.build())
#end
class Router {

    public var server(default, null):Server;

    public function new(?server:Server) {
        this.server = server;
        if (server != null) {
            server.add(this);
        }
    }

    public function handleRequest(req:Request, res:Response):Void {
        _handleRequestRoutes(req, res);
    }

    function matchRoute(route:String, uri:String):Null<Dynamic<String>> {

        if (route == null) return null;
        if (uri == null) return null;

        return Utils.matchRoute(route, uri, ":".code);

    }

    private function _handleRequestRoutes(req_:Request, res_:Response):Void {

        // Override in subclasses (automatically done by macro)

    }

}
