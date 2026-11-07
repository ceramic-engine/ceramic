// Ported from gpui-pre 0.3.10: src/platform.rs (the clipboard part of `Platform`)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * The system clipboard used by `App.readFromClipboard` / `App.writeToClipboard`
 * (`App.platformClipboard`). `CeramicClipboard` by default, `TestClipboard`
 * (in memory, like GPUI's test platform) in tests.
 */
interface PlatformClipboard {

    function readFromClipboard():Null<ClipboardItem>;

    function writeToClipboard(item:ClipboardItem):Void;

}
