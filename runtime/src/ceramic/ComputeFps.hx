package ceramic;

using ceramic.Extensions;

class ComputeFps {

    var frames:Array<Float>;

    var index:Int = 0;

    var size:Int;

    public var fps(default, null):Int = 0;

    public function new(size:Int = 10) {

        this.size = size;

        frames = [];
        for (i in 0...size) {
            frames.push(0);
        }

    } //new

    public function addFrame(delta:Float) {

        frames.unsafeSet(index, delta);
        index = (index + 1) % size;

        var newFps = 0.0;
        for (i in 0...size) {
            newFps += frames.unsafeGet(i);
        }
        if (newFps > 0) {
            newFps = size / newFps;
        }
        else {
            newFps = 0;
        }

        this.fps = Math.round(Math.min(999, newFps));

    } //addFrame

} //ComputeFps
