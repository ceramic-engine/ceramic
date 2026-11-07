package;

import gpui.App;
import gpui.Window;

/**
 * Defaults for scenarios: both modes and a no-op teardown.
 */
class BaseScenario implements Scenario {

    public var name:String;

    public var cachedModes:Array<Bool> = [false, true];

    public function new(name:String) {
        this.name = name;
    }

    public function setup(app:App, caching:Bool):Window {
        throw 'Scenario $name: setup() not implemented';
    }

    public function step(frame:Int):Void {}

    public function teardown():Void {}

}
