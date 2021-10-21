package backend;

class Screen implements tracker.Events #if !completion implements spec.Screen #end {

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

    }

    inline public function getHeight():Int {

        return ceramic.App.app.settings.targetHeight;

    }

    inline public function getDensity():Float {

        return 1.0;

    }

    public function setBackground(background:Int):Void {

        //

    }

    public function setWindowTitle(title:String):Void {

        //

    }

    public function setWindowFullscreen(fullscreen:Bool):Void {

        //

    }

    public function screenshotToTexture(done:(texture:Texture)->Void):Void {

        done(null);

    }

    public function screenshotToPng(?path:String, done:(?data:Bytes)->Void):Void {

        done(null);

    }

    public function screenshotToPixels(done:(pixels:ceramic.UInt8Array, width:Int, height:Int)->Void):Void {

        done(null, 0, 0);

    }

}
