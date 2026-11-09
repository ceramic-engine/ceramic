// Ported from vscode src/vs/platform/undoRedo/common/undoRedo.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.undoRedo.common;

/**
 * Groups undo elements of several models so that they are undone together.
 *
 * TODO(step 1): only `UndoRedoGroup` so far. The undo/redo service comes with
 * the edit stack, as a field of the `Cityscape` context (no dependency
 * injection). The id counter is global like Monaco's: ids only need to be
 * unique.
 */
class UndoRedoGroup {

    static var _ID:Int = 0;

    public final id:Int;

    var order:Int;

    public function new() {
        this.id = UndoRedoGroup._ID++;
        this.order = 1;
    }

    public function nextOrder():Int {
        if (this.id == 0) {
            return 0;
        }
        return this.order++;
    }

    public static final None:UndoRedoGroup = new UndoRedoGroup();

}
