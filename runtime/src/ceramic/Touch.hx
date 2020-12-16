package ceramic;

@:structInit
@:allow(ceramic.Screen)
class Touch {

    public var index(default,null):Int;

    public var x(default,null):Float;

    public var y(default,null):Float;

    public var deltaX(default,null):Float;

    public var deltaY(default,null):Float;

/// Print

    function toString():String {

        return '' + {
            index: index,
            x: x,
            y: y,
            deltaX: deltaX,
            deltaY: deltaY
        };

    }

}
