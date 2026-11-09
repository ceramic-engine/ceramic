// Ported from vscode src/vs/editor/test/common/model/modelInjectedText.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.model;

// Classes of this module:
// - EditorModelInjectedTextEventsTest

import cityscape.common.TextModelEvents;
import cityscape.common.core.EditOperation;
import cityscape.common.core.Range;
import tests.TestTextModel.createTextModel;
import testing.TestCase;

/**
 * suite('Editor Model - Injected Text Events')
 */
class EditorModelInjectedTextEventsTest extends TestCase {

    /**
     * JS `array.splice(0)`: removes and returns all the elements.
     */
    static function spliceAll(array:Array<Any>):Array<Any> {
        return array.splice(0, array.length);
    }

    function testBasic():Void {
        final thisModel = createTextModel('First Line\nSecond Line');

        final recordedChanges = new Array<Any>();

        final listener = thisModel.onDidChangeContentOrInjectedText((e) -> {
            final changes:Array<ModelRawChange> = (Std.isOfType(e, InternalModelContentChangeEvent)
                ? (cast e : InternalModelContentChangeEvent).rawContentChangedEvent.changes
                : cast (cast e : ModelInjectedTextChangedEvent).changes);
            for (change in changes) {
                recordedChanges.push(mapChange(change));
            }
        });

        // Initial decoration
        var decorations = thisModel.deltaDecorations([], [{
            options: {
                after: { content: 'injected1' },
                description: 'test1',
                showIfCollapsed: true
            },
            range: new Range(1, 1, 1, 1),
        }]);
        assertDeepEquals(spliceAll(recordedChanges), ([
            {
                kind: 'lineChanged',
                line: '[injected1]First Line',
                lineNumber: 1,
            }
        ] : Array<Any>));

        // Decoration change
        decorations = thisModel.deltaDecorations(decorations, [{
            options: {
                after: { content: 'injected1' },
                description: 'test1',
                showIfCollapsed: true
            },
            range: new Range(2, 1, 2, 1),
        }, {
            options: {
                after: { content: 'injected2' },
                description: 'test2',
                showIfCollapsed: true
            },
            range: new Range(2, 2, 2, 2),
        }]);
        assertDeepEquals(spliceAll(recordedChanges), ([
            {
                kind: 'lineChanged',
                line: 'First Line',
                lineNumber: 1,
            },
            {
                kind: 'lineChanged',
                line: '[injected1]S[injected2]econd Line',
                lineNumber: 2,
            }
        ] : Array<Any>));

        // Simple Insert
        thisModel.applyEdits([EditOperation.replace(new Range(2, 2, 2, 2), 'Hello')]);
        assertDeepEquals(spliceAll(recordedChanges), ([
            {
                kind: 'lineChanged',
                line: '[injected1]SHello[injected2]econd Line',
                lineNumber: 2,
            }
        ] : Array<Any>));

        // Multi-Line Insert
        thisModel.pushEditOperations(null, [EditOperation.replace(new Range(2, 2, 2, 2), '\n\n\n')], null);
        assertDeepEquals(thisModel.getAllDecorations(null).map(d -> ({ description: d.options.description, range: d.range.toString() })), [{
            description: 'test1',
            range: '[2,1 -> 2,1]'
        },
        {
            description: 'test2',
            range: '[2,2 -> 5,6]'
        }]);
        assertDeepEquals(spliceAll(recordedChanges), ([
            {
                kind: 'lineChanged',
                line: '[injected1]S',
                lineNumber: 2,
            },
            {
                fromLineNumber: 3,
                kind: 'linesInserted',
                lines: [
                    '',
                    '',
                    'Hello[injected2]econd Line',
                ]
            }
        ] : Array<Any>));


        // Multi-Line Replace
        thisModel.pushEditOperations(null, [EditOperation.replace(new Range(3, 1, 5, 1), '\n\n\n\n\n\n\n\n\n\n\n\n\n')], null);
        assertDeepEquals(spliceAll(recordedChanges), ([
            {
                kind: 'lineChanged',
                line: '',
                lineNumber: 5,
            },
            {
                kind: 'lineChanged',
                line: '',
                lineNumber: 4,
            },
            {
                kind: 'lineChanged',
                line: '',
                lineNumber: 3,
            },
            {
                fromLineNumber: 6,
                kind: 'linesInserted',
                lines: [
                    '',
                    '',
                    '',
                    '',
                    '',
                    '',
                    '',
                    '',
                    '',
                    '',
                    'Hello[injected2]econd Line',
                ]
            }
        ] : Array<Any>));

        // Multi-Line Replace undo
        // vscode: assert.strictEqual(thisModel.undo(), undefined);
        // TextModel.undo() returns Void here (vscode returns void | Promise<void>).
        thisModel.undo();
        assertDeepEquals(spliceAll(recordedChanges), ([
            {
                kind: 'lineChanged',
                line: '[injected1]SHello[injected2]econd Line',
                lineNumber: 2,
            },
            {
                kind: 'linesDeleted',
            }
        ] : Array<Any>));

        // store disposal (ensureNoDisposablesAreLeakedInTestSuite's store)
        listener.dispose();
        thisModel.dispose();
    }

    function mapChange(change:ModelRawChange):Any {
        if (change.changeType == RawContentChangedType.LineChanged) {
            final lineChanged:ModelRawLineChanged = cast change;
            // vscode calls `(change.injectedText || []).every(e => { assert... })`: the callback
            // returns undefined, so `every` stops after the first element. Same here.
            final injectedText = (lineChanged.injectedText != null ? lineChanged.injectedText : []);
            for (e in injectedText) {
                assertDeepEquals(e.lineNumber, lineChanged.lineNumber);
                break;
            }

            return {
                kind: 'lineChanged',
                line: getDetail(lineChanged.detail, lineChanged.injectedText),
                lineNumber: lineChanged.lineNumber,
            };
        }
        else if (change.changeType == RawContentChangedType.LinesInserted) {
            final linesInserted:ModelRawLinesInserted = cast change;
            return {
                kind: 'linesInserted',
                lines: [for (idx in 0...linesInserted.detail.length) getDetail(linesInserted.detail[idx], linesInserted.injectedTexts[idx])],
                fromLineNumber: linesInserted.fromLineNumber
            };
        }
        else if (change.changeType == RawContentChangedType.LinesDeleted) {
            return {
                kind: 'linesDeleted',
            };
        }
        else if (change.changeType == RawContentChangedType.EOLChanged) {
            return {
                kind: 'eolChanged'
            };
        }
        else if (change.changeType == RawContentChangedType.Flush) {
            return {
                kind: 'flush'
            };
        }
        return { kind: 'unknown' };
    }

    static function getDetail(line:String, injectedTexts:Null<Array<LineInjectedText>>):String {
        return LineInjectedText.applyInjectedText(line, (injectedTexts != null ? injectedTexts : []).map(t -> t.withText('[${t.options.content}]')));
    }

}
