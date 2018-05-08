package spec;

interface IO {

    function saveString(key:String, str:String):Bool;

    function appendString(key:String, str:String):Bool;

    function readString(key:String):String;

} //IO
