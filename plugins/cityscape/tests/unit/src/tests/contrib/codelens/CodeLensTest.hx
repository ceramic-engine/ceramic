// New code for Cityscape (not a port): the code lens contribution with a
// provider (vscode has no tests in contrib/codelens). The expected values
// follow Monaco's code (codelens.ts, codeLensCache.ts, codelensWidget.ts,
// codelensController.ts: the zone heights of `_getLayoutInfo`).
package tests.contrib.codelens;

import cityscape.Cityscape;
import cityscape.base.common.Cancellation;
import cityscape.base.common.Event;
import cityscape.base.common.Uri;
import cityscape.common.Languages;
import cityscape.common.Model;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.contrib.codelens.view.CodeLensCache;
import cityscape.contrib.codelens.view.CodeLensController;
import cityscape.contrib.codelens.view.CodeLensModel;
import cityscape.contrib.codelens.view.CodeLensWidget;
import cityscape.platform.storage.common.Storage;
import cityscape.view.EditorBrowser;
import testing.TestCase;
import testing.TestCodeEditor;

/**
 * A code lens provider giving lenses without commands, resolved to
 * "N references" and "Run" (and counting the requests).
 */
class TestCodeLensProvider implements CodeLensProvider {

    public var onDidChange(default, null):Null<Event<CodeLensProvider>> = null;
    public var resolveCodeLens(default, null):Null<(model:ITextModel, codeLens:CodeLens, token:CancellationToken, resolve:(codeLens:Null<CodeLens>) -> Void) -> Void>;

    public var requests = 0;
    public var resolves = 0;
    public final lines:Array<Int>;

    public function new(lines:Array<Int>) {
        this.lines = lines;
        this.resolveCodeLens = (model, codeLens, token, resolve) -> {
            resolves++;
            final run = codeLens.id == 'run';
            resolve({
                range: codeLens.range,
                id: codeLens.id,
                command: run ? {id: 'test.run', title: "$(play) Run", arguments: [codeLens.range.startLineNumber]} : {id: 'test.references', title: '3 references'}
            });
        };
    }

    public function provideCodeLenses(model:ITextModel, token:CancellationToken, resolve:(lenses:Null<CodeLensList>) -> Void):Void {
        requests++;
        final lenses:Array<CodeLens> = [];
        for (line in lines) {
            lenses.push({range: new Range(line, 1, line, 5), id: 'refs'});
            lenses.push({range: new Range(line, 6, line, 9), id: 'run'});
        }
        resolve({lenses: lenses});
    }

}

class CodeLensTest extends TestCase {

    static final NBSP = String.fromCharCode(0xa0);

    var context:Cityscape;
    var model:ITextModel;
    final editors:Array<TestCodeEditor> = [];

    override public function setup():Void {
        context = new Cityscape();
        context.languageService.registerLanguage({id: 'lenslang'});
        model = context.modelService.createModel('// lenses\nfunction one() {\n}\n\nfunction two() {\n}\n', 'lenslang', Uri.parse('file:///lenses.test'));
    }

    override public function teardown():Void {
        for (editor in editors) {
            editor.dispose();
        }
        editors.resize(0);
        model.dispose();
    }

    function newEditor(?options:cityscape.common.config.EditorOptions.IEditorOptions):TestCodeEditor {
        final editor = new TestCodeEditor(context, cast model, options != null ? options : {fontSize: 14, lineHeight: 19}, context.editorExtensions.getSomeEditorContributions([CodeLensContribution.ID]), {outerWidth: 800, outerHeight: 600});
        editor.getViewModel().setHasFocus(true);
        editors.push(editor);
        return editor;
    }

    function texts(lens:CodeLensWidget):Array<String> {
        return [for (s in lens.getContentWidget().segments) s.text];
    }

    function testZonesAboveTheLensLines() {
        final provider = new TestCodeLensProvider([2, 5]);
        context.registerCodeLensProvider('lenslang', provider);
        final editor = newEditor();
        final contribution = CodeLensContribution.get(editor);
        assertNotNull(contribution);
        contribution._flush();
        assertEquals(1, provider.requests);

        // one widget per line, its zone after the line above
        final lenses = contribution.getLenses();
        assertEquals(2, lenses.length);
        assertEquals(2, lenses[0].getLineNumber());
        assertEquals(5, lenses[1].getLineNumber());
        final whitespaces = editor.getWhitespaces();
        assertEquals(2, whitespaces.length);
        assertEquals(1, whitespaces[0].afterLineNumber);
        assertEquals(4, whitespaces[1].afterLineNumber);
        // the height of `_getLayoutInfo`: font size (14 * .9) | 0 = 12,
        // line height factor max(1.3, 19 / 14), (12 * 19 / 14) | 0 = 16
        assertEquals(16.0, whitespaces[0].height);
        assertEquals(16.0, whitespaces[1].height);
        assertEquals(12.0, contribution.getPaintStyle().fontSize);
        assertEquals(16.0, contribution.getPaintStyle().lineHeight);

        // the line moves down by the zone above it
        assertEquals(19.0 + 16.0, editor.getViewModel().viewLayout.getVerticalOffsetForLineNumber(2));
    }

