// Ported from lsp-types 0.97 (src/lib.rs, InlineCompletionItem), as used by gpui-kit 0.8.1: crates/base/src/input/editor/lsp
// Original code Copyright (c) 2016 Markus Westerlind (lsp-types), licensed under MIT.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * An inline completion item.
 */
class InlineCompletionItem {

    /** The text to replace the range with. */
    public var insertText:String;

    /** A text used to decide if this inline completion should be shown. */
    public var filterText:Null<String>;

    /** The range to replace. */
    public var range:Null<LspRange>;

    public function new(insertText:String, ?filterText:String, ?range:LspRange) {
        this.insertText = insertText;
        this.filterText = filterText;
        this.range = range;
    }

}
