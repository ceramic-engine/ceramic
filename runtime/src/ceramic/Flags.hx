package ceramic;

abstract Flags(Int) from Int to Int {

    inline public function new() {

        this = 0;

    }

    inline public function toInt():Int {
        return this;
    }

    inline public static function fromInt(value:Int):Flags {
        return value;
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

    inline public static extern overload function fromValues(flag0:Bool):Flags {
        return _fromValues(flag0, false, false, false, false, false, false, false);
    }

    inline public static extern overload function fromValues(flag0:Bool, flag1:Bool):Flags {
        return _fromValues(flag0, flag1, false, false, false, false, false, false);
    }

    inline public static extern overload function fromValues(flag0:Bool, flag1:Bool, flag2:Bool):Flags {
        return _fromValues(flag0, flag1, flag2, false, false, false, false, false);
    }

    inline public static extern overload function fromValues(flag0:Bool, flag1:Bool, flag2:Bool, flag3:Bool):Flags {
        return _fromValues(flag0, flag1, flag2, flag3, false, false, false, false);
    }

    inline public static extern overload function fromValues(
        flag0:Bool, flag1:Bool, flag2:Bool, flag3:Bool,
        flag4:Bool
    ):Flags {
        return _fromValues(flag0, flag1, flag2, flag3, flag4, false, false, false);
    }

    inline public static extern overload function fromValues(
        flag0:Bool, flag1:Bool, flag2:Bool, flag3:Bool,
        flag4:Bool, flag5:Bool
    ):Flags {
        return _fromValues(flag0, flag1, flag2, flag3, flag4, flag5, false, false);
    }

    inline public static extern overload function fromValues(
        flag0:Bool, flag1:Bool, flag2:Bool, flag3:Bool,
        flag4:Bool, flag5:Bool, flag6:Bool
    ):Flags {
        return _fromValues(flag0, flag1, flag2, flag3, flag4, flag5, flag6, false);
    }

    inline public static extern overload function fromValues(
        flag0:Bool, flag1:Bool, flag2:Bool, flag3:Bool,
        flag4:Bool, flag5:Bool, flag6:Bool, flag7:Bool
    ):Flags {
        return _fromValues(flag0, flag1, flag2, flag3, flag4, flag5, flag6, flag7);
    }

    inline static function _fromValues(
        flag0:Bool, flag1:Bool, flag2:Bool, flag3:Bool,
        flag4:Bool, flag5:Bool, flag6:Bool, flag7:Bool
    ):Flags {

        var flags:Flags = 0;
        if (flag0)
            flags.setBool(0, flag0);
        if (flag1)
            flags.setBool(1, flag1);
        if (flag2)
            flags.setBool(2, flag2);
        if (flag3)
            flags.setBool(3, flag3);
        if (flag4)
            flags.setBool(4, flag4);
        if (flag5)
            flags.setBool(5, flag5);
        if (flag6)
            flags.setBool(6, flag6);
        if (flag7)
            flags.setBool(7, flag7);
        return flags;

    }

}
