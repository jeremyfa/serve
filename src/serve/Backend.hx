package serve;

import haxe.io.Bytes;

interface Backend {

    function start(server:Server):Void;

    function host():String;

    function port():Int;

    function responseStatus(response:Response, status:Int):Void;

    function responseHeader(response:Response, name:String, value:String):Void;

    function responseText(response:Response, text:String):Void;

    function responseBinary(response:Response, data:Bytes):Void;

    function fileExists(path:String):Bool;

    function isDirectory(path:String):Bool;

    function readFile(path:String):String;

    function readBinaryFile(path:String):Bytes;

    function getFileMTime(path:String):Float;

}
