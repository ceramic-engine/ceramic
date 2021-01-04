package clay.base;

class BaseRuntime {

    public var name(default, null):String = null;

    public function init():Void {}

    public function shutdown(immediate:Bool = false):Void {}

    public function handleReady():Void {}

    public function run():Bool {

        return true;

    }

    public function windowDevicePixelRatio():Float {

        return 1.0;

    }

}
