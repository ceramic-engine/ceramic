// Ported from gpui-pre 0.3.10: src/platform.rs (WindowControls)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * What window controls this platform supports.
 *
 * The default assumes that we can do anything, unless told otherwise.
 */
class WindowControls {

    /** Whether this platform supports fullscreen */
    public var fullscreen:Bool;

    /** Whether this platform supports maximize */
    public var maximize:Bool;

    /** Whether this platform supports minimize */
    public var minimize:Bool;

    /** Whether this platform supports a window menu */
    public var windowMenu:Bool;

    public function new(fullscreen:Bool = true, maximize:Bool = true, minimize:Bool = true, windowMenu:Bool = true) {
        this.fullscreen = fullscreen;
        this.maximize = maximize;
        this.minimize = minimize;
        this.windowMenu = windowMenu;
    }

}
