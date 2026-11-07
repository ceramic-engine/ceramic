// Ported from lsp-types 0.97 (src/completion.rs, CompletionTextEdit), as used by gpui-kit 0.8.1: crates/base/src/input/editor/lsp
// Original code Copyright (c) 2016 Markus Westerlind (lsp-types), licensed under MIT.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * The edit of a completion item.
 */
enum CompletionTextEdit {

    Edit(edit:LspTextEdit);

    InsertAndReplace(newText:String, insert:LspRange, replace:LspRange);

}
