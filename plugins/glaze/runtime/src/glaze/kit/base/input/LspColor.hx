// Ported from lsp-types 0.97 (src/lib.rs, Color), as used by gpui-kit 0.8.1: crates/base/src/input/editor/lsp
// Original code Copyright (c) 2016 Markus Westerlind (lsp-types), licensed under MIT.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

/**
 * Represents a color in RGBA space (components in 0..1).
 */
class LspColor {

    public var red:Float;

    public var green:Float;

    public var blue:Float;

    public var alpha:Float;

    public function new(red:Float, green:Float, blue:Float, alpha:Float) {
        this.red = red;
        this.green = green;
        this.blue = blue;
        this.alpha = alpha;
    }

}
