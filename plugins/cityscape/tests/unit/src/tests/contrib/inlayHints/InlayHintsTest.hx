// New code for Cityscape (not a port): the inlay hints contribution with a
// provider (vscode has no tests in contrib/inlayHints). The expected values
// follow Monaco's code (inlayHints.ts, inlayHintsController.ts,
// inlayHintsHover.ts, the `EditorInlayHints` validation of editorOptions.ts).
package tests.contrib.inlayHints;

import cityscape.Cityscape;
import cityscape.base.common.Cancellation;
import cityscape.base.common.Event;
import cityscape.base.common.HtmlContent.IMarkdownString;
import cityscape.base.common.Platform;
import cityscape.base.common.Uri;
import cityscape.common.Languages;
import cityscape.common.Model;
import cityscape.common.config.EditorInlayHintsCodeLensOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.languages.LanguageKinds.InlayHintKind;
import cityscape.common.model.TextModel;
import cityscape.contrib.hover.view.HoverTypes;
import cityscape.contrib.hover.view.MarkdownHoverParticipant;
import cityscape.contrib.inlayHints.view.InlayHints;
import cityscape.contrib.inlayHints.view.InlayHintsController;
import cityscape.contrib.inlayHints.view.InlayHintsHover;
import cityscape.view.EditorBrowser;
import testing.TestCase;
import testing.TestCodeEditor;

/**
 * An inlay hints provider giving fixed hints (and counting the requests).
 */
class TestInlayHintsProvider implements InlayHintsProvider {

    public var displayName(default, null):Null<String> = 'test';
    public var onDidChangeInlayHints(default, null):Null<VoidEvent> = null;
    public var resolveInlayHint(default, null):Null<(hint:InlayHint, token:CancellationToken, resolve:(hint:Null<InlayHint>) -> Void) -> Void> = null;

    public var hints:() -> Array<InlayHint>;
    public var requests = 0;
    public var resolves = 0;

    public function new(hints:() -> Array<InlayHint>, ?resolveTooltip:String) {
        this.hints = hints;
        if (resolveTooltip != null) {
            this.resolveInlayHint = (hint, token, resolve) -> {
                resolves++;
                resolve({label: hint.label, position: hint.position, tooltip: resolveTooltip});
            };
        }
    }

    public function provideInlayHints(model:ITextModel, range:Range, token:CancellationToken, resolve:(hints:Null<InlayHintList>) -> Void):Void {
        requests++;
        resolve({hints: [for (h in hints()) if (range.containsPosition(Position.lift(h.position))) h]});
    }

}

private class LocationDefinitionProvider implements DefinitionProvider {
    final asked:Array<{line:Int, column:Int}>;
    final target:LocationLink;
    public function new(asked:Array<{line:Int, column:Int}>, target:LocationLink) {
        this.asked = asked;
        this.target = target;
    }
    public function provideDefinition(model:ITextModel, position:Position, token:CancellationToken, resolve:(definition:Null<Definition>) -> Void):Void {
        asked.push({line: position.lineNumber, column: position.column});
        resolve([target]);
    }
}

class InlayHintsTest extends TestCase {

    static final HAIR_SPACE = String.fromCharCode(0x200a);
    static final NBSP = String.fromCharCode(0xa0);

    var context:Cityscape;
    var model:ITextModel;
    final editors:Array<TestCodeEditor> = [];

    override public function setup():Void {
        context = new Cityscape();
        context.languageService.registerLanguage({id: 'hintlang'});
        model = context.modelService.createModel('let value = 1;\nfoo(1, 2);\n', 'hintlang', Uri.parse('file:///hints.test'));
    }

    override public function teardown():Void {
        for (editor in editors) {
            editor.dispose();
        }
        editors.resize(0);
        model.dispose();
    }

    function newEditor(?options:cityscape.common.config.EditorOptions.IEditorOptions):TestCodeEditor {
        final editor = new TestCodeEditor(context, cast model, options != null ? options : {}, context.editorExtensions.getSomeEditorContributions([InlayHintsController.ID]), {outerWidth: 800, outerHeight: 600});
        editor.getViewModel().setHasFocus(true);
        editors.push(editor);
        return editor;
    }

    static function typeAndParameterHints():Array<InlayHint> {
        return [
            {label: ': number', position: {lineNumber: 1, column: 10}, kind: InlayHintKind.Type, paddingLeft: true, tooltip: 'The type'},
            {label: [
                {label: 'a', location: {uri: Uri.parse('file:///hints.test'), range: new Range(1, 5, 1, 10)}, tooltip: 'Parameter a'},
                {label: ':'}
            ], position: {lineNumber: 2, column: 5}, kind: InlayHintKind.Parameter, paddingRight: true}
        ];
    }

