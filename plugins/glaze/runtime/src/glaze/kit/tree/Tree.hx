// Ported from gpui-kit 0.8.1: crates/component/src/tree.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
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

    public function render(window:Window, cx:App):IntoElement {
        final state = this.state;
        final renderItem = this.renderItem;
        final contextMenuBuilder = this.contextMenu;
        final scrollHandle = state.read(cx).scrollHandle();

        final tree = new BaseTree(state)
            .item((ix, entry, entryState, window, cx) -> {
                // Capture only the id: cloning the entry would deep-clone
                // its whole subtree for every visible row on every frame.
                final id = entry.item().id;
                final item = renderItem(ix, entry, entryState.isSelected(), window, cx)
                    .disabled(entry.isDisabled())
                    .selected(entryState.isSelected())
                    .secondarySelected(entryState.isRightClicked());

                return div()
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

        return div()
            .id(id)
            .sizeFull()
            .child(bounce)
            .refineStyle(treeStyle)
            .verticalScrollbar(scrollHandle);
    }

}
