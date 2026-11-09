// Ported from vscode src/vs/editor/common/model/editStack.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.model;

import cityscape.base.common.Errors;
import cityscape.base.common.Uri;
import cityscape.common.Model;
import cityscape.common.core.EditOperation.ISingleEditOperation;
import cityscape.common.core.Selection;
import cityscape.common.core.TextChange;
import cityscape.platform.undoRedo.common.UndoRedo;
import cityscape.platform.undoRedo.common.UndoRedoService;
import haxe.io.Bytes;

class SingleModelEditStackData {

    public static function create(model:ITextModel, beforeCursorState:Null<Array<Selection>>):SingleModelEditStackData {
        final alternativeVersionId = model.getAlternativeVersionId();
        final eol = EditStack.getModelEOL(model);
        return new SingleModelEditStackData(
            alternativeVersionId,
            alternativeVersionId,
            eol,
            eol,
            beforeCursorState,
            beforeCursorState,
            []
        );
    }

    public final beforeVersionId:Int;

    public var afterVersionId:Int;

    public final beforeEOL:EndOfLineSequence;

    public var afterEOL:EndOfLineSequence;

    public final beforeCursorState:Null<Array<Selection>>;

    public var afterCursorState:Null<Array<Selection>>;

    public var changes:Array<TextChange>;

    public function new(beforeVersionId:Int, afterVersionId:Int, beforeEOL:EndOfLineSequence, afterEOL:EndOfLineSequence, beforeCursorState:Null<Array<Selection>>, afterCursorState:Null<Array<Selection>>, changes:Array<TextChange>) {
        this.beforeVersionId = beforeVersionId;
        this.afterVersionId = afterVersionId;
        this.beforeEOL = beforeEOL;
        this.afterEOL = afterEOL;
        this.beforeCursorState = beforeCursorState;
        this.afterCursorState = afterCursorState;
        this.changes = changes;
    }

    public function append(model:ITextModel, textChanges:Array<TextChange>, afterEOL:EndOfLineSequence, afterVersionId:Int, afterCursorState:Null<Array<Selection>>):Void {
        if (textChanges.length > 0) {
            this.changes = TextChange.compressConsecutiveTextChanges(this.changes, textChanges);
        }
        this.afterEOL = afterEOL;
        this.afterVersionId = afterVersionId;
        this.afterCursorState = afterCursorState;
    }

    static function _writeSelectionsSize(selections:Null<Array<Selection>>):Int {
        return 4 + 4 * 4 * (selections != null ? selections.length : 0);
    }

    static function _writeSelections(b:Bytes, selections:Null<Array<Selection>>, offset:Int):Int {
        BufferUtils.writeUInt32BE(b, (selections != null ? selections.length : 0), offset);
        offset += 4;
        if (selections != null) {
            for (selection in selections) {
                BufferUtils.writeUInt32BE(b, selection.selectionStartLineNumber, offset);
                offset += 4;
                BufferUtils.writeUInt32BE(b, selection.selectionStartColumn, offset);
                offset += 4;
                BufferUtils.writeUInt32BE(b, selection.positionLineNumber, offset);
                offset += 4;
                BufferUtils.writeUInt32BE(b, selection.positionColumn, offset);
                offset += 4;
            }
        }
        return offset;
    }

    static function _readSelections(b:Bytes, offset:Int, dest:Array<Selection>):Int {
        final count = BufferUtils.readUInt32BE(b, offset);
        offset += 4;
        for (i in 0...count) {
            final selectionStartLineNumber = BufferUtils.readUInt32BE(b, offset);
            offset += 4;
            final selectionStartColumn = BufferUtils.readUInt32BE(b, offset);
            offset += 4;
            final positionLineNumber = BufferUtils.readUInt32BE(b, offset);
            offset += 4;
            final positionColumn = BufferUtils.readUInt32BE(b, offset);
            offset += 4;
            dest.push(new Selection(selectionStartLineNumber, selectionStartColumn, positionLineNumber, positionColumn));
        }
        return offset;
    }

    public function serialize():Bytes {
        var necessarySize = (
            4 // beforeVersionId
            + 4 // afterVersionId
            + 1 // beforeEOL
            + 1 // afterEOL
            + SingleModelEditStackData._writeSelectionsSize(this.beforeCursorState)
            + SingleModelEditStackData._writeSelectionsSize(this.afterCursorState)
            + 4 // change count
        );
        for (change in this.changes) {
            necessarySize += change.writeSize();
        }

        final b = Bytes.alloc(necessarySize);
        var offset = 0;
        BufferUtils.writeUInt32BE(b, this.beforeVersionId, offset);
        offset += 4;
        BufferUtils.writeUInt32BE(b, this.afterVersionId, offset);
        offset += 4;
        BufferUtils.writeUInt8(b, this.beforeEOL, offset);
        offset += 1;
        BufferUtils.writeUInt8(b, this.afterEOL, offset);
        offset += 1;
        offset = SingleModelEditStackData._writeSelections(b, this.beforeCursorState, offset);
        offset = SingleModelEditStackData._writeSelections(b, this.afterCursorState, offset);
        BufferUtils.writeUInt32BE(b, this.changes.length, offset);
        offset += 4;
        for (change in this.changes) {
            offset = change.write(b, offset);
        }
        return b;
    }

