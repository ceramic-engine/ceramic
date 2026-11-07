// Ported from gpui-kit 0.8.1: crates/base/src/text_selection.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

/**
 * Notifications emitted by a text-selection participant.
 */
enum TextSelectionEvent {
    /** The participant's window-selection projection changed. */
    SelectionChanged(snapshot:Null<TextSelectionSnapshot>);
    /** The active drag requests vertical auto-scroll, or `null` to stop. */
    AutoScroll(delta:Null<Float>);
    /** Window selection cleared the participant's participant-local state. */
    Cleared;
    /**
     * The touch selection the participant takes part in changed: it appeared,
     * its ends moved, a handle drag began or ended, or it went away. The
     * participant paints the handles and lays their hitboxes out from the ends
     * it painted last frame, so it renders once more.
     */
    TouchSelectionChanged;
}
