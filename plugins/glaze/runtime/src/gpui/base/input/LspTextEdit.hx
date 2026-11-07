// Ported from lsp-types 0.97 (src/lib.rs, TextEdit), as used by gpui-kit 0.8.1: crates/base/src/input/editor/lsp
// Original code Copyright (c) 2016 Markus Westerlind (lsp-types), licensed under MIT.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

/**
 * A textual edit applicable to a text document (lsp_types `TextEdit`, renamed for clarity next to the input edits).
 */
class LspTextEdit {

    /** The range of the text document to be manipulated. */
    public var range:LspRange;

    /** The string to be inserted (empty to delete). */
    public var newText:String;

    public function new(range:LspRange, newText:String) {
        this.range = range;
        this.newText = newText;
    }

}