    function testLensesAreResolvedAndSeparated() {
        final provider = new TestCodeLensProvider([2, 5]);
        context.registerCodeLensProvider('lenslang', provider);
        final editor = newEditor();
        final contribution = CodeLensContribution.get(editor);
        contribution._flush();
        assertEquals(4, provider.resolves);
        final lenses = contribution.getLenses();
        // ` | ` between the lenses, the `$(play)` codicon of the title a part
        // of its link
        assertDeepEquals(['3 references', NBSP + '|' + NBSP, '', ' Run'], texts(lenses[0]));
        assertDeepEquals(['3 references', NBSP + '|' + NBSP, '', ' Run'], texts(lenses[1]));
        final segments = lenses[0].getContentWidget().segments;
        assertNotNull(segments[0].linkId);
        assertNull(segments[0].icon);
        assertNull(segments[1].linkId);
        assertEquals('play', segments[2].icon);
        assertEquals(segments[2].linkId, segments[3].linkId);
        assertEquals('test.run', lenses[0].getCommand(segments[2].linkId).id);
        // the codicon is one em of the lenses' font wide (estimated widths
        // before painting)
        final widget = lenses[0].getContentWidget();
        widget.linkAt(0, contribution.getPaintStyle());
        assertEquals(12.0, segments[2].width);
        assertEquals(segments[2].x + 12.0, segments[3].x);

        // the model of the contribution has the resolved commands
        var lensModel:Null<CodeLensModel> = null;
        contribution.getModel(m -> lensModel = m);
        assertNotNull(lensModel);
        assertEquals(4, lensModel.lenses.length);
        assertEquals('3 references', lensModel.lenses[0].symbol.command.title);
    }

    function testLensesFollowTheEdits() {
        context.registerCodeLensProvider('lenslang', new TestCodeLensProvider([2, 5]));
        final editor = newEditor();
        final contribution = CodeLensContribution.get(editor);
        contribution._flush();
        editor.executeEdits('test', [{range: new Range(1, 1, 1, 1), text: 'x\n'}]);
        final lenses = contribution.getLenses();
        assertEquals(3, lenses[0].getLineNumber());
        assertEquals(2, editor.getWhitespaces()[0].afterLineNumber);
    }

    function testClickOnALensRunsItsCommand() {
        final runs:Array<Array<Any>> = [];
        context.commandsRegistry.registerCommandHandler('test.run', (accessor, args) -> runs.push(args));
        context.commandsRegistry.registerCommandHandler('test.references', (accessor, args) -> runs.push(['references']));
        context.registerCodeLensProvider('lenslang', new TestCodeLensProvider([2, 5]));
        final editor = newEditor();
        final contribution = CodeLensContribution.get(editor);
        contribution._flush();
        final lens = contribution.getLenses()[1];

        // the zone above line 5; without a view, the lenses start at the
        // content left (column 1) with the typical character width at 12 px
        final contentLeft = editor.getLayoutInfo().contentLeft;
        final charWidth = editor.getOption(cityscape.common.config.EditorOptions.EditorOption.fontInfo).typicalHalfwidthCharacterWidth * 12 / 14;
        function click(x:Float):Void {
            final position = new Position(5, 1);
            final target = new MouseTarget(MouseTargetType.CONTENT_VIEW_ZONE, position, 1, Range.fromPositions(position, position));
            target.viewZoneData = {
                viewZoneId: lens.getViewZoneId(),
                positionBefore: new Position(4, 1),
                positionAfter: position,
                position: position,
                afterLineNumber: 4
            };
            final data = new EditorMouseEventData(true, false, false, false, false, false, false, 1, x, 0);
            @:privateAccess editor._fireMouseMove(new EditorMouseEvent(data, target));
            @:privateAccess editor._fireMouseDown(new EditorMouseEvent(data, target));
        }
        // "Run" after "3 references" and " | " (15 characters)
        click(contentLeft + charWidth * 16);
        assertEquals(1, runs.length);
        assertEquals(5, (runs[0][0] : Int));
        // the link under the mouse is the hovered one
        assertEquals(lens.getContentWidget().segments[2].linkId, contribution.getPaintStyle().hoveredLinkId);
        // "3 references"
        click(contentLeft + charWidth * 2);
        assertEquals(2, runs.length);
        assertEquals('references', (runs[1][0] : String));
        // the separator is no link
        click(contentLeft + charWidth * 13);
        assertEquals(2, runs.length);
        assertNull(contribution.getPaintStyle().hoveredLinkId);
    }

