package npm;

typedef LockFileOptions = {

    @:optional var wait:Int;

    @:optional var pollPeriod:Int;

    @:optional var retries:Int;

    @:optional var retryWait:Int;

}

@:jsRequire('lockfile')
extern class LockFile {

    @:overload(function(path:String, cb:Dynamic->Void):Void { })
    static function lock(path:String, opts:LockFileOptions, cb:Dynamic->Void):Void;

    static function lockSync(path:String, ?opts:LockFileOptions):Void;

    static function unlock(path:String, cb:Dynamic->Void):Void;

    static function unlockSync(path:String):Void;

    @:overload(function(path:String, cb:Dynamic->Void):Void { })
    static function check(path:String, opts:LockFileOptions, cb:Dynamic->Void):Void;

    static function checkSync(path:String, ?opts:LockFileOptions):Void;

} //LockFile
