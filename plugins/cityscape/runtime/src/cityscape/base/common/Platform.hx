// Ported from vscode src/vs/base/common/platform.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common;

import glaze.OperatingSystem as GlazeOperatingSystem;

/**
 * platform.ts `OperatingSystem`.
 */
enum abstract OperatingSystem(Int) from Int to Int {
    var Windows = 1;
    var Macintosh = 2;
    var Linux = 3;
}

/**
 * The platform flags of platform.ts that Cityscape uses, read from Glaze's
 * `OperatingSystem.current` (which tests can change) instead of being
 * computed once at startup.
 */
class Platform {

    /**
     * platform.ts `OS`: the operating system the keybindings are resolved
     * for (Glaze's `OperatingSystem.current`, so that tests can change it;
     * iOS counts as macOS, other systems as Linux).
     */
    public static var OS(get, never):OperatingSystem;
    static function get_OS():OperatingSystem {
        return switch (GlazeOperatingSystem.current) {
            case GlazeOperatingSystem.Mac | GlazeOperatingSystem.Ios: OperatingSystem.Macintosh;
            case GlazeOperatingSystem.Windows: OperatingSystem.Windows;
            case _: OperatingSystem.Linux;
        };
    }

    public static var isMacintosh(get, never):Bool;
    static inline function get_isMacintosh():Bool {
        return GlazeOperatingSystem.current == GlazeOperatingSystem.Mac;
    }

    public static var isWindows(get, never):Bool;
    static inline function get_isWindows():Bool {
        return GlazeOperatingSystem.current == GlazeOperatingSystem.Windows;
    }

    public static var isLinux(get, never):Bool;
    static inline function get_isLinux():Bool {
        return GlazeOperatingSystem.current == GlazeOperatingSystem.Linux;
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