    function testLensesAreCachedPerModel() {
        final provider = new TestCodeLensProvider([2, 5]);
        context.registerCodeLensProvider('lenslang', provider);
        final other = context.modelService.createModel('other\n', 'lenslang', Uri.parse('file:///other.test'));
        final editor = newEditor();
        final contribution = CodeLensContribution.get(editor);
        contribution._flush();
        final cached = context.codeLensCache.get(model);
        assertNotNull(cached);
        assertEquals(4, cached.lenses.length);
        // the cache keeps the titles without the command ids
        assertEquals('', cached.lenses[0].symbol.command.id);
        assertEquals('3 references', cached.lenses[0].symbol.command.title);

        editor.setModel(cast other);
        contribution._flush();
        editor.setModel(cast model);
        // the cached lenses show before the providers answer
        final requests = provider.requests;
        final lenses = contribution.getLenses();
        assertEquals(2, lenses.length);
        assertDeepEquals(['3 references', NBSP + '|' + NBSP, '', ' Run'], texts(lenses[0]));
        assertNull(lenses[0].getContentWidget().segments[0].linkId);
        assertEquals(requests, provider.requests);
        contribution._flush();
        assertEquals(requests + 1, provider.requests);
        assertDeepEquals(['3 references', NBSP + '|' + NBSP, '', ' Run'], texts(contribution.getLenses()[0]));
        other.dispose();
    }

    function testCacheIsStored() {
        final storage = new InMemoryStorageService();
        final cache = new CodeLensCache(storage);
        final lensModel = new CodeLensModel();
        lensModel.add({lenses: [{range: new Range(2, 1, 2, 5), command: {id: 'x', title: 'T'}}, {range: new Range(2, 6, 2, 9)}, {range: new Range(5, 1, 5, 2)}]}, new TestCodeLensProvider([]));
        cache.put(model, lensModel);
        cache.saveState();
        final restored = new CodeLensCache(storage);
        final data = restored.get(model);
        assertNotNull(data);
        // the lines of the lenses, with a range of 10 columns
        assertEquals(2, data.lenses.length);
        assertTrue(Range.lift(data.lenses[0].symbol.range).equalsRange(new Range(2, 1, 2, 11)));
        assertTrue(Range.lift(data.lenses[1].symbol.range).equalsRange(new Range(5, 1, 5, 11)));
        assertNull(data.lenses[0].symbol.command);
    }

    function testCodeLensOption() {
        final provider = new TestCodeLensProvider([2, 5]);
        context.registerCodeLensProvider('lenslang', provider);
        final editor = newEditor({fontSize: 14, lineHeight: 19, codeLens: false});
        final contribution = CodeLensContribution.get(editor);
        contribution._flush();
        assertEquals(0, provider.requests);
        assertEquals(0, contribution.getLenses().length);
        editor.updateOptions({codeLens: true, codeLensFontSize: 10});
        contribution._flush();
        assertEquals(2, contribution.getLenses().length);
        // codeLensFontSize 10: (10 * 19 / 14) | 0 = 13
        assertEquals(13.0, editor.getWhitespaces()[0].height);
        editor.updateOptions({codeLensFontSize: 4});
        // below 5: 90% of the editor's font size
        assertEquals(16.0, editor.getWhitespaces()[0].height);
    }

    /**
     * iconLabels.ts `renderLabelWithIcons`: texts and codicons.
     */
    function testRenderLabelWithIcons() {
        final parts = (text:String) -> [for (p in cityscape.view.Codicons.parseLabelWithIcons(text)) switch p {
            case LabelText(t): 'text:' + t;
            case LabelIcon(id): 'icon:' + id;
        }];
        assertDeepEquals(['icon:play', 'text: Run'], parts("$(play) Run"));
        // the modifier (spinning) is dropped
        assertDeepEquals(['icon:debug-alt', 'text: Debug'], parts("$(debug-alt~spin) Debug"));
        // escaped: the text `$(play)`
        assertDeepEquals(['text:$(play) Run'], parts("\\$(play) Run"));
        // not an icon name
        assertDeepEquals(['text:Price $(5 off)'], parts("Price $(5 off)"));
        assertDeepEquals(['text:a ', 'icon:check', 'icon:error', 'text: b'], parts("a $(check)$(error) b"));
        assertDeepEquals([], parts(''));
    }

}
