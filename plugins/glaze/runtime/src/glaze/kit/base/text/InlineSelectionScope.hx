// New code for the Haxe port of gpui-kit (no gpui-kit origin): text selection for one paragraph outside of a
// markdown view (the kit's `RichText`), through the selection code of `TextView`. See NOTICE.md.
package glaze.kit.base.text;

import glaze.AnyElement;
import glaze.App;
import glaze.Bounds;
import glaze.ClipboardItem;
import glaze.Div;
import glaze.Element;
import glaze.ElementId;
import glaze.Entity;
import glaze.GlobalElementId;
import glaze.Hitbox;
import glaze.HitboxBehavior;
import glaze.LayoutId;
import glaze.Window;
import glaze.kit.base.GlobalState;
import glaze.kit.base.KeyedEntity;
import glaze.kit.base.TextSelection;
import glaze.kit.base.TouchHandleLayout;
import glaze.kit.base.input.InputActions.Copy;
import glaze.kit.base.input.InputActions.SelectAll;
import glaze.kit.base.text.TextView.TextViewDefaults;
import glaze.kit.base.theme.Theme;

using glaze.kit.base.ElementExt;

/**
 * Makes the text of one `InlineFlow` selectable outside of a `TextView`.
 *
 * It does for its content the selectable half of what the `TextView`
 * element does around a document: a `TextViewState` made by
 * `TextViewState.singleFlow` is on the state stack while the content
 * prepaints and paints, so the text leaves (`Inline`) behave as in a
 * markdown view (drag, double click, triple click, shift click, touch
 * handles), and the state's selection adapter registers with the window's
 * selection layer. Copy and select all are the actions of the `TextView`
 * key context, when the paragraph has the focus (it takes it when a
 * selection starts in it).
 *
 * Inside a selectable `TextView` (a custom block of a markdown view) the
 * scope steps aside: the view selects the paragraph with the rest of its
 * document.
 */
class InlineSelectionScope extends Element {

    final state:Entity<TextViewState>;

    final content:AnyElement;

    /** Whether a text view around the scope does the selection. */
    var nested:Bool = false;

    var hitbox:Null<Hitbox> = null;

    var touchHandles:Null<TouchHandleLayout> = null;

    function new(state:Entity<TextViewState>, content:AnyElement) {
        this.state = state;
        this.content = content;
    }

    /**
     * The selection state of the paragraph of id `id`, kept as long as it
     * is rendered in consecutive frames. Call it while the view that holds
     * the paragraph renders.
     */
    public static function useState(window:Window, id:ElementId, cx:App):Entity<TextViewState> {
        return KeyedEntity.useObserved(window, ElementId.Name(@:privateAccess TextView.idString(id) + '/selection'), TextViewState, cx,
            (_, cx) -> TextViewState.singleFlow(cx));
    }

    /**
     * Starts the text items of a frame: the states to give them, in order
     * (`InlineFlowSelection.itemState`), then `endItems`.
     */
    public static function beginItems(state:Entity<TextViewState>, cx:App):InlineFlowSelection {
        final flow = state.read(cx).flowSelection;
        flow.begin();
        return flow;
    }

    /** Ends the text items of a frame: a text that changed drops what was selected in it. */
    public static function endItems(state:Entity<TextViewState>, cx:App):Void {
        if (state.read(cx).flowSelection.end()) {
            state.update(cx, (state, cx) -> state.flowTextChanged(cx.app));
        }
    }

    /**
     * `container`, which holds the flow built with the item states of
     * `state`, made selectable. The container takes the focus handle, the
     * key context and the copy and select all actions of a text view.
     */
    public static function wrap(state:Entity<TextViewState>, container:Div, cx:App):InlineSelectionScope {
        final focusHandle = state.read(cx).focusHandle;
        final content = container
            .id(ElementId.NamedInteger('inline-selection', state.entityId()))
            .keyContext('TextView')
            .trackFocus(focusHandle)
            .onAction(Copy, (_, window, cx) -> {
                final text = StringTools.trim(TextSelection.selectedText(window, cx));
                if (text.length == 0) {
                    cx.propagate();
                    return;
                }
                cx.writeToClipboard(ClipboardItem.newString(text));
            })
            .onAction(SelectAll, (action, window, cx) -> state.update(cx, (state, cx) -> state.onActionSelectAll(action, window, cx)))
            .onPrepaint((bounds, window, cx) -> TextViewState.contentPrepainted(state, bounds, window, cx));
        return new InlineSelectionScope(state, content.intoAnyElement());
    }

    public function requestLayout(_:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        // The selection color is the one of the text views.
        final defaults = cx.tryGlobal(TextViewDefaults);
        final style = defaults != null && defaults._style != null ? defaults._style : TextViewStyle.fromTheme(Theme.global(cx));
        if (!state.read(cx).textViewStyle.equals(style)) {
            state.update(cx, (state, _) -> state.textViewStyle = style);
        }
        return content.requestLayout(window, cx);
    }

    public function prepaint(_:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final global = GlobalState.global(cx);
        final outer = global.textViewState();
        nested = outer != null && outer.read(cx).isSelectable();
        if (nested) {
            content.prepaint(window, cx);
            return;
        }
        global.pushTextViewState(state);
        content.prepaint(window, cx);
        global.popTextViewState();

        hitbox = window.insertHitbox(bounds, HitboxBehavior.Normal);
        // Over the text, so after its hitbox.
        touchHandles = state.read(cx).selectionAdapter.prepaintTouchHandles(window, cx);
    }

    public function paint(_:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        if (nested) {
            content.paint(window, cx);
            return;
        }
        final adapter = state.read(cx).selectionAdapter;
        adapter.beginFrame();

        final global = GlobalState.global(cx);
        global.pushTextViewState(state);
        content.paint(window, cx);
        global.popTextViewState();

        final current = state.read(cx);
        adapter.register(hitbox, current.bounds(), current.scrollOffset(), false, window, cx);
        adapter.paintTouchHandles(touchHandles, current.textViewStyle.selection().alpha(1.), window, cx);
    }

}
