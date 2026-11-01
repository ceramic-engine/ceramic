// Ported from gpui-kit 0.8.1: crates/component/src/input/popovers/completion_menu.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.input;

import gpui.Action;
import gpui.AnyElement;
import gpui.App;
import gpui.Context;
import gpui.Empty;
import gpui.Entity;
import gpui.HighlightStyle;
import gpui.HighlightStyle.TextHighlight;
import gpui.IntoElement;
import gpui.Model;
import gpui.MouseDownEvent;
import gpui.ParentElement;
import gpui.Pixels;
import gpui.Range;
import gpui.Render;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.StyledText;
import gpui.Subscription;
import gpui.Task;
import gpui.WeakEntity;
import gpui.Window;
import gpui.base.Actions.SelectDown;
import gpui.base.Actions.SelectUp;
import gpui.base.IndexPath;
import gpui.base.Popup;
import gpui.base.input.CompletionHighlighter;
import gpui.base.input.CompletionItem;
import gpui.base.input.Completions;
import gpui.base.input.EditorState;
import gpui.base.input.InputActions;
import gpui.base.input.InputBaseState;
import gpui.component.label.Label;
import gpui.component.list.List;
import gpui.component.list.ListDelegate;
import gpui.component.list.ListState;
import gpui.component.menu.MenuItemElement;
import gpui.component.theme.Theme;
import gpui.util.Utf8;

import gpui.Prelude.*;
import gpui.base.Prelude.*;

using gpui.base.Observe;
using gpui.base.input.InputLspExt;
using gpui.component.ThemeStyled;

/**
 * A context menu for code completions and code actions.
 */
@:access(gpui.component.list.ListState)
class CompletionMenu extends Model implements Render {

    static inline final MAX_MENU_HEIGHT:Pixels = 240.;

    static inline final POPOVER_GAP:Pixels = 4.;

    var offset:Int = 0;

    final editor:WeakEntity<EditorState>;

    final list:Entity<ListState<ContextMenuDelegate>>;

    var open:Bool = false;

    /** The offset of the first character that triggered the completion. */
    @:allow(gpui.component.input, tests)
    var triggerStartOffset:Null<Int> = null;

    var query:String = '';

    final _subscriptions:Array<Subscription>;

    /**
     * Creates a new `CompletionMenu` with the given offset and completion items.
     *
     * NOTE: This element should not call from EditorState::new, unless that will stack overflow.
     */
    @:allow(gpui.component.input, tests)
    static function create(editor:Entity<EditorState>, window:Window, cx:App):Entity<CompletionMenu> {
        return cx.newEntity((c:Context<CompletionMenu>) -> new CompletionMenu(editor, window, c));
    }

    function new(editor:Entity<EditorState>, window:Window, cx:Context<CompletionMenu>) {
        super();
        final menu = new ContextMenuDelegate(cx.weakEntity());

        list = cx.newEntity((c:Context<ListState<ContextMenuDelegate>>) -> new ListState(menu, window, c));

        _subscriptions = [
            cx.subscribe(list, ListEvent, (this_:CompletionMenu, _, ev:ListEvent, cx:Context<CompletionMenu>) -> {
                switch ev {
                    case Confirm(_):
                        this_.dismiss(cx);
                    case _:
                }
                cx.notify();
            }),
        ];

        this.editor = editor.downgrade();
    }

    /**
     * Drop ranges a custom highlighter cannot safely paint, then order the rest.
     *
     * A range past the label, or one that begins or ends inside a character,
     * would split a glyph. Empty ranges paint nothing, so they go too. What
     * remains is sorted and merged: GPUI builds text runs assuming highlights
     * are ordered and do not overlap, and an overlap makes the run longer than
     * the label.
     */
    @:allow(gpui.component.input, tests)
    static function retainedHighlightRanges(label:String, ranges:Array<Range>):Array<Range> {
        final labelLen = Utf8.byteLength(label);
        final kept:Array<Range> = [];
        for (range in ranges) {
            if (range.start < range.end
                && range.end <= labelLen
                && Utf8.isCharBoundary(label, range.start)
                && Utf8.isCharBoundary(label, range.end))
                kept.push(range);
        }
        // `sort_by_key(|range| range.start)` is stable
        haxe.ds.ArraySort.sort(kept, (a, b) -> a.start - b.start);

        final merged:Array<Range> = [];
        for (range in kept) {
            if (merged.length > 0) {
                final last = merged[merged.length - 1];
                if (range.start <= last.end) {
                    merged[merged.length - 1] = new Range(last.start, Std.int(Math.max(last.end, range.end)));
                    continue;
                }
            }
            merged.push(range);
        }
        return merged;
    }

    @:allow(gpui.component.input)
    function selectItem(item:CompletionItem, window:Window, cx:Context<CompletionMenu>):Void {
        final range = new Range(triggerStartOffset != null ? triggerStartOffset : offset, offset);

        final editor = this.editor;

        cx.spawn((_, acx) -> {
            if (window.isDestroyed())
                throw new gpui.EntityReleasedError(0);
            editor.update(acx, (editor:EditorState, cx:Context<EditorState>) -> {
                InputLspExt.insertCompletion(editor, item, range, window, cast cx);
            });
            return Task.done();
        }).detach();

        dismiss(cx);
    }

