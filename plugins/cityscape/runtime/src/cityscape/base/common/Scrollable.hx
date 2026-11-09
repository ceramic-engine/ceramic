// Ported from vscode src/vs/base/common/scrollable.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common;

enum abstract ScrollbarVisibility(Int) from Int to Int {
    var Auto = 1;
    var Hidden = 2;
    var Visible = 3;
}

typedef IScrollPosition = {
    final scrollLeft:Float;
    final scrollTop:Float;
}

/**
 * Monaco's scroll state (dimensions, position, smooth scrolling).
 *
 * TODO(step 2): placeholder. Cityscape scrolls with Glaze and the kit's
 * scrollbars (see the plan); the view layout decides what remains of this
 * class.
 */
class Scrollable {

    public function new() {}

}