    function hintDecorations(lineNumber:Int):Array<ModelDecorationOptions> {
        final result:Array<ModelDecorationOptions> = [];
        for (d in model.getLineDecorations(lineNumber)) {
            if (d.options.description == 'InlayHint') {
                result.push(cast d.options);
            }
        }
        return result;
    }

    function testDecorationsShowTheHints() {
        final provider = new TestInlayHintsProvider(typeAndParameterHints);
        context.registerInlayHintsProvider('hintlang', provider);
        final editor = newEditor();
        final controller = InlayHintsController.get(editor);
        assertNotNull(controller);
        assertTrue(controller._isScheduled());
        controller._flush();
        assertEquals(1, provider.requests);

        // ': number' after "value" (the word before the position): the
        // leading spacer, then the label, both after the range 1:5-1:10
        final line1 = hintDecorations(1);
        assertEquals(2, line1.length);
        assertNull(line1[0].before);
        assertEquals(HAIR_SPACE, line1[0].after.content);
        assertEquals(':' + NBSP + 'number', line1[1].after.content);
        final ranges1 = [for (d in model.getLineDecorations(1)) if (d.options.description == 'InlayHint') d.range];
        assertTrue(ranges1[0].equalsRange(new Range(1, 5, 1, 10)));
        assertEquals('let value' + HAIR_SPACE + ':' + NBSP + 'number = 1;', editor.getViewModel().getLineContent(1));

        // 'a' and ':' before "1" (the word at the position), then the trailing spacer
        final line2 = hintDecorations(2);
        assertEquals(3, line2.length);
        assertEquals('a', line2[0].before.content);
        assertEquals(':', line2[1].before.content);
        assertEquals(HAIR_SPACE, line2[2].before.content);
        assertEquals('foo(a:' + HAIR_SPACE + '1, 2);', editor.getViewModel().getLineContent(2));

        // the label parts carry their part (Monaco's `RenderedInlayHintLabelPart`)
        final part:RenderedInlayHintLabelPart = line2[0].before.attachedData;
        assertEquals(0, part.index);
        assertEquals('a', part.part.label);
        assertNull(line1[0].after.attachedData);

        // the typed style of the parts: the kind's colors
        assertEquals('editorInlayHint.typeForeground', (cast line1[1].after.inlineStyle.color : {id:String}).id);
        assertEquals('editorInlayHint.parameterBackground', (cast line2[0].before.inlineStyle.background : {id:String}).id);
        // the spacers are `fontSize / 3` wide
        assertEquals(Std.int(14 / 3), Std.int(line1[0].after.inlineStyle.width));
        assertEquals(1, controller.getInlayHintsForLine(2).length);
    }

    function testPaddingOption() {
        context.registerInlayHintsProvider('hintlang', new TestInlayHintsProvider(typeAndParameterHints));
        final editor = newEditor({fontSize: 14, inlayHints: {padding: true}});
        InlayHintsController.get(editor)._flush();
        final line2 = hintDecorations(2);
        // `padding: 1px 3px` on the outer sides, `border-radius: 3px`
        final first = line2[0].before.inlineStyle;
        final last = line2[1].before.inlineStyle;
        assertEquals(1.0, first.paddingTop);
        assertEquals(1.0, first.paddingBottom);
        assertEquals(3.0, first.paddingLeft);
        assertNull(first.paddingRight);
        assertNull(last.paddingLeft);
        assertEquals(3.0, last.paddingRight);
        assertEquals(3.0, first.borderRadius);
        // without padding: no box padding nor radius
        editor.updateOptions({inlayHints: {padding: false}});
        InlayHintsController.get(editor)._flush();
        assertNull(hintDecorations(2)[0].before.inlineStyle.paddingLeft);
        assertNull(hintDecorations(2)[0].before.inlineStyle.borderRadius);
    }

    function testLongLabelsAreTruncated() {
        final long = [for (_ in 0...50) 'x'].join('');
        context.registerInlayHintsProvider('hintlang', new TestInlayHintsProvider(() -> [{label: long, position: {lineNumber: 1, column: 10}}]));
        final editor = newEditor();
        InlayHintsController.get(editor)._flush();
        final line1 = hintDecorations(1);
        // _MAX_LABEL_LEN is 43: 50 - 7 characters and an ellipsis
        assertEquals([for (_ in 0...43) 'x'].join('') + String.fromCharCode(0x2026), line1[0].after.content);
    }

