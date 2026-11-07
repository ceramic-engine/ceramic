// Ported from gpui-kit 0.8.1: crates/component/src/list/list_item.rs,
// crates/component/src/list/separator_item.rs, crates/component/src/list/loading.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.list;

import glaze.AnyElement;
import glaze.App;
import glaze.ClickEvent;
import glaze.Div;
import glaze.ElementIdArg;
import glaze.IntoElement;
import glaze.MouseButton;
import glaze.MouseDownEvent;
import glaze.MouseMoveEvent;
import glaze.ParentElement;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.ComponentTraits.Disableable;
import glaze.kit.Icon;
import glaze.kit.Icon.IntoIcon;
import glaze.kit.skeleton.Skeleton;
import glaze.kit.theme.Theme;
import glaze.kit.list.ListDelegate.ListDelegateItem;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.base.Observe;
using glaze.kit.base.StyledExt;

private enum abstract ListItemMode(Int) {
    var Entry;
    var Separator;

    public inline function isSeparator():Bool {
        return abstract == Separator;
    }
}

/**
 * A row of a `List`.
 *
 * Rust's `InteractiveElement` / `StatefulInteractiveElement` forward to the
 * stateful `base` element: register drag, drop, hover and other listeners on
 * `base` (they are not gated by `disabled` / `separator`). The accessible
 * label is kept as data (`accessibilityLabelValue`): the port has no
 * accessibility tree.
 */
class ListItem implements ListDelegateItem implements Styled implements ParentElement implements Disableable {

    /** The stateful element the item renders (Rust `interactivity()`). */
    public final base:Div;

    var mode:ListItemMode = Entry;

    final itemStyle:StyleRefinement = new StyleRefinement();

    @:allow(glaze.kit, tests)
    var disabledValue:Bool = false;

    @:allow(glaze.kit, tests)
    var selectedValue:Bool = false;

    @:allow(glaze.kit, tests)
    var secondarySelectedValue:Bool = false;

    @:allow(glaze.kit, tests)
    var confirmedValue:Bool = false;

    var checkIconValue:Null<Icon> = null;

    var onClickHandler:Null<(ClickEvent, Window, App) -> Void> = null;

    final onMouseDownHandlers:Array<{button:MouseButton, handler:(MouseDownEvent, Window, App) -> Void}> = [];

    var onMouseEnterHandler:Null<(MouseMoveEvent, Window, App) -> Void> = null;

    var suffixBuilder:Null<(Window, App) -> AnyElement> = null;

    final childElements:Array<AnyElement> = [];

    @:allow(glaze.kit, tests)
    var accessibilityLabelValue:Null<String> = null;

    public function new(id:ElementIdArg) {
        base = hFlex().id(id);
    }

    /** Set this list item to as a separator, it not able to be selected. */
    public function separator():ListItem {
        mode = Separator;
        return this;
    }

    /** Set to show check icon, default is None. */
    public function checkIcon(icon:IntoIcon):ListItem {
        checkIconValue = new Icon(icon);
        return this;
    }

    /** Set ListItem as the selected item style. */
    public function selected(selected:Bool):ListItem {
        selectedValue = selected;
        return this;
    }

    /** Set ListItem as the confirmed item style, it will show a check icon. */
    public function confirmed(confirmed:Bool):ListItem {
        confirmedValue = confirmed;
        return this;
    }

    /**
     * Set the accessibility label of the list item.
     *
     * Without this, list rows are exposed to assistive technology without a
     * name: the visible children do not become the item's accessible name.
     */
    public function accessibilityLabel(label:String):ListItem {
        accessibilityLabelValue = label;
        return this;
    }

    public function disabled(disabled:Bool):ListItem {
        disabledValue = disabled;
        return this;
    }

    public function setDisabled(disabled:Bool):Void {
        disabledValue = disabled;
    }

    /** Set the suffix element of the input field, for example a clear button. */
    public function suffix(builder:(Window, App) -> IntoElement):ListItem {
        suffixBuilder = (window, cx) -> (builder(window, cx) : AnyElement);
        return this;
    }

    public function onClick(handler:(ClickEvent, Window, App) -> Void):ListItem {
        onClickHandler = handler;
        return this;
    }

    public function onMouseDown(button:MouseButton, handler:(MouseDownEvent, Window, App) -> Void):ListItem {
        // Rust keeps them in a HashMap keyed by button.
        for (entry in onMouseDownHandlers) {
            if (entry.button == button) {
                onMouseDownHandlers.remove(entry);
                break;
            }
        }
        onMouseDownHandlers.push({button: button, handler: handler});
        return this;
    }

    public function onMouseEnter(handler:(MouseMoveEvent, Window, App) -> Void):ListItem {
        onMouseEnterHandler = handler;
        return this;
    }

    // Selectable

    public function setSelected(selected:Bool):Void {
        selectedValue = selected;
    }