    @:allow(gpui.component.input, tests)
    function handleAction(action:Action, window:Window, cx:Context<CompletionMenu>):Bool {
        if (!open)
            return false;

        cx.propagate();
        if (Enter.isPrimary(action)) {
            onActionEnter(window, cx);
        }
        else if (action.partialEq(new Escape())) {
            onActionEscape(window, cx);
        }
        else if (action.partialEq(new MoveUp())) {
            onActionUp(window, cx);
        }
        else if (action.partialEq(new MoveDown())) {
            onActionDown(window, cx);
        }
        else {
            return false;
        }

        return true;
    }

    function onActionEnter(window:Window, cx:Context<CompletionMenu>):Void {
        final item = list.read(cx).delegate().selectedItem();
        if (item == null)
            return;
        selectItem(item, window, cx);
    }

    function onActionEscape(_:Window, cx:Context<CompletionMenu>):Void {
        dismiss(cx);
    }

    function onActionUp(window:Window, cx:Context<CompletionMenu>):Void {
        list.update(cx, (this_, cx) -> this_.onActionSelectPrev(new SelectUp(), window, cx));
    }

    function onActionDown(window:Window, cx:Context<CompletionMenu>):Void {
        list.update(cx, (this_, cx) -> this_.onActionSelectNext(new SelectDown(), window, cx));
    }

    /** Synchronize a hidden editor menu without dismissing a newer response. */
    @:allow(gpui.component.input, tests)
    function hide(cx:Context<CompletionMenu>):Void {
        open = false;
        triggerStartOffset = null;
        cx.notify();
    }

    /** Dismiss the menu in response to a user action. */
    function dismiss(cx:Context<CompletionMenu>):Void {
        hide(cx);
        final editor = this.editor;
        cx.spawn((_, acx) -> {
            editor.tryUpdate(acx, (editor:EditorState, cx:Context<EditorState>) -> InputLspExt.dismissCompletionOverlay(editor, cast cx));
            return Task.done();
        }).detach();
    }

    /** Sets the trigger start offset if it is not already set. */
    @:allow(gpui.component.input, tests)
    function updateQuery(startOffset:Int, query:String):Void {
        if (triggerStartOffset == null) {
            triggerStartOffset = startOffset;
        }
        this.query = query;
    }

    @:allow(gpui.component.input, tests)
    function show(offset:Int, items:Array<CompletionItem>, window:Window, cx:Context<CompletionMenu>):Void {
        this.offset = offset;
        open = true;
        final query = this.query;
        list.update(cx, (this_, cx) -> {
            // Rust `max_by_key` keeps the last of equal maxima
            var longestIx = 0;
            var longest = -1;
            for (ix in 0...items.length) {
                final item = items[ix];
                final len = Utf8.byteLength(item.label) + (item.detail != null ? Utf8.byteLength(item.detail) : 0);
                if (len >= longest) {
                    longest = len;
                    longestIx = ix;
                }
            }

            this_.delegateMut().query = query;
            this_.delegateMut().setItems(items);
            this_.setSelectedIndex(new IndexPath(0), window, cx);
            this_.setItemToMeasureIndex(new IndexPath(longestIx), window, cx);
        });

        cx.notify();
    }

    /** Replace the label highlighter and repaint an open menu. */
    @:allow(gpui.component.input, tests)
    function setHighlight(highlight:CompletionHighlighter, cx:Context<CompletionMenu>):Void {
        list.update(cx, (list, cx) -> {
            if (Reflect.compareMethods(list.delegate().highlight, highlight))
                return;
            list.delegateMut().highlight = highlight;
            cx.notify();
        });
    }

