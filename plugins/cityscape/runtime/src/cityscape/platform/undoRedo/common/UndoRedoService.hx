// Ported from vscode src/vs/platform/undoRedo/common/undoRedoService.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.undoRedo.common;

import cityscape.base.common.Errors;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Uri;
import cityscape.platform.undoRedo.common.UndoRedo;

/**
 * An element on the stack of one resource.
 */
class ResourceStackElement {

    public final id:Int;

    public final type:UndoRedoElementType = UndoRedoElementType.Resource;

    public final actual:IUndoRedoElement;

    public final label:String;

    public final confirmBeforeUndo:Bool;

    public final resourceLabel:String;

    public final strResource:String;

    public final resourceLabels:Array<String>;

    public final strResources:Array<String>;

    public final groupId:Int;

    public final groupOrder:Int;

    public final sourceId:Int;

    public final sourceOrder:Int;

    public var isValid:Bool;

    public function new(id:Int, actual:IUndoRedoElement, resourceLabel:String, strResource:String, groupId:Int, groupOrder:Int, sourceId:Int, sourceOrder:Int) {
        this.id = id;
        this.actual = actual;
        this.label = actual.label;
        this.confirmBeforeUndo = actual.confirmBeforeUndo;
        this.resourceLabel = resourceLabel;
        this.strResource = strResource;
        this.resourceLabels = [this.resourceLabel];
        this.strResources = [this.strResource];
        this.groupId = groupId;
        this.groupOrder = groupOrder;
        this.sourceId = sourceId;
        this.sourceOrder = sourceOrder;
        this.isValid = true;
    }

    public function setValid(isValid:Bool):Void {
        this.isValid = isValid;
    }

    public function toString():String {
        return '[id:${this.id}] [group:${this.groupId}] [${this.isValid ? '  VALID' : 'INVALID'}] ${Type.getClassName(Type.getClass(this.actual))} - ${this.actual}';
    }

}

/**
 * The undo and redo stacks of one resource.
 */
class ResourceEditStack {

    public final resourceLabel:String;

    final strResource:String;

    var _past:Array<ResourceStackElement>;

    var _future:Array<ResourceStackElement>;

    public var locked:Bool;

    public var versionId:Int;

    public function new(resourceLabel:String, strResource:String) {
        this.resourceLabel = resourceLabel;
        this.strResource = strResource;
        this._past = [];
        this._future = [];
        this.locked = false;
        this.versionId = 1;
    }

    public function dispose():Void {
        this.versionId++;
    }

    public function toString():String {
        final result:Array<String> = [];
        result.push('* ${this.strResource}:');
        for (i in 0...this._past.length) {
            result.push('   * [UNDO] ${this._past[i]}');
        }
        var i = this._future.length - 1;
        while (i >= 0) {
            result.push('   * [REDO] ${this._future[i]}');
            i--;
        }
        return result.join('\n');
    }

    public function flushAllElements():Void {
        this._past = [];
        this._future = [];
        this.versionId++;
    }

    public function setElementsIsValid(isValid:Bool):Void {
        for (element in this._past) {
            element.setValid(isValid);
        }
        for (element in this._future) {
            element.setValid(isValid);
        }
    }

    public function setElementsValidFlag(isValid:Bool, filter:(element:IUndoRedoElement) -> Bool):Void {
        for (element in this._past) {
            if (filter(element.actual)) {
                element.setValid(isValid);
            }
        }
        for (element in this._future) {
            if (filter(element.actual)) {
                element.setValid(isValid);
            }
        }
    }

    public function pushElement(element:ResourceStackElement):Void {
        // remove the future
        this._future = [];
        this._past.push(element);
        this.versionId++;
    }

    public function createSnapshot(resource:Uri):ResourceEditStackSnapshot {
        final elements:Array<Int> = [];

        for (i in 0...this._past.length) {
            elements.push(this._past[i].id);
        }
        var i = this._future.length - 1;
        while (i >= 0) {
            elements.push(this._future[i].id);
            i--;
        }

        return new ResourceEditStackSnapshot(resource, elements);
    }

