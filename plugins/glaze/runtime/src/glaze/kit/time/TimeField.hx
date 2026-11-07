// Ported from gpui-kit 0.8.1: crates/component/src/time/time_field.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.time;

import glaze.App;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.Entity;
import glaze.FontFeatures;
import glaze.IntoElement;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.ComponentTraits.Disableable;
import glaze.kit.base.TimeField.TimeFieldState;
import glaze.kit.base.TimeField.TimeSegment;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.input.Input;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;
using glaze.kit.StyleSized;
using glaze.kit.ThemeStyled;

/**
 * A segmented time editor, e.g. `09:30`, `09:30:15` or `09:30 PM`.
 *
 * The value lives in `TimeFieldState` (`glaze.kit.base.TimeField`, with
 * `HourCycle`, `TimeFieldEvent`, `TimePrecision` and `TimeSegment`); see it
 * for the keyboard model.
 */
class TimeField implements RenderOnce implements Styled implements Sizable implements Disableable {

    @:allow(glaze.kit)
    @:allow(tests)
    var id:ElementIdArg;

    final state:Entity<TimeFieldState>;

    @:allow(tests)
    var size:Size = Medium;

    final fieldStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    var disabledValue:Bool = false;

    @:allow(tests)
    var invalidValue:Bool = false;

    public function new(state:Entity<TimeFieldState>) {
        this.id = ElementId.NamedInteger('time-field', state.entityId());
        this.state = state;
    }

    /**
     * Digits of equal width (OpenType `tnum`), so a value that changes while it
     * is edited keeps its width instead of shifting with each digit.
     */
    @:allow(glaze.kit)
    static function tabularFigures():FontFeatures {
        return new FontFeatures(['tnum'], [1]);
    }

    /** Rust `font_features(...)`, set on the element's text style. */
    @:allow(glaze.kit)
    static function fontFeatures<T:Styled>(element:T, features:FontFeatures):T {
        element.style().textStyle().fontFeatures = features;
        return element;
    }

    /**
     * Both period labels stacked in one grid cell, the inactive one transparent,
     * so the segment is as wide as the wider label whichever is shown.
     */
    static function periodLabel(pm:Bool):IntoElement {
        function label(text:String, active:Bool) {
            final element = div().colStart(1).rowStart(1);
            if (!active) element.textColor(transparentBlack());
            return element.child(text);
        }
        return div().grid().gridCols(1).child(label('AM', !pm)).child(label('PM', pm));
    }

    @:allow(glaze.kit)
    @:allow(tests)
    function withId(id:ElementIdArg):TimeField {
        this.id = id;
        return this;
    }

    /** Display the caller's validation result. This does not reject edits. */
    public function invalid(invalid:Bool):TimeField {
        invalidValue = invalid;
        return this;
    }

    public function withSize(size:IntoSize):TimeField {
        this.size = size;
        return this;
    }

    public function setSize(size:Size):Void {
        this.size = size;
    }

    public function disabled(disabled:Bool):TimeField {
        disabledValue = disabled;
        return this;
    }

    public function setDisabled(disabled:Bool):Void {
        disabledValue = disabled;
    }

    public inline function style():StyleRefinement {
        return fieldStyle;
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final focused = state.read(cx).focusHandle.isFocused(window);
        final colors = @:privateAccess Input.inputStyleColors(disabledValue, cx);
        final segmentRadius = theme.radius / 2.;

        final frame = fontFeatures(div()
            .flex()
            .itemsCenter()
            .flexNone(), tabularFigures())
            .bg(colors.background)
            .textColor(colors.foreground)
            .border1()
            .borderColor(theme.input)
            .rounded(theme.radius)
            .inputTextSize(size)
            .inputH(size);
        if (disabledValue) frame.opacity(0.5);
        if (focused && !disabledValue) frame.focusRingStyle(window, cx);
        if (invalidValue) frame.borderColor(theme.danger);
        frame.child(new glaze.kit.base.TimeField(id, state)
            .disabled(disabledValue)
            // The base field fills the frame, so a press anywhere inside it lands on the
            // field rather than on the frame around it.
            .flex()
            .sizeFull()
            .px1()
            .itemsCenter()
            .renderSegment((segment, state, _, cx) -> {
                final theme = Theme.global(cx);
                segment.px0p5();
                if (state.segment() == TimeSegment.Period) {
                    segment.ml1().clearChildren().child(periodLabel(state.value() == 1));
                }
                segment.rounded(segmentRadius);
                if (state.isSelected()) segment.bg(theme.selection);
                return (segment : IntoElement).intoAnyElement();
            }));
        return frame.refineStyle(fieldStyle);
    }

}
