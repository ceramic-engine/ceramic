// Ported from gpui-kit 0.8.1: crates/component/src/command/state.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.command;

import glaze.AbsoluteLength;
import glaze.AnyElement;
import glaze.App;
import glaze.AppContext;
import glaze.AvailableSpace;
import glaze.Context;
import glaze.Div;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.FontFallbacks;
import glaze.FontFeatures;
import glaze.FontStyle;
import glaze.FontWeight;
import glaze.IntoElement;
import glaze.KeyBinding;
import glaze.Keystroke;
import glaze.ListSizingBehavior;
import glaze.Model;
import glaze.Pixels;
import glaze.Render;
import glaze.ScrollStrategy;
import glaze.SizeOf;
import glaze.StyleRefinement;
import glaze.Subscription;
import glaze.TextOverflow;
import glaze.WhiteSpace;
import glaze.Window;
import glaze.kit.base.Actions.Cancel;
import glaze.kit.base.Actions.Confirm;
import glaze.kit.base.Actions.SelectDown;
import glaze.kit.base.Actions.SelectUp;
import glaze.kit.base.IndexPath;
import glaze.kit.base.ScrollBounce;
import glaze.kit.base.VirtualList;
import glaze.kit.base.VirtualList.VirtualListScrollHandle;
import glaze.kit.base.input.InputBaseState;
import glaze.kit.base.input.InputEvent;
import glaze.kit.base.input.InputState;
import glaze.kit.I18n;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.command.Command.CommandOptions;
import glaze.kit.command.CommandItem.CommandEntry;
import glaze.kit.input.Input;
import glaze.kit.kbd.Kbd;
import glaze.kit.scroll.Scrollbar;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.base.ElementExt;
using glaze.kit.base.StyledExt;

typedef OnQuery = (String, Window, App) -> Void;

typedef OnIndex = (IndexPath, Window, App) -> Void;

typedef OnCancel = (Window, App) -> Void;

/**
 * The entries and callbacks of the latest `Command` render.
 */
@:allow(glaze.kit.command, tests)
class CommandModel {

    public var entries:Array<CommandEntry> = [];
    public var searchable:Bool = true;
    public var filterable:Bool = true;
    public var onQuery:Null<OnQuery> = null;
    public var onSelect:Null<OnIndex> = null;
    public var onConfirm:Null<OnIndex> = null;
    public var onCancel:Null<OnCancel> = null;

    public function new() {}

}

/**
 * One rendered line of the list.
 *
 * Groups are flattened into headings and items so the list is a single
 * sequence of rows, which is what the virtual list scrolls over.
 */
enum CommandRow {
    Heading(heading:String);
    /** Holds the index into `CommandState.matched`. */
    Item(matchedIx:Int);
    Separator;
}

@:allow(glaze.kit.command, tests)
private class TextShapeKey {

    final fontFamily:String;
    final fontFeatures:FontFeatures;
    final fontFallbacks:Null<FontFallbacks>;
    final fontSize:AbsoluteLength;
    final fontWeight:FontWeight;
    final fontStyle:FontStyle;
    final whiteSpace:WhiteSpace;
    final textOverflow:Null<TextOverflow>;
    final lineClamp:Int;

    function new(fontFamily:String, fontFeatures:FontFeatures, fontFallbacks:Null<FontFallbacks>, fontSize:AbsoluteLength, fontWeight:FontWeight,
            fontStyle:FontStyle, whiteSpace:WhiteSpace, textOverflow:Null<TextOverflow>, lineClamp:Int) {
        this.fontFamily = fontFamily;
        this.fontFeatures = fontFeatures;
        this.fontFallbacks = fontFallbacks;
        this.fontSize = fontSize;
        this.fontWeight = fontWeight;
        this.fontStyle = fontStyle;
        this.whiteSpace = whiteSpace;
        this.textOverflow = textOverflow;
        this.lineClamp = lineClamp;
    }

    function equals(other:TextShapeKey):Bool {
        return fontFamily == other.fontFamily
            && fontFeatures.equals(other.fontFeatures)
            && (fontFallbacks == null ? other.fontFallbacks == null : other.fontFallbacks != null && fontFallbacks.equals(other.fontFallbacks))
            && Type.enumEq(fontSize, other.fontSize)
            && fontWeight == other.fontWeight
            && fontStyle == other.fontStyle
            && whiteSpace == other.whiteSpace
            && (textOverflow == null ? other.textOverflow == null : other.textOverflow != null && Type.enumEq(textOverflow, other.textOverflow))
            && lineClamp == other.lineClamp;
    }

}

