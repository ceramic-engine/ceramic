// Ported from gpui-kit 0.8.1: crates/base/src/dock/panel.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.dock;

import gpui.App;
import gpui.Context;
import gpui.FocusHandle;
import gpui.WeakEntity;
import gpui.Window;

/**
 * The default methods of the Rust `Panel` trait. A panel extends this and
 * implements `panelName`, `render` and `focusHandle`.
 */
abstract class PanelBase extends gpui.Model implements Panel {

    public function new() {
        super();
    }

    public abstract function panelName():String;

    public abstract function render(window:Window, cx:Context<Dynamic>):gpui.IntoElement;

    public abstract function focusHandle(cx:App):FocusHandle;

    public function visible(cx:App):Bool {
        return true;
    }

    public function closable(cx:App):Bool {
        return true;
    }

    public function zoomable(cx:App):Bool {
        return true;
    }

    public function setActive(active:Bool, window:Window, cx:Context<Dynamic>):Void {}

    public function setZoomed(zoomed:Bool, window:Window, cx:Context<Dynamic>):Void {}

    public function onAddedTo(group:WeakEntity<TabGroup>, window:Window, cx:Context<Dynamic>):Void {}

    public function onRemoved(window:Window, cx:Context<Dynamic>):Void {}

    /**
     * The default records the name and nothing else, which is enough for a
     * panel whose builder can reconstruct it from the name alone.
     */
    public function dump(cx:App):PanelState {
        return PanelState.named(panelName());
    }

}
