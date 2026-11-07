// Ported from gpui-pre 0.3.10: src/platform.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * The style of the cursor (pointer).
 */
enum abstract CursorStyle(Int) {

    var Arrow = 0;

    var IBeam = 1;

    var Crosshair = 2;

    var ClosedHand = 3;

    var OpenHand = 4;

    var PointingHand = 5;

    var ResizeLeft = 6;

    var ResizeRight = 7;

    var ResizeLeftRight = 8;

    var ResizeUp = 9;

    var ResizeDown = 10;

    var ResizeUpDown = 11;

    var ResizeUpLeftDownRight = 12;

    var ResizeUpRightDownLeft = 13;

    var ResizeColumn = 14;

    var ResizeRow = 15;

    var IBeamCursorForVerticalLayout = 16;

    var OperationNotAllowed = 17;

    var DragLink = 18;

    var DragCopy = 19;

    var ContextualMenu = 20;

}
