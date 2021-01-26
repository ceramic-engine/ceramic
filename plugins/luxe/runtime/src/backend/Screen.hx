package backend;

class Screen implements tracker.Events implements spec.Screen {

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

    }

    inline public function getHeight():Int {

        return height;

    }

    inline public function getDensity():Float {

        return density;

    }

    public function setBackground(background:Int):Void {

        Luxe.renderer.clear_color.rgb(background);

    }

    public function setWindowTitle(title:String):Void {

        Luxe.core.app.config.window.title = title;
        
        #if (cpp && linc_sdl)
        var runtime:snow.modules.sdl.Runtime = cast Luxe.snow.runtime;
        sdl.SDL.setWindowTitle(runtime.window, title);
        #elseif web
        untyped document.title = title;
        #end

    }

    public function setWindowFullscreen(fullscreen:Bool):Void {

        // Not implemented

    }

}
