// Ported from vscode src/vs/platform/contextkey/common/contextkeys.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.contextkey.common;

import cityscape.base.common.Platform;
import cityscape.platform.contextkey.common.ContextKey.RawContextKey;

/**
 * The platform context keys. Their default values are read when they are
 * first used (Monaco reads them at module load).
 */
class ContextKeys {

    static var _IsMacContext:RawContextKey<Bool>;
    public static var IsMacContext(get, never):RawContextKey<Bool>;
    static function get_IsMacContext():RawContextKey<Bool> {
        if (!_initialized) init();
        return _IsMacContext;
    }
    static var _IsLinuxContext:RawContextKey<Bool>;
    public static var IsLinuxContext(get, never):RawContextKey<Bool>;
    static function get_IsLinuxContext():RawContextKey<Bool> {
        if (!_initialized) init();
        return _IsLinuxContext;
    }
    static var _IsWindowsContext:RawContextKey<Bool>;
    public static var IsWindowsContext(get, never):RawContextKey<Bool>;
    static function get_IsWindowsContext():RawContextKey<Bool> {
        if (!_initialized) init();
        return _IsWindowsContext;
    }

    static var _IsWebContext:RawContextKey<Bool>;
    public static var IsWebContext(get, never):RawContextKey<Bool>;
    static function get_IsWebContext():RawContextKey<Bool> {
        if (!_initialized) init();
        return _IsWebContext;
    }
    static var _IsMacNativeContext:RawContextKey<Bool>;
    public static var IsMacNativeContext(get, never):RawContextKey<Bool>;
    static function get_IsMacNativeContext():RawContextKey<Bool> {
        if (!_initialized) init();
        return _IsMacNativeContext;
    }

    static var _IsDevelopmentContext:RawContextKey<Bool>;
    public static var IsDevelopmentContext(get, never):RawContextKey<Bool>;
    static function get_IsDevelopmentContext():RawContextKey<Bool> {
        if (!_initialized) init();
        return _IsDevelopmentContext;
    }

    public static inline final InputFocusedContextKey = 'inputFocus';
    static var _InputFocusedContext:RawContextKey<Bool>;
    public static var InputFocusedContext(get, never):RawContextKey<Bool>;
    static function get_InputFocusedContext():RawContextKey<Bool> {
        if (!_initialized) init();
        return _InputFocusedContext;
    }


    static var _initialized = false;

    static function init():Void {
        _initialized = true;
        _IsMacContext = new RawContextKey<Bool>('isMac', Platform.isMacintosh, "Whether the operating system is macOS");
        _IsLinuxContext = new RawContextKey<Bool>('isLinux', Platform.isLinux, "Whether the operating system is Linux");
        _IsWindowsContext = new RawContextKey<Bool>('isWindows', Platform.isWindows, "Whether the operating system is Windows");
        _IsWebContext = new RawContextKey<Bool>('isWeb', Platform.isWeb, "Whether the platform is a web browser");
        _IsMacNativeContext = new RawContextKey<Bool>('isMacNative', Platform.isMacintosh && !Platform.isWeb, "Whether the operating system is macOS on a non-browser platform");
        _IsDevelopmentContext = new RawContextKey<Bool>('isDevelopment', false, true);
        _InputFocusedContext = new RawContextKey<Bool>(InputFocusedContextKey, false, "Whether keyboard focus is inside an input box");
    }

}
