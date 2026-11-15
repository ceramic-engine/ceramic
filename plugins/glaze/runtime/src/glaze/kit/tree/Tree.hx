// Ported from gpui-kit 0.8.1: crates/component/src/tree.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// Additions without upstream equivalent (KIT-004 in docs/DEVIATIONS.md): `toggleOnClick`, `navigationKeys`,
// drag and drop of the rows (`dragEntries`, `dropOnEntries`, `dropOnRoot`, the drop target styles).
package glaze.kit.tree;

import glaze.App;
import glaze.Component;
import glaze.Context;
import glaze.ElementId;
import glaze.Entity;
import glaze.IntoElement;
import glaze.StyleBuilder;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.ScrollBounce;
import glaze.kit.base.Tree as BaseTree;
import glaze.kit.list.ListItem;
import glaze.kit.menu.PopupMenu;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;
using glaze.kit.menu.ContextMenu.ContextMenuExt;
using glaze.kit.scroll.Scrollable.ScrollableElement;

/** Rust `pub use gpui_base::TreeEntry`. */
typedef TreeEntry = glaze.kit.base.Tree.TreeEntry;

/** Rust `pub use gpui_base::TreeEvent`. */
typedef TreeEvent = glaze.kit.base.Tree.TreeEvent;

/** Rust `pub use gpui_base::TreeItem`. */
typedef TreeItem = glaze.kit.base.Tree.TreeItem;

/** Rust `pub use gpui_base::TreeState`. */
typedef TreeState = glaze.kit.base.Tree.TreeState;

typedef TreeComponentRenderItem = (Int, TreeEntry, Bool, Window, App) -> ListItem;

typedef TreeContextMenuBuilder = (Int, TreeEntry, PopupMenu, Window, Context<TreeState>) -> PopupMenu;

/**
 * A styled tree view that preserves the legacy `gpui-component` API while
 * delegating tree behavior and interaction state to `gpui-base`.
 */
class Tree extends Component implements Styled {

    final id:ElementId;

    final state:Entity<TreeState>;

    final treeStyle:StyleRefinement = new StyleRefinement();

    final renderItem:TreeComponentRenderItem;

    /** Add a context menu to the tree. */
    @prop var contextMenu:Null<TreeContextMenuBuilder> = null;

    /**
     * Bounce at the vertical boundaries. On by default on iOS, Android and
     * macOS, off elsewhere; reduced motion disables displacement.
     */
    @prop var scrollBounce:Null<Bool> = null;

    /** See `glaze.kit.base.Tree.toggleOnClick`. */
    @prop var toggleOnClick:Bool = true;

    /** See `glaze.kit.base.Tree.navigationKeys`. */
    @prop var navigationKeys:Bool = false;

    var dragValue:Null<(Int, TreeEntry) -> Dynamic> = null;

    var dragPreview:Null<(Dynamic, glaze.Point, Window, App) -> glaze.AnyView> = null;

    final entryDrops:Array<{type:Class<Dynamic>, onDrop:(Dynamic, Int, TreeEntry, Window, App) -> Void, canDrop:Null<(Dynamic, Int, TreeEntry, Window, App) -> Bool>}> = [];

    final rootDrops:Array<{type:Class<Dynamic>, onDrop:(Dynamic, Window, App) -> Void, canDrop:Null<(Dynamic, Window, App) -> Bool>}> = [];

    var dropTargetStyleValue:Null<(StyleBuilder) -> StyleBuilder> = null;

    var rootDropTargetStyleValue:Null<(StyleBuilder) -> StyleBuilder> = null;

    public function new(state:Entity<TreeState>, renderItem:TreeComponentRenderItem) {
        super();
        id = ElementId.Name('tree-' + state.entityId());
        this.state = state;
        this.renderItem = renderItem;
    }

    /** Create a `Tree` (Rust `tree::tree`). */
    public static function tree(state:Entity<TreeState>, renderItem:TreeComponentRenderItem):Tree {
        return Tree.component(state, renderItem);
    }

    public inline function style():StyleRefinement {
        return treeStyle;
    }

    /**
     * Makes the rows drag sources: a row for which `value` returns a non
     * null value starts a drag of that value, previewed by the view
     * `preview` builds (Glaze's `onDrag`). A press that starts a drag is
     * not a click.
     */
    public function dragEntries<T>(value:(Int, TreeEntry) -> Null<T>, preview:(T, glaze.Point, Window, App) -> glaze.AnyView):Tree {
        dragValue = value;
        dragPreview = cast preview;
        return this;
    }

    /**
     * Makes the rows drop targets of drags of type `type` (Glaze's
     * `onDrop`): `onDrop` gets the dragged value and the row it was dropped
     * on. A row for which `canDrop` returns false neither highlights nor
     * takes the drop. While a drag it accepts is over a row, the row takes
     * the `dropTargetStyle` (the theme's `drop_target` background by
     * default).
     */
    public function dropOnEntries<T>(type:Class<T>, onDrop:(T, Int, TreeEntry, Window, App) -> Void, ?canDrop:(T, Int, TreeEntry, Window, App) -> Bool):Tree {
        entryDrops.push({type: cast type, onDrop: cast onDrop, canDrop: cast canDrop});
        return this;
    }