    function testHintsAreCachedPerModel() {
        final provider = new TestInlayHintsProvider(typeAndParameterHints);
        context.registerInlayHintsProvider('hintlang', provider);
        final other = context.modelService.createModel('other\n', 'hintlang', Uri.parse('file:///other.test'));
        final editor = newEditor();
        final controller = InlayHintsController.get(editor);
        controller._flush();
        assertEquals(1, provider.requests);
        assertNotNull(context.inlayHintsCache.get(model));

        editor.setModel(cast other);
        controller._flush();

        // back to the model: the cached hints show before the provider answers
        editor.setModel(cast model);
        final requests = provider.requests;
        assertEquals(2, hintDecorations(1).length);
        assertEquals(':' + NBSP + 'number', hintDecorations(1)[1].after.content);
        assertEquals(requests, provider.requests);
        controller._flush();
        assertEquals(requests + 1, provider.requests);
        assertEquals(2, hintDecorations(1).length);
        other.dispose();
    }

    function testEnabledModes() {
        final provider = new TestInlayHintsProvider(typeAndParameterHints);
        context.registerInlayHintsProvider('hintlang', provider);

        final editor = newEditor({inlayHints: {enabled: 'off'}});
        final controller = InlayHintsController.get(editor);
        controller._flush();
        assertEquals(0, provider.requests);
        assertEquals(0, hintDecorations(1).length);

        // offUnlessPressed: decorations without text until Ctrl+Alt is held
        editor.updateOptions({inlayHints: {enabled: 'offUnlessPressed'}});
        controller._flush();
        assertEquals(1, provider.requests);
        assertEquals(2, hintDecorations(1).length);
        assertNull(hintDecorations(1)[1].after);
        assertEquals('let value = 1;', editor.getViewModel().getLineContent(1));

        final key = (ctrl:Bool, alt:Bool) -> ({ctrlKey: ctrl, shiftKey: false, altKey: alt, metaKey: false, altGraphKey: false, keyCode: cityscape.base.common.KeyCodes.KeyCode.Alt, code: 'AltLeft'} : cityscape.platform.keybinding.common.Keybinding.IKeyboardEvent);
        @:privateAccess editor._fireKeyDown(key(true, true));
        assertEquals(':' + NBSP + 'number', hintDecorations(1)[1].after.content);
        @:privateAccess editor._fireKeyUp(key(true, false));
        assertNull(hintDecorations(1)[1].after);

        // onUnlessPressed: the other way round
        editor.updateOptions({inlayHints: {enabled: 'onUnlessPressed'}});
        controller._flush();
        assertEquals(':' + NBSP + 'number', hintDecorations(1)[1].after.content);
        @:privateAccess editor._fireKeyDown(key(true, true));
        assertNull(hintDecorations(1)[1].after);

        // a boolean is turned into 'on' or 'off'
        editor.updateOptions({inlayHints: {enabled: true}});
        assertEquals('on', editor.getOption(cityscape.common.config.EditorOptions.EditorOption.inlayHints).enabled);
    }

    function testOptionValidation() {
        final option = new EditorInlayHints();
        assertDeepEquals({enabled: 'on', fontSize: 0, fontFamily: '', padding: false}, option.validate(null));
        assertDeepEquals({enabled: 'on', fontSize: 0, fontFamily: '', padding: false}, option.validate('on'));
        assertDeepEquals({enabled: 'off', fontSize: 100, fontFamily: 'Menlo', padding: true}, option.validate({enabled: false, fontSize: 200, fontFamily: 'Menlo', padding: true}));
        assertDeepEquals({enabled: 'on', fontSize: 12, fontFamily: '', padding: false}, option.validate({enabled: 'sometimes', fontSize: '12.7', fontFamily: 3}));
        assertDeepEquals({enabled: 'offUnlessPressed', fontSize: 0, fontFamily: '', padding: false}, option.validate({enabled: 'offUnlessPressed', fontSize: -4}));
    }

    /**
     * A mouse event on the view column `viewColumn` of line `lineNumber`
     * (its injected text, like the view's hit test).
     */
    function textEvent(editor:TestCodeEditor, lineNumber:Int, viewColumn:Int, modelColumn:Int, trigger:Bool, clickCount:Int = 1):EditorMouseEvent {
        final position = new Position(lineNumber, modelColumn);
        final target = new MouseTarget(MouseTargetType.CONTENT_TEXT, position, viewColumn, Range.fromPositions(position, position));
        target.injectedText = editor.getViewModel().getInjectedTextAt(new Position(lineNumber, viewColumn));
        final mac = Platform.isMacintosh;
        // the link modifier of `multiCursorModifier: 'alt'`: Cmd on macOS, Ctrl elsewhere
        final data = new EditorMouseEventData(true, false, false, trigger && !mac, false, false, trigger && mac, clickCount, 50, 10);
        return new EditorMouseEvent(data, target);
    }

