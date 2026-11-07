// Ported from gpui-kit 0.8.1: crates/component/src/stepper/stepper.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.stepper;

import gpui.App;
import gpui.Axis;
import gpui.ElementId;
import gpui.ElementIdArg;
import gpui.IntoElement;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.component.Sizable;
import gpui.component.Size;

import gpui.Prelude.*;

using gpui.base.Geometry.AxisExt;
using gpui.base.StyledExt;

/**
 * A step-by-step progress for users to navigate through a series of steps or stages.
 */
class Stepper implements RenderOnce implements Styled implements Sizable {

    final id:ElementId;

    final stepperStyle:StyleRefinement = new StyleRefinement();

    final stepItems:Array<StepperItem> = [];

    var step:Int = 0;

    var layoutValue:Axis = Horizontal;

    var disabledValue:Bool = false;

    var size:Size = Medium;

    var textCenterValue:Bool = false;

    var onClickHandler:(Int, Window, App) -> Void = (_, _, _) -> {};

    /**
     * Creates a new stepper with the given ID.
     *
     * Default use is horizontal layout with step 0 selected.
     */
    public function new(id:ElementIdArg) {
        this.id = id;
    }

    /**
     * Set whether to center the text within each stepper item.
     */
    public function textCenter(center:Bool):Stepper {
        textCenterValue = center;
        return this;
    }

    /**
     * Set the layout of the stepper, default is horizontal.
     */
    public function layout(layout:Axis):Stepper {
        layoutValue = layout;
        return this;
    }

    /**
     * Sets the layout of the stepper to Vertical.
     */
    public function vertical():Stepper {
        layoutValue = Vertical;
        return this;
    }

    /**
     * Sets the selected index of the stepper, default is 0.
     */
    public function selectedIndex(index:Int):Stepper {
        step = index;
        return this;
    }

    /**
     * Adds a stepper item to the stepper.
     */
    public function item(item:StepperItem):Stepper {
        stepItems.push(item);
        return this;
    }

    /**
     * Add multiple stepper items to the stepper.
     */
    public function items(items:Array<StepperItem>):Stepper {
        for (item in items) stepItems.push(item);
        return this;
    }

    /**
     * Set the disabled state of the stepper, default is false.
     */
    public function disabled(disabled:Bool):Stepper {
        disabledValue = disabled;
        return this;
    }

    /**
     * Add an on_click handler for when a step is clicked.
     *
     * The first parameter is the `step` of currently clicked item.
     */
    public function onClick(f:(Int, Window, App) -> Void):Stepper {
        onClickHandler = f;
        return this;
    }

    public function withSize(size:IntoSize):Stepper {
        this.size = size;
        return this;
    }

    public function setSize(size:Size):Void {
        this.size = size;
    }

    public inline function style():StyleRefinement {
        return stepperStyle;
    }

    public function render(window:Window, cx:App):IntoElement {
        final totalItems = stepItems.length;
        final root = div()
            .id(id)
            .wFull();
        if (layoutValue.isHorizontal()) root.hFlex();
        if (layoutValue.isVertical()) root.vFlex();
        root.refineStyle(stepperStyle);
        final onClick = onClickHandler;
        for (step in 0...totalItems) {
            final item = stepItems[step];
            final isLast = step + 1 == totalItems;
            item.step(step)
                .withSize(size)
                .checkedStep(this.step)
                .layout(layoutValue)
                .textCenter(textCenterValue);
            if (disabledValue) item.disabled(true);
            item.isLast(isLast)
                .onClick((_, window, cx) -> {
                    onClick(step, window, cx);
                });
            root.child(item);
        }
        return root;
    }

}
