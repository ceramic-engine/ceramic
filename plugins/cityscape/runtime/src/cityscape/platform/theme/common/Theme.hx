// Ported from vscode src/vs/platform/theme/common/theme.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.theme.common;

/**
 * Color scheme used by the OS and by color themes.
 */
enum abstract ColorScheme(String) from String to String {
    var DARK = 'dark';
    var LIGHT = 'light';
    var HIGH_CONTRAST_DARK = 'hcDark';
    var HIGH_CONTRAST_LIGHT = 'hcLight';
}

/**
 * Module functions of theme.ts.
 */
class Theme {

    public static function isHighContrast(scheme:ColorScheme):Bool {
        return scheme == ColorScheme.HIGH_CONTRAST_DARK || scheme == ColorScheme.HIGH_CONTRAST_LIGHT;
    }

    public static function isDark(scheme:ColorScheme):Bool {
        return scheme == ColorScheme.DARK || scheme == ColorScheme.HIGH_CONTRAST_DARK;
    }

}
