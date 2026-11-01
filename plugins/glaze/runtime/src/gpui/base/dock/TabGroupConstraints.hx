// Ported from gpui-kit 0.8.1: crates/base/src/dock/tab_group.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.dock;

/**
 * Everything the container knows about a group's place in the dock.
 *
 * Pushed as one value rather than one setter per fact. These are read
 * together, and a container that updates one while leaving another stale
 * describes a dock that cannot exist: a group beside siblings that still
 * reports itself alone. Choosing a constructor forces the container kind to be
 * stated; anything a constructor does not grant stays off, so a container
 * that forgets something gets a group that does less rather than more.
 *
 * Rust `Copy`: the builders return a new value.
 */
class TabGroupConstraints {

    final alone:Bool;

    final dockLockedValue:Bool;

    final collapsedValue:Bool;

    final closableValue:Bool;

    function new(alone:Bool, dockLocked:Bool, collapsed:Bool, closable:Bool) {
        this.alone = alone;
        this.dockLockedValue = dockLocked;
        this.collapsedValue = collapsed;
        this.closableValue = closable;
    }

    /**
     * A group with nowhere to go: locked, alone, unclosable. What a group
     * starts as, before any container has placed it.
     */
    public static function sealed():TabGroupConstraints {
        return new TabGroupConstraints(true, true, false, false);
    }

    /**
     * A group in a split layout. `alone` when nothing sits beside it, which
     * is what stops its last visible panel being dragged out and leaving the
     * dock empty.
     */
    public static function inSplit(alone:Bool):TabGroupConstraints {
        return new TabGroupConstraints(alone, false, false, true);
    }

    /**
     * Whether the dock as a whole forbids rearranging.
     */
    public function dockLocked(dockLocked:Bool):TabGroupConstraints {
        return new TabGroupConstraints(alone, dockLocked, collapsedValue, closableValue);
    }

    /**
     * Whether the group is folded away to a strip of tabs with no content.
     */
    public function collapsed(collapsed:Bool):TabGroupConstraints {
        return new TabGroupConstraints(alone, dockLockedValue, collapsed, closableValue);
    }

    /**
     * Whether the container allows this group's panels to be closed at all.
     * A dock's last group sets this `false` so the dock cannot be emptied.
     */
    public function closable(closable:Bool):TabGroupConstraints {
        return new TabGroupConstraints(alone, dockLockedValue, collapsedValue, closable);
    }

    /**
     * Whether nothing sits beside this group in its tree.
     */
    public inline function isAlone():Bool {
        return alone;
    }

    /**
     * Whether the group's place in the dock is fixed. The dock-wide lock is
     * the whole of it.
     */
    public inline function isLocked():Bool {
        return dockLockedValue;
    }

    public inline function isCollapsed():Bool {
        return collapsedValue;
    }

    public inline function isClosable():Bool {
        return closableValue;
    }

    /**
     * Rust derived `PartialEq`.
     */
    public function equals(other:TabGroupConstraints):Bool {
        return alone == other.alone && dockLockedValue == other.dockLockedValue && collapsedValue == other.collapsedValue
            && closableValue == other.closableValue;
    }

}
