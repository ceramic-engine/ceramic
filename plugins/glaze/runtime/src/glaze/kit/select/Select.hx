// Ported from gpui-kit 0.8.1: crates/component/src/select.rs (`SelectOptions`, `Select`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.select;

import glaze.AnyElement;
import glaze.App;
import glaze.kit.select.SelectState.SelectEvent;
import glaze.kit.searchablelist.SearchableVec;
import glaze.kit.searchablelist.SearchableListItems;
import glaze.kit.KeyedEntity;
import glaze.Context;
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

    var idValue:Null<ElementId>;

    /**
     * The `SelectState` rendered: the one given to `component(state)` or
     * `Select.component(state)`, or the one created by `component()` once the
     * select was rendered (`null` before).
     */
    public var state(default, null):Null<Entity<SelectState<I>>>;

    final builderOptions:SelectOptions = new SelectOptions();

    var emptyBuilder:Null<(Window, App) -> AnyElement> = null;

    /**
     * The position of the `component()` call, the identity of the state
     * it creates when none is given (`null` when the state was given).
     */
    var keyedPos:Null<haxe.PosInfos> = null;

    /** `.at(key)`: the identity of the created state instead of the call position. */
    var keyedId:Null<ElementId> = null;

    var optionItems:Null<Array<I>> = null;

    var valueToPush:Null<Any> = null;

    var hasValueToPush:Bool = false;

    var changeHandler:Null<(Null<Any>) -> Void> = null;

    public function new(state:Entity<SelectState<I>>) {
        this.idValue = state != null ? ElementId.NamedInteger("select", state.entityId()) : null;
        this.state = state;
    }

    /**
     * Places a select in a tree. With `state`, it is `Select.component(state)`.
     * Without, the select creates its `SelectState` over `.options(items)`
     * the first time it is rendered and keeps it as long as it is rendered,
     * under the identity of this call (its position in the code, or
     * `.at(key)` in a loop); the state is destroyed when the select leaves
     * the tree. `.value(v)` selects the item of that value when it differs
     * from the selected one, `.onChange(f)` is called with the confirmed
     * value (the latest `f` is kept, without invalidation), and `.state`
     * gives the entity once rendered.
     */
    public static function component<I>(?state:Entity<SelectState<I>>, ?pos:haxe.PosInfos):Select<I> {
        if (state != null) return new Select<I>(state);
        final select = new Select<I>(null);
        select.keyedPos = pos;
        return select;
    }

    /**
     * The identity of the state created by `component()` without a state,
     * instead of the position of the call: needed when the call runs more
     * than once per render (a loop).
     */
    public function at(key:ElementIdArg):Select<I> {
        keyedId = key;
        return this;
    }

    /**
     * The items of the state created by `component()` (a `SearchableVec`):
     * strings, or items implementing `SearchableListItem`. Items that
     * differ from the ones applied last replace them (`setItems`).
     */
    public function options(items:Array<I>):Select<I> {
        optionItems = items;
        return this;
    }

    /**
     * Selects the item of `value` (`SearchableListItems.value`) when it is
     * not the selected one. For a select built by `component()`.
     */
    public function value(value:Null<Any>):Select<I> {
        valueToPush = value;
        hasValueToPush = true;
        return this;
    }

    /**
     * Called with the confirmed value (`SelectEvent.Confirm`, `null` when
     * cleared) of the state created by `component()`. The handler of the
     * latest render is the one called; replacing it invalidates nothing.
     */
    public function onChange(handler:(Null<Any>) -> Void):Select<I> {
        changeHandler = handler;
        return this;
    }

    static function sameItems<I>(a:Array<I>, b:Null<Array<I>>):Bool {
        if (b == null || a.length != b.length) return false;
        for (i in 0...a.length) {
            if (!SearchableListItems.itemEquals(a[i], b[i])) return false;
        }
        return true;
    }

    /**
     * Creates or finds the state of a select built by `component()` without
     * one, under the identity of the call, applies `.options()` and
     * `.value()` and installs the change handler (`KeyedEntity`).
     */
    function resolveKeyedState(window:Window, cx:App):Void {
        final key:ElementIdArg = keyedId != null ? keyedId : ElementId.CodeLocation(keyedPos.fileName, keyedPos.lineNumber);
        final initialItems:Array<I> = optionItems != null ? optionItems : [];
        final keyed:KeyedEntity<SelectState<I>, (Null<Any>) -> Void> = window.useKeyedState(key, cx, w -> {
            #if cs
            // Names I in this closure's own body: Haxe's C# output makes a closure generic
            // only then (see `SelectState`)
            final _csTypeParam:Null<I> = null;
            #end
            final holder = new KeyedEntity(cx.newEntity((c:Context<SelectState<I>>) -> new SelectState<I>(new SearchableVec<I>(initialItems), null, w, c)));
            holder.memo = initialItems;
            return holder;
        }).read(cx).value;
        final entity = keyed.entity;
        state = entity;
        keyed.handler = changeHandler;
        if (changeHandler != null) {
            keyed.subscribe(cx, SelectEvent, (entity, event, cx) -> {
                switch event {
                    case Confirm(value):
                        if (keyed.handler != null) keyed.handler(value);
                }
            });
        }
        // The state is the select's own: what is compared and pushed here
        // is not tracked by the view being rendered. Reading `selectedValue`
        // (an observable) then writing it in the view's render capture would
        // bind the view to it and unbind the view from everything it read
        // before, mid render.
        tracker.Autorun.unobserve();
        if (optionItems != null && !sameItems(optionItems, keyed.memo)) {
            final items = optionItems;
            keyed.memo = items;
            entity.update(cx, (s, c) -> s.setItems(new SearchableVec<I>(items), window, c));
        }
        if (hasValueToPush && !SearchableListItems.valueEquals(entity.read(cx).selectedValue(), valueToPush)) {
            final value = valueToPush;
            entity.update(cx, (s, c) -> s.setSelectedValue(value, window, c));
        }
        tracker.Autorun.reobserve();
    }

    /** Sets an explicit identity for the select root. */
    public function id(id:ElementIdArg):Select<I> {
        this.idValue = id;
        return this;
    }

    /** Set the width of the dropdown menu, default: `Length.Auto`. */
    public function menuWidth(width:IntoLength):Select<I> {
        builderOptions.menuWidth = width;
        return this;
    }

    /** Set the max height of the dropdown menu, default: 20rem. */
    public function menuMaxH(maxH:IntoLength):Select<I> {
        builderOptions.menuMaxH = maxH;
        return this;
    }

    /** Set the placeholder shown when no value is selected. */
    public function placeholder(placeholder:String):Select<I> {
        builderOptions.placeholder = placeholder;
        return this;
    }

    /**
     * Set the name a screen reader announces for the select.
     *
     * The placeholder and selected value are not used as the accessible name,
     * because they describe the current value rather than the control itself.
     */
    public function accessibilityLabel(label:String):Select<I> {
        builderOptions.accessibilityLabel = label;
        return this;
    }

    /** Override the trailing icon, replacing the default chevron. */
    public function icon(icon:IntoIcon):Select<I> {
        builderOptions.icon = Icon.component(icon);
        return this;
    }

    /**
     * Set a label prefix shown before the selected title in the trigger.
     *
     * e.g. `titlePrefix("Country: ")` gives "Country: United States"
     */
    public function titlePrefix(prefix:String):Select<I> {
        builderOptions.titlePrefix = prefix;
        return this;
    }

    /** Show a clear button when a value is selected. */
    public function cleanable(cleanable:Bool):Select<I> {
        builderOptions.cleanable = cleanable;
        return this;
    }

    /** Set the placeholder text for the search input. */
    public function searchPlaceholder(placeholder:String):Select<I> {
        builderOptions.searchPlaceholder = placeholder;
        return this;
    }

    /**
     * Bounce the dropdown list at its vertical boundaries. On by default on iOS,
     * Android and macOS, off elsewhere; reduced motion disables displacement.
     */
    public function scrollBounce(enabled:Bool):Select<I> {
        builderOptions.scrollBounce = enabled;
        return this;
    }

    /** Set the disabled state. */
    public function disabled(disabled:Bool):Select<I> {
        builderOptions.disabled = disabled;
        return this;
    }

    /** Set a custom closure that renders the empty-state element. */
    public function empty(builder:(Window, App) -> IntoElement):Select<I> {
        emptyBuilder = (window, cx) -> (builder(window, cx) : AnyElement);
        return this;
    }

    /** Control whether the trigger shows a border and background (`true` by default). */
    public function appearance(appearance:Bool):Select<I> {
        builderOptions.appearance = appearance;
        return this;
    }

    public function withSize(size:IntoSize):Select<I> {
        builderOptions.size = size;
        return this;
    }

    public function setSize(size:Size):Void {
        builderOptions.size = size;
    }

    public function focusRing(enabled:Bool):Select<I> {
        builderOptions.focusRingEnabled = enabled;
        return this;
    }

    public function setFocusRing(enabled:Bool):Void {
        builderOptions.focusRingEnabled = enabled;
    }

    public function isFocusRingEnabled():Bool {
        return builderOptions.focusRingEnabled;
    }

    public inline function style():StyleRefinement {
        return builderOptions.style;
    }

    public function render(window:Window, cx:App):IntoElement {
        if (state == null) resolveKeyedState(window, cx);
        if (idValue == null) idValue = ElementId.NamedInteger("select", state.entityId());
        final disabled = builderOptions.disabled;
        final accessibilityLabel = builderOptions.accessibilityLabel;
        final focusHandle = state.read(cx).state.focusHandle;
        final empty = emptyBuilder;
        final opts = builderOptions;

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

        final root = glaze.kit.base.Select.component(idValue)
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
