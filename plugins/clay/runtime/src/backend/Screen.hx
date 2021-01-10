package backend;

import clay.Clay;

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

        return Clay.app.screenWidth;

    }

    inline public function getHeight():Int {

        return Clay.app.screenHeight;

    }

    inline public function getDensity():Float {

        return Clay.app.screenDensity;

    }

    public function setBackground(background:Int):Void {

        //

    }

    public function setWindowTitle(title:String):Void {

        //

    }

}
