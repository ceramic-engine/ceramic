// Ported from lsp-types 0.97 (src/lib.rs, SemanticTokensLegend), as used by gpui-kit 0.8.1: crates/base/src/input/editor/lsp
// Original code Copyright (c) 2016 Markus Westerlind (lsp-types), licensed under MIT.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

/**
 * The names of the semantic token types and modifiers.
 */
class SemanticTokensLegend {

    /** The token types a server uses. */
    public var tokenTypes:Array<String>;

    /** The token modifiers a server uses. */
    public var tokenModifiers:Array<String>;

    public function new(tokenTypes:Array<String>, tokenModifiers:Array<String>) {
        this.tokenTypes = tokenTypes;
        this.tokenModifiers = tokenModifiers;
    }

}