    /**
     * Makes the tree itself a drop target of drags of type `type`, for a
     * drop outside every accepting row (a move to the root). While a drag
     * it accepts is over the tree, the tree takes the `rootDropTargetStyle`
     * (the theme's `drop_target` background by default; for a ring, give the
     * tree a transparent border and color it in that style, so nothing
     * moves).
     */
    public function dropOnRoot<T>(type:Class<T>, onDrop:(T, Window, App) -> Void, ?canDrop:(T, Window, App) -> Bool):Tree {
        rootDrops.push({type: cast type, onDrop: cast onDrop, canDrop: cast canDrop});
        return this;
    }

    /** Sets the style of a row while an accepted drag is over it. */
    public function dropTargetStyle(style:(StyleBuilder) -> StyleBuilder):Tree {
        dropTargetStyleValue = style;
        return this;
    }

    /** Sets the style of the tree while a drag accepted by `dropOnRoot` is over it. */
    public function rootDropTargetStyle(style:(StyleBuilder) -> StyleBuilder):Tree {
        rootDropTargetStyleValue = style;
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final state = this.state;
        final renderItem = this.renderItem;
        final contextMenuBuilder = this.contextMenu;
        final scrollHandle = state.read(cx).scrollHandle();

        final theme = glaze.kit.theme.Theme.global(cx);
        final dragValue = this.dragValue;
        final dragPreview = this.dragPreview;
        final entryDrops = this.entryDrops;
        final rootDrops = this.rootDrops;
        final rowDragAndDrop = dragValue != null || entryDrops.length > 0;
        final dropTargetStyle:(StyleBuilder) -> StyleBuilder = dropTargetStyleValue != null ? dropTargetStyleValue : s -> s.bg(theme.dropTarget);
        final rootDropTargetStyle:(StyleBuilder) -> StyleBuilder = rootDropTargetStyleValue != null ? rootDropTargetStyleValue : s -> s.bg(theme.dropTarget);

        final tree = new BaseTree(state)
            .toggleOnClick(toggleOnClick)
            .navigationKeys(navigationKeys)
            .item((ix, entry, entryState, window, cx) -> {
                // Capture only the id: cloning the entry would deep-clone
                // its whole subtree for every visible row on every frame.
                final id = entry.item().id;
                final item = renderItem(ix, entry, entryState.isSelected(), window, cx)
                    .disabled(entry.isDisabled())
                    .selected(entryState.isSelected())
                    .secondarySelected(entryState.isRightClicked());

                final row = div();
                if (rowDragAndDrop) {
                    // Drags and drops need an element with an identity.
                    row.id(ElementId.NamedInteger('tree-row', ix));
                    final value:Dynamic = dragValue != null ? dragValue(ix, entry) : null;
                    if (value != null && !entry.isDisabled()) {
                        row.onDrag(value, (value, position, window, cx) -> dragPreview(value, position, window, cx));
                    }
                    if (entryDrops.length > 0 && !entry.isDisabled()) {
                        // The row may be gone when the drop comes: look the
                        // entry up again by its id.
                        final current = (cx:App) -> {
                            final found = state.read(cx).entry(ix);
                            return found != null && found.item().id == id ? found : null;
                        };
                        final accepts = (value:Dynamic, window:Window, cx:App) -> {
                            final found = current(cx);
                            if (found == null) return false;
                            for (drop in entryDrops) {
                                if (Std.isOfType(value, drop.type)) {
                                    return drop.canDrop == null || drop.canDrop(value, ix, found, window, cx);
                                }
                            }
                            return false;
                        };
                        row.canDrop(accepts);
                        for (drop in entryDrops) {
                            row.dragOver(drop.type, (s, _, _, _) -> dropTargetStyle(s));
                            row.onDrop(drop.type, (value, window, cx) -> {
                                final found = current(cx);
                                if (found != null) drop.onDrop(value, ix, found, window, cx);
                            });
                        }
                    }
                }
                return row
                    .child(item)
                    .contextMenu((menu, window, cx) -> {
                        final build = contextMenuBuilder;
                        if (build == null) {
                            return menu;
                        }
                        return state.update(cx, (state, cx) -> {
                            final entry = state.entry(ix);
                            if (entry == null || entry.item().id != id || entry.isDisabled()) {
                                return menu;
                            }
                            return build(ix, entry.clone(), menu, window, cx);
                        });
                    })
                    .intoAnyElement();
            })
            .listStyle(StyleBuilder.build(s -> s.flexGrow1().sizeFull()))
            .relative()
            .sizeFull();
        final bounce = new ScrollBounce("tree-scroll-bounce", scrollHandle, tree);
        if (scrollBounce != null) bounce.enabled(scrollBounce);

        final container = div()
            .id(id)
            .sizeFull();
        if (rootDrops.length > 0) {
            container.canDrop((value, window, cx) -> {
                for (drop in rootDrops) {
                    if (Std.isOfType(value, drop.type)) return drop.canDrop == null || drop.canDrop(value, window, cx);
                }
                return false;
            });
            for (drop in rootDrops) {
                container.dragOver(drop.type, (s, _, _, _) -> rootDropTargetStyle(s));
                container.onDrop(drop.type, (value, window, cx) -> drop.onDrop(value, window, cx));
            }
        }
        return container
            .child(bounce)
            .refineStyle(treeStyle)
            .verticalScrollbar(scrollHandle);
    }

}
