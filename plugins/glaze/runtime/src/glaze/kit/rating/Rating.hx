// Ported from gpui-kit 0.8.1: crates/component/src/rating.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.rating;

import glaze.App;
import glaze.Component;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.IntoHsla;
import glaze.Model;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.Size.IntoSize;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * The state of a `Rating` kept across frames (Rust `RaitingState`), with
 * observable fields: hovering or clicking re-renders without `notify`.
 */
class RatingState extends Model {

    public var defaultValue:Int;

    @observe public var value:Int;

    @observe public var hoveredValue:Int = 0;

    public function new(defaultValue:Int) {
        super();
        this.defaultValue = defaultValue;
        this.value = defaultValue;
    }

}

/**
 * A row of stars to show or pick a value between 0 and `max` (5 by
 * default). Clicking the current value clears it.
 */
class Rating extends Component implements Styled implements Sizable {

    final id:ElementId;

    final ratingStyle:StyleRefinement = new StyleRefinement();

    var size:Size = Medium;

    @prop var disabled:Bool = false;

    @:allow(tests) var valueValue:Int = 0;

    @:allow(tests) var maxValue:Int = 5;

    @prop var color:Null<Hsla> = null;

    /** Called with the new value after a click. */
    @prop var onClick:Null<(Int, Window, App) -> Void> = null;

    public function new(id:ElementIdArg) {
        super();
        this.id = id;
    }

    public function withSize(size:IntoSize):Rating {
        this.size = size;
        return this;
    }

    /** The active color (default: the theme's `yellow`). */
    public function color(color:IntoHsla):Rating {
        this.color = color;
        return this;
    }

    /** The value, at most `max`. */
    public function value(value:Int):Rating {
        valueValue = value > maxValue ? maxValue : value;
        return this;
    }

    public function max(max:Int):Rating {
        maxValue = max;
        if (valueValue > maxValue) valueValue = maxValue;
        return this;
    }

    public inline function style():StyleRefinement {
        return ratingStyle;
    }

    public function render(window:Window, cx:App):IntoElement {
        final disabled = this.disabled;
        final max = maxValue;
        final defaultValue = valueValue;
        final activeColor = color != null ? color : Theme.global(cx).yellow;
        final onClick = this.onClick;

        final state:RatingState = window.useKeyedState(id, cx, _ -> new RatingState(defaultValue)).read(cx).value;

        // Reset state if outside has changed `value` prop.
        if (state.defaultValue != defaultValue) {
            state.defaultValue = defaultValue;
            tracker.Autorun.unobserve();
            state.value = defaultValue;
            tracker.Autorun.reobserve();
        }
        final value = state.value;

        final row = glaze.kit.base.Prelude.hFlex()
            .id(id)
            .flexNowrap()
            .refineStyle(ratingStyle)
            .onHover((hovered, _, _) -> {
                if (!hovered && state.hoveredValue != 0) {
                    state.hoveredValue = 0;
                }
            });
        for (ix in 1...max + 1) {
            final filled = ix <= value;
            final hovered = state.hoveredValue >= ix;
            final star = div()
                .id(ix)
                .p0p5()
                .flexNone()
                .flexShrink0();
            if (filled || hovered) star.textColor(activeColor);
            star.child(Icon.component(filled ? IconName.StarFill : IconName.Star).withSize(size));
            if (!disabled) {
                star.onMouseMove((_, _, _) -> {
                    if (state.hoveredValue != ix) {
                        state.hoveredValue = ix;
                    }
                }).onClick((_, window, cx) -> {
                    final newValue = value >= ix ? ix - 1 : ix;
                    state.value = newValue;
                    if (onClick != null) {
                        onClick(newValue, window, cx);
                    }
                });
            }
            row.child(star);
        }
        return row;
    }

}
