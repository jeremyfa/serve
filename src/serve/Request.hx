package serve;

@:structInit
class Request {

    public var uri:String;

    public var method:HttpMethod;

    public var params:Dynamic<String>;

    public var query:Dynamic<String>;

    public var body:Dynamic;

    public var headers:Map<String,String>;

    public var backendItem:Any = null;

    public var server(default, null):Server;

    var routeResolved:Bool = false;

}
