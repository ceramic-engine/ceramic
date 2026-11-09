// Ported from vscode src/vs/editor/contrib/inlineCompletions/browser/utils.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.inlineCompletions.view;

import cityscape.base.common.Lifecycle;
import cityscape.base.common.Observable;
import cityscape.base.common.observableInternal.Base;
import cityscape.common.Model.IModelDeltaDecoration;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.view.EditorBrowser.ICodeEditor;

class ColumnRange {

    public final startColumn:Int;
    public final endColumnExclusive:Int;

    public function new(startColumn:Int, endColumnExclusive:Int) {
        if (startColumn > endColumnExclusive) {
            throw 'startColumn ' + startColumn + ' cannot be after endColumnExclusive ' + endColumnExclusive;
        }
        this.startColumn = startColumn;
        this.endColumnExclusive = endColumnExclusive;
    }

    public function toRange(lineNumber:Int):Range {
        return new Range(lineNumber, this.startColumn, lineNumber, this.endColumnExclusive);
    }

    public function equals(other:ColumnRange):Bool {
        return this.startColumn == other.startColumn
            && this.endColumnExclusive == other.endColumnExclusive;
    }

}

/**
 * Module functions of utils.ts.
 */
class Utils {

    public static function applyObservableDecorations(editor:ICodeEditor, decorations:IObservable<Array<IModelDeltaDecoration>>):IDisposable {
        final d = new DisposableStore();
        final decorationsCollection = editor.createDecorationsCollection();
        d.add(Observable.autorun(reader -> {
            final d = decorations.read(reader);
            decorationsCollection.set(d);
        }));
        d.add(Lifecycle.toDisposable(() -> {
            decorationsCollection.clear();
        }));
        return d;
    }

    public static function addPositions(pos1:Position, pos2:Position):Position {
        return new Position(pos1.lineNumber + pos2.lineNumber - 1, pos2.lineNumber == 1 ? pos1.column + pos2.column - 1 : pos2.column);
    }

    public static function subtractPositions(pos1:Position, pos2:Position):Position {
        return new Position(pos1.lineNumber - pos2.lineNumber + 1, pos1.lineNumber - pos2.lineNumber == 0 ? pos1.column - pos2.column + 1 : pos1.column);
    }

}
