// Ported from gpui-kit 0.8.1: crates/component/src/stepper/stepper.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.stepper;

import glaze.App;
import glaze.Axis;
import glaze.Component;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.IntoElement;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.Sizable;
import glaze.kit.Size;

import glaze.Prelude.*;

using glaze.kit.base.Geometry.AxisExt;
using glaze.kit.base.StyledExt;

/**
 * A step-by-step progress for users to navigate through a series of steps or stages.
 */
class Stepper extends Component implements Styled implements Sizable {

    final id:ElementId;

    final stepperStyle:StyleRefinement = new StyleRefinement();

    final stepItems:Array<StepperItem> = [];

    var step:Int = 0;

    /**
     * Set the layout of the stepper, default is horizontal.
     */
    @prop var layout:Axis = Horizontal;

    /**
     * Set the disabled state of the stepper, default is false.
     */
    @prop var disabled:Bool = false;

    var size:Size = Medium;

    /**
     * Set whether to center the text within each stepper item.
     */
    @prop var textCenter:Bool = false;

    /**
     * Add an on_click handler for when a step is clicked.
     *
     * The first parameter is the `step` of currently clicked item.
     */
    @prop var onClick:(Int, Window, App) -> Void = (_, _, _) -> {};

    /**
     * Creates a new stepper with the given ID.
     *
     * Default use is horizontal layout with step 0 selected.
     */
    public function new(id:ElementIdArg) {
        super();
        this.id = id;
    }

    /**
     * Sets the layout of the stepper to Vertical.
     */
    public function vertical():Stepper {
        layout = Vertical;
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
        if (layout.isHorizontal()) root.hFlex();
        if (layout.isVertical()) root.vFlex();
        root.refineStyle(stepperStyle);
        final onClick = this.onClick;
        for (step in 0...totalItems) {
            final item = stepItems[step];
            final isLast = step + 1 == totalItems;
            item.step(step)
                .withSize(size)
                .checkedStep(this.step)
                .layout(layout)
                .textCenter(textCenter);
            if (disabled) item.disabled(true);
            item.isLast(isLast)
                .onClick((_, window, cx) -> {
                    onClick(step, window, cx);
                });
            root.child(item);
        }
        return root;
    }

}
