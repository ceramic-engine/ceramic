package unityengine.networking;

@:native('UnityEngine.Networking.UnityWebRequest')
extern class UnityWebRequest {

    static function ClearCookieCache():Void;

    static function Get(uri:String):UnityWebRequest;

    static function Post(uri:String, postData:String):UnityWebRequest;

    static function Put(uri:String, bodyData:String):UnityWebRequest;

    static function Delete(uri:String):UnityWebRequest;

    static function Head(uri:String):UnityWebRequest;

    function Abort():Void;

    function Dispose():Void;

    function GetRequestHeader(name:String):String;

    function GetResponseHeaders():Any; // Dictionary<String, String>

    function SetRequestHeader(name:String, value:String):Void;

    var isNetworkError(default, null):Bool;

    var isHttpError(default, null):Bool;

    var isDone(default, null):Bool;

    var error(default, null):String;

    var responseCode(default, null):Any; // long

    var method(default, null):String;

    var timeout:Int;

}