@:allow(glaze.kit.command, tests)
private class ListMeasurementKey {

    final contentWidth:Pixels;
    final remSize:Pixels;
    final lineHeight:Pixels;
    final textShape:TextShapeKey;

    function new(contentWidth:Pixels, remSize:Pixels, lineHeight:Pixels, textShape:TextShapeKey) {
        this.contentWidth = contentWidth;
        this.remSize = remSize;
        this.lineHeight = lineHeight;
        this.textShape = textShape;
    }

    function equals(other:Null<ListMeasurementKey>):Bool {
        return other != null
            && contentWidth == other.contentWidth
            && remSize == other.remSize
            && lineHeight == other.lineHeight
            && textShape.equals(other.textShape);
    }

}

/**
 * An item that survived the current query, and where it landed.
 */
@:allow(glaze.kit.command, tests)
private class MatchedItem {

    final entryIx:Int;
    final itemIx:Int;
    final indexPath:IndexPath;
    final rowIx:Int;
    final disabled:Bool;

    function new(entryIx:Int, itemIx:Int, indexPath:IndexPath, rowIx:Int, disabled:Bool) {
        this.entryIx = entryIx;
        this.itemIx = itemIx;
        this.indexPath = indexPath;
        this.rowIx = rowIx;
        this.disabled = disabled;
    }

}

/**
 * The interaction state of a `Command` palette: its query, focus, scrolling,
 * and highlighted command.
 */
@:allow(glaze.kit.command, tests)
class CommandState extends Model implements Render {

    public static inline final CONTEXT:String = "Command";

    /**
     * The row a separator occupies: a one-pixel rule with a little air on
     * either side. Fixed, so that only the item and heading rows need measuring.
     */
    static inline final SEPARATOR_ROW_HEIGHT:Float = 9.;

    /**
     * Rust `command::init`: binds the palette keys.
     */
    public static function init(cx:AppContext):Void {
        final context = CONTEXT;
        (cx : App).bindKeys([
            new KeyBinding("escape", new Cancel(), context),
            new KeyBinding("enter", new Confirm(false), context),
            new KeyBinding("up", new SelectUp(), context),
            new KeyBinding("down", new SelectDown(), context),
        ]);
    }

    final focusHandleValue:FocusHandle;

    final queryInput:Entity<InputState>;

    final scrollHandle:VirtualListScrollHandle;

    var model:CommandModel = new CommandModel();

    @observe var rows:Array<CommandRow> = [];

    var rowSizes:Array<glaze.Size> = [];

    var listMeasurementKey:Null<ListMeasurementKey> = null;

    var needsMeasure:Bool = true;

    /**
     * The keybinding hint each matched item showed when the rows were last
     * measured. Hints are looked up on every render, so a keymap change can
     * resize a row while the model stays the same.
     */
    var measuredBindings:Array<Null<Keystroke>> = [];

    var matched:Array<MatchedItem> = [];

    @observe var selectedIndexValue:Null<Int> = null;

    var preserveNoSelection:Bool = false;

    @observe var loading:Bool = false;

    var pendingScroll:Null<Int> = null;

    /**
     * The placeholder last written to the query input, so that `render` only
     * writes when it changed: `setPlaceholder` notifies, and an unconditional
     * notify from `render` would redraw every frame.
     */
    var appliedPlaceholder:String = "";

    var appliedQuery:String = "";

    var options:CommandOptions = new CommandOptions();

    final _subscriptions:Array<Subscription>;

    /**
     * Create an empty palette.
     */
    public function new(window:Window, cx:Context<CommandState>) {
        super();
        final queryInput = cx.newEntity(c -> new InputState(window, cast c));
        this.queryInput = queryInput;

        _subscriptions = [
            cx.subscribeIn((cast queryInput : Entity<InputBaseState>), InputEvent, window, (this_, input, event, window, cx) -> this_.onQueryInputEvent(event, window, cx)),
        ];

        focusHandleValue = cx.focusHandle();
        scrollHandle = new VirtualListScrollHandle();
    }

    /**
     * Apply the presentation of the latest `Command` render.
     */
    function setOptions(options:CommandOptions):Void {
        if (!StyleRefinementEq.textEquals(this.options.style.text, options.style.text)) {
            needsMeasure = true;
        }
        this.options = options;
    }

