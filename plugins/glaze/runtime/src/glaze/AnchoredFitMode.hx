// Ported from gpui-pre 0.3.10: src/elements/anchored.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * Which algorithm to use when fitting the anchored element to be inside the window.
 */
enum AnchoredFitMode {

    /** Snap the anchored element to the window edge. */
    SnapToWindow;

    /** Snap to window edge and leave some margins. */
    SnapToWindowWithMargin(edges:Edges);

    /** Switch which corner anchor this anchored element is attached to. */
    SwitchAnchor;

}
