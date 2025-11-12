package serve;

interface Backend {

    function start(server:Server):Void;

    function host():String;

    function port():Int;

    function responseStatus(response:Response, status:Int):Void;

    function responseHeader(response:Response, name:String, value:String):Void;

    function responseText(response:Response, text:String):Void;

}
