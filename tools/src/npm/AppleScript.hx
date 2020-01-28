package npm;

@:jsRequire('applescript')
extern class AppleScript {

    static function execString(script:String, callback:Dynamic->Dynamic->Void):Void;

}
