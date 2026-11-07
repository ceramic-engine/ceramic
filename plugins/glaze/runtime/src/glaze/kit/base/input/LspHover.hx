// Ported from lsp-types 0.97 (src/lib.rs, Hover), as used by gpui-kit 0.8.1: crates/base/src/input/editor/lsp
// Original code Copyright (c) 2016 Markus Westerlind (lsp-types), licensed under MIT.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * The result of a hover request. The `contents` (lsp `HoverContents`) are kept as markdown or plain text.
 */
class LspHover {

    /** The hover's content. */
    public var contents:String;

    /** An optional range inside a text document used to visualize the hover. */
    public var range:Null<LspRange>;

    public function new(contents:String, ?range:LspRange) {
        this.contents = contents;
        this.range = range;
    }

}
