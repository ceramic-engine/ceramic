// Ported from gpui-kit 0.8.1: crates/base/src/dock/panel.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.dock;

import glaze.AnyView;
import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.Model;
import glaze.WeakEntity;
import glaze.Window;

/**
 * Object-safe counterpart of `Panel`, used to hold heterogeneous panel
 * entities behind a single handle (Rust `Arc<dyn PanelView>`).
 *
 * `EntityPanelView` is the handle of a panel entity (Rust's blanket
 * `impl<T: Panel> PanelView for Entity<T>`). A layer above base that needs
 * more off a panel than this interface carries defines its own concrete
 * handle, implements this interface by delegation, hands base that, and
 * recovers it with `asAny()`.
 */
interface PanelView {

    function panelName(cx:App):String;

    function panelId(cx:App):PanelId;

    function closable(cx:App):Bool;

    function zoomable(cx:App):Bool;

    function visible(cx:App):Bool;

    function setActive(active:Bool, window:Window, cx:App):Void;

    function setZoomed(zoomed:Bool, window:Window, cx:App):Void;

    function onAddedTo(group:WeakEntity<TabGroup>, window:Window, cx:App):Void;

    function onRemoved(window:Window, cx:App):Void;

    function view():AnyView;

    function focusHandle(cx:App):FocusHandle;

    function dump(cx:App):PanelState;

    /**
     * The concrete value behind this handle. `EntityPanelView` answers with
     * the entity, so a caller that knows the panel type can recover it.
     */
    function asAny():Dynamic;

}
