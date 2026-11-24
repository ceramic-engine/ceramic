// Ported from gpui-kit 0.8.1: crates/component/src/tree.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// Additions without upstream equivalent (KIT-004 in docs/DEVIATIONS.md): `toggleOnClick`, `navigationKeys`,
// drag and drop of the rows (`dragEntries`, `dropOnEntries`, `dropOnRoot`, the drop target styles).
// KIT-022: `rowHeight` (rows of different heights).
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

    /** See `glaze.kit.base.Tree.multiSelect` (KIT-046). */
    @prop var multiSelect:Bool = false;

    /** See `glaze.kit.base.Tree.navigationKeys`. */
    @prop var navigationKeys:Bool = false;

    /** See `glaze.kit.base.Tree.rowHeight` (KIT-022): null by default, a uniform list. */
    @prop var rowHeight:Null<(ix:Int, entry:TreeEntry) -> Float> = null;

    var dragValue:Null<(Int, TreeEntry) -> Dynamic> = null;

    var dragPreview:Null<(Dynamic, glaze.Point, Window, App) -> glaze.AnyView> = null;

    final entryDrops:Array<{type:Class<Dynamic>, onDrop:(Dynamic, Int, TreeEntry, Window, App) -> Void, canDrop:Null<(Dynamic, Int, TreeEntry, Window, App) -> Bool>}> = [];

    final rootDrops:Array<{type:Class<Dynamic>, onDrop:(Dynamic, Window, App) -> Void, canDrop:Null<(Dynamic, Window, App) -> Bool>}> = [];

    var dropTargetStyleValue:Null<(StyleBuilder) -> StyleBuilder> = null;

    var rootDropTargetStyleValue:Null<(StyleBuilder) -> StyleBuilder> = null;

    var dropTargetForValue:Null<(Int, TreeEntry) -> Null<Int>> = null;

    var rootContextMenuValue:Null<(PopupMenu, Window, Context<PopupMenu>) -> PopupMenu> = null;

    var rowHoverValue:Null<(StyleBuilder) -> StyleBuilder> = null;

    var rowSelectedValue:Null<(StyleBuilder) -> StyleBuilder> = null;

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

    /**
     * Chooses the row that is highlighted while an accepted drag is over a
     * row (addition, KIT-016): `target(ix, entry)` gets the row under the
     * pointer and returns the index of the row that takes the
     * `dropTargetStyle` (the row of the parent folder of a file, with
     * `TreeState.parentIndex`), or `null` for the tree itself, which then
     * takes the `rootDropTargetStyle`. Only the highlight moves: the drop
     * still goes to `dropOnEntries` with the row under the pointer.
     * Without it, the row under the pointer is highlighted.
     */
    public function dropTargetFor(target:Null<(ix:Int, entry:TreeEntry) -> Null<Int>>):Tree {
        dropTargetForValue = target;
        return this;
    }

    /**
     * Opens the menu `builder` fills on a right click (or a long press) on
     * the tree outside its rows: the empty area under the last row
     * (addition, KIT-017). A right click on a row opens the row's menu
     * (`contextMenu`) only, and closes this one if it was open.
     */
    public function rootContextMenu(builder:Null<(PopupMenu, Window, Context<PopupMenu>) -> PopupMenu>):Tree {
        rootContextMenuValue = builder;
        return this;
    }

    /**
     * The style of a row under the pointer, in place of the theme's
     * `list.hover` background, for the rows of this tree only (addition,
     * KIT-015; it is `ListItem.hover` set on every row that has none).
     */
    public function rowHover(style:Null<(StyleBuilder) -> StyleBuilder>):Tree {
        rowHoverValue = style;
        return this;
    }

    /**
     * The style of the selected row, in place of the theme's `list.active`
     * background, for the rows of this tree only (addition, KIT-015; it is
     * `ListItem.selectedStyle` set on every row that has none).
     */
    public function rowSelected(style:Null<(StyleBuilder) -> StyleBuilder>):Tree {
        rowSelectedValue = style;
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
        // KIT-022: the handle of the list this frame builds
        final scrollHandle:glaze.kit.base.Scrollbar.ScrollbarHandle = rowHeight != null ? state.read(cx).rowScrollHandle() : state.read(cx).scrollHandle();

        final theme = glaze.kit.theme.Theme.global(cx);
        final dragValue = this.dragValue;
        final dragPreview = this.dragPreview;
        final entryDrops = this.entryDrops;
        final rootDrops = this.rootDrops;
        final rowDragAndDrop = dragValue != null || entryDrops.length > 0;
        final dropTargetStyle:(StyleBuilder) -> StyleBuilder = dropTargetStyleValue != null ? dropTargetStyleValue : s -> s.bg(theme.dropTarget);
        final rootDropTargetStyle:(StyleBuilder) -> StyleBuilder = rootDropTargetStyleValue != null ? rootDropTargetStyleValue : s -> s.bg(theme.dropTarget);

        final rowHover = rowHoverValue;
        final rowSelected = rowSelectedValue;
        // KIT-016: the row an accepted drag points at, kept across frames
        final redirect = entryDrops.length > 0 ? dropTargetForValue : null;
        final highlight:Null<TreeDropHighlight> = redirect != null
            ? window.useKeyedState(ElementId.Name('tree-drop-highlight-' + state.entityId()), cx, _ -> new TreeDropHighlight()).read(cx).value
            : null;
        if (highlight != null && !cx.hasActiveDrag()) highlight.clear();
        // KIT-017: the menu of the empty area
        final rootMenuControl = rootContextMenuValue != null ? new glaze.kit.menu.ContextMenu.ContextMenuControl() : null;

        final tree = new BaseTree(state)
            .toggleOnClick(toggleOnClick)
            .navigationKeys(navigationKeys)
            .multiSelect(multiSelect)
            .rowHeight(rowHeight)
            .item((ix, entry, entryState, window, cx) -> {
                // Capture only the id: cloning the entry would deep-clone
                // its whole subtree for every visible row on every frame.
                final id = entry.item().id;
                final item = renderItem(ix, entry, entryState.isSelected(), window, cx)
                    .disabled(entry.isDisabled())
                    .selected(entryState.isSelected())
                    .secondarySelected(entryState.isRightClicked());
                if (rowHover != null && @:privateAccess item.hoverStyleValue == null) item.hover(rowHover);
                if (rowSelected != null && @:privateAccess item.selectedStyleValue == null) item.selectedStyle(rowSelected);

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
                            if (highlight == null) {
                                row.dragOver(drop.type, (s, _, _, _) -> dropTargetStyle(s));
                            } else {
                                // KIT-016: the highlight goes to the row `redirect` names
                                row.onDragMove(drop.type, (event, window, cx) -> {
                                    final over = event.bounds.contains(event.event.position) && accepts(event.drag(cx), window, cx);
                                    var changed = false;
                                    if (over) {
                                        final found = current(cx);
                                        changed = found != null && highlight.set(ix, redirect(ix, found));
                                    } else if (highlight.active && highlight.source == ix) {
                                        highlight.clear();
                                        changed = true;
                                    }
                                    if (changed) state.update(cx, (_, cx) -> cx.notify());
                                });
                            }
                            row.onDrop(drop.type, (value, window, cx) -> {
                                final found = current(cx);
                                if (found != null) drop.onDrop(value, ix, found, window, cx);
                            });
                        }
                    }
                }
                if (highlight != null && highlight.active && highlight.target == ix) {
                    row.refineStyle(StyleBuilder.build(dropTargetStyle));
                }
                return row
                    .child(item)
                    .contextMenu((menu, window, cx) -> {
                        // KIT-017: a row's menu replaces the tree's own
                        if (rootMenuControl != null) rootMenuControl.close(window);
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
        container
            .child(bounce)
            .refineStyle(treeStyle);
        if (highlight != null && highlight.active && highlight.target == null) {
            container.refineStyle(StyleBuilder.build(rootDropTargetStyle));
        }
        final rootMenu = rootContextMenuValue;
        if (rootMenu != null) {
            // The rows' own triggers are inside this one and stop the right
            // click before it gets here
            return new glaze.kit.menu.ContextMenu(ElementId.Name('tree-root-menu-' + state.entityId()), container.verticalScrollbar(scrollHandle))
                .menu(rootMenu)
                .withControl(rootMenuControl);
        }
        return container.verticalScrollbar(scrollHandle);
    }

}

/**
 * The row an accepted drag points at in a tree with `dropTargetFor`
 * (KIT-016): `source` is the row under the pointer, `target` the row to
 * highlight (`null`: the tree itself).
 */
private class TreeDropHighlight {

    public var active:Bool = false;

    public var source:Int = -1;

    public var target:Null<Int> = null;

    public function new() {}

    /** Returns whether something changed. */
    public function set(source:Int, target:Null<Int>):Bool {
        if (active && this.source == source && this.target == target) return false;
        active = true;
        this.source = source;
        this.target = target;
        return true;
    }

    public function clear():Void {
        active = false;
        source = -1;
        target = null;
    }

}
