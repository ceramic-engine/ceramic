// Ported from lsp-types 0.97 (src/lib.rs, ColorInformation), as used by gpui-kit 0.8.1: crates/base/src/input/editor/lsp
// Original code Copyright (c) 2016 Markus Westerlind (lsp-types), licensed under MIT.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * A color range from a document.
 */
class ColorInformation {

    /** The range in the document where this color appears. */
    public var range:LspRange;

    /** The actual color value for this color range. */
    public var color:LspColor;

    public function new(range:LspRange, color:LspColor) {
        this.range = range;
        this.color = color;
    }

}
