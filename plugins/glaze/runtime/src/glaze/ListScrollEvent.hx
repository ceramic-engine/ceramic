// Ported from gpui-pre 0.3.10: src/elements/list.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * A scroll event that has been converted to be in terms of the list's items.
 */
class ListScrollEvent {

    /** Start (inclusive) of the range of items currently visible in the list, after applying the scroll event. */
    public final visibleRangeStart:Int;

    /** End (exclusive) of the range of items currently visible in the list. */
    public final visibleRangeEnd:Int;

    /** The number of items that are currently visible in the list, after applying the scroll event. */
    public final count:Int;

    /** Whether the list has been scrolled. */
    public final isScrolled:Bool;

    /** Whether the list is currently in follow-tail mode (auto-scrolling to end). */
    public final isFollowingTail:Bool;

    public function new(visibleRangeStart:Int, visibleRangeEnd:Int, count:Int, isScrolled:Bool, isFollowingTail:Bool) {
        this.visibleRangeStart = visibleRangeStart;
        this.visibleRangeEnd = visibleRangeEnd;
        this.count = count;
        this.isScrolled = isScrolled;
        this.isFollowingTail = isFollowingTail;
    }

}
