// Ported from gpui-kit 0.8.1: crates/component/src/combobox.rs (ComboboxOptions, Combobox)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.combobox;

import glaze.AbsoluteLength;
import glaze.AnyElement;
import glaze.App;
import glaze.DefiniteLength;
import glaze.ElementId;
import glaze.Entity;
import glaze.IntoElement;
import glaze.IntoLength;
import glaze.Length;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.ComponentTraits.FocusableExt;
import glaze.kit.Icon;
import glaze.kit.Icon.IntoIcon;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.Size.IntoSize;
import glaze.kit.combobox.ComboboxState.ComboboxEvent;
import glaze.kit.combobox.ComboboxState.ComboboxTriggerContext;
import glaze.kit.searchablelist.SearchableListChange;

using glaze.kit.base.StyledExt;

/**
 * Back-compat alias: new code should use `SearchableListChange` directly.
 */
typedef ComboboxChange = SearchableListChange;

/**
 * The builder options of a `Combobox`, applied to its state during render.
 */
private class ComboboxOptions {

    public var style:StyleRefinement = new StyleRefinement();
    public var size:Size = Medium;
    public var cleanable:Bool = false;
    public var placeholder:Null<String> = null;
    public var searchPlaceholder:Null<String> = null;
    public var menuWidth:Length = Length.Auto;
    public var menuMaxH:Length = Length.Definite(DefiniteLength.Absolute(AbsoluteLength.Rems(20.)));
    public var disabled:Bool = false;
    public var appearance:Bool = true;
    public var focusRingEnabled:Bool = true;
    public var triggerIcon:Null<Icon> = null;
    public var checkIcon:Null<Icon> = null;

    public function new() {}

}

/**
 * A combo box with support for single and multi-select.
 *
 * Clicking an item toggles it in the selection; the dropdown stays open until the user
 * presses Escape or clicks outside.
 */
class Combobox<I> implements RenderOnce implements Styled implements Sizable implements FocusableExt {

    final id:ElementId;

    final state:Entity<ComboboxState<I>>;

    final options:ComboboxOptions = new ComboboxOptions();

    var renderTriggerValue:Null<(ComboboxTriggerContext<I>, Window, App) -> AnyElement> = null;

    var footerValue:Null<(Window, App) -> AnyElement> = null;

    var emptyValue:Null<(Window, App) -> AnyElement> = null;

    public function new(state:Entity<ComboboxState<I>>) {
        this.id = ElementId.NamedInteger("multi-combo-box", state.entityId());
        this.state = state;
    }

    /**
     * Set the width of the dropdown menu.
     */
    public function menuWidth(width:IntoLength):Combobox<I> {
        options.menuWidth = width;
        return this;
    }

    /**
     * Set the maximum height of the dropdown menu.
     */
    public function menuMaxH(maxH:IntoLength):Combobox<I> {
        options.menuMaxH = maxH;
        return this;
    }

    /**
     * Set the placeholder text shown when no items are selected.
     */
    public function placeholder(placeholder:String):Combobox<I> {
        options.placeholder = placeholder;
        return this;
    }

    /**
     * Override the trigger chevron icon.
     */
    public function icon(icon:IntoIcon):Combobox<I> {
        options.triggerIcon = (icon:Icon);
        return this;
    }

    /**
     * Override the trailing check icon shown next to selected items.
     */
    public function checkIcon(icon:IntoIcon):Combobox<I> {
        options.checkIcon = (icon:Icon);
        return this;
    }

    /**
     * Set the placeholder text for the search input.
     */
    public function searchPlaceholder(placeholder:String):Combobox<I> {
        options.searchPlaceholder = placeholder;
        return this;
    }

    /**
     * Show a clear button when at least one item is selected.
     */
    public function cleanable(cleanable:Bool):Combobox<I> {
        options.cleanable = cleanable;
        return this;
    }

    /**
     * Set the disabled state.
     */
    public function disabled(disabled:Bool):Combobox<I> {
        options.disabled = disabled;
        return this;
    }

    /**
     * Set a custom closure that renders the empty-state element.
     */
    public function empty(builder:(Window, App) -> IntoElement):Combobox<I> {
        emptyValue = (window, cx) -> (builder(window, cx):AnyElement);
        return this;
    }

    /**
     * Control whether the trigger shows a border and background.
     */
    public function appearance(appearance:Bool):Combobox<I> {
        options.appearance = appearance;
        return this;
    }

    /**
     * Override the entire trigger element.
     */
    public function renderTrigger(f:(ComboboxTriggerContext<I>, Window, App) -> IntoElement):Combobox<I> {
        renderTriggerValue = (trigger, window, cx) -> (f(trigger, window, cx):AnyElement);
        return this;
    }

    /**
     * Render an element below a separator at the bottom of the dropdown.
     */
    public function footer(f:(Window, App) -> IntoElement):Combobox<I> {
        footerValue = (window, cx) -> (f(window, cx):AnyElement);
        return this;
    }

    public function withSize(size:IntoSize):Combobox<I> {
        options.size = size;
        return this;
    }

    public function focusRing(enabled:Bool):Combobox<I> {
        options.focusRingEnabled = enabled;
        return this;
    }

    public function setFocusRing(enabled:Bool):Void {
        options.focusRingEnabled = enabled;
    }

    public function isFocusRingEnabled():Bool {
        return options.focusRingEnabled;
    }

    public inline function style():StyleRefinement {
        return options.style;
    }

    public function render(_window:Window, cx:App):IntoElement {
        final disabled = options.disabled;
        final focusHandle = state.read(cx).state.focusHandle;
        final renderTrigger = renderTriggerValue;
        final footer = footerValue;
        final empty = emptyValue;
        final opts = options;

        state.update(cx, (this_, _) -> {
            this_.state.style = opts.style;
            this_.state.size = opts.size;
            this_.state.cleanable = opts.cleanable;
            this_.state.placeholder = opts.placeholder;
            this_.state.searchPlaceholder = opts.searchPlaceholder;
            this_.state.menuWidth = opts.menuWidth;
            this_.state.menuMaxH = opts.menuMaxH;
            this_.state.disabled = opts.disabled;
            this_.state.appearance = opts.appearance;
            this_.focusRingEnabled = opts.focusRingEnabled;
            this_.triggerIcon = opts.triggerIcon;
            this_.checkIcon = opts.checkIcon;
            this_.renderTrigger = renderTrigger;
            this_.footer = footer;

            if (empty != null) {
                this_.state.empty = empty;
            }
        });

        final isOpen = state.read(cx).state.open;
        final contentFocusHandle = state.read(cx).state.list.read(cx).focusHandle(cx);
        final openState = state;
        final confirmState = state;

        return new glaze.kit.base.Combobox(id)
            .open(isOpen)
            .disabled(disabled)
            .focusHandle(focusHandle)
            .contentFocusHandle(contentFocusHandle)
            .onOpenChange((open, _, cx) -> {
                openState.update(cx, (state, cx) -> state.setOpen(open, cx));
            })
            // This combobox commits its pending selection when the popup
            // closes, so it listens for dismissal rather than Confirm.
            .onDismiss((_, cx) -> {
                confirmState.update(cx, (state, cx) -> {
                    cx.emit(ComboboxEvent.Confirm(state.selectedValues()));
                });
            })
            .sizeFull()
            .child(state);
    }

}