    public static function deserialize(source:Bytes):SingleModelEditStackData {
        final b = source;
        var offset = 0;
        final beforeVersionId = BufferUtils.readUInt32BE(b, offset);
        offset += 4;
        final afterVersionId = BufferUtils.readUInt32BE(b, offset);
        offset += 4;
        final beforeEOL = BufferUtils.readUInt8(b, offset);
        offset += 1;
        final afterEOL = BufferUtils.readUInt8(b, offset);
        offset += 1;
        final beforeCursorState:Array<Selection> = [];
        offset = SingleModelEditStackData._readSelections(b, offset, beforeCursorState);
        final afterCursorState:Array<Selection> = [];
        offset = SingleModelEditStackData._readSelections(b, offset, afterCursorState);
        final changeCount = BufferUtils.readUInt32BE(b, offset);
        offset += 4;
        final changes:Array<TextChange> = [];
        for (i in 0...changeCount) {
            offset = TextChange.read(b, offset, changes);
        }
        return new SingleModelEditStackData(
            beforeVersionId,
            afterVersionId,
            beforeEOL,
            afterEOL,
            beforeCursorState,
            afterCursorState,
            changes
        );
    }

}

/**
 * An undo/redo element of one model: its data is kept open while the
 * element can grow (typing), then serialized into bytes once closed (less
 * memory), like Monaco.
 */
class SingleModelEditStackElement implements IResourceUndoRedoElement {

    /**
     * The model, or its uri once the model is gone (Monaco's
     * `ITextModel | URI`).
     */
    public var model:Null<ITextModel>;

    var modelUri:Uri;

    var _data:Null<SingleModelEditStackData>;

    var _serializedData:Null<Bytes>;

    public var type(get, never):UndoRedoElementType;
    function get_type():UndoRedoElementType {
        return UndoRedoElementType.Resource;
    }

    public var resource(get, never):Uri;
    function get_resource():Uri {
        return this.model != null ? this.model.uri : this.modelUri;
    }

    final _label:String;

    public var label(get, never):String;
    function get_label():String {
        return _label;
    }

    final _code:String;

    public var code(get, never):String;
    function get_code():String {
        return _code;
    }

    public var confirmBeforeUndo(get, never):Bool;
    function get_confirmBeforeUndo():Bool {
        return false;
    }

    public function new(label:String, code:String, model:ITextModel, beforeCursorState:Null<Array<Selection>>) {
        this._label = label;
        this._code = code;
        this.model = model;
        this.modelUri = model.uri;
        this._data = SingleModelEditStackData.create(model, beforeCursorState);
        this._serializedData = null;
    }

    function _getData():SingleModelEditStackData {
        return (this._data != null ? this._data : SingleModelEditStackData.deserialize(this._serializedData));
    }

    public function toString():String {
        final data = _getData();
        return [for (change in data.changes) change.toString()].join(', ');
    }

    public function matchesResource(resource:Uri):Bool {
        return (this.resource.toString() == resource.toString());
    }

    /**
     * Sets the model, or only its uri (`model` null) when the model is gone.
     */
    public function setModel(model:Null<ITextModel>, ?uri:Uri):Void {
        this.model = model;
        if (model != null) {
            this.modelUri = model.uri;
        }
        else if (uri != null) {
            this.modelUri = uri;
        }
    }

    public function canAppend(model:ITextModel):Bool {
        return (this.model == model && this._data != null);
    }

    public function append(model:ITextModel, textChanges:Array<TextChange>, afterEOL:EndOfLineSequence, afterVersionId:Int, afterCursorState:Null<Array<Selection>>):Void {
        if (this._data != null) {
            this._data.append(model, textChanges, afterEOL, afterVersionId, afterCursorState);
        }
    }

    public function close():Void {
        if (this._data != null) {
            this._serializedData = this._data.serialize();
            this._data = null;
        }
    }

    public function open():Void {
        if (this._data == null) {
            this._data = SingleModelEditStackData.deserialize(this._serializedData);
            this._serializedData = null;
        }
    }

