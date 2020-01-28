package ceramic;

@:structInit
@:allow(ceramic.Screen)
class ImmutablePoint {

    public var x(default,null):Float;

    public var y(default,null):Float;

/// Print

    function toString():String {

        return '' + {
            x: x,
            y: y
        };

    }

}
