package ceramic;

abstract Flags(Int) from Int to Int {

    inline public function new() {

        this = 0;

    }

    inline public function bool(bit:Int):Bool {

        var mask = 1 << bit;
        return this & mask == mask;

    }

    inline public function setBool(bit:Int, bool:Bool):Bool {

        this = bool ? this | (1 << bit) : this & ~(1 << bit);
        return bool;

    }

    inline public static function getBool(flags:Flags, bit:Int):Bool {

        return flags.bool(bit);

    }

    inline public static function setBoolAndGetFlags(flags:Flags, bit:Int, bool:Bool):Int {

        flags.setBool(bit, bool);
        return flags;

    }

}
