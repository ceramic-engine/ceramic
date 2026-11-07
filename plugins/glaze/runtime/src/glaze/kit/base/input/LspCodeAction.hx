// Ported from lsp-types 0.97 (src/lib.rs, CodeAction), as used by gpui-kit 0.8.1: crates/base/src/input/editor/lsp
// Original code Copyright (c) 2016 Markus Westerlind (lsp-types), licensed under MIT.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

/**
 * A code action (the fields read by the input engine; the others are kept in `data`).
 */
class LspCodeAction {

    /** A short, human-readable, title for this code action. */
    public var title:String;

    /** The kind of the code action. */
    public var kind:Null<String>;

    /** Marks this as a preferred action. */
    public var isPreferred:Null<Bool>;

    /** The workspace edit this code action performs (JSON). */
    public var edit:Null<Dynamic>;

    /** A data entry field preserved between requests (JSON). */
    public var data:Null<Dynamic>;

    public function new(title:String, ?kind:String, ?isPreferred:Bool, ?edit:Dynamic, ?data:Dynamic) {
        this.title = title;
        this.kind = kind;
        this.isPreferred = isPreferred;
        this.edit = edit;
        this.data = data;
    }

}
