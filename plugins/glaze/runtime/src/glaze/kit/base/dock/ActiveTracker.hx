// Ported from gpui-kit 0.8.1: crates/base/src/dock/active.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.dock;

/**
 * Tracks what each panel was last told about its active state, so a group
 * emits exactly one notification per real edge.
 *
 * This is the enforcement point for the `Panel.setActive` contract: called
 * with the frame-end net state when a panel becomes, or stops being, the
 * displayed tab of its group, exactly one notification per edge, delivered
 * on the next tick after the change, never same-value repeats nor
 * false-then-true flips within one frame. A panel removed from its group is
 * NOT told `false`; `Panel.onRemoved` is the deactivation signal instead. A
 * hidden panel occupying the active slot still receives `true`, even though
 * rendering falls back to the first visible panel.
 *
 * `TabGroup` owns one of these, and is the only thing that does.
 */
@:allow(gpui.base.dock, tests)
class ActiveTracker {

    /**
     * What each panel was last told, by panel id (Rust `HashMap<PanelId, bool>`).
     */
    final notified:Map<Int, Bool> = new Map();

    var syncScheduled:Bool = false;

    public function new() {}

    /**
     * Compare the group's current membership and displayed panel against
     * what each panel was last told, and return only the real edges,
     * deactivations before the activation.
     *
     * `displayed` names at most one panel, so at most one panel can newly
     * become active per call, which guarantees no panel ever observes two
     * panels active in its group at the same time. A `displayed` id absent
     * from `panels` degrades to "no panel in this group is displayed".
     */
    function reconcile(panels:Array<PanelId>, displayed:Null<PanelId>):Array<{panel:PanelId, active:Bool}> {
        // A panel that left the group is forgotten, not deactivated.
        for (key in [for (key in notified.keys()) key]) {
            if (!panels.contains(PanelId.fromU64(key))) notified.remove(key);
        }

        final deactivations:Array<{panel:PanelId, active:Bool}> = [];
        var activation:Null<{panel:PanelId, active:Bool}> = null;

        for (panel in panels) {
            final shouldBeActive = displayed != null && displayed == panel;
            final wasActive:Null<Bool> = notified.get(panel.asU64());
            if (wasActive != null && wasActive == shouldBeActive) continue;
            if (!shouldBeActive && wasActive == null) {
                // Never announce `false` to a panel that was never told `true`.
                notified.set(panel.asU64(), false);
                continue;
            }

            notified.set(panel.asU64(), shouldBeActive);
            if (shouldBeActive) {
                activation = {panel: panel, active: true};
            }
            else {
                deactivations.push({panel: panel, active: false});
            }
        }

        if (activation != null) deactivations.push(activation);
        return deactivations;
    }

    /**
     * Record what a panel was last told, without emitting anything. Used
     * when a panel moves between groups while displayed, so the move does
     * not look like an edge to the destination group.
     */
    function seed(panel:PanelId, active:Bool):Void {
        notified.set(panel.asU64(), active);
    }

    /**
     * What this tracker last told `panel`, if anything. A pure read.
     */
    function lastNotified(panel:PanelId):Null<Bool> {
        return notified.get(panel.asU64());
    }

    function tracks(panel:PanelId):Bool {
        return notified.exists(panel.asU64());
    }

    /**
     * Returns whether a sync needs scheduling; the caller defers the actual
     * `reconcile` to frame end so within-frame churn nets out to one
     * delivery per edge.
     */
    function scheduleSync():Bool {
        final needed = !syncScheduled;
        syncScheduled = true;
        return needed;
    }

    /**
     * Marks the deferred sync as delivered, so a future change schedules a
     * new one.
     */
    function syncFinished():Void {
        syncScheduled = false;
    }

}
