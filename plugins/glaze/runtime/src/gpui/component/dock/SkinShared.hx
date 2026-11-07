// Ported from gpui-kit 0.8.1: crates/component/src/dock/mod.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.dock;

import gpui.App;
import gpui.WeakEntity;
import gpui.base.dock.DockArea;
import gpui.base.dock.DockPlacement;

/**
 * What every part of the skin reads, and the dock area it belongs to.
 *
 * The renderer is the only skin-owned object in the picture, so the settings
 * the old `DockArea` carried (the panel style, whether dock collapse
 * affordances are offered at all) live here. It is shared by reference with
 * the per-container renderers, which are built once each and outlive any one
 * frame.
 *
 * The settings are observable (tracker), so the tab groups that read them
 * render again when one changes: the port caches every view by default, and
 * notifying the area alone would leave the groups' cached frames in place.
 */
@:allow(gpui.component.dock)
class SkinShared extends ceramic.Entity implements tracker.Observable {

    final areaValue:WeakEntity<DockArea>;

    @observe var panelStyleValue:PanelStyle = PanelStyle.defaultValue();

    @observe var toggleButtonVisible:Bool = true;

    @observe var closeButtonVisible:Bool = false;

    /**
     * The dock whose resize handle is being dragged, if any. Only one can be.
     */
    var resizingDock:Null<DockPlacement> = null;

    /**
     * Whether that dock was open when the drag began, so the release can
     * tell whether the drag opened or closed it.
     */
    var resizeStartedOpen:Bool = false;

    function new(area:WeakEntity<DockArea>) {
        super();
        this.areaValue = area;
    }

    public inline function area():WeakEntity<DockArea> {
        return areaValue;
    }

    public inline function panelStyle():PanelStyle {
        return panelStyleValue;
    }

    public inline function isToggleButtonVisible():Bool {
        return toggleButtonVisible;
    }

    /**
     * Redraw the area after a setting changed. The skin is not an entity, so
     * nothing else would notice.
     */
    function notify(cx:App):Void {
        areaValue.tryUpdate(cx, (_, cx) -> cx.notify());
    }

}