    function installModel(model:CommandModel, cx:Context<CommandState>):Void {
        final selectedIndexPath = selectedIndex();
        // The model reinstalls on every host re-render, usually unchanged.
        // Keep the rows and their measured sizes then: measuring lays out
        // every row, not only the visible ones.
        var sameLayout = this.model.searchable == model.searchable
            && this.model.filterable == model.filterable
            && this.model.entries.length == model.entries.length;
        if (sameLayout) {
            for (i in 0...model.entries.length) {
                if (!this.model.entries[i].sameLayout(model.entries[i])) {
                    sameLayout = false;
                    break;
                }
            }
        }
        this.model = model;
        if (!sameLayout) {
            updateMatches(cx.app);
        }

        var preservedSelection:Null<Int> = null;
        if (selectedIndexPath != null) {
            for (matchedIx in 0...matched.length) {
                final m = matched[matchedIx];
                if (!m.disabled && m.indexPath.equals(selectedIndexPath)) {
                    preservedSelection = matchedIx;
                    break;
                }
            }
        }

        if (preservedSelection != null) {
            // Preserving the selection is not a navigation: the model
            // reinstalls on every host re-render, so scrolling here would
            // move the list one frame after a hover selection.
            selectedIndexValue = preservedSelection;
            preserveNoSelection = false;
        } else if (preserveNoSelection) {
            selectedIndexValue = null;
            pendingScroll = null;
        } else {
            resetSelection();
        }
    }

    /**
     * The current search query.
     */
    public function query(cx:App):String {
        return queryInput.read(cx).value();
    }

    /**
     * Replace the search query, as if it had been typed.
     *
     * The input suppresses its own change event for a programmatic write, so
     * the re-filter and query callback happen here instead.
     */
    public function setQuery(query:String, window:Window, cx:Context<CommandState>):Void {
        if (this.query(cx.app) == query) return;

        queryInput.update(cx, (input, cx) -> input.setValue(query, window, cast cx));
        onQueryChanged(window, cx);
    }

    /**
     * The highlighted item's path in the model installed by the latest
     * `Command` render, before local filtering.
     *
     * Ungrouped items occupy section 0 and use their input position as the
     * row. Explicit groups use their group and item positions; when a model
     * mixes both forms, the implicit ungrouped section comes first.
     */
    public function selectedIndex():Null<IndexPath> {
        final ix = selectedIndexValue;
        if (ix == null || ix < 0 || ix >= matched.length) return null;
        final m = matched[ix];
        return m.disabled ? null : m.indexPath;
    }

    /**
     * Highlight an item by its original, unfiltered model path, or clear the
     * highlight with `null`.
     *
     * A path that is currently filtered out or disabled clears the
     * highlight. A visible selection is scrolled into view.
     */
    public function setSelectedIndex(index:Null<IndexPath>, window:Window, cx:Context<CommandState>):Void {
        var matchedIx:Null<Int> = null;
        if (index != null) {
            for (i in 0...matched.length) {
                if (matched[i].indexPath.equals(index) && !matched[i].disabled) {
                    matchedIx = i;
                    break;
                }
            }
        }

        final preserveNoSelection = matchedIx == null;
        if (selectedIndexValue == matchedIx) {
            this.preserveNoSelection = preserveNoSelection;
            return;
        }

        final previousIndex = selectedIndex();
        selectedIndexValue = matchedIx;
        this.preserveNoSelection = preserveNoSelection;
        pendingScroll = (matchedIx != null && matchedIx < matched.length) ? matched[matchedIx].rowIx : null;

        final callback = onSelectIfChanged(previousIndex);
        if (callback != null) {
            final onSelect = callback.onSelect;
            final index = callback.index;
            window.defer(cx.app, (window, cx) -> onSelect(index, window, cx));
        }

        cx.notify();
    }

    /**
     * The number of items matching the current query.
     */
    public function matchedCount():Int {
        return matched.length;
    }

    /**
     * Move focus to the palette's active control.
     */
    public function focus(window:Window, cx:App):Void {
        if (model.searchable) {
            queryInput.read(cx).focusHandle.focus(window, cx);
        } else {
            focusHandleValue.focus(window, cx);
        }
    }

    /**
     * Show or hide the search field's spinner, and suppress the empty message
     * while it spins.
     *
     * Turn it on while an `onQuery` callback is being answered.
     */
    public function setLoading(loading:Bool, window:Window, cx:Context<CommandState>):Void {
        this.loading = loading;
        queryInput.update(cx, (input, cx) -> input.setLoading(loading, window, cast cx));
        cx.notify();
    }

