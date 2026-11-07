// Ported from gpui-kit 0.8.1: crates/base/src/dock/registry.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.dock;

import glaze.App;
import glaze.WeakEntity;
import glaze.Window;

/**
 * Global registry of panel builders, keyed by panel name, used to reconstruct
 * a panel view from persisted `PanelState` / `PanelInfo` data.
 *
 * A builder returns a `PanelView`, not a bare `AnyView`: without a
 * `PanelView` a restored panel could not be asked for its `dump`, so every
 * registered panel's own persisted payload would be dropped on the first save
 * after a load.
 *
 * Building a panel that was never registered returns `null` rather than a
 * placeholder view: rendering an "invalid panel" placeholder is presentation
 * behavior that belongs above this seam. `DockArea` substitutes a
 * draw-nothing placeholder that carries the original `PanelState` forward, so
 * an unknown panel survives a round trip.
 */
class PanelRegistry {

    final items:Map<String, (PanelBuildContext, Window, App) -> PanelView> = new Map();

    public function new() {}

    /**
     * Initialize the panel registry.
     */
    @:allow(glaze.kit.base.dock)
    static function init(cx:App):Void {
        if (cx.tryGlobal(PanelRegistry) == null) {
            cx.setGlobal(new PanelRegistry());
        }
    }

    public static function global(cx:App):PanelRegistry {
        return cx.global(PanelRegistry);
    }

    public static function globalMut(cx:App):PanelRegistry {
        return cx.globalMut(PanelRegistry);
    }

    /**
     * Build a panel by name. Returns `null` if no builder is registered for
     * `panelName`.
     */
    public static function buildPanel(panelName:String, context:PanelBuildContext, window:Window, cx:App):Null<PanelView> {
        final build = global(cx).items.get(panelName);
        if (build == null) return null;
        return build(context, window, cx);
    }

    /**
     * Register the Panel init by panel_name to global registry (Rust free
     * function `register_panel`).
     */
    public static function registerPanel(cx:App, panelName:String, deserialize:(PanelBuildContext, Window, App) -> PanelView):Void {
        init(cx);
        globalMut(cx).items.set(panelName, deserialize);
    }

}
