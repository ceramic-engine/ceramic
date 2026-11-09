// Ported from vscode src/vs/platform/undoRedo/common/undoRedo.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.undoRedo.common;

import cityscape.base.common.Lifecycle.IDisposable;
import cityscape.base.common.Uri;

enum abstract UndoRedoElementType(Int) from Int to Int {
    var Resource = 0;
    var Workspace = 1;
}

/**
 * An element of the undo/redo stacks (Monaco's union
 * `IResourceUndoRedoElement | IWorkspaceUndoRedoElement`: test `type`).
 */
interface IUndoRedoElement {
    var type(get, never):UndoRedoElementType;
    /**
     * A user presentable label. May be localized.
     */
    var label(get, never):String;
    /**
     * A code describing the operation. Will not be localized.
     */
    var code(get, never):String;
    /**
     * Show a message to the user confirming when trying to undo this element
     */
    var confirmBeforeUndo(get, never):Bool;
    /**
     * Undoes the element (Monaco may return a promise; synchronous here).
     */
    function undo():Void;
    /**
     * Redoes the element (Monaco may return a promise; synchronous here).
     */
    function redo():Void;
}

interface IResourceUndoRedoElement extends IUndoRedoElement {
    /**
     * The resource impacted by this element.
     */
    var resource(get, never):Uri;
}

/**
 * TODO(step 3): elements spanning several resources (multi model edits,
 * `MultiModelEditStackElement`) are not supported by `UndoRedoService` yet.
 */
interface IWorkspaceUndoRedoElement extends IUndoRedoElement {
    /**
     * The resources impacted by this element.
     */
    var resources(get, never):Array<Uri>;
}

typedef IPastFutureElements = {
    var past:Array<IUndoRedoElement>;
    var future:Array<IUndoRedoElement>;
}

interface UriComparisonKeyComputer {
    function getComparisonKey(uri:Uri):String;
}

class ResourceEditStackSnapshot {

    public final resource:Uri;

    public final elements:Array<Int>;

    public function new(resource:Uri, elements:Array<Int>) {
        this.resource = resource;
        this.elements = elements;
    }

}

/**
 * Groups undo elements of several models so that they are undone together.
 * The id counter is global like Monaco's: ids only need to be unique.
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

/**
 * The source of undo elements (undo only the elements of one source).
 * The id counter is global like Monaco's: ids only need to be unique.
 */
class UndoRedoSource {

    static var _ID:Int = 0;

    public final id:Int;

    var order:Int;

    public function new() {
        this.id = UndoRedoSource._ID++;
        this.order = 1;
    }

    public function nextOrder():Int {
        if (this.id == 0) {
            return 0;
        }
        return this.order++;
    }

    public static final None:UndoRedoSource = new UndoRedoSource();

}
