// Ported from lsp-types 0.97 (src/lib.rs, SemanticTokens), as used by gpui-kit 0.8.1: crates/base/src/input/editor/lsp
// Original code Copyright (c) 2016 Markus Westerlind (lsp-types), licensed under MIT.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * The semantic tokens of a document or range.
 */
class SemanticTokens {

    /** The actual tokens. */
    public var data:Array<SemanticToken>;

    /** An optional result id. */
    public var resultId:Null<String>;

    public function new(data:Array<SemanticToken>, ?resultId:String) {
        this.data = data;
        this.resultId = resultId;
    }

}
