// Ported from lsp-types 0.97 (src/lib.rs, ShowDocumentParams), as used by gpui-kit 0.8.1: crates/base/src/input/editor/lsp
// Original code Copyright (c) 2016 Markus Westerlind (lsp-types), licensed under MIT.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

/**
 * Params to show a document (`window/showDocument`).
 */
class LspShowDocumentParams {

    /** The document uri to show. */
    public var uri:String;

    /** Indicates to show the resource in an external program. */
    public var external:Null<Bool>;

    /** An optional property to indicate whether the editor showing the document should take focus or not. */
    public var takeFocus:Null<Bool>;

    /** An optional selection range if the document is a text document. */
    public var selection:Null<LspRange>;

    public function new(uri:String, ?external:Bool, ?takeFocus:Bool, ?selection:LspRange) {
        this.uri = uri;
        this.external = external;
        this.takeFocus = takeFocus;
        this.selection = selection;
    }

}
