// Ported from gpui-kit 0.8.1: crates/component/src/form/field.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.form;

import glaze.AlignItems;
import glaze.AnyElement;
import glaze.AnyView;
import glaze.App;
import glaze.Axis;
import glaze.Div;
import glaze.ElementId;
import glaze.IntoElement;
import glaze.ParentElement;
import glaze.Pixels;
import glaze.Rems;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.Size;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.base.Geometry.AxisExt;
using glaze.kit.base.StyledExt;

/**
 * The properties a `Form` hands to each of its fields.
 */
@:allow(glaze.kit.form, tests)
class FieldProps {

    var size:Size = Medium;

    var layout:Axis = Vertical;

    var columns:Int = 1;

    var labelWidth:Null<Pixels> = 140.;

    var labelTextSize:Null<Rems> = null;

    function new() {}

    /** Rust `Copy`. */
    function copy():FieldProps {
        final result = new FieldProps();
        result.size = size;
        result.layout = layout;
        result.columns = columns;
        result.labelWidth = labelWidth;
        result.labelTextSize = labelTextSize;
        return result;
    }

}

/**
 * The label or the description of a field: a text, an element built on
 * render, or a view.
 */
enum FieldBuilder {
    String(value:std.String);
    Element(builder:(Window, App) -> AnyElement);
    View(view:AnyView);
}

/**
 * Rust `impl Into<FieldBuilder>`: a string or a view.
 */
abstract IntoFieldBuilder(FieldBuilder) from FieldBuilder to FieldBuilder {

    @:from static inline function fromString(value:std.String):IntoFieldBuilder {
        return FieldBuilder.String(value);
    }

    @:from static inline function fromView(view:AnyView):IntoFieldBuilder {
        return FieldBuilder.View(view);
    }

}

/**
 * Rust `impl RenderOnce for FieldBuilder`.
 */
class FieldBuilderTools {

    public static function render(self:FieldBuilder, window:Window, cx:App):AnyElement {
        return switch self {
            case String(value): (value : IntoElement).intoAnyElement();
            case Element(builder): builder(window, cx);
            case View(view): (view : IntoElement).intoAnyElement();
        }
    }

}

/**
 * Form field element.
 */
class Field implements RenderOnce implements Styled implements ParentElement {

    var id:ElementId = ElementId.Integer(0);

    @:allow(glaze.kit.form, tests)
    var propsValue:FieldProps = new FieldProps();

    final fieldStyle:StyleRefinement = new StyleRefinement();

    var labelValue:Null<FieldBuilder> = null;

    var labelIndentValue:Bool = true;

    var descriptionValue:Null<FieldBuilder> = null;

    /**
     * Used to render the actual form field, e.g.: Input, Switch...
     */
    final childElements:Array<AnyElement> = [];

    var visibleValue:Bool = true;

    var requiredValue:Bool = false;

    /**
     * Alignment of the form field.
     */
    var alignItems:Null<AlignItems> = null;

    var colSpanValue:Int = 1;

    var colStartValue:Null<Int> = null;

    var colEndValue:Null<Int> = null;

    public function new() {}

    /**
     * Sets the label for the form field.
     */
    public function label(label:IntoFieldBuilder):Field {
        labelValue = label;
        return this;
    }

    /**
     * Sets indent with the label width (in Horizontal layout), default is `true`.
     *
     * Sometimes you want to align the input form left (Default is align after
     * the label width in Horizontal layout).
     *
     * This is only work when the `label` is not set.
     */
    public function labelIndent(indent:Bool):Field {
        labelIndentValue = indent;
        return this;
    }

    /**
     * Sets the label for the form field using a function.
     */
    public function labelFn(label:(Window, App) -> IntoElement):Field {
        labelValue = FieldBuilder.Element((window, cx) -> label(window, cx).intoAnyElement());
        return this;
    }

    /**
     * Sets the description for the form field.
     */
    public function description(description:IntoFieldBuilder):Field {
        descriptionValue = description;
        return this;
    }

    /**
     * Sets the description for the form field using a function.
     */
    public function descriptionFn(description:(Window, App) -> IntoElement):Field {
        descriptionValue = FieldBuilder.Element((window, cx) -> description(window, cx).intoAnyElement());
        return this;
    }

