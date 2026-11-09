// Ported from vscode src/vs/base/common/platform.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common;

import glaze.OperatingSystem;

/**
 * The platform flags of platform.ts that Cityscape uses, read from Glaze's
 * `OperatingSystem.current` (which tests can change) instead of being
 * computed once at startup.
 */
class Platform {

    public static var isMacintosh(get, never):Bool;
    static inline function get_isMacintosh():Bool {
        return OperatingSystem.current == Mac;
    }

    public static var isWindows(get, never):Bool;
    static inline function get_isWindows():Bool {
        return OperatingSystem.current == Windows;
    }

    public static var isLinux(get, never):Bool;
    static inline function get_isLinux():Bool {
        return OperatingSystem.current == Linux;
    }

    public static var isWeb(get, never):Bool;
    static inline function get_isWeb():Bool {
        #if web
        return true;
        #else
        return false;
        #end
    }

}
