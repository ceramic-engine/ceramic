package ceramic;

@:structInit
class Point {

    public var x:Float;

    public var y:Float;

    function toString():String {

        return 'Point($x, $y)';

    }

    public function new(x:Float = 0, y:Float = 0) {

        this.x = x;
        this.y = y;

    }

}
