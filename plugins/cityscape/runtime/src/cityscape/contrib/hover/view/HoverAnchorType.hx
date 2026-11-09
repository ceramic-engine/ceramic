// Ported from vscode src/vs/editor/contrib/hover/browser/hoverTypes.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.hover.view;

/**
 * The type of a hover anchor. In a module of its own: its value `Range`
 * would hide the `Range` class in a module importing it (write
 * `HoverAnchorType.Range` qualified with the module).
 */
enum abstract HoverAnchorType(Int) from Int to Int {
    var Range = 1;
    var ForeignElement = 2;
}