    /**
     * Whether the search field is showing its spinner.
     */
    public function isLoading():Bool {
        return loading;
    }

    // MARK: Matching

    function itemMatches(item:CommandItem, query:String):Bool {
        if (!model.searchable || !model.filterable || query.length == 0) {
            return true;
        }
        return item.matches(query);
    }

    function itemAt(matchedIx:Int):Null<CommandItem> {
        if (matchedIx < 0 || matchedIx >= matched.length) return null;
        final m = matched[matchedIx];
        if (m.entryIx < 0 || m.entryIx >= model.entries.length) return null;

        return switch model.entries[m.entryIx] {
            case Item(item): item;
            case Group(group): m.itemIx < group.items.length ? group.items[m.itemIx] : null;
            case Separator: null;
        }
    }

    /**
     * Recompute the visible rows and the matching items for the current query.
     */
    function updateMatches(cx:App):Void {
        final query = StringTools.trim(this.query(cx));

        final rows:Array<CommandRow> = [];
        final matched:Array<MatchedItem> = [];
        var hasUngroupedItems = false;
        for (entry in model.entries) {
            switch entry {
                case Item(_): hasUngroupedItems = true;
                case _:
            }
        }
        var ungroupedItemIx = 0;
        var groupIx = 0;
        // A separator is only drawn once something follows it, which drops the
        // leading, trailing and doubled separators a filtered list leaves behind.
        var pendingSeparator = false;

        for (entryIx in 0...model.entries.length) {
            switch model.entries[entryIx] {
                case Separator:
                    pendingSeparator = rows.length != 0;
                case Item(item):
                    final itemIx = ungroupedItemIx;
                    ungroupedItemIx += 1;
                    if (!itemMatches(item, query)) continue;

                    if (pendingSeparator) {
                        rows.push(Separator);
                        pendingSeparator = false;
                    }

                    final indexPath = new IndexPath(itemIx).withSection(0);
                    matched.push(new MatchedItem(entryIx, 0, indexPath, rows.length, item.isDisabled()));
                    rows.push(Item(matched.length - 1));
                case Group(group):
                    final sectionIx = groupIx + (hasUngroupedItems ? 1 : 0);
                    groupIx += 1;
                    final visible:Array<{itemIx:Int, disabled:Bool}> = [];
                    for (itemIx in 0...group.items.length) {
                        final item = group.items[itemIx];
                        if (itemMatches(item, query)) visible.push({itemIx: itemIx, disabled: item.isDisabled()});
                    }

                    if (visible.length == 0) continue;

                    if (pendingSeparator) {
                        rows.push(Separator);
                        pendingSeparator = false;
                    }

                    final heading = group.heading();
                    if (heading != null) {
                        rows.push(Heading(heading));
                    }

                    for (v in visible) {
                        final indexPath = new IndexPath(v.itemIx).withSection(sectionIx);
                        matched.push(new MatchedItem(entryIx, v.itemIx, indexPath, rows.length, v.disabled));
                        rows.push(Item(matched.length - 1));
                    }
            }
        }

        this.rows = rows;
        this.matched = matched;
        needsMeasure = true;
        if (selectedIndexValue != null && selectedIndexValue >= matched.length) {
            selectedIndexValue = null;
        }
    }

    /**
     * Move the highlight to the first item that can be confirmed.
     */
    function resetSelection():Void {
        var first:Null<Int> = null;
        for (i in 0...matched.length) {
            if (!matched[i].disabled) {
                first = i;
                break;
            }
        }
        selectedIndexValue = first;
        preserveNoSelection = false;
        pendingScroll = first != null ? matched[first].rowIx : 0;
    }

    function onQueryInputEvent(event:InputEvent, window:Window, cx:Context<CommandState>):Void {
        if (event != Change) return;

        onQueryChanged(window, cx);
    }

    /**
     * Re-filter for the query that is now in the field, and report it.
     */
    function onQueryChanged(window:Window, cx:Context<CommandState>):Void {
        final query = this.query(cx.app);
        if (query == appliedQuery) return;

        final previousSelection = selectedIndex();
        appliedQuery = query;
        updateMatches(cx.app);
        resetSelection();
        final selectionCallback = onSelectIfChanged(previousSelection);
        final queryCallback = model.searchable ? model.onQuery : null;

        if (selectionCallback != null || queryCallback != null) {
            window.defer(cx.app, (window, cx) -> {
                if (selectionCallback != null) {
                    selectionCallback.onSelect(selectionCallback.index, window, cx);
                }
                if (queryCallback != null) {
                    queryCallback(query, window, cx);
                }
            });
        }

        cx.notify();
    }

