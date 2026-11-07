// Ported from gpui-kit 0.8.1: crates/component/src/dock/panel.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.dock;

import glaze.AnyElement;
import glaze.AnyView;
import glaze.App;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.Model;
import glaze.WeakEntity;
import glaze.Window;
import glaze.kit.base.dock.PanelId;
import glaze.kit.base.dock.PanelState;
import glaze.kit.base.dock.TabGroup;
import glaze.kit.button.Button;
import glaze.kit.menu.PopupMenu;

/**
 * The panel handle `gpui-base` holds on this crate's behalf.
 *
 * Concrete on purpose. Base stores it as a `glaze.kit.base.dock.PanelView`, and
 * every renderer hook (the tab bar most of all) gets it back with `of`,
 * which answers it only for this one type: the presentation handle cannot be
 * reached through base's interface, but a concrete wrapper around it can be.
 *
 * Rust's `Deref<Target = dyn PanelView>` becomes the presentation methods
 * below, which delegate to the wrapped handle.
 */
class PanelHandle implements glaze.kit.base.dock.PanelView {

    final inner:PanelView;

    /**
     * Wrap a presentation handle that is already erased (Rust `from_view`).
     */
    public function new(panel:PanelView) {
        this.inner = panel;
    }

    /**
     * Rust `PanelHandle::new`: the handle of a panel entity.
     */
    public static function create<P:Model & Panel>(panel:Entity<P>):PanelHandle {
        return new PanelHandle(new EntityPanelView(panel));
    }

    /**
     * Wrap a presentation handle that is already erased.
     */
    public static inline function fromView(panel:PanelView):PanelHandle {
        return new PanelHandle(panel);
    }

    /**
     * Recover the handle behind one of base's, or `null` when base is
     * holding a panel this crate did not wrap (a bare entity handed straight
     * to `DockLayout.panel`, say). A skin must draw something for that case;
     * base's own `panelName` is the fallback with no obligations on the
     * panel author.
     */
    public static function of(panel:Null<glaze.kit.base.dock.PanelView>):Null<PanelHandle> {
        if (panel == null) return null;
        final value:Dynamic = panel.asAny();
        return Std.isOfType(value, PanelHandle) ? (value : PanelHandle) : null;
    }

    /**
     * The presentation handle, kept by a callback that outlives the frame
     * that recovered it (the title bar's ellipsis menu).
     */
    public inline function panel():PanelView {
        return inner;
    }

    /**
     * Wrap `panel` so base carries its presentation across the renderer seam
     * (Rust free function `panel_handle`).
     *
     * This is what every entry point into the dock wants:
     * `DockLayout.tabs().panelView(PanelHandle.panelHandle(story), cx)`,
     * `DockArea.addPanelView(PanelHandle.panelHandle(story), ..)`, and the
     * closure a `PanelRegistry.registerPanel` builder returns.
     *
     * Base's own `DockLayout.panel` and `DockArea.addPanel` also accept a
     * panel, but they store the bare entity, and a skin cannot recover
     * presentation from one. Such a panel still docks, drags and persists; it
     * just draws its `panelName` where its title would be.
     */
    public static function panelHandle<P:Model & Panel>(panel:Entity<P>):glaze.kit.base.dock.PanelView {
        return create(panel);
    }

/// Presentation (Rust `Deref`)

    public inline function tabName(cx:App):Null<String> {
        return inner.tabName(cx);
    }

    public inline function title(window:Window, cx:App):AnyElement {
        return inner.title(window, cx);
    }

    public inline function titleStyle(cx:App):Null<TitleStyle> {
        return inner.titleStyle(cx);
    }

    public inline function titleSuffix(window:Window, cx:App):Null<AnyElement> {
        return inner.titleSuffix(window, cx);
    }

    public inline function toolbarButtons(window:Window, cx:App):Null<Array<Button>> {
        return inner.toolbarButtons(window, cx);
    }

    public inline function dropdownMenu(menu:PopupMenu, window:Window, cx:App):PopupMenu {
        return inner.dropdownMenu(menu, window, cx);
    }

    public inline function zoomControl(cx:App):Null<PanelControl> {
        return inner.zoomControl(cx);
    }

    public inline function innerPadding(cx:App):Bool {
        return inner.innerPadding(cx);
    }

    public inline function titleBar(cx:App):Bool {
        return inner.titleBar(cx);
    }

/// Behavior (Rust `impl gpui_base::dock::PanelView for PanelHandle`)

    public function panelName(cx:App):String {
        return inner.panelName(cx);
    }

    public function panelId(cx:App):PanelId {
        return inner.panelId(cx);
    }

    public function closable(cx:App):Bool {
        return inner.closable(cx);
    }

    public function zoomable(cx:App):Bool {
        return inner.zoomable(cx);
    }

    public function visible(cx:App):Bool {
        return inner.visible(cx);
    }

    public function setActive(active:Bool, window:Window, cx:App):Void {
        inner.setActive(active, window, cx);
    }

    public function setZoomed(zoomed:Bool, window:Window, cx:App):Void {
        inner.setZoomed(zoomed, window, cx);
    }

    public function onAddedTo(group:WeakEntity<TabGroup>, window:Window, cx:App):Void {
        inner.onAddedTo(group, window, cx);
    }

    public function onRemoved(window:Window, cx:App):Void {
        inner.onRemoved(window, cx);
    }

    public function view():AnyView {
        return inner.view();
    }

    public function focusHandle(cx:App):FocusHandle {
        return inner.focusHandle(cx);
    }

    public function dump(cx:App):PanelState {
        return inner.dump(cx);
    }

    public function asAny():Dynamic {
        return this;
    }

}
