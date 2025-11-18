package serve;

import haxe.io.Bytes;

interface SyncFileBackend {

    function fileExists(path:String):Bool;

    function isDirectory(path:String):Bool;

    function readFile(path:String):String;

    function readBinaryFile(path:String):Bytes;

    function getFileMTime(path:String):Float;

}