    function setListMeasurementKey(measurementKey:ListMeasurementKey, window:Window, cx:Context<CommandState>):Void {
        if (measurementKey.equals(listMeasurementKey)) return;

        listMeasurementKey = measurementKey;
        measureOnNextFrame(window, cx);
    }

    /**
     * Measure the rows again on the next frame. Called while the list is
     * drawn, where a plain notify schedules no new frame.
     */
    function measureOnNextFrame(window:Window, cx:Context<CommandState>):Void {
        needsMeasure = true;
        final entityId = cx.entityId();
        window.onNextFrame((_, cx) -> cx.notify(entityId));
    }

    // MARK: Actions

    function onSelectIfChanged(previousIndex:Null<IndexPath>):Null<{onSelect:OnIndex, index:IndexPath}> {
        final index = selectedIndex();
        if (index == null ? previousIndex == null : (previousIndex != null && index.equals(previousIndex))) return null;

        if (model.onSelect == null || index == null) return null;
        return {onSelect: model.onSelect, index: index};
    }

    /**
     * Highlight an item without scrolling it into view. Hover goes through
     * here, and revealing a half-clipped edge row would slide the next row
     * under the resting cursor, hover-selecting and scrolling in a loop.
     */
    function select(matchedIx:Int, window:Window, cx:Context<CommandState>):Void {
        if (selectedIndexValue == matchedIx) return;

        final previousIndex = selectedIndex();
        selectedIndexValue = matchedIx;
        preserveNoSelection = false;

        final callback = onSelectIfChanged(previousIndex);
        if (callback != null) {
            final onSelect = callback.onSelect;
            final index = callback.index;
            window.defer(cx.app, (window, cx) -> onSelect(index, window, cx));
        }

        cx.notify();
    }

    /**
     * Move the highlight by `step` items, wrapping around and skipping the
     * disabled ones.
     */
    function selectBy(step:Int, window:Window, cx:Context<CommandState>):Void {
        final len = matched.length;
        if (len == 0) return;

        var next:Int = selectedIndexValue != null ? selectedIndexValue : (step >= 0 ? (len > 0 ? len - 1 : 0) : 0);
        var enabled:Null<Int> = null;
        for (_ in 0...len) {
            next = remEuclid(next + step, len);
            if (!matched[next].disabled) {
                enabled = next;
                break;
            }
        }

        if (enabled != null && selectedIndexValue != enabled) {
            pendingScroll = matched[enabled].rowIx;
            select(enabled, window, cx);
        }
    }

    static inline function remEuclid(a:Int, b:Int):Int {
        final r = a % b;
        return r < 0 ? r + b : r;
    }

    function onActionSelectUp(_:SelectUp, window:Window, cx:Context<CommandState>):Void {
        selectBy(-1, window, cx);
    }

    function onActionSelectDown(_:SelectDown, window:Window, cx:Context<CommandState>):Void {
        selectBy(1, window, cx);
    }

    function onActionConfirm(_:Confirm, window:Window, cx:Context<CommandState>):Void {
        final selected = selectedIndexValue;
        if (selected != null) {
            confirm(selected, window, cx);
        }
    }

    /**
     * Escape clears a non-empty query first, and only then leaves the palette:
     * the dialog that hosts it closes on the second press.
     */
    function onActionCancel(_:Cancel, window:Window, cx:Context<CommandState>):Void {
        if (model.searchable && query(cx.app).length != 0) {
            setQuery("", window, cx);
            return;
        }

        // Cancel is the one synchronous callback: propagation must continue in
        // this dispatch so a hosting Dialog observes it once and owns the pop.
        final onCancel = model.onCancel;
        if (onCancel != null) {
            onCancel(window, cx.app);
        }

        cx.propagate();
    }

    function confirm(matchedIx:Int, window:Window, cx:Context<CommandState>):Void {
        final item = itemAt(matchedIx);
        if (item == null) return;
        if (item.isDisabled()) return;

        final indexPath = matched[matchedIx].indexPath;
        final action = item.actionValue != null ? item.actionValue.boxedClone() : null;
        final onConfirm = model.onConfirm;

        if (action != null) {
            window.dispatchAction(action, cx.app);
        }
        if (onConfirm != null) {
            window.defer(cx.app, (window, cx) -> onConfirm(indexPath, window, cx));
        }
    }

    // MARK: Row sizing

