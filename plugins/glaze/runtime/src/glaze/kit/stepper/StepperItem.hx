// Ported from gpui-kit 0.8.1: crates/component/src/stepper/item.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.stepper;

import glaze.AnyElement;
import glaze.App;
import glaze.Axis;
import glaze.ClickEvent;
import glaze.Component;
import glaze.ElementId;
import glaze.IntoElement;
import glaze.ParentElement;
import glaze.Pixels;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.A11y;
import glaze.kit.Icon;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;

using glaze.kit.base.Geometry.AxisExt;
using glaze.kit.base.StyledExt;

/**
 * A step item within a `Stepper`.
 */
class StepperItem extends Component implements Styled implements ParentElement implements Sizable {

    var stepValue:Int = 0;

    var checkedStepValue:Int = 0;

    final itemStyle:StyleRefinement = new StyleRefinement();

    @prop var icon:Null<Icon> = null;

    final childElements:Array<AnyElement> = [];

    var layoutValue:Axis = Horizontal;

    /**
     * Set disabled state of the stepper item.
     *
     * Will override the stepper's disabled state if set to true.
     *
     * Default is false.
     */
    @prop var disabled:Bool = false;

    var size:Size = Medium;

    var isLastValue:Bool = false;

    var textCenterValue:Bool = false;

    var onClickHandler:(ClickEvent, Window, App) -> Void = (_, _, _) -> {};

    /** The accessibility properties the item exports (filled by `render`). */
    public final a11y:A11y = new A11y(Role.ListItem);

    public function new() {
        super();
    }

    /**
     * Set the icon of the stepper item.
     */
    public function icon(icon:IntoIcon):StepperItem {
        this.icon = icon;
        return this;
    }

    @:allow(glaze.kit.stepper)
    function textCenter(center:Bool):StepperItem {
        textCenterValue = center;
        return this;
    }

    @:allow(glaze.kit.stepper)
    function step(ix:Int):StepperItem {
        stepValue = ix;
        return this;
    }

    @:allow(glaze.kit.stepper)
    function checkedStep(checkedStep:Int):StepperItem {
        checkedStepValue = checkedStep;
        return this;
    }

    @:allow(glaze.kit.stepper)
    function layout(layout:Axis):StepperItem {
        layoutValue = layout;
        return this;
    }

    @:allow(glaze.kit.stepper)
    function isLast(isLast:Bool):StepperItem {
        isLastValue = isLast;
        return this;
    }

    @:allow(glaze.kit.stepper)
    function onClick(f:(ClickEvent, Window, App) -> Void):StepperItem {
        onClickHandler = f;
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):StepperItem {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):StepperItem {
        for (child in children) if (child != null) childElements.push(child);
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
            case XSmall: glaze.Prelude.px(8.);
            case Small: glaze.Prelude.px(18.);
            case Large: glaze.Prelude.px(32.);
            case _: glaze.Prelude.px(24.);
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
            .icon(icon)
            .iconSize(iconSize)
            .step(stepValue)
            .withSize(size)
            .checkedStep(checkedStepValue)
            .textCenter(textCenterValue)
            .layout(layoutValue)
            .disabled(disabled);
        trigger.extend(childElements);
        final onClick = onClickHandler;
        root.child(trigger.onClick((e, window, cx) -> {
            onClick(e, window, cx);
        }));
        if (!isLastValue) {
            root.child(StepperSeparator.component()
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
@:allow(glaze.kit.stepper)
class StepperSeparator extends Component implements Styled {

    var size:Size = Medium;

    @prop var checked:Bool = false;

    @prop var iconSize:Pixels = 24.;

    @prop var layout:Axis = Horizontal;

    final separatorStyle:StyleRefinement = new StyleRefinement();

    @prop var textCenter:Bool = false;

    public function new() {
        super();
    }

    public function withSize(size:Size):StepperSeparator {
        this.size = size;
        return this;
    }

    public inline function style():StyleRefinement {
        return separatorStyle;
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final iconSize = this.iconSize;
        final textCenter = this.textCenter;
        final separatorWide:Pixels = switch size {
            case XSmall: glaze.Prelude.px(1.5);
            case Large: glaze.Prelude.px(3.);
            case _: glaze.Prelude.px(2.);
        };

        final gap = glaze.Prelude.px(4.);

        final root = div()
            .absolute()
            .flex1();
        if (layout.isHorizontal()) {
            root.h(separatorWide).mt(iconSize.half());
            if (!textCenter) {
                root.ml(iconSize + gap).mr(gap).left0().right0();
            } else {
                root.mx(iconSize.half() + gap)
                    .left(glaze.Prelude.relative(0.5))
                    .right(glaze.Prelude.relative(-0.5));
            }
        }
        if (layout.isVertical()) {
            root.w(separatorWide).ml(iconSize.half());
            if (!textCenter) {
                root.mt(iconSize + gap).mb(gap).top0().bottom0();
            } else {
                root.mx(iconSize.half() + gap)
                    .top(glaze.Prelude.relative(0.5))
                    .bottom(glaze.Prelude.relative(-0.5));
            }
        }
        root.refineStyle(separatorStyle)
            .bg(theme.border);
        if (checked) root.bg(theme.tokens.primary.background);
        return root;
    }

}
