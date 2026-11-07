// Ported from gpui-kit 0.8.1: crates/component/src/searchable_list/item.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.searchablelist;

import glaze.AnyElement;
import glaze.App;
import glaze.ElementId;
import glaze.IntoElement;
import glaze.ParentElement;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.ComponentTraits.Disableable;
import glaze.kit.base.ComponentTraits.Selectable;
import glaze.kit.Icon;
import glaze.kit.Icon.IntoIcon;
import glaze.kit.IconName;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.Size.IntoSize;
import glaze.kit.list.ListDelegate.ListDelegateItem;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.base.StyledExt;
using glaze.kit.StyleSized;

/**
 * A single row element used inside searchable-list dropdowns (Select, ComboBox, MultiComboBox).
 *
 * - `selected` controls the cursor-highlight background (the `List` overwrites this field via
 *   `Selectable.setSelected` to match the keyboard cursor position).
 * - `checked` controls the visibility of the trailing check icon; set by the adapter based on
 *   the current selection state and NOT overwritten by the `List`.
 */
class SearchableListItemElement implements RenderOnce implements Styled implements ParentElement implements Disableable implements ListDelegateItem implements Sizable {

    final id:ElementId;

    @:allow(glaze.kit, tests)
    var size:Size = Medium;

    final itemStyle:StyleRefinement = new StyleRefinement();

    /** Cursor/highlight background (overridden by `List` to the keyboard cursor row). */
    @:allow(glaze.kit, tests)
    var selectedValue:Bool = false;

    /** Whether the trailing check icon is shown. */
    @:allow(glaze.kit, tests)
    var checkedValue:Bool = false;

    @:allow(glaze.kit, tests)
    var disabledValue:Bool = false;

    final childElements:Array<AnyElement> = [];

    /** The icon drawn at the trailing edge when `checked` is `true`. */
    @:allow(glaze.kit, tests)
    var checkIconValue:Null<Icon>;

    public function new(ix:Int) {
        this.id = ElementId.NamedInteger("searchable-list-item", ix);
        this.checkIconValue = new Icon(IconName.Check);
    }

    /**
     * Set whether the trailing check icon is visible.
     */
    public function checked(checked:Bool):SearchableListItemElement {
        checkedValue = checked;
        return this;
    }

    /**
     * Override the default check icon.
     */
    public function checkIcon(icon:IntoIcon):SearchableListItemElement {
        checkIconValue = (icon:Icon);
        return this;
    }

    public function disabled(disabled:Bool):SearchableListItemElement {
        disabledValue = disabled;
        return this;
    }

    public function setDisabled(disabled:Bool):Void {
        disabledValue = disabled;
    }

    public function selected(selected:Bool):SearchableListItemElement {
        selectedValue = selected;
        return this;
    }

    public function setSelected(selected:Bool):Void {
        selectedValue = selected;
    }

    public function isSelected():Bool {
        return selectedValue;
    }

    public function setOpen(open:Bool):Void {
        setSelected(open);
    }

    public function isOpen():Bool {
        return isSelected();
    }

    /** Rust `Selectable::secondary_selected` default: no effect. */
    public function setSecondarySelected(selected:Bool):Void {}

    public function withSize(size:IntoSize):SearchableListItemElement {
        this.size = size;
        return this;
    }

    public inline function style():StyleRefinement {
        return itemStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):SearchableListItemElement {
        if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final element = hFlex()
            .id(id)
            .relative()
            .gapX1()
            .py1()
            .px2()
            .rounded(theme.radius)
            .textBase()
            .textColor(theme.foreground)
            .itemsCenter()
            .justifyBetween()
            .inputTextSize(size)
            .listSize(size)
            .refineStyle(itemStyle);
        if (!disabledValue && !selectedValue) {
            final hoverBg = theme.accent.opacity(0.7);
            element.hover(s -> s.bg(hoverBg));
        }
        if (selectedValue) {
            element.bg(theme.tokens.accent.background);
        }
        if (disabledValue) {
            element.cursorNotAllowed().textColor(theme.mutedForeground);
        }
        final inner = hFlex()
            .wFull()
            .minW0()
            .itemsCenter()
            .justifyBetween()
            .gapX1()
            .child(hFlex()
                .flex1()
                .minW0()
                .overflowHidden()
                .itemsCenter()
                .children(cast childElements));
        if (checkIconValue != null) {
            final icon = checkIconValue.xsmall().flexShrink0().textColor(theme.foreground);
            if (!checkedValue) icon.invisible();
            inner.child(icon);
        }
        return element.child(inner);
    }

}
