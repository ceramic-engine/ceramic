// Ported from gpui-kit 0.8.1: crates/component/src/select.rs (`SelectOptions`, `Select`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.select;

import glaze.AnyElement;
import glaze.App;
import glaze.ElementId;
import glaze.ElementIdArg;
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

import glaze.Prelude.*;

/**
 * The builder options of a `Select`, applied to the state during render.
 */
@:allow(glaze.kit, tests)
class SelectOptions {

    var style:StyleRefinement = new StyleRefinement();

    var size:Size = Medium;

    var icon:Null<Icon> = null;

    var cleanable:Bool = false;

    var placeholder:Null<String> = null;

    var accessibilityLabel:Null<String> = null;

    var titlePrefix:Null<String> = null;

    var searchPlaceholder:Null<String> = null;

    var menuWidth:Length = Length.Auto;

    var menuMaxH:Length = Length.Definite(DefiniteLength.Absolute(AbsoluteLength.Rems(20.)));

    var scrollBounce:Null<Bool> = null;

    var disabled:Bool = false;

    var appearance:Bool = true;

    var focusRingEnabled:Bool = true;

    public function new() {}

}

/**
 * A Select element.
 */
@:allow(glaze.kit, tests)
class Select<I> implements RenderOnce implements Styled implements Sizable implements FocusableExt {

    var idValue:ElementId;

    final state:Entity<SelectState<I>>;

    final options:SelectOptions = new SelectOptions();

    var emptyBuilder:Null<(Window, App) -> AnyElement> = null;

    public function new(state:Entity<SelectState<I>>) {
        this.idValue = ElementId.NamedInteger("select", state.entityId());
        this.state = state;
    }

    /** Sets an explicit identity for the select root. */
    public function id(id:ElementIdArg):Select<I> {
        this.idValue = id;
        return this;
    }

    /** Set the width of the dropdown menu, default: `Length.Auto`. */
    public function menuWidth(width:IntoLength):Select<I> {
        options.menuWidth = width;
        return this;
    }

    /** Set the max height of the dropdown menu, default: 20rem. */
    public function menuMaxH(maxH:IntoLength):Select<I> {
        options.menuMaxH = maxH;
        return this;
    }

    /** Set the placeholder shown when no value is selected. */
    public function placeholder(placeholder:String):Select<I> {
        options.placeholder = placeholder;
        return this;
    }

    /**
     * Set the name a screen reader announces for the select.
     *
     * The placeholder and selected value are not used as the accessible name,
     * because they describe the current value rather than the control itself.
     */
    public function accessibilityLabel(label:String):Select<I> {
        options.accessibilityLabel = label;
        return this;
    }

    /** Override the trailing icon, replacing the default chevron. */
    public function icon(icon:IntoIcon):Select<I> {
        options.icon = new Icon(icon);
        return this;
    }

    /**
     * Set a label prefix shown before the selected title in the trigger.
     *
     * e.g. `titlePrefix("Country: ")` gives "Country: United States"
     */
    public function titlePrefix(prefix:String):Select<I> {
        options.titlePrefix = prefix;
        return this;
    }

    /** Show a clear button when a value is selected. */
    public function cleanable(cleanable:Bool):Select<I> {
        options.cleanable = cleanable;
        return this;
    }

    /** Set the placeholder text for the search input. */
    public function searchPlaceholder(placeholder:String):Select<I> {
        options.searchPlaceholder = placeholder;
        return this;
    }

    /**
     * Bounce the dropdown list at its vertical boundaries. On by default on iOS,
     * Android and macOS, off elsewhere; reduced motion disables displacement.
     */
    public function scrollBounce(enabled:Bool):Select<I> {
        options.scrollBounce = enabled;
        return this;
    }

    /** Set the disabled state. */
    public function disabled(disabled:Bool):Select<I> {
        options.disabled = disabled;
        return this;
    }

    /** Set a custom closure that renders the empty-state element. */
    public function empty(builder:(Window, App) -> IntoElement):Select<I> {
        emptyBuilder = (window, cx) -> (builder(window, cx) : AnyElement);
        return this;
    }

    /** Control whether the trigger shows a border and background (`true` by default). */
    public function appearance(appearance:Bool):Select<I> {
        options.appearance = appearance;
        return this;
    }

    public function withSize(size:IntoSize):Select<I> {
        options.size = size;
        return this;
    }

    public function setSize(size:Size):Void {
        options.size = size;
    }

    public function focusRing(enabled:Bool):Select<I> {
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

    public function render(window:Window, cx:App):IntoElement {
        final disabled = options.disabled;
        final accessibilityLabel = options.accessibilityLabel;
        final focusHandle = state.read(cx).state.focusHandle;
        final empty = emptyBuilder;
        final opts = options;

        state.update(cx, (this_, _) -> {
            this_.state.style = opts.style;
            this_.state.size = opts.size;
            this_.state.cleanable = opts.cleanable;
            this_.state.placeholder = opts.placeholder;
            this_.state.searchPlaceholder = opts.searchPlaceholder;
            this_.state.menuWidth = opts.menuWidth;
            this_.state.menuMaxH = opts.menuMaxH;
            this_.state.scrollBounce = opts.scrollBounce;
            this_.state.disabled = opts.disabled;
            this_.state.appearance = opts.appearance;
            this_.focusRingEnabled = opts.focusRingEnabled;
            this_.icon = opts.icon;
            this_.titlePrefix = opts.titlePrefix;

            if (empty != null) {
                this_.state.empty = empty;
            }
        });

        final isOpen = state.read(cx).state.open;
        final accessibilityValue = state.read(cx).accessibilityValue();
        final contentFocusHandle = state.read(cx).state.list.read(cx).focusHandle(cx);
        final openState = state;

        final root = new glaze.kit.base.Select(idValue)
            .open(isOpen)
            .disabled(disabled);
        if (accessibilityLabel != null) root.accessibilityLabel(accessibilityLabel);
        root.focusHandle(focusHandle)
            .contentFocusHandle(contentFocusHandle)
            .accessibilityValue(accessibilityValue)
            .onOpenChange((open, window, cx) -> {
                openState.update(cx, (state, cx) -> {
                    if (!open) {
                        state.clearQueryAndRestoreCursor(window, cx);
                    }
                    state.setOpen(open, cx);
                });
            })
            .sizeFull()
            .child(state);
        return root;
    }

}