    public function restoreSnapshot(snapshot:ResourceEditStackSnapshot):Void {
        final snapshotLength = snapshot.elements.length;
        var isOK = true;
        var snapshotIndex = 0;
        var removePastAfter = -1;
        for (i in 0...this._past.length) {
            final element = this._past[i];
            if (isOK && (snapshotIndex >= snapshotLength || element.id != snapshot.elements[snapshotIndex])) {
                isOK = false;
                removePastAfter = 0;
            }
            snapshotIndex++;
        }
        var removeFutureBefore = -1;
        var i = this._future.length - 1;
        while (i >= 0) {
            final element = this._future[i];
            if (isOK && (snapshotIndex >= snapshotLength || element.id != snapshot.elements[snapshotIndex])) {
                isOK = false;
                removeFutureBefore = i;
            }
            i--;
            snapshotIndex++;
        }
        if (removePastAfter != -1) {
            this._past = this._past.slice(0, removePastAfter);
        }
        if (removeFutureBefore != -1) {
            this._future = this._future.slice(removeFutureBefore + 1);
        }
        this.versionId++;
    }

    public function getElements():IPastFutureElements {
        final past:Array<IUndoRedoElement> = [];
        final future:Array<IUndoRedoElement> = [];

        for (element in this._past) {
            past.push(element.actual);
        }
        for (element in this._future) {
            future.push(element.actual);
        }

        return {past: past, future: future};
    }

    public function getClosestPastElement():Null<ResourceStackElement> {
        if (this._past.length == 0) {
            return null;
        }
        return this._past[this._past.length - 1];
    }

    public function getSecondClosestPastElement():Null<ResourceStackElement> {
        if (this._past.length < 2) {
            return null;
        }
        return this._past[this._past.length - 2];
    }

    public function getClosestFutureElement():Null<ResourceStackElement> {
        if (this._future.length == 0) {
            return null;
        }
        return this._future[this._future.length - 1];
    }

    public function hasPastElements():Bool {
        return (this._past.length > 0);
    }

    public function hasFutureElements():Bool {
        return (this._future.length > 0);
    }

    public function moveBackward(element:ResourceStackElement):Void {
        this._past.pop();
        this._future.push(element);
        this.versionId++;
    }

    public function moveForward(element:ResourceStackElement):Void {
        this._future.pop();
        this._past.push(element);
        this.versionId++;
    }

}

/**
 * The undo/redo stacks of the resources (models) of a `Cityscape` context.
 *
 * Only the part that text models need is ported: elements of a single
 * resource, groups (`UndoRedoGroup`) undone and redone together across
 * resources, sources, snapshots, the validity flag and the edit stack locks.
 * Undo and redo are synchronous (no element of Cityscape returns a promise).
 * Monaco asks for a confirmation (dialog service) before undoing an element
 * of another source or flagged `confirmBeforeUndo`; there is no dialog here,
 * the undo proceeds. Errors while undoing drop the stacks of the resource
 * and are reported to `Errors.onUnexpectedError` (Monaco also notifies the
 * user).
 *
 * TODO(step 3): elements spanning several resources (workspace elements,
 * `MultiModelEditStackElement`): `pushElement` throws for them.
 */
class UndoRedoService {

    /**
     * The stacks by comparison key, in insertion order (Monaco's `Map`).
     */
    final _editStacks:Map<String, ResourceEditStack>;

    final _editStackKeys:Array<String>;

    final _uriComparisonKeyComputers:Array<{scheme:String, computer:UriComparisonKeyComputer}>;

    var stackElementCounter:Int = 0;

    public function new() {
        this._editStacks = new Map<String, ResourceEditStack>();
        this._editStackKeys = [];
        this._uriComparisonKeyComputers = [];
    }

    public function registerUriComparisonKeyComputer(scheme:String, uriComparisonKeyComputer:UriComparisonKeyComputer):IDisposable {
        final entry = {scheme: scheme, computer: uriComparisonKeyComputer};
        this._uriComparisonKeyComputers.push(entry);
        return Lifecycle.toDisposable(() -> {
            this._uriComparisonKeyComputers.remove(entry);
        });
    }

    public function getUriComparisonKey(resource:Uri):String {
        for (uriComparisonKeyComputer in this._uriComparisonKeyComputers) {
            if (uriComparisonKeyComputer.scheme == resource.scheme) {
                return uriComparisonKeyComputer.computer.getComparisonKey(resource);
            }
        }
        return resource.toString();
    }

