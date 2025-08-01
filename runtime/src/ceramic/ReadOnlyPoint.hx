package ceramic;

/**
 * A read-only view of a Point that prevents modification.
 * 
 * ReadOnlyPoint provides access to x, y, and z coordinates without
 * allowing changes. This is useful for exposing point data that
 * should not be modified by consumers.
 * 
 * Example usage:
 * ```haxe
 * var position = new Point(100, 200);
 * var readOnly:ReadOnlyPoint = position;
 * 
 * trace(readOnly.x); // 100 - OK
 * // readOnly.x = 150; // Compile error!
 * ```
 * 
 * @see Point
 */
@:structInit
@:allow(ceramic.Screen)
abstract ReadOnlyPoint(Point) from Point {

    public var x(get,never):Float;
    inline function get_x():Float return this.x;

    public var y(get,never):Float;
    inline function get_y():Float return this.y;

    public var z(get,never):Float;
    inline function get_z():Float return this.z;

    public inline function toPoint():Point return this;

/// Print

    function toString():String {

        return 'ReadOnlyPoint($x, $y, $z)';

    }

}
