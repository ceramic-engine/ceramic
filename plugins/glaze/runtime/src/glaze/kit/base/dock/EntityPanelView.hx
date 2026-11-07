// Ported from gpui-kit 0.8.1: crates/base/src/dock/panel.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.dock;

import glaze.AnyView;
import glaze.App;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.Model;
import glaze.WeakEntity;
import glaze.Window;

/**
 * The `PanelView` of a panel entity (Rust's blanket implementation for
 * `Entity<T: Panel>`; `Arc::new(entity)` in Rust).
 */
class EntityPanelView<T:Model & Panel> implements PanelView {

    public final entity:Entity<T>;

    public function new(entity:Entity<T>) {
        this.entity = entity;
    }

    public function panelName(cx:App):String {
        return entity.read(cx).panelName();
    }

    public function panelId(cx:App):PanelId {
        return PanelId.fromEntityId(entity.entityId());
    }

    public function closable(cx:App):Bool {
        return entity.read(cx).closable(cx);
    }

    public function zoomable(cx:App):Bool {
        return entity.read(cx).zoomable(cx);
    }

    public function visible(cx:App):Bool {
        return entity.read(cx).visible(cx);
    }

    public function setActive(active:Bool, window:Window, cx:App):Void {
        entity.update(cx, (panel, cx) -> panel.setActive(active, window, cx));
    }

    public function setZoomed(zoomed:Bool, window:Window, cx:App):Void {
        entity.update(cx, (panel, cx) -> panel.setZoomed(zoomed, window, cx));
    }

    public function onAddedTo(group:WeakEntity<TabGroup>, window:Window, cx:App):Void {
        entity.update(cx, (panel, cx) -> panel.onAddedTo(group, window, cx));
    }

    public function onRemoved(window:Window, cx:App):Void {
        entity.update(cx, (panel, cx) -> panel.onRemoved(window, cx));
    }

    public function view():AnyView {
        return (entity : T);
    }

    public function focusHandle(cx:App):FocusHandle {
        return entity.read(cx).focusHandle(cx);
    }

    public function dump(cx:App):PanelState {
        return entity.read(cx).dump(cx);
    }

    public function asAny():Dynamic {
        return entity;
    }

}