    static function getResourceLabel(resource:Uri):String {
        return resource.scheme == 'file' ? resource.fsPath : resource.path;
    }

    function setEditStack(strResource:String, editStack:ResourceEditStack):Void {
        if (!this._editStacks.exists(strResource)) {
            this._editStackKeys.push(strResource);
        }
        this._editStacks.set(strResource, editStack);
    }

    function deleteEditStack(strResource:String):Void {
        if (this._editStacks.remove(strResource)) {
            this._editStackKeys.remove(strResource);
        }
    }

    /**
     * Add a new element to the `undo` stack.
     * This will destroy the `redo` stack.
     */
    public function pushElement(element:IUndoRedoElement, ?group:UndoRedoGroup, ?source:UndoRedoSource):Void {
        if (group == null) {
            group = UndoRedoGroup.None;
        }
        if (source == null) {
            source = UndoRedoSource.None;
        }
        if (element.type == UndoRedoElementType.Resource) {
            final resource = (cast element : IResourceUndoRedoElement).resource;
            final resourceLabel = getResourceLabel(resource);
            final strResource = this.getUriComparisonKey(resource);
            this._pushElement(new ResourceStackElement(++stackElementCounter, element, resourceLabel, strResource, group.id, group.nextOrder(), source.id, source.nextOrder()));
        }
        else {
            final resources = (cast element : IWorkspaceUndoRedoElement).resources;
            final seen = new Map<String, Bool>();
            final resourceLabels:Array<String> = [];
            final strResources:Array<String> = [];
            for (resource in resources) {
                final resourceLabel = getResourceLabel(resource);
                final strResource = this.getUriComparisonKey(resource);

                if (seen.exists(strResource)) {
                    continue;
                }
                seen.set(strResource, true);
                resourceLabels.push(resourceLabel);
                strResources.push(strResource);
            }

            if (resourceLabels.length == 1) {
                this._pushElement(new ResourceStackElement(++stackElementCounter, element, resourceLabels[0], strResources[0], group.id, group.nextOrder(), source.id, source.nextOrder()));
            }
            else {
                throw 'UndoRedoService: elements of several resources are not supported yet';
            }
        }
    }

    function _pushElement(element:ResourceStackElement):Void {
        for (i in 0...element.strResources.length) {
            final resourceLabel = element.resourceLabels[i];
            final strResource = element.strResources[i];

            var editStack:ResourceEditStack;
            if (this._editStacks.exists(strResource)) {
                editStack = this._editStacks.get(strResource);
            }
            else {
                editStack = new ResourceEditStack(resourceLabel, strResource);
                this.setEditStack(strResource, editStack);
            }

            editStack.pushElement(element);
        }
    }

    /**
     * Get the last pushed element for a resource.
     * If the last pushed element has been undone, returns null.
     */
    public function getLastElement(resource:Uri):Null<IUndoRedoElement> {
        final strResource = this.getUriComparisonKey(resource);
        if (this._editStacks.exists(strResource)) {
            final editStack = this._editStacks.get(strResource);
            if (editStack.hasFutureElements()) {
                return null;
            }
            final closestPastElement = editStack.getClosestPastElement();
            return closestPastElement != null ? closestPastElement.actual : null;
        }
        return null;
    }

    /**
     * Remove elements that target `resource` (a uri or its comparison key).
     */
    public function removeElements(resource:haxe.extern.EitherType<Uri, String>):Void {
        final strResource:String = Std.isOfType(resource, String) ? (cast resource : String) : this.getUriComparisonKey(cast resource);
        if (this._editStacks.exists(strResource)) {
            final editStack = this._editStacks.get(strResource);
            editStack.dispose();
            this.deleteEditStack(strResource);
        }
    }

    public function setElementsValidFlag(resource:Uri, isValid:Bool, filter:(element:IUndoRedoElement) -> Bool):Void {
        final strResource = this.getUriComparisonKey(resource);
        if (this._editStacks.exists(strResource)) {
            final editStack = this._editStacks.get(strResource);
            editStack.setElementsValidFlag(isValid, filter);
        }
    }

