package ceramic;

@:structInit
@:allow(ceramic.Screen)
abstract ReadOnlyPoint(Point) from Point {

    public var x(get,never):Float;
    inline function get_x():Float return this.x;

    public var y(get,never):Float;
    inline function get_y():Float return this.y;

    public inline function toPoint():Point return this;

/// Print

    function toString():String {

        return '' + {
            x: this.x,
            y: this.y
        };

    }

}