    /**
     * Measure each row before passing the sizes to the virtual list. Custom
     * item elements can have independent intrinsic heights.
     */
    function measureRows(window:Window, cx:Context<CommandState>):Void {
        final available = new SizeOf<AvailableSpace>(
            listMeasurementKey != null ? AvailableSpace.Definite(listMeasurementKey.contentWidth) : AvailableSpace.MinContent,
            AvailableSpace.MinContent
        );
        final textStyle = new StyleRefinement();
        textStyle.text = options.style.text != null ? options.style.text.clone() : null;
        final bindings:Array<Null<Keystroke>> = [for (_ in 0...matched.length) null];

        final rowSizes:Array<glaze.Size> = [];
        for (rowIx in 0...rows.length) {
            final row:AnyElement = switch rows[rowIx] {
                case Separator:
                    rowSizes.push(new glaze.Size(0., SEPARATOR_ROW_HEIGHT));
                    continue;
                case Heading(_):
                    renderRow(rowIx, window, cx);
                case Item(matchedIx):
                    final binding = itemBinding(matchedIx, window, cx.app);
                    bindings[matchedIx] = binding != null ? binding.keystroke() : null;
                    renderItemWithBinding(matchedIx, binding, window, cx);
            };
            final element = div()
                .refineStyle(textStyle)
                .child(row)
                .intoAnyElement();
            final rowSize = element.layoutAsRoot(available, window, cx.app);
            rowSizes.push(new glaze.Size(0., rowSize.height));
        }

        this.rowSizes = rowSizes;
        measuredBindings = bindings;
    }

    // MARK: Rendering

    function syncPlaceholder(window:Window, cx:Context<CommandState>):Void {
        final placeholder = options.placeholder != null ? options.placeholder : I18n.t("Command.placeholder");

        if (appliedPlaceholder == placeholder) return;

        appliedPlaceholder = placeholder;
        queryInput.update(cx, (input, cx) -> input.setPlaceholder(placeholder, window, cast cx));
    }

    /**
     * Row corner radius, concentric with the frame: the list's `p_1` (plus the
     * border when bordered) sits between a row and the frame's corner. A
     * borderless command without its own radius keeps the theme radius, since
     * its frame belongs to the host.
     */
    function itemRadius(window:Window, cx:App):Pixels {
        final theme = Theme.global(cx);
        final remSize = window.remSize();
        final ownRadius = options.style.cornerRadiusTopLeft;
        var outer:Float;
        var border:Float;
        if (options.bordered) {
            outer = ownRadius == null ? theme.radiusLg : ownRadius.toPixels(remSize);
            border = 1.;
        } else if (ownRadius != null) {
            outer = ownRadius.toPixels(remSize);
            border = 0.;
        } else {
            return theme.radius;
        }
        return glaze.util.MathUtil.max(outer - (remSize:Float) * 0.25 - border, 0.);
    }

    /**
     * The frame every item row shares, so that the measured height matches the
     * rendered one.
     */
    function itemRow(selected:Bool, window:Window, cx:App):Div {
        final theme = Theme.global(cx);
        final row = div()
            .flex()
            .flexRow()
            .itemsCenter()
            .wFull()
            .gap2()
            .px2()
            .py1p5()
            .textSm()
            .rounded(itemRadius(window, cx));
        if (selected) {
            row.bg(theme.accent).textColor(theme.accentForeground);
        }
        return row;
    }

    function headingRow(heading:String, cx:App):Div {
        return div()
            .wFull()
            .px2()
            .py1p5()
            .textXs()
            .fontMedium()
            .textColor(Theme.global(cx).mutedForeground)
            .child(heading);
    }

    function renderRow(rowIx:Int, window:Window, cx:Context<CommandState>):AnyElement {
        if (rowIx < 0 || rowIx >= rows.length) return div().intoAnyElement();
        return switch rows[rowIx] {
            case Separator:
                div()
                    .wFull()
                    .py(px(4.))
                    .child(div().h(px(1.)).wFull().bg(Theme.global(cx.app).border))
                    .intoAnyElement();
            case Heading(heading):
                headingRow(heading, cx.app).intoAnyElement();
            case Item(matchedIx):
                renderItem(matchedIx, window, cx);
        }
    }

