// Ported from gpui-pre 0.3.10: src/spring.rs (SpringPlayback)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package gpui;

/**
 * Controls how a spring advances and resolves its presentation value.
 * The default is `Running`.
 */
enum abstract SpringPlayback(Int) {

    /**
     * Advances toward the latest target, preserving velocity across retargets.
     */
    var Running = 0;

    /**
     * Holds the current position and velocity until playback resumes.
     */
    var Paused = 1;

    /**
     * Holds the current position and discards velocity.
     */
    var Stopped = 2;

    /**
     * Snaps to the latest target and discards velocity.
     */
    var Completed = 3;

    /**
     * Returns to the initial value and discards velocity.
     */
    var Cancelled = 4;

    public function toString():String {

        return switch (cast this:SpringPlayback) {
            case Running: 'Running';
            case Paused: 'Paused';
            case Stopped: 'Stopped';
            case Completed: 'Completed';
            case Cancelled: 'Cancelled';
        }

    }

}
