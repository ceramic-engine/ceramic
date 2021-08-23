package elements;

import ceramic.System;
import ceramic.View;

class ImSystem extends System {

    @lazy public static var shared = new ImSystem();

    public function new() {

        super();

        earlyUpdateOrder = 100;
        lateUpdateOrder = 10000;

    }

    @:allow(elements.Im)
    function createView():Void {

        var view = new View();
        view.transparent = true;
        view.bindToNativeScreenSize();
        view.depth = 1000;
        view.onLayout(this, _layoutWindows);
        Context.context.view = view;

    }

    override function earlyUpdate(delta:Float):Void {

        Im.beginFrame();

    }

    override function lateUpdate(delta:Float):Void {

        Im.endFrame();

    }

/// Internal

    function _layoutWindows():Void {

        var subviews = Context.context.view.subviews;
        if (subviews != null) {
            for (i in 0...subviews.length) {
                var view = subviews[i];
                if (view is Window) {
                    view.autoComputeSizeIfNeeded(true);
                }
            }
        }

    }

}