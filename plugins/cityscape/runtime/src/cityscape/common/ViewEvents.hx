// Ported from vscode src/vs/editor/common/viewEvents.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common;

/**
 * TODO(step 2): the view events (`ViewEventType` and the event classes) come
 * with the view model.
 */
enum abstract VerticalRevealType(Int) from Int to Int {
    var Simple = 0;
    var Center = 1;
    var CenterIfOutsideViewport = 2;
    var Top = 3;
    var Bottom = 4;
    var NearTop = 5;
    var NearTopIfOutsideViewport = 6;
}
