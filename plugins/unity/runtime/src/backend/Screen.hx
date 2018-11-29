package backend;

class Screen implements ceramic.Events #if !completion implements spec.Screen #end {

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

        return ceramic.App.app.settings.targetWidth;

    } //getPixelWidth

    inline public function getHeight():Int {

        return ceramic.App.app.settings.targetHeight;

    } //getPixelHeight

    inline public function getDensity():Float {

        return 1.0;

    } //getPixelHeight

    public function setBackground(background:Int):Void {

        //

    } //setBackground

} //Screen
