// Ported from gpui-kit 0.8.1: crates/component/src/dock/mod.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.dock;

import glaze.App;
import glaze.WeakEntity;
import glaze.kit.base.dock.DockArea;
import glaze.kit.base.dock.DockPlacement;

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
@:allow(glaze.kit.dock)
class SkinShared extends ceramic.Entity implements tracker.Observable {

    final areaValue:WeakEntity<DockArea>;

    @observe var panelStyleValue:PanelStyle = PanelStyle.defaultValue();

    @observe var toggleButtonVisible:Bool = true;

    @observe var closeButtonVisible:Bool = false;

    /** The color of the line drawn at the top of the active tab, or null for none. */
    @observe var activeTabAccent:Null<glaze.Hsla> = null;

    /** How thick that line is, in pixels. */
    @observe var activeTabAccentWidth:Float = 2.;

    /** The close button of a tab that is not the active one shows while the pointer is over the tab only. */
    @observe var closeButtonOnHover:Bool = false;

    /** The groups of the centre always draw tabs, even for one panel (KIT-054). */
    @observe var centerTabsAlways:Bool = false;

    /**
     * The group of the centre that last held the focus, by the key of its
     * node, or -1 before any did (KIT-053).
     */
    @observe var focusedCenterNode:Int = -1;

    /** The focused handle the groups of the centre last answered to, so each move of the focus counts once (KIT-053). */
    var seenFocusId:Int = -1;

    /** The color of the active tab's label in a group of the centre that is not the focused one, or null (KIT-053). */
    @observe var unfocusedTabForeground:Null<glaze.Hsla> = null;

    /** How far from their top the lines between side by side groups start, in pixels (KIT-055). */
    @observe var dividerTopInset:Float = 0.;

    /** A tab alone in its group, outside the centre, shows its close button like any other (KIT-058). */
    @observe var closeButtonOnLoneTab:Bool = true;

    /** The region the group at `node` is in, or null. */
    function placementOfNode(node:glaze.kit.base.dock.NodeId):Null<DockPlacement> {
        final area = liveArea();
        if (area == null) return null;
        for (placement in [DockPlacement.Center, DockPlacement.Left, DockPlacement.Right, DockPlacement.Bottom]) {
            final tree = area.layout(placement);
            if (tree != null && tree.findNode(node) != null) return placement;
        }
        return null;
    }

    /** What an empty centre shows, or null (KIT-051). */
    var emptyCenter:Null<(glaze.Window, App) -> glaze.IntoElement> = null;

    /** The live area, or null once it is gone. */
    function liveArea():Null<DockArea> {
        final upgraded = areaValue.upgrade();
        if (upgraded == null) return null;
        final live:DockArea = upgraded;
        return live;
    }

    /** Whether the group at `node` is in the centre. */
    function isCenterNode(node:glaze.kit.base.dock.NodeId):Bool {
        final area = liveArea();
        if (area == null) return false;
        final tree = area.layout(DockPlacement.Center);
        return tree != null && tree.findNode(node) != null;
    }

    /**
     * The group of the centre that has the focus: the last one that held it
     * if it is still there, the first group otherwise, null for an empty
     * centre (KIT-053).
     */
    function focusedCenterGroup():Null<glaze.kit.base.dock.NodeId> {
        final area = liveArea();
        if (area == null) return null;
        final nodes = area.groupNodes(DockPlacement.Center);
        if (nodes.length == 0) return null;
        final key = focusedCenterNode;
        for (node in nodes) if (node.asU64() == key) return node;
        return nodes[0];
    }

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
