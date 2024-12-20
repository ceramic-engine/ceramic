package tools;

class Native {

    public static function fileUTime(path:String, mtime_ms:Float):Void {
        Native_Extern.file_utime(path, mtime_ms);
    }

    public static function fileUTimeNow(path:String):Void {
        Native_Extern.file_utime_now(path);
    }

    public static function executablePath():String {
        return Native_Extern.executable_path();
    }

}

@:keep
#if !display
@:build(linc.Linc.touch())
@:build(linc.Linc.xml('ceramic'))
#end
@:include('linc_ceramic.h')
@:noCompletion
extern class Native_Extern {

    @:native("linc::ceramic::file_utime")
    static function file_utime(path:String, mtime_ms:Float):Void;

    @:native("linc::ceramic::file_utime_now")
    static function file_utime_now(path:String):Void;

    @:native("linc::ceramic::executable_path")
    static function executable_path():String;

}
