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

    private var density:Float = -1;
    private var width:Int = 0;
    private var height:Int = 0;

/// Public API

    inline public function getWidth():Int {

        return width;

    } //getPixelWidth

    inline public function getHeight():Int {

        return height;

    } //getPixelHeight

    inline public function getDensity():Float {

        return density;

    } //getPixelHeight

    public function setBackground(background:Int):Void {

        Luxe.renderer.clear_color.rgb(background);

    } //setBackground

    public function setWindowTitle(title:String):Void {

        Luxe.core.app.config.window.title = title;
        
        #if (cpp && linc_sdl)
        var runtime:snow.modules.sdl.Runtime = cast Luxe.snow.runtime;
        sdl.SDL.setWindowTitle(runtime.window, title);
        #end

    } //setWindowTitle

} //Screen
