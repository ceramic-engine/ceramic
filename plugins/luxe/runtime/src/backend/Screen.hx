package backend;

class Screen implements ceramic.Events implements spec.Screen {

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

        return Luxe.screen.w;

    } //getPixelWidth

    inline public function getHeight():Int {

        return Luxe.screen.h;

    } //getPixelHeight

    private var density:Float = -1;

    inline public function getDensity():Float {

        return density;

    } //getPixelHeight

    public function setBackground(background:Int):Void {

        Luxe.renderer.clear_color.rgb(background);

    } //setBackground

} //Screen
