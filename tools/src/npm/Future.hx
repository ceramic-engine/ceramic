package npm;

@:jsRequire('fibers/future')
extern class Future {

    function new();

    function wait():Void;

    @:native('return')
    function ret():Void;

}