    /**
     * Render a row the virtual list shows. When an item's keybinding hint no
     * longer matches the one it was measured with, measure the rows again.
     */
    function renderVisibleRow(rowIx:Int, window:Window, cx:Context<CommandState>):AnyElement {
        final matchedIx = (rowIx >= 0 && rowIx < rows.length) ? switch rows[rowIx] {
            case Item(matchedIx): matchedIx;
            case _: -1;
        } : -1;
        if (matchedIx < 0) return renderRow(rowIx, window, cx);

        final binding = itemBinding(matchedIx, window, cx.app);
        final measured = matchedIx < measuredBindings.length ? measuredBindings[matchedIx] : null;
        final keystroke = binding != null ? binding.keystroke() : null;
        if (!needsMeasure && !keystrokeEquals(measured, keystroke)) {
            measureOnNextFrame(window, cx);
        }

        return renderItemWithBinding(matchedIx, binding, window, cx);
    }

    static function keystrokeEquals(a:Null<Keystroke>, b:Null<Keystroke>):Bool {
        if (a == null || b == null) return a == b;
        return a.equals(b);
    }

    /**
     * The keybinding hint an item shows in its trailing slot. A custom child
     * owns its complete presentation, so it has none.
     */
    function itemBinding(matchedIx:Int, window:Window, cx:App):Null<Kbd> {
        final item = itemAt(matchedIx);
        if (item == null) return null;
        if (item.content != null) return null;

        final action = item.actionValue;
        if (action == null) return null;
        final binding = Kbd.bindingForActionIn(action, focusHandle(cx), window);
        return binding != null ? binding : Kbd.bindingForAction(action, null, window);
    }

    function renderItem(matchedIx:Int, window:Window, cx:Context<CommandState>):AnyElement {
        final binding = itemBinding(matchedIx, window, cx.app);
        return renderItemWithBinding(matchedIx, binding, window, cx);
    }

    function renderItemWithBinding(matchedIx:Int, binding:Null<Kbd>, window:Window, cx:Context<CommandState>):AnyElement {
        final item = itemAt(matchedIx);
        if (item == null) return div().intoAnyElement();

        final theme = Theme.global(cx.app);
        final disabled = item.isDisabled();
        final selected = selectedIndexValue == matchedIx && !disabled;
        final mutedForeground = theme.mutedForeground;
        final iconColor = selected ? theme.accentForeground : mutedForeground;
        final content:AnyElement = if (item.content != null) {
            item.content(window, cx.app);
        } else {
            final row = hFlex()
                .flex1()
                .gap2()
                .itemsCenter();
            if (item.iconValue != null) {
                row.child(item.iconValue.clone().size4().textColor(iconColor));
            }
            final label = item.labelText();
            if (label != null) row.child(label);
            row.intoAnyElement();
        };

        // `Role::ListBoxOption` and `aria_selected`: no accessibility tree in the port.
        final element = itemRow(selected, window, cx.app)
            .id(matched[matchedIx].indexPath.toElementId());
        if (disabled) {
            element.textColor(mutedForeground);
        }
        if (!disabled) {
            element.cursorDefault()
                .onHover(cx.listener((this_:CommandState, hovered:Bool, window, cx) -> {
                    if (hovered) {
                        this_.select(matchedIx, window, cx);
                    }
                }))
                .onClick(cx.listener((this_:CommandState, _, window, cx) -> {
                    this_.confirm(matchedIx, window, cx);
                }));
        }
        element.child(content);
        if (binding != null) {
            element.child(binding.mlAuto());
        } else if (item.checkedValue) {
            // The binding owns the trailing slot, so only an item without
            // one can show its check there.
            element.child(new Icon(IconName.Check).mlAuto().xsmall());
        }
        return element.intoAnyElement();
    }

    function renderEmpty(window:Window, cx:App):AnyElement {
        if (options.empty != null) {
            return options.empty(this, window, cx);
        }

        final message = I18n.t("Command.empty");

        return div()
            .py6()
            .wFull()
            .textCenter()
            .textSm()
            .textColor(Theme.global(cx).mutedForeground)
            .child(message)
            .intoAnyElement();
    }

