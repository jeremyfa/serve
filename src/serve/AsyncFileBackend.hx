package serve;

import haxe.io.Bytes;

interface AsyncFileBackend {

    function fileExistsAsync(path:String, callback:(exists:Bool)->Void):Void;

    function isDirectoryAsync(path:String, callback:(isDir:Bool)->Void):Void;

    function readFileAsync(path:String, callback:(error:Dynamic, content:String)->Void):Void;

    function readBinaryFileAsync(path:String, callback:(error:Dynamic, content:Bytes)->Void):Void;

    function getFileMTimeAsync(path:String, callback:(error:Dynamic, mtime:Float)->Void):Void;

    function getFileSizeAsync(path:String, callback:(error:Dynamic, size:Int)->Void):Void;

    function readBinaryFileRangeAsync(path:String, start:Int, end:Int, callback:(error:Dynamic, content:Bytes)->Void):Void;

}