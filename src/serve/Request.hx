package serve;

@:structInit
@:allow(serve.Server)
class Request {

    public var uri:String;

    public var method:HttpMethod;

    public var params:Dynamic<String>;

    public var query:Dynamic<String>;

    public var body:Dynamic;

    public var rawBody:Dynamic;

    public var headers:Map<String,String>;

    public var backendItem:Any = null;

    public var server(default, null):Server;

    var resolved:Bool = false;

    var asyncPending:Bool = false;

    var handlerIndex:Int = -1;

}
