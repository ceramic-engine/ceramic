// Ported from vscode src/vs/editor/browser/widget/diffEditor/utils.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.view.widget.diffEditor;

import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.diff.RangeMapping.DetailedLineRangeMapping;
import cityscape.common.diff.RangeMapping.LineRangeMapping;
import cityscape.view.EditorBrowser;

/**
 * Module functions of utils.ts (the DOM and observable helpers are not
 * ported: their work is done by the diff editor's update methods and
 * `ViewZoneSet`).
 */
class DiffEditorUtils {

    public static function joinCombine<T>(arr1:Array<T>, arr2:Array<T>, keySelector:(val:T) -> Float, combine:(v1:T, v2:T) -> T):Array<T> {
        if (arr1.length == 0) {
            return arr2;
        }
        if (arr2.length == 0) {
            return arr1;
        }

        final result:Array<T> = [];
        var i = 0;
        var j = 0;
        while (i < arr1.length && j < arr2.length) {
            final val1 = arr1[i];
            final val2 = arr2[j];
            final key1 = keySelector(val1);
            final key2 = keySelector(val2);

            if (key1 < key2) {
                result.push(val1);
                i++;
            }
            else if (key1 > key2) {
                result.push(val2);
                j++;
            }
            else {
                result.push(combine(val1, val2));
                i++;
                j++;
            }
        }
        while (i < arr1.length) {
            result.push(arr1[i]);
            i++;
        }
        while (j < arr2.length) {
            result.push(arr2[j]);
            j++;
        }
        return result;
    }

    public static function translatePosition(posInOriginal:Position, mappings:Array<DetailedLineRangeMapping>):Range {
        var mapping:Null<DetailedLineRangeMapping> = null;
        var k = mappings.length - 1;
        while (k >= 0) {
            if (mappings[k].original.startLineNumber <= posInOriginal.lineNumber) {
                mapping = mappings[k];
                break;
            }
            k--;
        }
        if (mapping == null) {
            // No changes before the position
            return Range.fromPositions(posInOriginal);
        }

        if (mapping.original.endLineNumberExclusive <= posInOriginal.lineNumber) {
            final newLineNumber = posInOriginal.lineNumber - mapping.original.endLineNumberExclusive + mapping.modified.endLineNumberExclusive;
            return Range.fromPositions(new Position(newLineNumber, posInOriginal.column));
        }

        if (mapping.innerChanges == null) {
            // Only for legacy algorithm
            return Range.fromPositions(new Position(mapping.modified.startLineNumber, 1));
        }

        var innerMapping:Null<cityscape.common.diff.RangeMapping.RangeMapping> = null;
        k = mapping.innerChanges.length - 1;
        while (k >= 0) {
            if (mapping.innerChanges[k].originalRange.getStartPosition().isBeforeOrEqual(posInOriginal)) {
                innerMapping = mapping.innerChanges[k];
                break;
            }
            k--;
        }
        if (innerMapping == null) {
            final newLineNumber = posInOriginal.lineNumber - mapping.original.startLineNumber + mapping.modified.startLineNumber;
            return Range.fromPositions(new Position(newLineNumber, posInOriginal.column));
        }

        if (innerMapping.originalRange.containsPosition(posInOriginal)) {
            return innerMapping.modifiedRange;
        }
        else {
            final end = innerMapping.originalRange.getEndPosition();
            final target = innerMapping.modifiedRange.getEndPosition();
            // lengthBetweenPositions(end, posInOriginal).addToPosition(target)
            if (end.lineNumber == posInOriginal.lineNumber) {
                return Range.fromPositions(new Position(target.lineNumber, target.column + posInOriginal.column - end.column));
            }
            return Range.fromPositions(new Position(target.lineNumber + posInOriginal.lineNumber - end.lineNumber, posInOriginal.column));
        }
    }

    public static function filterWithPrevious<T>(arr:Array<T>, filter:(cur:T, prev:Null<T>) -> Bool):Array<T> {
        var prev:Null<T> = null;
        return arr.filter(cur -> {
            final result = filter(cur, prev);
            prev = cur;
            return result;
        });
    }

}

/**
 * Monaco's `applyViewZones(editor, viewZones)`: keeps a set of view zones
 * in an editor, replacing them all at each `set` (the zone ids are added to
 * `zoneIds` when given, like Monaco's set of ids to ignore).
 */
class ViewZoneSet {

    final editor:ICodeEditor;
    final lastViewZoneIds:Array<String> = [];
    final zoneIds:Null<Map<String, Bool>>;
    final setIsUpdating:Null<(isUpdatingViewZones:Bool) -> Void>;

    public function new(editor:ICodeEditor, ?setIsUpdating:(isUpdatingViewZones:Bool) -> Void, ?zoneIds:Map<String, Bool>) {
        this.editor = editor;
        this.setIsUpdating = setIsUpdating;
        this.zoneIds = zoneIds;
    }

    public function set(curViewZones:Array<IViewZone>):Void {
        if (setIsUpdating != null) {
            setIsUpdating(true);
        }
        editor.changeViewZones(a -> {
            for (id in lastViewZoneIds) {
                a.removeZone(id);
                if (zoneIds != null) {
                    zoneIds.remove(id);
                }
            }
            lastViewZoneIds.resize(0);

            for (z in curViewZones) {
                final id = a.addZone(z);
                lastViewZoneIds.push(id);
                if (zoneIds != null) {
                    zoneIds.set(id, true);
                }
            }
        });
        if (setIsUpdating != null) {
            setIsUpdating(false);
        }
    }

    /**
     * The ids of the zones of the last `set`, in order.
     */
    public function ids():Array<String> {
        return lastViewZoneIds;
    }

    public function dispose():Void {
        set([]);
    }

}
