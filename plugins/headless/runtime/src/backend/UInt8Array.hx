package backend;

typedef UInt8Array = UInt8ArrayImplHeadless;

@:forward
abstract UInt8ArrayImplHeadless(Array<Int>) from Array<Int> to Array<Int> {

    public function new(size:Int) {

        this = [];
        if (size > 0) {
            this[size-1] = 0;
        }

    }

}
