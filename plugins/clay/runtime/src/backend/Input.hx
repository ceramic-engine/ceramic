package backend;

class Input implements tracker.Events implements spec.Input {

    @event function keyDown(key:ceramic.Key);
    @event function keyUp(key:ceramic.Key);

    @event function gamepadAxis(gamepadId:Int, axisId:Int, value:Float);
    @event function gamepadDown(gamepadId:Int, buttonId:Int);
    @event function gamepadUp(gamepadId:Int, buttonId:Int);
    @event function gamepadGyro(gamepadId:Int, dx:Float, dy:Float, dz:Float);
    @event function gamepadEnable(gamepadId:Int, name:String);
    @event function gamepadDisable(gamepadId:Int);

    public function startGamepadRumble(gamepadId:Int, lowFrequency:Float, highFrequency:Float, duration:Float):Void {

        Clay.app.runtime.startGamepadRumble(gamepadId, lowFrequency, highFrequency, duration);

    };

    public function stopGamepadRumble(gamepadId:Int): Void {

        Clay.app.runtime.stopGamepadRumble(gamepadId);

    };

    public function new() {

    }

}
