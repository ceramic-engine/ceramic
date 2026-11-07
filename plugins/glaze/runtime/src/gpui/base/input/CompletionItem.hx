// Ported from lsp-types 0.97 (src/lib.rs, CompletionItem), as used by gpui-kit 0.8.1: crates/base/src/input/editor/lsp
// Original code Copyright (c) 2016 Markus Westerlind (lsp-types), licensed under MIT.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

/**
 * A completion item (the fields the input engine reads; `textEdit` is one of `CompletionTextEdit`).
 */
class CompletionItem {

    /** The label of this completion item, inserted when nothing else is set. */
    public var label:String;

    /** The kind of this completion item (lsp `CompletionItemKind`). */
    public var kind:Null<Int>;

    /** Additional information, like type or symbol information. */
    public var detail:Null<String>;

    /** A human-readable string that represents a doc-comment. */
    public var documentation:Null<String>;

    /** A string used when comparing this item with other items. */
    public var sortText:Null<String>;

    /** A string used when filtering a set of completion items. */
    public var filterText:Null<String>;

    /** A string inserted when this completion is selected. */
    public var insertText:Null<String>;

    /** An edit applied when this completion is selected. */
    public var textEdit:Null<CompletionTextEdit>;

    /** A data entry field preserved between completion and resolve requests (JSON). */
    public var data:Null<Dynamic>;

    /** Indicates if this item is deprecated. */
    public var deprecated:Null<Bool>;

    public function new(label:String, ?kind:Int, ?detail:String, ?documentation:String, ?sortText:String, ?filterText:String, ?insertText:String, ?textEdit:CompletionTextEdit, ?data:Dynamic, ?deprecated:Bool) {
        this.label = label;
        this.kind = kind;
        this.detail = detail;
        this.documentation = documentation;
        this.sortText = sortText;
        this.filterText = filterText;
        this.insertText = insertText;
        this.textEdit = textEdit;
        this.data = data;
        this.deprecated = deprecated;
    }

}
