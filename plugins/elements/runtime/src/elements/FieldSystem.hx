package elements;

import ceramic.Entity;
import ceramic.Shortcuts.*;
import ceramic.System;
import ceramic.Visual;
import elements.FieldView;
import tracker.Autorun.reobserve;
import tracker.Autorun.unobserve;
import tracker.Observable;

class FieldSystem extends System implements Observable {

/// Statics

    @lazy public static var shared = new FieldSystem();

/// Public properties

    @observe public var focusedField:FieldView = null;

/// Lifecycle

    public function new() {

        super();

        earlyUpdateOrder = 50;

    }

    override function earlyUpdate(delta:Float):Void {

        updateFocusedField();

    }

    public function updateFocusedField():Void {

        var focusedVisual = screen.focusedVisual;

        unobserve();

        var focusedField:FieldView = null;

        var testedVisual:Visual = focusedVisual;
        while (testedVisual != null) {
            if (Std.isOfType(testedVisual, FieldView)) {
                focusedField = cast testedVisual;
                break;
            }
            testedVisual = testedVisual.parent;
        }

        var prevFocusedField = this.focusedField;

        this.focusedField = focusedField;

        if (prevFocusedField != focusedField && Std.isOfType(prevFocusedField, FieldView)) {
            var prevFieldView:FieldView = cast prevFocusedField;
            prevFieldView.didLostFocus();
        }

        reobserve();

    }

}
