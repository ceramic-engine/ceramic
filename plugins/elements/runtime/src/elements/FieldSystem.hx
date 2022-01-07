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

    @observe public var focusedFieldThisFrame(default, null):FieldView = null;

/// Lifecycle

    public function new() {

        super();

        earlyUpdateOrder = 50;

        focusedFieldThisFrame = focusedField;
        onFocusedFieldChange(this, handleFocusedFieldChange);

    }

    function handleFocusedFieldChange(focusedField:FieldView, prevFocusedField:FieldView) {

        if (focusedField != null) {
            focusedFieldThisFrame = focusedField;
        }
        else {
            ceramic.App.app.onceFinishDraw(this, updateFocusedFieldThisFrame);
        }

    }

    function updateFocusedFieldThisFrame() {

        focusedFieldThisFrame = focusedField;

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
            if (testedVisual is FieldView) {
                focusedField = cast testedVisual;
                break;
            }
            else if (testedVisual is RelatedToFieldView) {
                var relatedToFieldView:RelatedToFieldView = cast testedVisual;
                var fieldView = relatedToFieldView.relatedFieldView();
                if (fieldView != null) {
                    focusedField = fieldView;
                    break;
                }
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
