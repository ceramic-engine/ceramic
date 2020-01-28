package npm;

@:jsRequire('fibers')
extern class Fiber {

    inline static function fiber(fn:Void->Void):Fiber {
        return js.Node.require('fibers')(fn);
    }

    function run():Void;

}
