// Ported from vscode src/vs/platform/accessibility/common/accessibility.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.accessibility.common;

enum abstract AccessibilitySupport(Int) from Int to Int {
    /**
     * This should be the browser case where it is not known if a screen reader is attached or no.
     */
    var Unknown = 0;

    var Disabled = 1;

    var Enabled = 2;
}

/**
 * The accessibility context keys (accessibility.ts).
 */
class AccessibilityContextKeys {

    static var _accessibilityModeEnabled:Null<cityscape.platform.contextkey.common.ContextKey.RawContextKey<Bool>> = null;

    /**
     * `CONTEXT_ACCESSIBILITY_MODE_ENABLED`: Cityscape has no screen reader
     * support yet, the key is never set.
     */
    public static var CONTEXT_ACCESSIBILITY_MODE_ENABLED(get, never):cityscape.platform.contextkey.common.ContextKey.RawContextKey<Bool>;
    static function get_CONTEXT_ACCESSIBILITY_MODE_ENABLED() {
        if (_accessibilityModeEnabled == null) {
            _accessibilityModeEnabled = new cityscape.platform.contextkey.common.ContextKey.RawContextKey<Bool>('accessibilityModeEnabled', false);
        }
        return _accessibilityModeEnabled;
    }

}