    public function isSelected():Bool {
        return selectedValue;
    }

    public function setSecondarySelected(selected:Bool):Void {
        secondarySelectedValue = selected;
    }

    /** Rust `Selectable::secondary_selected`. */
    public function secondarySelected(selected:Bool):ListItem {
        secondarySelectedValue = selected;
        return this;
    }

    public function setOpen(open:Bool):Void {
        setSelected(open);
    }

    public function isOpen():Bool {
        return isSelected();
    }

    public inline function style():StyleRefinement {
        return itemStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):ListItem {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):ListItem {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final isActive = confirmedValue || selectedValue || secondarySelectedValue;

        final isSelectable = !(disabledValue || mode.isSeparator());

        // The outline is an absolute child, so it has to repeat the item's own radius.
        final outlineStyle = new StyleRefinement();
        outlineStyle.cornerRadiusTopLeft = itemStyle.cornerRadiusTopLeft;
        outlineStyle.cornerRadiusTopRight = itemStyle.cornerRadiusTopRight;
        outlineStyle.cornerRadiusBottomRight = itemStyle.cornerRadiusBottomRight;
        outlineStyle.cornerRadiusBottomLeft = itemStyle.cornerRadiusBottomLeft;

        final element = base
            .testSupport()
            .relative()
            .gapX1()
            .py1()
            .px3()
            .textBase()
            .textColor(theme.foreground)
            .relative()
            .itemsCenter()
            .justifyBetween()
            .refineStyle(itemStyle);
        // Rust `.aria_label(label)`: kept in `accessibilityLabelValue`.
        if (isSelectable) {
            if (onClickHandler != null) element.onClick(onClickHandler);
            if (onMouseEnterHandler != null) {
                final onMouseEnter = onMouseEnterHandler;
                element.onMouseMove((ev, window, cx) -> onMouseEnter(ev, window, cx));
            }
            for (entry in onMouseDownHandlers) {
                final handler = entry.handler;
                element.onMouseDown(entry.button, (ev, window, cx) -> handler(ev, window, cx));
            }
            // Register `hover` unconditionally, a conditional registration
            // leaves a stale hover style behind when the item turns active.
            element.hover(s -> isActive ? s : s.bg(theme.tokens.listHover.background));
        }
        if (!isSelectable) {
            element.textColor(theme.mutedForeground);
        }
        final row = hFlex()
            .wFull()
            .itemsCenter()
            .justifyBetween()
            .gapX1()
            .child(div().wFull().children(cast childElements));
        if (checkIconValue != null) {
            final icon = checkIconValue;
            final slot = div().w5().itemsCenter().justifyCenter();
            if (confirmedValue) {
                slot.child(icon.small().textColor(theme.mutedForeground));
            }
            row.child(slot);
        }
        element.child(row);
        if (suffixBuilder != null) element.child(suffixBuilder(window, cx));
        if (isSelectable && selectedValue) {
            final bg = theme.listSettings.activeHighlight ? theme.listActive : theme.accent;
            element.bg(bg);
        }
        if (isSelectable && secondarySelectedValue) {
            element.child(div()
                .absolute()
                .inset0()
                .border1()
                .borderColor(theme.selection)
                .refineStyle(outlineStyle));
        }
        return element;
    }

}

/**
 * A disabled list row used as a separator.
 */
class ListSeparatorItem implements ListDelegateItem implements Styled implements ParentElement {

    final separatorStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    public function new() {}

    public inline function style():StyleRefinement {
        return separatorStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):ListSeparatorItem {
        if (child != null) childElements.push(child);
        return this;
    }

    public function setSelected(_:Bool):Void {}

    public function isSelected():Bool {
        return false;
    }

    public function setSecondarySelected(_:Bool):Void {}

    public function setOpen(open:Bool):Void {
        setSelected(open);
    }

    public function isOpen():Bool {
        return isSelected();
    }

    public function render(window:Window, cx:App):IntoElement {
        final item = new ListItem("separator").refineStyle(separatorStyle);
        item.extend(childElements);
        return item.disabled(true);
    }

}

/**
 * The built-in skeleton loading view of a list.
 */
class Loading implements RenderOnce {

    public function new() {}

    public function render(window:Window, cx:App):IntoElement {
        return vFlex()
            .py2p5()
            .gap3()
            .child(new LoadingItem())
            .child(new LoadingItem())
            .child(new LoadingItem());
    }

}

private class LoadingItem implements RenderOnce {

    public function new() {}

    public function render(window:Window, cx:App):IntoElement {
        return new ListItem("skeleton").disabled(true).child(
            vFlex()
                .gap1p5()
                .overflowHidden()
                .child(new Skeleton().h5().w48().maxWFull())
                .child(new Skeleton().secondary().h3().w64().maxWFull())
        );
    }

}