    function testCmdClickOnACommandPartRunsTheCommand() {
        final runs:Array<Array<Any>> = [];
        context.commandsRegistry.registerCommandHandler('test.hintCommand', (accessor, args) -> runs.push(args));
        context.registerInlayHintsProvider('hintlang', new TestInlayHintsProvider(() -> [
            {label: [{label: 'run', command: {id: 'test.hintCommand', title: 'Run it', arguments: [42]}}], position: {lineNumber: 2, column: 5}}
        ]));
        final editor = newEditor();
        InlayHintsController.get(editor)._flush();
        assertEquals('foo(run1, 2);', editor.getViewModel().getLineContent(2));

        // view column 6 is inside "run" (columns 5 to 7)
        final e = textEvent(editor, 2, 6, 5, true);
        assertNotNull(InlayHintsController.labelPartOf(e.target));
        @:privateAccess editor._fireMouseMove(e);
        // the active part is underlined, in the active link color with the modifier
        final style = hintDecorations(2)[0].before.inlineStyle;
        assertNotNull(style.underline);
        assertEquals('editorLink.activeForeground', (cast style.color : {id:String}).id);
        @:privateAccess editor._fireMouseDown(e);
        @:privateAccess editor._fireMouseUp(e);
        assertEquals(1, runs.length);
        assertEquals(42, (runs[0][0] : Int));

        // without the modifier the click does nothing
        final plain = textEvent(editor, 2, 6, 5, false);
        @:privateAccess editor._fireMouseDown(plain);
        @:privateAccess editor._fireMouseUp(plain);
        assertEquals(1, runs.length);
    }

    function testCmdClickOnALocationPartGoesToItsDefinition() {
        // inlayHintsLocations.ts: Cmd+click runs the definition action at
        // the location of the part (a `SymbolNavigationAnchor`)
        final asked:Array<{line:Int, column:Int}> = [];
        context.registerDefinitionProvider('hintlang', new LocationDefinitionProvider(asked, {uri: model.uri, range: new Range(2, 1, 2, 4)}));
        final opened:Array<{resource:String, line:Int, column:Int}> = [];
        context.codeEditorService.registerCodeEditorOpenHandler((input, source, sideBySide, resolve) -> {
            if (input.options != null && input.options.selection != null) {
                opened.push({resource: input.resource.toString(), line: input.options.selection.startLineNumber, column: input.options.selection.startColumn});
            }
            resolve(source);
        });
        context.registerInlayHintsProvider('hintlang', new TestInlayHintsProvider(typeAndParameterHints));
        final editor = newEditor();
        InlayHintsController.get(editor)._flush();
        // view column 6 is the end of "a" (the location part, columns 5 to 6)
        final e = textEvent(editor, 2, 6, 5, true);
        assertEquals('a', InlayHintsController.labelPartOf(e.target).part.label);
        @:privateAccess editor._fireMouseMove(e);
        @:privateAccess editor._fireMouseDown(e);
        @:privateAccess editor._fireMouseUp(e);
        // the definitions are asked at the start of the location (1, 5)
        assertEquals(1, asked.length);
        assertEquals(1, asked[0].line);
        assertEquals(5, asked[0].column);
        // and the editor goes to the definition
        assertEquals(1, opened.length);
        assertEquals('file:///hints.test', opened[0].resource);
        assertEquals(2, opened[0].line);
        assertEquals(1, opened[0].column);
    }

    function testDoubleClickInsertsTheTextEdits() {
        context.registerInlayHintsProvider('hintlang', new TestInlayHintsProvider(() -> [
            {label: ': number', position: {lineNumber: 1, column: 10}, textEdits: [{range: new Range(1, 10, 1, 10), text: ': number'}]}
        ]));
        final editor = newEditor();
        InlayHintsController.get(editor)._flush();
        // view column 12 is inside ": number" (columns 10 to 17)
        final e = textEvent(editor, 1, 12, 10, false, 2);
        @:privateAccess editor._fireMouseUp(e);
        assertEquals('let value: number = 1;', model.getLineContent(1));
    }

