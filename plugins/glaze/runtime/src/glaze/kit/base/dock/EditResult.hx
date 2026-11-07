// Ported from gpui-kit 0.8.1: crates/base/src/dock/layout/edit.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.dock;

/**
 * What one edit changed.
 *
 * Only whether anything changed, for now. An earlier revision also carried
 * the created and removed nodes, the removed panels, and the activation
 * edges, but nothing outside tests ever read them, and computing them meant
 * cloning the whole tree on every edit to diff against. Fields are private, so
 * any of them can come back the day something needs one.
 */
class EditResult {

    final changedValue:Bool;

    @:allow(gpui.base.dock)
    function new(changed:Bool = false) {
        this.changedValue = changed;
    }

    public inline function changed():Bool {
        return changedValue;
    }

}
