// Ported from vscode src/vs/editor/common/core/textChange.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.core;

/**
 * A change of the text buffer, by offsets (undo/redo elements).
 *
 * TODO(step 1): only the fields and the getters so far; the rest of
 * textChange.ts (`toString`, `write`/`read`, `compressConsecutiveTextChanges`)
 * comes with the edit stack.
 */
class TextChange {

    public var oldLength(get, never):Int;
    inline function get_oldLength():Int {
        return this.oldText.length;
    }

    public var oldEnd(get, never):Int;
    inline function get_oldEnd():Int {
        return this.oldPosition + this.oldText.length;
    }

    public var newLength(get, never):Int;
    inline function get_newLength():Int {
        return this.newText.length;
    }

    public var newEnd(get, never):Int;
    inline function get_newEnd():Int {
        return this.newPosition + this.newText.length;
    }

    public final oldPosition:Int;

    public final oldText:String;

    public final newPosition:Int;

    public final newText:String;

    public function new(oldPosition:Int, oldText:String, newPosition:Int, newText:String) {
        this.oldPosition = oldPosition;
        this.oldText = oldText;
        this.newPosition = newPosition;
        this.newText = newText;
    }

}
