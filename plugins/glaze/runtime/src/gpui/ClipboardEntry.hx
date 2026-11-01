// Ported from gpui-pre 0.3.10: src/platform.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * Either a string or an image (file entries, `ExternalPaths`, are not ported).
 */
enum ClipboardEntry {

    /** A string entry */
    String(string:ClipboardString);

    /** An image entry */
    Image(image:gpui.Image);

}
