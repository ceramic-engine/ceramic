// Ported from gpui-kit 0.8.1: crates/component/src/description_list.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.descriptionlist;

import gpui.AnyElement;
import gpui.App;
import gpui.Axis;
import gpui.DefiniteLength;
import gpui.IntoDefiniteLength;
import gpui.IntoElement;
import gpui.Pixels;
import gpui.RenderOnce;
import gpui.Window;
import gpui.component.Sizable;
import gpui.component.Size;
import gpui.component.Size.IntoSize;
import gpui.component.theme.Theme;

import gpui.Prelude.*;

/**
 * The label or value of a description item: a string, rich `Text` or any
 * element.
 *
 * A null source converts to a null `DescriptionText`, and a description item
 * takes a null label or value as no text: the empty string, which is what
 * Rust's `DescriptionItem::new` puts in the value it leaves unset. The cell
 * stays (with its padding, border, label width and the height of one empty
 * text line), so `DescriptionItem.create(label).value(null)` and
 * `item(label, null, span)` build the same list as
 * `DescriptionItem.create(label).span(span)`.
 */
abstract DescriptionText(AnyElement) to AnyElement {

    inline function new(element:AnyElement) {
        this = element;
    }

    @:from static function fromString(text:String):DescriptionText {
        return text != null ? new DescriptionText(div().child(text).intoAnyElement()) : null;
    }

    @:from static function fromText(text:gpui.component.text.Text):DescriptionText {
        return text != null ? new DescriptionText(gpui.component.text.Text.TextTools.intoAnyElement(text)) : null;
    }

    @:from static inline function fromIntoElement(element:IntoElement):DescriptionText {
        return element != null ? new DescriptionText(element.intoAnyElement()) : null;
    }

    /** `text`, or the empty text (Rust `"".into()`) when it is null. */
    @:allow(gpui.component.descriptionlist)
    static function orEmpty(text:Null<DescriptionText>):DescriptionText {
        return text != null ? text : fromString('');
    }

}

/**
 * An item of a `DescriptionList`: a label, a value and a column span, or a separator.
 */
class DescriptionItem {

    public final label:Null<DescriptionText>;

    public var valueText:Null<DescriptionText>;

    public var spanValue:Int;

    public final isSeparator:Bool;

    function new(label:Null<DescriptionText>, value:Null<DescriptionText>, span:Int, isSeparator:Bool) {
        // A null label or value is no text: the empty text (see `DescriptionText`).
        this.label = isSeparator ? null : DescriptionText.orEmpty(label);
        this.valueText = isSeparator ? null : DescriptionText.orEmpty(value);
        this.spanValue = span;
        this.isSeparator = isSeparator;
    }

    /** An item with the given label (empty value, span 1; a null label is the empty text). */
    public static function create(label:DescriptionText):DescriptionItem {
        return new DescriptionItem(label, '', 1, false);
    }

    public static function item(label:DescriptionText, value:DescriptionText, span:Int):DescriptionItem {
        return new DescriptionItem(label, value, span, false);
    }

    public static function separator():DescriptionItem {
        return new DescriptionItem(null, null, 0, true);
    }

    /** Set the value (null for no text, the empty text). */
    public function value(value:DescriptionText):DescriptionItem {
        if (!isSeparator) valueText = DescriptionText.orEmpty(value);
        return this;
    }

    public function span(span:Int):DescriptionItem {
        if (!isSeparator) spanValue = span;
        return this;
    }

    /** The span of an item, null for a separator. */
    @:allow(gpui.component.descriptionlist)
    function itemSpan():Null<Int> {
        return isSeparator ? null : spanValue;
    }

}

/**
 * A list of label / value pairs laid out in rows of `columns` columns
 * (3 by default), horizontally (label beside value) or vertically,
 * bordered by default.
 */
class DescriptionList implements RenderOnce implements Sizable {

    final items:Array<DescriptionItem> = [];

    var size:Size = Medium;

    var layoutValue:Axis = Horizontal;

    var labelWidthValue:DefiniteLength = DefiniteLength.Absolute(gpui.AbsoluteLength.Pixels(120.));

    var borderedValue:Bool = true;

    var columnsValue:Int = 3;

    public function new() {}

    public static function vertical():DescriptionList {
        return new DescriptionList().layout(Vertical);
    }

    public static function horizontal():DescriptionList {
        return new DescriptionList().layout(Horizontal);
    }

    /** Set the label width (horizontal layout only, default 120px). */
    public function labelWidth(labelWidth:IntoDefiniteLength):DescriptionList {
        labelWidthValue = labelWidth;
        return this;
    }