    function hoverParts(editor:TestCodeEditor, e:EditorMouseEvent):Array<MarkdownHover> {
        final participant = new InlayHintsHover(editor);
        assertEquals(6, participant.hoverOrdinal);
        final anchor = participant.suggestHoverAnchor(e);
        assertNotNull(anchor);
        final parts:Array<MarkdownHover> = [];
        var done = false;
        participant.computeAsync(anchor, [], CancellationTokens.None, part -> parts.push(cast part), () -> done = true);
        assertTrue(done);
        haxe.ds.ArraySort.sort(parts, (a, b) -> a.ordinal - b.ordinal);
        return parts;
    }

    function testHoverShowsTheTooltips() {
        context.registerInlayHintsProvider('hintlang', new TestInlayHintsProvider(typeAndParameterHints));
        final editor = newEditor();
        InlayHintsController.get(editor)._flush();

        // the hint's tooltip, as text
        final typeParts = hoverParts(editor, textEvent(editor, 1, 12, 10, false));
        assertEquals(1, typeParts.length);
        assertEquals('The&nbsp;type', typeParts[0].contents[0].value);
        assertEquals(0, typeParts[0].ordinal);

        // the part's tooltip and the "Go to Definition" help of its location
        final parameterParts = hoverParts(editor, textEvent(editor, 2, 6, 5, false));
        assertEquals(2, parameterParts.length);
        assertEquals('Parameter&nbsp;a', parameterParts[0].contents[0].value);
        assertEquals(1, parameterParts[0].ordinal);
        final kb = Platform.isMacintosh ? 'cmd&nbsp;\\+&nbsp;click' : 'ctrl&nbsp;\\+&nbsp;click';
        assertEquals('Go&nbsp;to&nbsp;Definition&nbsp;\\(' + kb + '\\)', parameterParts[1].contents[0].value);
        assertEquals(10000, parameterParts[1].ordinal);

        // a mouse outside the hints has no anchor
        final participant = new InlayHintsHover(editor);
        assertNull(participant.suggestHoverAnchor(textEvent(editor, 1, 2, 2, false)));
    }

    function testHoverOfACommandPart() {
        context.registerInlayHintsProvider('hintlang', new TestInlayHintsProvider(() -> [
            {label: [{label: 'run', command: {id: 'test.hintCommand', title: 'Run it', arguments: [42]}}], position: {lineNumber: 2, column: 5}, textEdits: [{range: new Range(2, 5, 2, 5), text: 'x'}]}
        ]));
        final editor = newEditor();
        InlayHintsController.get(editor)._flush();
        final parts = hoverParts(editor, textEvent(editor, 2, 6, 5, false));
        assertEquals(2, parts.length);
        final kb = Platform.isMacintosh ? 'cmd + click' : 'ctrl + click';
        assertEquals('[Execute Command](command:test.hintCommand?%255B42%255D "Run it") (' + kb + ')', parts[0].contents[0].value);
        assertEquals(true, parts[0].contents[0].isTrusted);
        assertEquals('Double\\-click&nbsp;to&nbsp;insert', parts[1].contents[0].value);
        assertEquals(10001, parts[1].ordinal);

        // the link runs the command
        final runs:Array<Array<Any>> = [];
        context.commandsRegistry.registerCommandHandler('test.hintCommand', (accessor, args) -> runs.push(args));
        assertTrue(InlayHintsHover.runCommandLink(editor, InlayHints.asCommandLink({id: 'test.hintCommand', title: 'Run it', arguments: [42]})));
        assertEquals(1, runs.length);
        assertEquals(42, (runs[0][0] : Int));
    }

    function testResolveBeforeTheHover() {
        final provider = new TestInlayHintsProvider(() -> [{label: 'hint', position: {lineNumber: 1, column: 10}}], 'Resolved');
        context.registerInlayHintsProvider('hintlang', provider);
        final editor = newEditor();
        InlayHintsController.get(editor)._flush();
        assertEquals(0, provider.resolves);
        final parts = hoverParts(editor, textEvent(editor, 1, 11, 10, false));
        assertEquals(1, provider.resolves);
        assertEquals(1, parts.length);
        assertEquals('Resolved', parts[0].contents[0].value);
        // resolved once
        hoverParts(editor, textEvent(editor, 1, 11, 10, false));
        assertEquals(1, provider.resolves);
    }

    function testAsCommandLink() {
        // Monaco encodes the query (JSON, already URI encoded) again when the URI is formatted
        assertEquals('command:my.command', InlayHints.asCommandLink({id: 'my.command', title: 'T'}));
        assertEquals('command:my.command?%255B1%252C%2522a%2522%255D', InlayHints.asCommandLink({id: 'my.command', title: 'T', arguments: [1, 'a']}));
    }

}
