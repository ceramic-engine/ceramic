package backend;

@:allow(Main)
class Screen implements spec.Screen implements ceramic.Events {

    public function new() {}

/// Events

    @event function resize();

    @event function mouseDown(buttonId:Int, x:Float, y:Float);
    @event function mouseUp(buttonId:Int, x:Float, y:Float);
    @event function mouseWheel(x:Float, y:Float);
    @event function mouseMove(x:Float, y:Float);

    @event function touchDown(touchIndex:Int, x:Float, y:Float);
    @event function touchUp(touchIndex:Int, x:Float, y:Float);
    @event function touchMove(touchIndex:Int, x:Float, y:Float);

/// Public API

    inline public function getWidth():Int {

#if completion
        return 0;
#else
        return Std.int(@:privateAccess Main.lastWidth);
#end

    } //getPixelWidth

    inline public function getHeight():Int {

#if completion
        return 0;
#else
        return Std.int(@:privateAccess Main.lastHeight);
#end

    } //getPixelHeight

    inline public function getDensity():Float {

#if completion
        return 1;
#else
        return @:privateAccess Main.lastDevicePixelRatio;
#end

    } //getPixelHeight

    public function setBackground(background:Int):Void {

        //Luxe.renderer.clear_color.rgb(background);

    } //setBackground

} //Screen