    /**
     * Rust `Focusable::focus_handle`: the query input's handle when the
     * palette is searchable.
     */
    public function focusHandle(cx:App):FocusHandle {
        if (model.searchable) {
            return queryInput.read(cx).focusHandle;
        }
        return focusHandleValue;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final cx:Context<CommandState> = cast cx;
        syncPlaceholder(window, cx);

        if (needsMeasure) {
            needsMeasure = false;
            measureRows(window, cx);
        }

        final pending = pendingScroll;
        if (pending != null) {
            pendingScroll = null;
            scrollHandle.scrollToItem(pending, Nearest);
        }

        final theme = Theme.global(cx.app);
        final rowsCount = rows.length;
        final rowSizes = this.rowSizes;
        final commandState = cx.entity();

        final root = vFlex()
            .id("command")
            .keyContext(CONTEXT)
            .trackFocus(focusHandleValue)
            .onAction(SelectUp, cx.listener(onActionSelectUpListener))
            .onAction(SelectDown, cx.listener(onActionSelectDownListener))
            .onAction(Confirm, cx.listener(onActionConfirmListener))
            .onAction(Cancel, cx.listener(onActionCancelListener))
            .wFull()
            .overflowHidden()
            .bg(theme.popover)
            .textColor(theme.popoverForeground);
        if (options.bordered) {
            root.rounded(theme.radiusLg)
                .border1()
                .borderColor(theme.border);
        }
        root.refineStyle(options.style);
        if (options.header != null) {
            root.child(options.header(this, window, cx.app));
        }
        if (model.searchable) {
            root.child(div()
                .flexNone()
                .px3()
                .borderB1()
                .borderColor(theme.border)
                .child(new Input(queryInput)
                    .prefix(new Icon(IconName.Search).textColor(theme.mutedForeground))
                    .appearance(false)
                    .p0()));
        }

        // `Role::ListBox`: no accessibility tree in the port.
        final container = vFlex()
            .id("command-list-container")
            .relative()
            .flex1();
        // The rows carry their inset on the virtual list itself so that a
        // mid-scroll clip edge sits flush against the surrounding dividers;
        // only the empty slot needs the container padding, and only while it
        // is shown, so a loading list leaves no blank strip under the query.
        if (rowsCount == 0 && !loading) container.p1();
        container.onPrepaint((bounds, window, cx) -> {
            commandState.update(cx, (state, cx) -> {
                // The list's `p_1` is one quarter rem on each side. Its
                // rem-dependent padding and inherited layout-relevant text
                // style participate in the row-size cache key.
                final textStyle = window.textStyle();
                state.setListMeasurementKey(new ListMeasurementKey(
                    glaze.util.MathUtil.max((bounds.size.width:Float) - (window.remSize():Float) * 0.5, 0.),
                    window.remSize(),
                    window.lineHeight(),
                    new TextShapeKey(
                        textStyle.fontFamily,
                        textStyle.fontFeatures,
                        textStyle.fontFallbacks,
                        textStyle.fontSize,
                        textStyle.fontWeight,
                        textStyle.fontStyle,
                        textStyle.whiteSpace,
                        textStyle.textOverflow,
                        textStyle.lineClamp
                    )
                ), window, cx);
            });
        });
        container.maxH(options.maxH).overflowHidden();
        // While a search is in flight the list is empty because the answer
        // has not arrived, which is not the same as no match.
        if (rowsCount == 0 && !loading) {
            container.child(renderEmpty(window, cx.app));
        }
        if (rowsCount > 0) {
            final list = VirtualList.vVirtualList(commandState, "command-list", rowSizes, (this_, start, end, window, cx) -> {
                return [for (rowIx in start...end) (this_.renderVisibleRow(rowIx, window, cx):IntoElement)];
            })
                // Padding on the virtual list acts like CSS scroll-padding:
                // the scroll ends keep their inset while scrolled-under rows
                // paint and clip at the list edge.
                .p1()
                .withSizingBehavior(ListSizingBehavior.Infer)
                .trackScroll(scrollHandle);
            final bounce = new ScrollBounce("command-scroll-bounce", scrollHandle, list);
            if (options.scrollBounce != null) bounce.enabled(options.scrollBounce);
            container.child(bounce)
                .child(Scrollbar.vertical(scrollHandle));
        }
        root.child(container);
        if (options.footer != null) {
            root.child(options.footer(this, window, cx.app));
        }
        return root;
    }

    // The action listeners, kept as fields so that render does not make new closures.

    final onActionSelectUpListener = (this_:CommandState, action:SelectUp, window:Window, cx:Context<CommandState>) -> this_.onActionSelectUp(action, window, cx);
    final onActionSelectDownListener = (this_:CommandState, action:SelectDown, window:Window, cx:Context<CommandState>) -> this_.onActionSelectDown(action, window, cx);
    final onActionConfirmListener = (this_:CommandState, action:Confirm, window:Window, cx:Context<CommandState>) -> this_.onActionConfirm(action, window, cx);
    final onActionCancelListener = (this_:CommandState, action:Cancel, window:Window, cx:Context<CommandState>) -> this_.onActionCancel(action, window, cx);

}
