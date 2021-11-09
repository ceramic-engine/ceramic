package ceramic;

import ceramic.Shortcuts.*;
import ceramic.System;
import ceramic.View;

class ViewSystem extends System {

    @lazy public static var shared = new ViewSystem();

    public function new() {

        super();

        lateUpdateOrder = 7000;

    }

    @:allow(ceramic.View)
    @:keep function bind():Void {

        // Nothing to do specifically

    }

    override function lateUpdate(delta:Float):Void {

        View._updateViewsLayout(delta);

    }

}