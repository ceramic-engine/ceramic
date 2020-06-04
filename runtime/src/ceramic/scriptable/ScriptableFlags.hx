package ceramic.scriptable;

class ScriptableFlags {

    public static function getBool(flags:Int, bit:Int):Bool {

        var mask = 1 << bit;
        return flags & mask == mask;

    }

    public static function setBoolAndGetFlags(flags:Int, bit:Int, bool:Bool):Int {

        flags = bool ? flags | (1 << bit) : flags & ~(1 << bit);
        return flags;

    }

}