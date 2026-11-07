// Ported from lsp-types 0.97 (src/lib.rs, SemanticToken), as used by gpui-kit 0.8.1: crates/base/src/input/editor/lsp
// Original code Copyright (c) 2016 Markus Westerlind (lsp-types), licensed under MIT.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

/**
 * A semantic token, relative to the previous one.
 */
class SemanticToken {

    public var deltaLine:Int;

    public var deltaStart:Int;

    public var length:Int;

    public var tokenType:Int;

    public var tokenModifiersBitset:Int;

    public function new(deltaLine:Int, deltaStart:Int, length:Int, tokenType:Int, tokenModifiersBitset:Int) {
        this.deltaLine = deltaLine;
        this.deltaStart = deltaStart;
        this.length = length;
        this.tokenType = tokenType;
        this.tokenModifiersBitset = tokenModifiersBitset;
    }

}
