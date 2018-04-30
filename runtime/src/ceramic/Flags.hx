package ceramic;

abstract Flags(Int) from Int to Int {

    inline public function new() {

        this = 0;

    } //new

    inline public function bool(bit:Int):Bool {

        var mask = 1 << bit;
        return this & mask == mask;

    } //bool

    inline public function setBool(bit:Int, bool:Bool):Void {

        this = bool ? this | (1 << bit) : this & ~(1 << bit);

    } //setBool

} //Flags
