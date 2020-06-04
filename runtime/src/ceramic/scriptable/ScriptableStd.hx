package ceramic.scriptable;

class ScriptableStd {

    public static function int(x:Float):Int {
        return Std.int(x);
    }

    public static function string(s:Dynamic):String {
        return Std.string(s);
    }

    public static function parseInt(s:String):Null<Int> {
        return Std.parseInt(s);
    }

    public static function parseFloat(s:String):Float {
        return Std.parseFloat(s);
    }

    public static function random(x:Int):Int {
        return Std.random(x);
    }

}