    public function hasElements(resource:Uri):Bool {
        final strResource = this.getUriComparisonKey(resource);
        if (this._editStacks.exists(strResource)) {
            final editStack = this._editStacks.get(strResource);
            return (editStack.hasPastElements() || editStack.hasFutureElements());
        }
        return false;
    }

    public function createSnapshot(resource:Uri):ResourceEditStackSnapshot {
        final strResource = this.getUriComparisonKey(resource);
        if (this._editStacks.exists(strResource)) {
            final editStack = this._editStacks.get(strResource);
            return editStack.createSnapshot(resource);
        }
        return new ResourceEditStackSnapshot(resource, []);
    }

    public function restoreSnapshot(snapshot:ResourceEditStackSnapshot):Void {
        final strResource = this.getUriComparisonKey(snapshot.resource);
        if (this._editStacks.exists(strResource)) {
            final editStack = this._editStacks.get(strResource);
            editStack.restoreSnapshot(snapshot);

            if (!editStack.hasPastElements() && !editStack.hasFutureElements()) {
                // the edit stack is now empty, just remove it entirely
                editStack.dispose();
                this.deleteEditStack(strResource);
            }
        }
    }

    public function getElements(resource:Uri):IPastFutureElements {
        final strResource = this.getUriComparisonKey(resource);
        if (this._editStacks.exists(strResource)) {
            final editStack = this._editStacks.get(strResource);
            return editStack.getElements();
        }
        return {past: [], future: []};
    }

    var _matchedStrResource:Null<String> = null;

    /**
     * Monaco returns `[element, strResource]`; the resource goes to
     * `_matchedStrResource`.
     */
    function _findClosestUndoElementWithSource(sourceId:Int):Null<ResourceStackElement> {
        _matchedStrResource = null;
        if (sourceId == 0) {
            return null;
        }

        // find an element with the sourceId and with the highest sourceOrder ready to be undone
        var matchedElement:Null<ResourceStackElement> = null;
        var matchedStrResource:Null<String> = null;

        for (strResource in this._editStackKeys) {
            final editStack = this._editStacks.get(strResource);
            final candidate = editStack.getClosestPastElement();
            if (candidate == null) {
                continue;
            }
            if (candidate.sourceId == sourceId) {
                if (matchedElement == null || candidate.sourceOrder > matchedElement.sourceOrder) {
                    matchedElement = candidate;
                    matchedStrResource = strResource;
                }
            }
        }

        _matchedStrResource = matchedStrResource;
        return matchedElement;
    }

    /**
     * Is there anything to undo for `resourceOrSource` (a `Uri` or an
     * `UndoRedoSource`)?
     */
    public function canUndo(resourceOrSource:haxe.extern.EitherType<Uri, UndoRedoSource>):Bool {
        if (Std.isOfType(resourceOrSource, UndoRedoSource)) {
            _findClosestUndoElementWithSource((cast resourceOrSource : UndoRedoSource).id);
            return _matchedStrResource != null;
        }
        final strResource = this.getUriComparisonKey(cast resourceOrSource);
        if (this._editStacks.exists(strResource)) {
            final editStack = this._editStacks.get(strResource);
            return editStack.hasPastElements();
        }
        return false;
    }

    function _onError(err:Dynamic, element:ResourceStackElement):Void {
        Errors.onUnexpectedError(err);
        // An error occurred while undoing or redoing => drop the undo/redo stack for all affected resources
        for (strResource in element.strResources) {
            this.removeElements(strResource);
        }
    }

    function _safeInvokeWithLocks(element:ResourceStackElement, invoke:() -> Void, editStack:ResourceEditStack, continuation:() -> Void):Void {
        // _acquireLocks
        if (editStack.locked) {
            throw 'Cannot acquire edit stack lock';
        }
        editStack.locked = true;

        try {
            invoke();
        }
        catch (err:Dynamic) {
            editStack.locked = false;
            this._onError(err, element);
            return;
        }

        editStack.locked = false;
        continuation();
    }

