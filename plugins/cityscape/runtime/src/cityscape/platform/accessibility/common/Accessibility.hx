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
