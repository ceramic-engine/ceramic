// Ported from gpui-kit 0.8.1: crates/component/src/stepper/trigger.rs
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
import glaze.kit.Icon;
import glaze.kit.Size;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;

using glaze.kit.base.Geometry.AxisExt;
using glaze.kit.base.StyledExt;
using glaze.kit.StyleSized;
using glaze.kit.ThemeStyled;

/**
 * The trigger part of a stepper item.
 */
@:allow(glaze.kit.stepper)
class StepperTrigger extends Component implements Styled implements ParentElement {

    var stepValue:Int = 0;

    var checkedStepValue:Int = 0;

    final triggerStyle:StyleRefinement = new StyleRefinement();

    var iconValue:Null<Icon> = null;

    var iconSizeValue:Pixels = 24.;

    final childElements:Array<AnyElement> = [];

    var layoutValue:Axis = Horizontal;

    var disabledValue:Bool = false;

    var textCenterValue:Bool = false;

    var size:Size = Medium;

    var onClickHandler:(ClickEvent, Window, App) -> Void = (_, _, _) -> {};

    function new() {
        super();
    }

    function step(ix:Int):StepperTrigger {
        stepValue = ix;
        return this;
    }

    function checkedStep(checkedStep:Int):StepperTrigger {
        checkedStepValue = checkedStep;
        return this;
    }

    function layout(layout:Axis):StepperTrigger {
        layoutValue = layout;
        return this;
    }

    function icon(icon:Null<Icon>):StepperTrigger {
        iconValue = icon;
        return this;
    }

    function iconSize(size:Pixels):StepperTrigger {
        iconSizeValue = size;
        return this;
    }

    function disabled(disabled:Bool):StepperTrigger {
        disabledValue = disabled;
        return this;
    }

    function withSize(size:Size):StepperTrigger {
        this.size = size;
        return this;
    }

    function textCenter(center:Bool):StepperTrigger {
        textCenterValue = center;
        return this;
    }

    function onClick(f:(ClickEvent, Window, App) -> Void):StepperTrigger {
        onClickHandler = f;
        return this;
    }

    public inline function style():StyleRefinement {
        return triggerStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final isChecked = stepValue <= checkedStepValue;

        final root = div()
            .id(ElementId.NamedInteger('trigger', stepValue));
        if (layoutValue.isHorizontal()) root.vFlex().gap1();
        if (layoutValue.isVertical()) root.hFlex().gap2();
        root.itemsStart();
        if (textCenterValue) root.itemsCenter();
        root.inputTextSize(size.smaller())
            .refineStyle(triggerStyle);

        final indicator = div()
            .id('indicator')
            .size(iconSizeValue)
            .overflowHidden()
            .flex()
            .roundedFullStyle(cx)
            .itemsCenter()
            .justifyCenter()
            .bg(theme.tokens.secondary.background);
        if (!disabledValue && !isChecked) {
            indicator.hover(s -> s.bg(theme.tokens.secondaryHover.background))
                .active(s -> s.bg(theme.tokens.secondaryActive.background));
        }
        indicator.textColor(theme.secondaryForeground);
        if (isChecked) {
            indicator.bg(theme.tokens.primary.background)
                .textColor(theme.primaryForeground);
        }
        if (!size.equals(XSmall)) {
            final content:IntoElement = if (iconValue != null) {
                iconValue;
            } else {
                div().child('${stepValue + 1}');
            };
            indicator.child(content);
        }
        root.child(indicator);
        root.extend(childElements);
        if (!disabledValue) {
            final onClick = onClickHandler;
            root.onClick((event, window, cx) -> {
                onClick(event, window, cx);
            });
        }
        return root;
    }

}
