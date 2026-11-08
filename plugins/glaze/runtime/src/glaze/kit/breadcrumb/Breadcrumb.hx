// Ported from gpui-kit 0.8.1: crates/component/src/breadcrumb.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.breadcrumb;

import glaze.App;
import glaze.ClickEvent;
import glaze.Component;
import glaze.ElementId;
import glaze.IntoElement;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.A11y;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * An item of a `Breadcrumb`: a label, clickable when it has `onClick`.
 */
class BreadcrumbItem extends Component implements Styled {

    var id:ElementId = ElementId.Integer(0);

    final itemStyle:StyleRefinement = new StyleRefinement();

    final label:String;

    var onClickHandler:Null<(ClickEvent, Window, App) -> Void> = null;

    @prop var disabled:Bool = false;

    var isLastValue:Bool = false;

    /** The accessibility properties the item exports (filled by `render`). */
    public final a11y:A11y = new A11y(Role.ListItem);

    public function new(label:String) {
        super();
        this.label = label;
    }

    public function onClick(onClick:(ClickEvent, Window, App) -> Void):BreadcrumbItem {
        onClickHandler = onClick;
        return this;
    }

    @:allow(glaze.kit.breadcrumb)
    function withId(id:Int):BreadcrumbItem {
        this.id = ElementId.Integer(id);
        return this;
    }

    @:allow(glaze.kit.breadcrumb)
    function isLast(isLast:Bool):BreadcrumbItem {
        isLastValue = isLast;
        return this;
    }

    public inline function style():StyleRefinement {
        return itemStyle;
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        a11y.role = onClickHandler != null && !disabled ? Role.Link : Role.ListItem;
        final element = div()
            .id(id)
            .child(label)
            .textColor(theme.mutedForeground);
        if (isLastValue) element.textColor(theme.foreground);
        if (disabled) element.textColor(theme.mutedForeground);
        element.refineStyle(itemStyle);
        if (!disabled && onClickHandler != null) {
            final onClick = onClickHandler;
            element.cursorPointer().onClick((event, window, cx) -> onClick(event, window, cx));
        }
        return element;
    }

}

/**
 * Rust `impl Into<BreadcrumbItem>`: an item, or a string label.
 *
 * A null label converts to a null item, which `child` / `children` skip
 * (a convenience beyond Rust, like `child(null)`).
 */
abstract IntoBreadcrumbItem(BreadcrumbItem) from BreadcrumbItem to BreadcrumbItem {

    @:from static inline function fromString(label:String):IntoBreadcrumbItem {
        return label != null ? BreadcrumbItem.component(label) : null;
    }

}

/**
 * A trail of items separated by chevrons, the last one in the foreground color.
 */
class Breadcrumb extends Component implements Styled {

    final breadcrumbStyle:StyleRefinement = new StyleRefinement();

    final items:Array<BreadcrumbItem> = [];

    public function new() {
        super();
    }

    public function child(item:IntoBreadcrumbItem):Breadcrumb {
        if (item != null) items.push(item);
        return this;
    }

    public function children(items:Array<IntoBreadcrumbItem>):Breadcrumb {
        for (item in items) if (item != null) this.items.push(item);
        return this;
    }

    public inline function style():StyleRefinement {
        return breadcrumbStyle;
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final itemsCount = items.length;
        final element = glaze.kit.base.Prelude.hFlex()
            .gap1p5()
            .textSm()
            .textColor(theme.mutedForeground)
            .refineStyle(breadcrumbStyle);
        for (ix in 0...itemsCount) {
            final isLast = ix == itemsCount - 1;
            element.child(items[ix].withId(ix).isLast(isLast));
            if (!isLast) {
                element.child(Icon.component(IconName.ChevronRight).textColor(theme.mutedForeground).size3p5());
            }
        }
        return element;
    }

}
