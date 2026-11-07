// Ported from gpui-pre 0.3.10: src/platform/platform_info.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * The operating system the app runs on.
 *
 * GPUI reads it from `cx.platform_info().os`, and decides some keyboard
 * behaviours at compile time (`#[cfg(target_os = "windows")]`). Here both use
 * `OperatingSystem.current`, detected at startup and writable so that tests can
 * check the behaviour of every platform.
 */
enum abstract OperatingSystem(Int) {

    /**
     * Apple's desktop operating system.
     */
    var Mac = 0;

    /**
     * Microsoft Windows.
     */
    var Windows = 1;

    /**
     * Linux, including browser hosts running ChromeOS.
     */
    var Linux = 2;

    /**
     * FreeBSD.
     */
    var FreeBsd = 3;

    /**
     * iOS and iPadOS.
     */
    var Ios = 4;

    /**
     * Android.
     */
    var Android = 5;

    /**
     * The backend could not identify the host operating system.
     */
    var Unknown = 6;

    static var _current:Null<OperatingSystem> = null;

    /**
     * The host operating system. Detected on first access; assign it to
     * simulate another platform (tests).
     */
    public static var current(get, set):OperatingSystem;

    static function get_current():OperatingSystem {
        if (_current == null) {
            _current = detect();
        }
        return _current;
    }

    static function set_current(os:OperatingSystem):OperatingSystem {
        return _current = os;
    }

    /**
     * Whether the host operating system is macOS.
     */
    public inline function isMac():Bool {
        return (cast this:OperatingSystem) == Mac;
    }

    static function detect():OperatingSystem {
        #if (ios || tvos)
        return Ios;
        #elseif android
        return Android;
        #elseif (mac || macos)
        return Mac;
        #elseif windows
        return Windows;
        #elseif linux
        return Linux;
        #else
        // The host of the browser on the web (Ceramic backend info)
        return fromName(ceramic.App.app.backend.info.operatingSystem());
        #end
    }

    static function fromName(name:String):OperatingSystem {
        final lower = name.toLowerCase();
        if (lower == 'darwin' || lower == 'mac' || lower.indexOf('mac') == 0) return Mac;
        if (lower.indexOf('iphone') != -1 || lower.indexOf('ipad') != -1 || lower == 'ios') return Ios;
        if (lower == 'win32' || lower.indexOf('win') == 0) return Windows;
        if (lower.indexOf('android') != -1) return Android;
        if (lower == 'freebsd' || lower == 'bsd') return FreeBsd;
        if (lower.indexOf('linux') != -1 || lower.indexOf('cros') != -1) return Linux;
        return Unknown;
    }

}
