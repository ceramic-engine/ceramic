// Ported from vscode src/vs/editor/common/viewLayout/linePart.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.viewLayout;

enum abstract LinePartMetadata(Int) from Int to Int {
    var IS_WHITESPACE = 1;
    var PSEUDO_BEFORE = 2;
    var PSEUDO_AFTER = 4;

    var IS_WHITESPACE_MASK = 1;
    var PSEUDO_BEFORE_MASK = 2;
    var PSEUDO_AFTER_MASK = 4;
}

class LinePart {

    /**
     * last char index of this token (not inclusive).
     */
    public final endIndex:Int;
    public final type:String;
    public final metadata:Int;
    public final containsRTL:Bool;

    public function new(endIndex:Int, type:String, metadata:Int, containsRTL:Bool) {
        this.endIndex = endIndex;
        this.type = type;
        this.metadata = metadata;
        this.containsRTL = containsRTL;
    }

    public function isWhitespace():Bool {
        return (this.metadata & LinePartMetadata.IS_WHITESPACE_MASK) != 0;
    }

    public function isPseudoAfter():Bool {
        return (this.metadata & LinePartMetadata.PSEUDO_AFTER_MASK) != 0;
    }

}
