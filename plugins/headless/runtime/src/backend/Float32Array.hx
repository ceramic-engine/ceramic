package backend;

typedef Float32Array = Float32ArrayImplHeadless;

@:forward
abstract Float32ArrayImplHeadless(Array<Float>) from Array<Float> to Array<Float> {

    public function new(size:Int) {

        this = [];
        if (size > 0) {
            this[size-1] = 0.0;
        }

    }

}
