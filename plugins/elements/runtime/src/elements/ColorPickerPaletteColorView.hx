package elements;

import ceramic.Click;
import ceramic.Color;
import ceramic.LongPress;
import ceramic.Shortcuts.*;
import ceramic.TouchInfo;
import ceramic.Transform;
import ceramic.View;
import ceramic.Visual;
import tracker.Observable;

class ColorPickerPaletteColorView extends View implements Observable {

/// Components

    @component var click:Click;

    @component var longPress:LongPress;

    @component public var dragDrop:DragDrop;

/// Events

    @event function click(instance:ColorPickerPaletteColorView);

    @event function drop(instance:ColorPickerPaletteColorView);

    @event function longPress(instance:ColorPickerPaletteColorView, info:TouchInfo);

/// Properties

    public var dragging(get, never):Bool;
    inline function get_dragging():Bool return dragDrop.dragging;

    @:allow(elements.ColorPickerView)
    static final PALETTE_COLOR_SIZE = 14.0;

    public var colorValue(default, set):Color;
    function set_colorValue(colorValue:Color):Color {
        if (this.colorValue == colorValue)
            return colorValue;
        this.colorValue = colorValue;
        this.color = colorValue;
        return colorValue;
    }

/// Lifecycle

    public function new(colorValue:Color = Color.WHITE) {

        super();

        viewSize(PALETTE_COLOR_SIZE, PALETTE_COLOR_SIZE);

        this.colorValue = colorValue;

        click = new Click();
        click.onClick(this, () -> emitClick(this));

        longPress = new LongPress(click);
        longPress.onLongPress(this, (info) -> emitLongPress(this, info));

        dragDrop = new DragDrop(click, getDraggingVisual, releaseDraggingVisual);
        dragDrop.onDraggingChange(this, handleDraggingChange);

        transform = new Transform();

        autorun(updateStyle);

        bindDraggingDepth();

    }

    function updateStyle() {

        if (dragging) {
            transform.tx = dragDrop.dragX;
            transform.ty = dragDrop.dragY;
            transform.changedDirty = true;
        }
        else if (click.pressed) {
            transform.tx = 0;
            transform.ty = 1;
            transform.changedDirty = true;
        }
        else {
            transform.tx = 0;
            transform.ty = 0;
            transform.changedDirty = true;
        }

    }

/// Drag & Drop

    function bindDraggingDepth() {

        var originalComputedDepth:Float = computedDepth;

        app.onBeginSortVisuals(this, () -> {
            originalComputedDepth = computedDepth;
            if (dragging) {
                computedDepth = 9999999;
            }
        });

        app.onFinishSortVisuals(this, () -> {
            computedDepth = originalComputedDepth;
        });

    }

    function getDraggingVisual() {

        return this;

    }

    function releaseDraggingVisual(visual:Visual) {

        // Nothing to do

    }

    function handleDraggingChange(dragging:Bool, wasDragging:Bool) {

        trace('dragging change dragging=$dragging wasDragging=$wasDragging');

        if (wasDragging && !dragging) {
            emitDrop(this);
        }

    }

    override function toString() {

        return 'ColorPickerPaletteColorView(' + colorValue + ')';

    }

}