    public function layout(layout:Axis):DescriptionList {
        layoutValue = layout;
        return this;
    }

    public function bordered(bordered:Bool):DescriptionList {
        borderedValue = bordered;
        return this;
    }

    /** Set the number of columns, clamped to 1..10. */
    public function columns(columns:Int):DescriptionList {
        columnsValue = columns < 1 ? 1 : (columns > 10 ? 10 : columns);
        return this;
    }

    public function item(label:DescriptionText, value:DescriptionText, span:Int):DescriptionList {
        items.push(DescriptionItem.item(label, value, span));
        return this;
    }

    public function child(child:DescriptionItem):DescriptionList {
        if (child != null) items.push(child);
        return this;
    }

    public function children(children:Array<DescriptionItem>):DescriptionList {
        for (child in children) if (child != null) items.push(child);
        return this;
    }

    public function separator():DescriptionList {
        items.push(DescriptionItem.separator());
        return this;
    }

    public function withSize(size:IntoSize):DescriptionList {
        this.size = size;
        return this;
    }

    @:allow(tests)
    static function groupItemRows(items:Array<DescriptionItem>, columns:Int):Array<Array<DescriptionItem>> {
        final rows:Array<Array<DescriptionItem>> = [];
        var currentSpan = 0;
        for (item in items) {
            final itemSpan = item.itemSpan();
            final span = itemSpan != null ? itemSpan : columns;
            if (rows.length == 0) {
                rows.push([]);
            }
            if (currentSpan + span > columns) {
                rows.push([]);
                currentSpan = 0;
            }
            rows[rows.length - 1].push(item);
            currentSpan += span;
        }
        // Remove last empty rows if it exists
        while (rows.length > 0 && rows[rows.length - 1].length == 0) {
            gpui.util.Stacks.drop(rows);
        }
        return rows;
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final baseGap:Pixels = switch size {
            case XSmall | Small: 2.;
            case Medium: 4.;
            case Large: 8.;
            case _: 4.;
        };

        // Only for Horizontal layout
        var paddings:Array<Pixels> = switch size {
            case XSmall | Small: [4., 2.];
            case Medium: [8., 4.];
            case Large: [12., 6.];
            case _: [8., 4.];
        };
        final horizontal = layoutValue == Horizontal;
        final labelWidth = horizontal ? labelWidthValue : null;
        if (!borderedValue) {
            paddings = [0., 0.];
        }
        final paddingX = px(paddings[0]);
        final paddingY = px(paddings[1]);
        final gap:Pixels = borderedValue ? 0. : baseGap;
        final bordered = borderedValue;
        final columns = columnsValue;

        final rows = groupItemRows(items, columns);
        final rowsLen = rows.length;

        final list = gpui.base.Prelude.vFlex().gap(px(gap)).overflowHidden();
        if (bordered) {
            list.rounded(theme.radius).border1().borderColor(theme.border);
        }
        for (ix in 0...rows.length) {
            final isLast = ix == rowsLen - 1;
            final row = gpui.base.Prelude.hFlex();
            if (bordered && !isLast) {
                row.borderB1().borderColor(theme.border);
            }
            final rowItems = rows[ix];
            for (itemIx in 0...rowItems.length) {
                final item = rowItems[itemIx];
                final isFirstCol = itemIx == 0;
                if (!item.isSeparator) {
                    final el = horizontal ? div().flex().flexRow().hFull() : gpui.base.Prelude.vFlex();
                    final label = div();
                    if (horizontal) label.hFull();
                    label.textColor(theme.descriptionListLabelForeground)
                        .textSm()
                        .px(paddingX)
                        .py(paddingY);
                    if (bordered) {
                        if (horizontal) {
                            label.borderR1();
                            if (!isFirstCol) label.borderL1();
                        }
                        else {
                            label.borderB1();
                        }
                        label.borderColor(theme.border).bg(theme.tokens.descriptionListLabel.background);
                    }
                    if (labelWidth != null) {
                        label.w(labelWidth).flexShrink0();
                    }
                    label.child((item.label : AnyElement));
                    row.child(
                        el.flex1()
                            .flexBasis(relative(gpui.SpringMath.f32(gpui.SpringMath.f32(item.spanValue) / gpui.SpringMath.f32(columns))))
                            .overflowXHidden()
                            .child(label)
                            .child(div().flex1().px(paddingX).py(paddingY).overflowHidden().child((item.valueText : AnyElement)))
                    );
                }
                else {
                    final separator = div().h2().wFull();
                    if (bordered) separator.bg(theme.tokens.descriptionListLabel.background);
                    row.child(separator);
                }
            }
            list.child(row);
        }
        return list;
    }

}
