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

    public function recycle():Void {

        this.x = 0;
        this.y = 0;
        pool.recycle(this);

    }

    public inline static function get(x:Float = 0, y:Float = 0):Point {

        var point = pool.get();

        if (point == null) {
            point = new Point(x, y);
        }
        else {
            point.x = x;
            point.y = y;
        }

        return point;

    }

    static var pool = new Pool<Point>();

}
