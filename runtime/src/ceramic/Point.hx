package ceramic;

@:structInit
class Point {

    public var x:Float = 0;

    public var y:Float = 0;

    public var z:Float = 0;

    function toString():String {

        return 'Point($x, $y, $z)';

    }

    public function new(x:Float = 0, y:Float = 0, z:Float = 0) {

        this.x = x;
        this.y = y;
        this.z = z;

    }

    public function recycle():Void {

        this.x = 0;
        this.y = 0;
        this.z = 0;
        pool.recycle(this);

    }

    public inline static function get(x:Float = 0, y:Float = 0, z:Float = 0):Point {

        var point = pool.get();

        if (point == null) {
            point = new Point(x, y, z);
        }
        else {
            point.x = x;
            point.y = y;
            point.z = z;
        }

        return point;

    }

    static var pool = new Pool<Point>();

}