    /** Whether the menu is shown (tests). */
    @:allow(tests)
    function isOpen():Bool {
        return open;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        if (!open) {
            return new Empty();
        }

        if (list.read(cx).delegate().items.length == 0) {
            open = false;
            return new Empty();
        }

        final editor = this.editor.upgrade();
        if (editor == null) {
            return new Empty();
        }
        // The anchor is resolved in the popup's deferred prepaint from the
        // input's current-frame geometry; the content below is built there.
        final configuredMax:Pixels = editor.read(cx).lsp().completionMenu.maxWidth;
        final list = this.list;
        final menu:WeakEntity<CompletionMenu> = cast cx.weakEntity();

        return deferred(new CaretAnchoredPopup(this.editor, (anchor, window, cx) -> {
            // `anchor` is in window coordinates, from the current frame.
            final maxWidth:Pixels = Math.min(configuredMax, window.viewportSize().width - anchor.x);
            final verticalLayout = anchor.x + configuredMax + POPOVER_GAP + configuredMax + POPOVER_GAP > window.viewportSize().width;

            final selected = list.read(cx).delegate().selectedItem();
            final selectedDocumentation = selected != null ? selected.documentation : null;

            final root = div()
                .flex()
                .flexRow()
                .gap(POPOVER_GAP)
                .itemsStart();
            if (verticalLayout) root.flexCol();
            root.child(Popovers.editorPopover("completion-menu", cx)
                .popoverStyle(cx)
                .textSm()
                // Each virtual row includes the menu's inter-item gap.
                .pb0p5()
                .testSupport()
                .maxW(px(maxWidth))
                .minW(px(120.))
                .child(new List(list).maxH(px(MAX_MENU_HEIGHT))));
            if (selectedDocumentation != null) {
                var doc:String = selectedDocumentation;
                if (verticalLayout) {
                    doc = doc.split("\n")[0];
                }

                root.child(div().child(Popovers.editorPopover("completion-menu", cx)
                    .popoverStyle(cx)
                    .textSm()
                    .w(px(configuredMax))
                    .px2()
                    .child(Popovers.renderMarkdown("doc", doc, window, cx))));
            }
            root.onMouseDownOut((_:MouseDownEvent, _:Window, cx:App) -> {
                final menu = menu.upgrade();
                if (menu != null) {
                    menu.update(cx, (menu, cx) -> menu.dismiss(cx));
                }
            });
            return root.intoAnyElement();
        })).withPriority(Popup.POPUP_PRIORITY);
    }

}

class ContextMenuDelegate extends ListDelegateBase {

    @:allow(gpui.component.input)
    var query:String = '';

    final menu:WeakEntity<CompletionMenu>;

    @:allow(gpui.component.input)
    var items:Array<CompletionItem> = [];

    var selectedIx:Int = 0;

    @:allow(gpui.component.input)
    var highlight:CompletionHighlighter = Completions.highlightPrefix;

    public function new(menu:WeakEntity<CompletionMenu>) {
        this.menu = menu;
    }

    @:allow(gpui.component.input)
    function setItems(items:Array<CompletionItem>):Void {
        this.items = items.copy();
        selectedIx = 0;
    }

    @:allow(gpui.component.input, tests)
    function selectedItem():Null<CompletionItem> {
        return selectedIx >= 0 && selectedIx < items.length ? items[selectedIx] : null;
    }

    public function itemsCount(_:Int, _:App):Int {
        return items.length;
    }

    public function renderItem(ix:IndexPath, _:Window, _:Context<ListState<Dynamic>>):Null<ListDelegateItem> {
        if (ix.row < 0 || ix.row >= items.length)
            return null;
        return new CompletionMenuItem(ix.row, items[ix.row], query, highlight);
    }

    public function setSelectedIndex(ix:Null<IndexPath>, _:Window, cx:Context<ListState<Dynamic>>):Void {
        selectedIx = ix != null ? ix.row : 0;
        cx.notify();
    }

    override public function confirm(_:Bool, window:Window, cx:Context<ListState<Dynamic>>):Void {
        final item = selectedItem();
        if (item == null)
            return;

        menu.update(cx, (this_:CompletionMenu, cx:Context<CompletionMenu>) -> this_.selectItem(item, window, cx));
    }

}

class CompletionMenuItem implements ListDelegateItem implements ParentElement {

    final ix:Int;

    final item:CompletionItem;

    final childElements:Array<AnyElement> = [];

    var selected:Bool = false;

    final query:String;

    final highlight:CompletionHighlighter;

    public function new(ix:Int, item:CompletionItem, query:String, highlight:CompletionHighlighter) {
        this.ix = ix;
        this.item = item;
        this.query = query;
        this.highlight = highlight;
    }

    public function setSelected(selected:Bool):Void {
        this.selected = selected;
    }

    public function isSelected():Bool {
        return selected;
    }

    public function setSecondarySelected(_:Bool):Void {}

    public function setOpen(open:Bool):Void {
        setSelected(open);
    }

    public function isOpen():Bool {
        return isSelected();
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function render(_:Window, cx:App):IntoElement {
        final item = this.item;
        final theme = Theme.global(cx);

        final deprecated = item.deprecated == true;
        final highlights = [
            for (range in CompletionMenu.retainedHighlightRanges(item.label, highlight(query, item)))
                new TextHighlight(range.start, range.end, new HighlightStyle(theme.blue))
        ];

        final element = new MenuItemElement(ix)
            .ariaLabel(item.label)
            .selected(selected)
            .textSm()
            .py0()
            .px2()
            .h(rems(26. / 16.))
            .mb0p5()
            .rounded(theme.radius);
        if (deprecated) element.lineThrough();
        final row = hFlex()
            .wFull()
            .gap3()
            .justifyBetween()
            .child(new StyledText(item.label).withHighlights(highlights));
        if (item.detail != null) {
            final label = new Label(item.detail).textColor(theme.mutedForeground);
            if (deprecated) label.lineThrough();
            row.child(label.italic());
        }
        element.child(row);
        element.extend(childElements);
        return element;
    }

}
