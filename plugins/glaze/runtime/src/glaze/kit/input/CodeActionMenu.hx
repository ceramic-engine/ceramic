// Ported from gpui-kit 0.8.1: crates/component/src/input/popovers/code_action_menu.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.input;

import glaze.Action;
import glaze.AnyElement;
import glaze.App;
import glaze.Context;
import glaze.Empty;
import glaze.Entity;
import glaze.HighlightStyle.TextHighlight;
import glaze.IntoElement;
import glaze.Model;
import glaze.MouseDownEvent;
import glaze.ParentElement;
import glaze.Pixels;
import glaze.Render;
import glaze.StyledText;
import glaze.Subscription;
import glaze.Task;
import glaze.WeakEntity;
import glaze.Window;
import glaze.kit.base.Actions.SelectDown;
import glaze.kit.base.Actions.SelectUp;
import glaze.kit.base.IndexPath;
import glaze.kit.base.Popup;
import glaze.kit.base.input.CodeActionItem;
import glaze.kit.base.input.EditorState;
import glaze.kit.base.input.InputActions;
import glaze.kit.list.List;
import glaze.kit.list.ListDelegate;
import glaze.kit.list.ListState;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.base.Observe;
using glaze.kit.base.input.InputLspExt;

/**
 * A context menu for code completions and code actions.
 */
@:access(glaze.kit.list.ListState)
class CodeActionMenu extends Model implements Render {

    static inline final MAX_MENU_WIDTH:Pixels = 320.;

    static inline final MAX_MENU_HEIGHT:Pixels = 480.;

    var offset:Int = 0;

    final state:WeakEntity<EditorState>;

    final list:Entity<ListState<MenuDelegate>>;

    var open:Bool = false;

    final _subscriptions:Array<Subscription>;

    /**
     * Creates a new `CompletionMenu` with the given offset and completion items.
     *
     * NOTE: This element should not call from EditorState::new, unless that will stack overflow.
     */
    @:allow(glaze.kit.input, tests)
    static function create(state:Entity<EditorState>, window:Window, cx:App):Entity<CodeActionMenu> {
        return cx.newEntity((c:Context<CodeActionMenu>) -> new CodeActionMenu(state, window, c));
    }

    function new(state:Entity<EditorState>, window:Window, cx:Context<CodeActionMenu>) {
        super();
        final menu = new MenuDelegate(cx.weakEntity());

        list = cx.newEntity((c:Context<ListState<MenuDelegate>>) -> new ListState(menu, window, c));

        _subscriptions = [
            cx.subscribe(list, ListEvent, (this_:CodeActionMenu, _, ev:ListEvent, cx:Context<CodeActionMenu>) -> {
                switch ev {
                    case Confirm(_):
                        this_.hide(cx);
                    case _:
                }
                cx.notify();
            }),
        ];

        this.state = state.downgrade();
    }

    @:allow(glaze.kit.input)
    function selectItem(item:CodeActionItem, window:Window, cx:Context<CodeActionMenu>):Void {
        final state = this.state;

        cx.spawn((_, acx) -> {
            if (window.isDestroyed())
                throw new glaze.EntityReleasedError(0);
            state.update(acx, (state:EditorState, cx:Context<EditorState>) -> {
                InputLspExt.performCodeAction(state, item, window, cast cx);
            });
            return Task.done();
        }).detach();

        hide(cx);
    }

