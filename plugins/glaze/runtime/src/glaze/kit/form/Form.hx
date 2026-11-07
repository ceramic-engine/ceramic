// Ported from gpui-kit 0.8.1: crates/component/src/form/form.rs, crates/component/src/form/mod.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.form;

import glaze.AnyElement;
import glaze.App;
import glaze.Axis;
import glaze.IntoElement;
import glaze.Pixels;
import glaze.Rems;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.Size.IntoSize;
import glaze.kit.form.Field.FieldProps;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * A form element that contains multiple form fields.
 */
class Form implements RenderOnce implements Styled implements Sizable {

    /**
     * Create a new `Form` with a vertical layout.
     */
    public static function vForm():Form {
        return Form.vertical();
    }

    /**
     * Create a new `Form` with a horizontal layout.
     */
    public static function hForm():Form {
        return Form.horizontal();
    }

    /**
     * Create a new `Field`.
     */
    public static function field():Field {
        return new Field();
    }

    final formStyle:StyleRefinement = new StyleRefinement();

    @:allow(glaze.kit.form, tests)
    final fields:Array<Field> = [];

    @:allow(glaze.kit.form, tests)
    var footerValue:Null<AnyElement> = null;

    @:allow(glaze.kit.form, tests)
    final props:FieldProps = new FieldProps();

    /**
     * Creates a single-column form with labels above their controls.
     */
    public function new() {}

    /**
     * Creates a new form with labels beside their controls.
     */
    public static function horizontal():Form {
        return new Form().layout(Horizontal);
    }

    /**
     * Creates a new form with labels above their controls.
     */
    public static function vertical():Form {
        return new Form().layout(Vertical);
    }

    /**
     * Sets label/control orientation within each field, default is `Axis.Vertical`.
     *
     * This is an alias for `labelLayout`. Use `columns` to arrange fields.
     */
    public function layout(layout:Axis):Form {
        return labelLayout(layout);
    }

    /**
     * Sets label/control orientation within each field.
     *
     * `Axis.Vertical` (default) places labels above controls; `Axis.Horizontal`
     * places labels beside controls. This does not change the field grid columns.
     */
    public function labelLayout(layout:Axis):Form {
        props.layout = layout;
        return this;
    }

    /**
     * Set the width of the labels in the form. Default is `px(140.)`.
     */
    public function labelWidth(width:Pixels):Form {
        props.labelWidth = width;
        return this;
    }

    /**
     * Set the text size of the labels in the form. Default is `null`.
     */
    public function labelTextSize(size:Rems):Form {
        props.labelTextSize = size;
        return this;
    }

    /**
     * Add a child to the form.
     */
    public function child(field:Field):Form {
        if (field != null) fields.push(field);
        return this;
    }

    /**
     * Add multiple children to the form.
     */
    public function children(fields:Iterable<Field>):Form {
        glaze.util.Iterables.appendNonNull(this.fields, fields);
        return this;
    }

    /**
     * Sets content in a full-width footer after all fields, aligned to the trailing edge.
     *
     * The caller owns action composition, state, and callbacks. Calling this again
     * replaces the footer. No footer row is rendered unless content is supplied.
     */
    public function footer(footer:IntoElement):Form {
        footerValue = footer.intoAnyElement();
        return this;
    }

    /**
     * Set the column count for the field grid, independently of label orientation.
     *
     * Default is 1.
     */
    public function columns(columns:Int):Form {
        props.columns = columns;
        return this;
    }

    public inline function style():StyleRefinement {
        return formStyle;
    }

    public function withSize(size:IntoSize):Form {
        props.size = size;
        return this;
    }

    public function setSize(size:Size):Void {
        props.size = size;
    }

    public function render(window:Window, cx:App):IntoElement {
        final props = this.props;

        final gap:Pixels = switch props.size {
            case XSmall | Small: 6.;
            case Large: 12.;
            case _: 8.;
        };

        final form = vFlex()
            .wFull()
            .gapX(gap * 3.)
            .gapY(gap)
            .grid()
            .gridCols(props.columns);
        for (ix in 0...fields.length) {
            final field = fields[ix];
            if (!field.isVisible()) continue;
            form.child(field.props(ix, props.copy()));
        }
        if (footerValue != null) {
            form.child(
                hFlex()
                    .colSpanFull()
                    .minW0()
                    .justifyEnd()
                    .child(footerValue)
            );
        }
        return form.refineStyle(formStyle);
    }

}
