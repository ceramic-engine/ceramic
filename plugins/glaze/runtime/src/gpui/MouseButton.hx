// Ported from gpui-pre 0.3.10: src/interactive.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * An enum representing the mouse button that was pressed.
 *
 * Rust's `Navigate(NavigationDirection)` variant is flattened into
 * `NavigateBack` and `NavigateForward`, so buttons compare with `==`.
 */
enum abstract MouseButton(Int) {

    /** The left mouse button. */
    var Left = 0;

    /** The right mouse button. */
    var Right = 1;

    /** The middle mouse button. */
    var Middle = 2;

    /** The back navigation button (Rust `Navigate(Back)`). */
    var NavigateBack = 3;

    /** The forward navigation button (Rust `Navigate(Forward)`). */
    var NavigateForward = 4;

    /**
     * Get all the mouse buttons in a list.
     */
    public static function all():Array<MouseButton> {
        return [Left, Right, Middle, NavigateBack, NavigateForward];
    }

    public function toString():String {
        return switch (cast this : MouseButton) {
            case Left: 'Left';
            case Right: 'Right';
            case Middle: 'Middle';
            case NavigateBack: 'Navigate(Back)';
            case NavigateForward: 'Navigate(Forward)';
        }
    }

}