    public function undo():Void {
        if (this.model == null) {
            // don't have a model
            throw 'Invalid SingleModelEditStackElement';
        }
        if (this._data != null) {
            this._serializedData = this._data.serialize();
            this._data = null;
        }
        final data = SingleModelEditStackData.deserialize(this._serializedData);
        this.model._applyUndo(data.changes, data.beforeEOL, data.beforeVersionId, data.beforeCursorState);
    }

    public function redo():Void {
        if (this.model == null) {
            // don't have a model
            throw 'Invalid SingleModelEditStackElement';
        }
        if (this._data != null) {
            this._serializedData = this._data.serialize();
            this._data = null;
        }
        final data = SingleModelEditStackData.deserialize(this._serializedData);
        this.model._applyRedo(data.changes, data.afterEOL, data.afterVersionId, data.afterCursorState);
    }

    public function heapSize():Int {
        if (this._data != null) {
            this._serializedData = this._data.serialize();
            this._data = null;
        }
        return this._serializedData.length + 168/*heap overhead*/;
    }

}

class EditStack {

    final _model:TextModel;

    final _undoRedoService:UndoRedoService;

    public function new(model:TextModel, undoRedoService:UndoRedoService) {
        this._model = model;
        this._undoRedoService = undoRedoService;
    }

    public static function getModelEOL(model:ITextModel):EndOfLineSequence {
        final eol = model.getEOL();
        if (eol == '\n') {
            return EndOfLineSequence.LF;
        }
        else {
            return EndOfLineSequence.CRLF;
        }
    }

    /**
     * TODO(step 3): `MultiModelEditStackElement` (edits of several models)
     * is not ported yet, so only `SingleModelEditStackElement` counts.
     */
    public static function isEditStackElement(element:Null<IUndoRedoElement>):Bool {
        if (element == null) {
            return false;
        }
        return Std.isOfType(element, SingleModelEditStackElement);
    }

    public function pushStackElement():Void {
        final lastElement = this._undoRedoService.getLastElement(this._model.uri);
        if (isEditStackElement(lastElement)) {
            (cast lastElement : SingleModelEditStackElement).close();
        }
    }

    public function popStackElement():Void {
        final lastElement = this._undoRedoService.getLastElement(this._model.uri);
        if (isEditStackElement(lastElement)) {
            (cast lastElement : SingleModelEditStackElement).open();
        }
    }

    public function clear():Void {
        this._undoRedoService.removeElements(this._model.uri);
    }

    function _getOrCreateEditStackElement(beforeCursorState:Null<Array<Selection>>, group:Null<UndoRedoGroup>):SingleModelEditStackElement {
        final lastElement = this._undoRedoService.getLastElement(this._model.uri);
        if (isEditStackElement(lastElement) && (cast lastElement : SingleModelEditStackElement).canAppend(this._model)) {
            return cast lastElement;
        }
        // nls.localize('edit', "Typing")
        final newElement = new SingleModelEditStackElement('Typing', 'undoredo.textBufferEdit', this._model, beforeCursorState);
        this._undoRedoService.pushElement(newElement, group);
        return newElement;
    }

    public function pushEOL(eol:EndOfLineSequence):Void {
        final editStackElement = this._getOrCreateEditStackElement(null, null);
        this._model.setEOL(eol);
        editStackElement.append(this._model, [], getModelEOL(this._model), this._model.getAlternativeVersionId(), null);
    }

    public function pushEditOperation(beforeCursorState:Null<Array<Selection>>, editOperations:Array<ValidAnnotatedEditOperation>, cursorStateComputer:Null<ICursorStateComputer>, ?group:UndoRedoGroup):Null<Array<Selection>> {
        final editStackElement = this._getOrCreateEditStackElement(beforeCursorState, group);
        final inverseEditOperations = this._model._applyValidatedEdits(editOperations, true);
        final afterCursorState = EditStack._computeCursorState(cursorStateComputer, inverseEditOperations);
        final textChanges = [for (index in 0...inverseEditOperations.length) {index: index, textChange: inverseEditOperations[index].textChange}];
        textChanges.sort((a, b) -> {
            if (a.textChange.oldPosition == b.textChange.oldPosition) {
                return a.index - b.index;
            }
            return a.textChange.oldPosition - b.textChange.oldPosition;
        });
        editStackElement.append(this._model, [for (op in textChanges) op.textChange], getModelEOL(this._model), this._model.getAlternativeVersionId(), afterCursorState);
        return afterCursorState;
    }

    static function _computeCursorState(cursorStateComputer:Null<ICursorStateComputer>, inverseEditOperations:Array<IValidEditOperation>):Null<Array<Selection>> {
        try {
            return cursorStateComputer != null ? cursorStateComputer(inverseEditOperations) : null;
        }
        catch (e:Dynamic) {
            Errors.onUnexpectedError(e);
            return null;
        }
    }

}