    /**
     * Set the visibility of the form field, default is `true`.
     */
    public function visible(visible:Bool):Field {
        visibleValue = visible;
        return this;
    }

    /**
     * Returns whether the form field is visible.
     */
    @:allow(glaze.kit.form, tests)
    function isVisible():Bool {
        return visibleValue;
    }

    /**
     * Set the required status of the form field, default is `false`.
     */
    public function required(required:Bool):Field {
        requiredValue = required;
        return this;
    }

    /**
     * Set the properties for the form field.
     *
     * This is internal API for sync props from From.
     */
    @:allow(glaze.kit.form, tests)
    function props(ix:Int, props:FieldProps):Field {
        this.id = ElementId.Integer(ix);
        this.propsValue = props;
        return this;
    }

    /**
     * Align the form field items to the start, this is the default.
     */
    public function itemsStart():Field {
        alignItems = AlignItems.Start;
        return this;
    }

    /**
     * Align the form field items to the end.
     */
    public function itemsEnd():Field {
        alignItems = AlignItems.End;
        return this;
    }

    /**
     * Align the form field items to the center.
     */
    public function itemsCenter():Field {
        alignItems = AlignItems.Center;
        return this;
    }

    /**
     * Sets the column span for the form field.
     *
     * Default is 1.
     */
    public function colSpan(colSpan:Int):Field {
        colSpanValue = colSpan;
        return this;
    }

    /**
     * Sets the column start of this form field.
     */
    public function colStart(colStart:Int):Field {
        colStartValue = colStart;
        return this;
    }

    /**
     * Sets the column end of this form field.
     */
    public function colEnd(colEnd:Int):Field {
        colEndValue = colEnd;
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):Field {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):Field {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public inline function style():StyleRefinement {
        return fieldStyle;
    }

    static inline function wrapDiv(layout:Axis):Div {
        return layout.isVertical() ? vFlex() : hFlex();
    }

    static inline function wrapLabel(labelWidth:Null<Pixels>):Div {
        final label = div();
        if (labelWidth != null) label.w(labelWidth).flexShrink0();
        return label;
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final layout = propsValue.layout;

        final labelWidth = layout.isVertical() ? null : propsValue.labelWidth;
        final hasLabel = labelIndentValue;

        final gap:Pixels = switch propsValue.size {
            case Large: 8.;
            case XSmall | Small: 4.;
            case _: 4.;
        };
        final innerGap:Pixels = layout.isHorizontal() ? gap : gap / 2.;

        final field = vFlex()
            .flex1()
            .gap(gap / 2.)
            .colSpan(colSpanValue);
        if (colStartValue != null) field.colStart(colStartValue);
        if (colEndValue != null) field.colEnd(colEndValue);
        field.refineStyle(fieldStyle);
        if (!visibleValue) field.hidden();

        // This warp for aligning the Label + Input
        final row = wrapDiv(layout)
            .id(id)
            .gap(innerGap);
        if (alignItems != null) {
            switch alignItems {
                case Start: row.itemsStart();
                case End: row.itemsEnd();
                case Center: row.itemsCenter();
                case Baseline: row.itemsBaseline();
                case _:
            }
        }
        if (hasLabel) {
            // Label
            final label = wrapLabel(labelWidth).textSm();
            if (propsValue.labelTextSize != null) label.textSize(propsValue.labelTextSize);
            label.fontMedium().gap1().itemsCenter();
            if (labelValue != null) {
                final labelRow = hFlex()
                    .gap1()
                    .child(div().overflowXHidden().child(FieldBuilderTools.render(labelValue, window, cx)));
                if (requiredValue) {
                    labelRow.child(div().textColor(theme.danger).child('*'));
                }
                label.child(labelRow);
            }
            row.child(label);
        }
        final content = div().wFull().flex1();
        content.extend(childElements);
        row.child(content);
        field.child(row);

        // Other
        final other = wrapDiv(layout).gap(innerGap);
        if (hasLabel && layout.isHorizontal()) {
            // Empty for spacing to align with the input
            other.child(wrapLabel(labelWidth));
        }
        if (descriptionValue != null) {
            other.child(
                div()
                    .textXs()
                    .textColor(theme.mutedForeground)
                    .child(FieldBuilderTools.render(descriptionValue, window, cx))
            );
        }
        field.child(other);
        return field;
    }

}
