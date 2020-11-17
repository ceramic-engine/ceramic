package backend;

class Screen implements tracker.Events #if !completion implements spec.Screen #end {

    public function new() {
        
        width = untyped __cs__('UnityEngine.Screen.width');
        height = untyped __cs__('UnityEngine.Screen.height');
        
    }

    var width:Int = 0;

    var height:Int = 0;

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

        return width;

    }

    inline public function getHeight():Int {

        return height;

    }

    inline public function getDensity():Float {

        return 1.0; // TODO retrieve native screen density

    }

    public function setBackground(background:Int):Void {

        // Background will be updated when drawing

    }

    public function setWindowTitle(title:String):Void {

        // TODO

    }

/// Internal

    @:allow(backend.Backend)
    function update() {

        var newWidth = untyped __cs__('UnityEngine.Screen.width');
        var newHeight = untyped __cs__('UnityEngine.Screen.height');

        var didResize = (width != newWidth) || (height != newHeight);

        width = newWidth;
        height = newHeight;

        if (didResize) {
            emitResize();
        }

    }

}
