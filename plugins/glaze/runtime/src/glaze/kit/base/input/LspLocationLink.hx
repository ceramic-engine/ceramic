// Ported from lsp-types 0.97 (src/lib.rs, LocationLink), as used by gpui-kit 0.8.1: crates/base/src/input/editor/lsp
// Original code Copyright (c) 2016 Markus Westerlind (lsp-types), licensed under MIT.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * Represents a link between a source and a target location.
 */
class LspLocationLink {

    /** The target resource identifier of this link. */
    public var targetUri:String;

    /** The full target range of this link. */
    public var targetRange:LspRange;

    /** The range that should be selected and revealed when this link is followed. */
    public var targetSelectionRange:LspRange;

    /** Span of the origin of this link. */
    public var originSelectionRange:Null<LspRange>;

    public function new(targetUri:String, targetRange:LspRange, targetSelectionRange:LspRange, ?originSelectionRange:LspRange) {
        this.targetUri = targetUri;
        this.targetRange = targetRange;
        this.targetSelectionRange = targetSelectionRange;
        this.originSelectionRange = originSelectionRange;
    }

}