    function _resourceUndo(editStack:ResourceEditStack, element:ResourceStackElement, undoConfirmed:Bool):Void {
        if (!element.isValid) {
            // invalid element => immediately flush edit stack!
            editStack.flushAllElements();
            return;
        }
        if (editStack.locked) {
            // Monaco warns "Could not undo '{0}' because there is already an undo or redo operation running."
            return;
        }
        editStack.moveBackward(element);
        this._safeInvokeWithLocks(element, () -> element.actual.undo(), editStack, () -> this._continueUndoInGroup(element.groupId, undoConfirmed));
    }

    function _findClosestUndoElementInGroup(groupId:Int):Null<ResourceStackElement> {
        _matchedStrResource = null;
        if (groupId == 0) {
            return null;
        }

        // find another element with the same groupId and with the highest groupOrder ready to be undone
        var matchedElement:Null<ResourceStackElement> = null;
        var matchedStrResource:Null<String> = null;

        for (strResource in this._editStackKeys) {
            final editStack = this._editStacks.get(strResource);
            final candidate = editStack.getClosestPastElement();
            if (candidate == null) {
                continue;
            }
            if (candidate.groupId == groupId) {
                if (matchedElement == null || candidate.groupOrder > matchedElement.groupOrder) {
                    matchedElement = candidate;
                    matchedStrResource = strResource;
                }
            }
        }

        _matchedStrResource = matchedStrResource;
        return matchedElement;
    }

    function _continueUndoInGroup(groupId:Int, undoConfirmed:Bool):Void {
        if (groupId == 0) {
            return;
        }

        this._findClosestUndoElementInGroup(groupId);
        final matchedStrResource = _matchedStrResource;
        if (matchedStrResource != null) {
            this._undo(matchedStrResource, 0, undoConfirmed);
        }
    }

    /**
     * Undo the last element of `resourceOrSource` (a `Uri`, an
     * `UndoRedoSource` or a comparison key).
     */
    public function undo(resourceOrSource:haxe.extern.EitherType<Uri, haxe.extern.EitherType<UndoRedoSource, String>>):Void {
        if (Std.isOfType(resourceOrSource, UndoRedoSource)) {
            final source:UndoRedoSource = cast resourceOrSource;
            this._findClosestUndoElementWithSource(source.id);
            final matchedStrResource = _matchedStrResource;
            if (matchedStrResource != null) {
                this._undo(matchedStrResource, source.id, false);
            }
            return;
        }
        if (Std.isOfType(resourceOrSource, String)) {
            this._undo(cast resourceOrSource, 0, false);
            return;
        }
        this._undo(this.getUriComparisonKey(cast resourceOrSource), 0, false);
    }

    function _undo(strResource:String, sourceId:Int = 0, undoConfirmed:Bool):Void {
        if (!this._editStacks.exists(strResource)) {
            return;
        }

        final editStack = this._editStacks.get(strResource);
        final element = editStack.getClosestPastElement();
        if (element == null) {
            return;
        }

        if (element.groupId != 0) {
            // this element is a part of a group, we need to make sure undoing in a group is in order
            final matchedElement = this._findClosestUndoElementInGroup(element.groupId);
            final matchedStrResource = _matchedStrResource;
            if (element != matchedElement && matchedStrResource != null) {
                // there is an element in the same group that should be undone before this one
                this._undo(matchedStrResource, sourceId, undoConfirmed);
                return;
            }
        }

        final shouldPromptForConfirmation = (element.sourceId != sourceId || element.confirmBeforeUndo);
        if (shouldPromptForConfirmation && !undoConfirmed) {
            // Monaco asks for a confirmation here (no dialog in Cityscape: confirmed)
            this._undo(strResource, sourceId, true);
            return;
        }

        this._resourceUndo(editStack, element, undoConfirmed);
    }

    function _findClosestRedoElementWithSource(sourceId:Int):Null<ResourceStackElement> {
        _matchedStrResource = null;
        if (sourceId == 0) {
            return null;
        }

        // find an element with sourceId and with the lowest sourceOrder ready to be redone
        var matchedElement:Null<ResourceStackElement> = null;
        var matchedStrResource:Null<String> = null;

        for (strResource in this._editStackKeys) {
            final editStack = this._editStacks.get(strResource);
            final candidate = editStack.getClosestFutureElement();
            if (candidate == null) {
                continue;
            }
            if (candidate.sourceId == sourceId) {
                if (matchedElement == null || candidate.sourceOrder < matchedElement.sourceOrder) {
                    matchedElement = candidate;
                    matchedStrResource = strResource;
                }
            }
        }

        _matchedStrResource = matchedStrResource;
        return matchedElement;
    }