    @:allow(glaze.kit.input, tests)
    function handleAction(action:Action, window:Window, cx:Context<CodeActionMenu>):Bool {
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

    function onActionEnter(window:Window, cx:Context<CodeActionMenu>):Void {
        final item = list.read(cx).delegate().selectedItem();
        if (item == null)
            return;
        selectItem(item, window, cx);
    }

    function onActionEscape(_:Window, cx:Context<CodeActionMenu>):Void {
        hide(cx);
    }

    function onActionUp(window:Window, cx:Context<CodeActionMenu>):Void {
        list.update(cx, (this_, cx) -> this_.onActionSelectPrev(new SelectUp(), window, cx));
    }

    function onActionDown(window:Window, cx:Context<CodeActionMenu>):Void {
        list.update(cx, (this_, cx) -> this_.onActionSelectNext(new SelectDown(), window, cx));
    }

    /** Hide the completion menu and reset the trigger start offset. */
    @:allow(glaze.kit.input, tests)
    function hide(cx:Context<CodeActionMenu>):Void {
        open = false;
        final state = this.state;
        cx.spawn((_, acx) -> {
            state.tryUpdate(acx, (state:EditorState, cx:Context<EditorState>) -> InputLspExt.dismissCodeActionOverlay(state, cast cx));
            return Task.done();
        }).detach();
        cx.notify();
    }

    @:allow(glaze.kit.input, tests)
    function show(offset:Int, items:Array<CodeActionItem>, window:Window, cx:Context<CodeActionMenu>):Void {
        this.offset = offset;
        open = true;
        list.update(cx, (this_, cx) -> {
            this_.delegateMut().setItems(items);
            this_.setSelectedIndex(new IndexPath(0), window, cx);
        });

        cx.notify();
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

        // The anchor is resolved in the popup's deferred prepaint from the
        // input's current-frame geometry; the content below is built there.
        final list = this.list;
        final menu:WeakEntity<CodeActionMenu> = cast cx.weakEntity();

        return deferred(new CaretAnchoredPopup(state, (anchor, window, cx) -> {
            final maxWidth:Pixels = Math.min(MAX_MENU_WIDTH, window.viewportSize().width - anchor.x);

            // A flex root measures to its contents; a block root would
            // stretch its outside-click hitbox across the viewport.
            return div()
                .flex()
                .child(Popovers.editorPopover("code-action-menu", cx)
                    .testSupport()
                    .maxW(px(maxWidth))
                    .minW(px(120.))
                    .child(List.component(list).maxH(px(MAX_MENU_HEIGHT))))
                .onMouseDownOut((_:MouseDownEvent, _:Window, cx:App) -> {
                    final menu = menu.upgrade();
                    if (menu != null) {
                        menu.update(cx, (menu, cx) -> menu.hide(cx));
                    }
                })
                .intoAnyElement();
        })).withPriority(Popup.POPUP_PRIORITY);
    }

}

class MenuDelegate extends ListDelegateBase {

    final menu:WeakEntity<CodeActionMenu>;

    @:allow(glaze.kit.input)
    var items:Array<CodeActionItem> = [];

    var selectedIx:Int = 0;

    public function new(menu:WeakEntity<CodeActionMenu>) {
        this.menu = menu;
    }

    @:allow(glaze.kit.input)
    function setItems(items:Array<CodeActionItem>):Void {
        this.items = items.copy();
        selectedIx = 0;
    }

    @:allow(glaze.kit.input, tests)
    function selectedItem():Null<CodeActionItem> {
        return selectedIx >= 0 && selectedIx < items.length ? items[selectedIx] : null;
    }

    public function itemsCount(_:Int, _:App):Int {
        return items.length;
    }

    public function renderItem(ix:IndexPath, _:Window, _:Context<ListState<Dynamic>>):Null<ListDelegateItem> {
        if (ix.row < 0 || ix.row >= items.length)
            return null;
        return new CodeActionMenuItem(ix.row, items[ix.row]);
    }

    public function setSelectedIndex(ix:Null<IndexPath>, _:Window, cx:Context<ListState<Dynamic>>):Void {
        selectedIx = ix != null ? ix.row : 0;
        cx.notify();
    }

    override public function confirm(_:Bool, window:Window, cx:Context<ListState<Dynamic>>):Void {
        final item = selectedItem();
        if (item == null)
            return;

        menu.update(cx, (this_:CodeActionMenu, cx:Context<CodeActionMenu>) -> this_.selectItem(item, window, cx));
    }

}

/** Rust `MenuItem` of `code_action_menu.rs`. */
class CodeActionMenuItem implements ListDelegateItem implements ParentElement {

    final ix:Int;

    final item:CodeActionItem;

    final childElements:Array<AnyElement> = [];

    var selected:Bool = false;

    public function new(ix:Int, item:CodeActionItem) {
        this.ix = ix;
        this.item = item;
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

        final highlights:Array<TextHighlight> = [];

        final element = hFlex()
            .id(ix)
            .gap2()
            .p1()
            .textXs()
            .lineHeight(relative(1.))
            .rounded(theme.radius * 0.5)
            .hover(style -> style.bg(theme.accent.opacity(0.8)));
        if (selected) {
            element.bg(theme.tokens.accent.background).textColor(theme.accentForeground);
        }
        element.child(div().child(new StyledText(item.action.title).withHighlights(highlights)));
        element.children([for (child in childElements) (child : IntoElement)]);
        return element;
    }

}
