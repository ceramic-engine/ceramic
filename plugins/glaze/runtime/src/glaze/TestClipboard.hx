// Ported from gpui-pre 0.3.10: src/platform/test/platform.rs (clipboard)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * An in memory clipboard keeping items as they are (metadata and images
 * included), like GPUI's test platform.
 */
class TestClipboard implements PlatformClipboard {

    var current:Null<ClipboardItem> = null;

    public function new() {}

    public function readFromClipboard():Null<ClipboardItem> {
        return current;
    }

    public function writeToClipboard(item:ClipboardItem):Void {
        current = item;
    }

}
