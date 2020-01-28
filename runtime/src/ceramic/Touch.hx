package ceramic;

@:structInit
@:allow(ceramic.Screen)
class Touch {

    public var index(default,null):Int;

    public var x(default,null):Float;

    public var y(default,null):Float;

/// Print

    function toString():String {

        return '' + {
            index: index,
            x: x,
            y: y
        };

    }

}
