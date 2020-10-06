package ceramic;

@:structInit
class Rect {

    public var x:Float;

    public var y:Float;

    public var width:Float;

    public var height:Float;

    function toString():String {

        return 'Rect($x, $y, $width, $height)';

    }

    public function new(x:Float = 0, y:Float = 0, width:Float = 0, height:Float = 0) {

        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;

    }

}