    /**
     * Is there anything to redo for `resourceOrSource` (a `Uri` or an
     * `UndoRedoSource`)?
     */
    public function canRedo(resourceOrSource:haxe.extern.EitherType<Uri, UndoRedoSource>):Bool {
        if (Std.isOfType(resourceOrSource, UndoRedoSource)) {
            _findClosestRedoElementWithSource((cast resourceOrSource : UndoRedoSource).id);
            return _matchedStrResource != null;
        }
        final strResource = this.getUriComparisonKey(cast resourceOrSource);
        if (this._editStacks.exists(strResource)) {
            final editStack = this._editStacks.get(strResource);
            return editStack.hasFutureElements();
        }
        return false;
    }

    function _resourceRedo(editStack:ResourceEditStack, element:ResourceStackElement):Void {
        if (!element.isValid) {
            // invalid element => immediately flush edit stack!
            editStack.flushAllElements();
            return;
        }
        if (editStack.locked) {
            // Monaco warns "Could not redo '{0}' because there is already an undo or redo operation running."
            return;
        }

        editStack.moveForward(element);
        this._safeInvokeWithLocks(element, () -> element.actual.redo(), editStack, () -> this._continueRedoInGroup(element.groupId));
    }

    function _findClosestRedoElementInGroup(groupId:Int):Null<ResourceStackElement> {
        _matchedStrResource = null;
        if (groupId == 0) {
            return null;
        }

        // find another element with the same groupId and with the lowest groupOrder ready to be redone
        var matchedElement:Null<ResourceStackElement> = null;
        var matchedStrResource:Null<String> = null;

        for (strResource in this._editStackKeys) {
            final editStack = this._editStacks.get(strResource);
            final candidate = editStack.getClosestFutureElement();
            if (candidate == null) {
                continue;
            }
            if (candidate.groupId == groupId) {
                if (matchedElement == null || candidate.groupOrder < matchedElement.groupOrder) {
                    matchedElement = candidate;
                    matchedStrResource = strResource;
                }
            }
        }

        _matchedStrResource = matchedStrResource;
        return matchedElement;
    }

    function _continueRedoInGroup(groupId:Int):Void {
        if (groupId == 0) {
            return;
        }

        this._findClosestRedoElementInGroup(groupId);
        final matchedStrResource = _matchedStrResource;
        if (matchedStrResource != null) {
            this._redo(matchedStrResource);
        }
    }

    /**
     * Redo the next element of `resourceOrSource` (a `Uri`, an
     * `UndoRedoSource` or a comparison key).
     */
    public function redo(resourceOrSource:haxe.extern.EitherType<Uri, haxe.extern.EitherType<UndoRedoSource, String>>):Void {
        if (Std.isOfType(resourceOrSource, UndoRedoSource)) {
            this._findClosestRedoElementWithSource((cast resourceOrSource : UndoRedoSource).id);
            final matchedStrResource = _matchedStrResource;
            if (matchedStrResource != null) {
                this._redo(matchedStrResource);
            }
            return;
        }
        if (Std.isOfType(resourceOrSource, String)) {
            this._redo(cast resourceOrSource);
            return;
        }
        this._redo(this.getUriComparisonKey(cast resourceOrSource));
    }

    function _redo(strResource:String):Void {
        if (!this._editStacks.exists(strResource)) {
            return;
        }

        final editStack = this._editStacks.get(strResource);
        final element = editStack.getClosestFutureElement();
        if (element == null) {
            return;
        }

        if (element.groupId != 0) {
            // this element is a part of a group, we need to make sure redoing in a group is in order
            final matchedElement = this._findClosestRedoElementInGroup(element.groupId);
            final matchedStrResource = _matchedStrResource;
            if (element != matchedElement && matchedStrResource != null) {
                // there is an element in the same group that should be redone before this one
                this._redo(matchedStrResource);
                return;
            }
        }

        this._resourceRedo(editStack, element);
    }

}
