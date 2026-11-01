// Ported from gpui-kit 0.8.1: crates/component/src/stepper/item.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.stepper;

import gpui.AnyElement;
import gpui.App;
import gpui.Axis;
import gpui.ClickEvent;
import gpui.ElementId;
import gpui.IntoElement;
import gpui.ParentElement;
import gpui.Pixels;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.base.A11y;
import gpui.component.Icon;
import gpui.component.Sizable;
import gpui.component.Size;
import gpui.component.theme.Theme;

import gpui.Prelude.*;

using gpui.base.Geometry.AxisExt;
using gpui.base.StyledExt;

/**
 * A step item within a `Stepper`.
 */
class StepperItem implements RenderOnce implements Styled implements ParentElement implements Sizable {

    var stepValue:Int = 0;

    var checkedStepValue:Int = 0;

    final itemStyle:StyleRefinement = new StyleRefinement();

    var iconValue:Null<Icon> = null;

    final childElements:Array<AnyElement> = [];

    var layoutValue:Axis = Horizontal;

    var disabledValue:Bool = false;

    var size:Size = Medium;

    var isLastValue:Bool = false;

    var textCenterValue:Bool = false;

    var onClickHandler:(ClickEvent, Window, App) -> Void = (_, _, _) -> {};

    /** The accessibility properties the item exports (filled by `render`). */
    public final a11y:A11y = new A11y(Role.ListItem);

    public function new() {}

    /**
     * Set the icon of the stepper item.
     */
    public function icon(icon:IntoIcon):StepperItem {
        iconValue = icon;
        return this;
    }

    /**
     * Set disabled state of the stepper item.
     *
     * Will override the stepper's disabled state if set to true.
     *
     * Default is false.
     */
    public function disabled(disabled:Bool):StepperItem {
        disabledValue = disabled;
        return this;
    }

    @:allow(gpui.component.stepper)
    function textCenter(center:Bool):StepperItem {
        textCenterValue = center;
        return this;
    }

    @:allow(gpui.component.stepper)
    function step(ix:Int):StepperItem {
        stepValue = ix;
        return this;
    }

    @:allow(gpui.component.stepper)
    function checkedStep(checkedStep:Int):StepperItem {
        checkedStepValue = checkedStep;
        return this;
    }

    @:allow(gpui.component.stepper)
    function layout(layout:Axis):StepperItem {
        layoutValue = layout;
        return this;
    }

    @:allow(gpui.component.stepper)
    function isLast(isLast:Bool):StepperItem {
        isLastValue = isLast;
        return this;
    }

    @:allow(gpui.component.stepper)
    function onClick(f:(ClickEvent, Window, App) -> Void):StepperItem {
        onClickHandler = f;
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):StepperItem {
        childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):StepperItem {
        for (child in children) childElements.push(child);
        return this;
    }

    public function withSize(size:IntoSize):StepperItem {
        this.size = size;
        return this;
    }

    public function setSize(size:Size):Void {
        this.size = size;
    }

    public inline function style():StyleRefinement {
        return itemStyle;
    }

    public function render(window:Window, cx:App):IntoElement {
        final isPassed = stepValue < checkedStepValue;
        final iconSize:Pixels = switch size {
            case XSmall: gpui.Prelude.px(8.);
            case Small: gpui.Prelude.px(18.);
            case Large: gpui.Prelude.px(32.);
            case _: gpui.Prelude.px(24.);
        };

        a11y.positionInSet = stepValue + 1;
        final root = div()
            .id(ElementId.NamedInteger('stepper-item', stepValue))
            .relative();
        if (layoutValue.isHorizontal()) root.hFlex();
        if (layoutValue.isVertical()) root.vFlex();
        if (!isLastValue) root.flex1();
        if (textCenterValue) root.flex1().justifyCenter();
        root.itemsStart()
            .refineStyle(itemStyle);
        final trigger = new StepperTrigger()
            .icon(iconValue)
            .iconSize(iconSize)
            .step(stepValue)
            .withSize(size)
            .checkedStep(checkedStepValue)
            .textCenter(textCenterValue)
            .layout(layoutValue)
            .disabled(disabledValue);
        trigger.extend(childElements);
        final onClick = onClickHandler;
        root.child(trigger.onClick((e, window, cx) -> {
            onClick(e, window, cx);
        }));
        if (!isLastValue) {
            root.child(new StepperSeparator()
                .withSize(size)
                .layout(layoutValue)
                .textCenter(textCenterValue)
                .iconSize(iconSize)
                .checked(isPassed));
        }
        return root;
    }

}

/**
 * A separator between stepper items.
 *
 * Default is `absolute` positioned.
 */
@:allow(gpui.component.stepper)
class StepperSeparator implements RenderOnce implements Styled {

    var size:Size = Medium;

    var checkedValue:Bool = false;

    var iconSizeValue:Pixels = 24.;

    var layoutValue:Axis = Horizontal;

    final separatorStyle:StyleRefinement = new StyleRefinement();

    var textCenterValue:Bool = false;

    public function new() {}

    public function withSize(size:Size):StepperSeparator {
        this.size = size;
        return this;
    }

    public function textCenter(center:Bool):StepperSeparator {
        textCenterValue = center;
        return this;
    }

    public function layout(layout:Axis):StepperSeparator {
        layoutValue = layout;
        return this;
    }

    public function iconSize(size:Pixels):StepperSeparator {
        iconSizeValue = size;
        return this;
    }

    public function checked(checked:Bool):StepperSeparator {
        checkedValue = checked;
        return this;
    }

    public inline function style():StyleRefinement {
        return separatorStyle;
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final iconSize = iconSizeValue;
        final textCenter = textCenterValue;
        final separatorWide:Pixels = switch size {
            case XSmall: gpui.Prelude.px(1.5);
            case Large: gpui.Prelude.px(3.);
            case _: gpui.Prelude.px(2.);
        };

        final gap = gpui.Prelude.px(4.);

        final root = div()
            .absolute()
            .flex1();
        if (layoutValue.isHorizontal()) {
            root.h(separatorWide).mt(iconSize.half());
            if (!textCenter) {
                root.ml(iconSize + gap).mr(gap).left0().right0();
            } else {
                root.mx(iconSize.half() + gap)
                    .left(gpui.Prelude.relative(0.5))
                    .right(gpui.Prelude.relative(-0.5));
            }
        }
        if (layoutValue.isVertical()) {
            root.w(separatorWide).ml(iconSize.half());
            if (!textCenter) {
                root.mt(iconSize + gap).mb(gap).top0().bottom0();
            } else {
                root.mx(iconSize.half() + gap)
                    .top(gpui.Prelude.relative(0.5))
                    .bottom(gpui.Prelude.relative(-0.5));
            }
        }
        root.refineStyle(separatorStyle)
            .bg(theme.border);
        if (checkedValue) root.bg(theme.tokens.primary.background);
        return root;
    }

}
