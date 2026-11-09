// New code for Cityscape (not a port): the parameter hints and the
// snippets of an editor fed by its providers, through the editor's API and
// keybindings (the widget's content, the context keys, the commands).
package tests.contrib.parameterHints;

import cityscape.Cityscape;
import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.Uri;
import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;
import cityscape.common.config.EditorOptions;
import cityscape.common.config.EditorParameterHintsOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Selection;
import cityscape.contrib.parameterHints.view.ParameterHints;
import cityscape.contrib.parameterHints.view.ParameterHintsWidget;
import cityscape.contrib.parameterHints.view.ProvideSignatureHelp;
import cityscape.contrib.snippet.view.SnippetController2;
import cityscape.contrib.suggest.view.SuggestController;
import cityscape.view.KeyboardEvents;
import testing.TestCase;
import testing.TestCodeEditor;
import testing.TimeTravelScheduler;

/**
 * A signature help provider for `max(...)`: two overloads, the active
 * parameter counted from the commas before the cursor.
 */
private class MaxSignatureHelpProvider implements SignatureHelpProvider {
    public var signatureHelpTriggerCharacters(default, null):Null<Array<String>> = ['('];
    public var signatureHelpRetriggerCharacters(default, null):Null<Array<String>> = [','];
    public final contexts:Array<SignatureHelpContext> = [];

    public function new() {}

    public function provideSignatureHelp(model:ITextModel, position:Position, token:CancellationToken, context:SignatureHelpContext, resolve:(result:Null<SignatureHelpResult>) -> Void):Void {
        contexts.push(context);
        final before = model.getLineContent(position.lineNumber).substring(0, position.column - 1);
        final open = before.lastIndexOf('max(');
        if (open < 0 || before.indexOf(')', open) >= 0) {
            resolve(null);
            return;
        }
        final args = before.substring(open + 4);
        final activeParameter = args.split(',').length - 1;
        resolve({
            value: {
                signatures: [{
                    label: 'max(a: number, b: number): number',
                    documentation: ({value: 'Returns the **larger** of two numbers.'} : cityscape.base.common.HtmlContent.IMarkdownString),
                    parameters: [
                        {label: 'a: number', documentation: 'The first number'},
                        // offsets of `b: number` in the label
                        {label: [15, 24], documentation: 'The second number'}
                    ]
                }, {
                    label: 'max(...values: number[]): number',
                    parameters: [{label: '...values: number[]'}]
                }],
                activeSignature: context.activeSignatureHelp != null ? context.activeSignatureHelp.activeSignature : 0,
                activeParameter: activeParameter
            },
            dispose: () -> {}
        });
    }
}

class ParameterHintsEditorTest extends TestCase {

    var context:Cityscape;
    var model:ITextModel;
    var provider:MaxSignatureHelpProvider;
    final editors:Array<TestCodeEditor> = [];

    override public function setup():Void {
        context = new Cityscape();
        context.languageService.registerLanguage({id: 'maxlang'});
        provider = new MaxSignatureHelpProvider();
        context.registerSignatureHelpProvider('maxlang', provider);
        model = context.modelService.createModel('let x = \n', 'maxlang', Uri.parse('file:///max.txt'));
    }

    override public function teardown():Void {
        for (editor in editors) {
            editor.dispose();
        }
        editors.resize(0);
        model.dispose();
    }

    function newEditor(?options:IEditorOptions):TestCodeEditor {
        final ids = [ParameterHintsController.ID, SnippetController2.ID, SuggestController.ID];
        final editor = new TestCodeEditor(context, cast model, options != null ? options : {}, context.editorExtensions.getSomeEditorContributions(ids));
        editor.getViewModel().setHasFocus(true);
        editors.push(editor);
        // instantiates the `BeforeFirstInteraction` contribution (like a first key event)
        ParameterHintsController.get(editor);
        return editor;
    }

    /** A key pressed in the editor, resolved by the keybindings like the view does. */
    function press(editor:TestCodeEditor, keystroke:String):Bool {
        final keypress = KeyboardEvents.dispatchStringOf(glaze.Keystroke.parse(keystroke));
        return context.codeEditorService.withInvokingEditor(editor, () -> {
            return context.keybindingService.dispatchKeypress(keypress, KeyboardEvents.labelOf(keypress), editor.contextKeyService);
        });
    }

    function contentOf(editor:TestCodeEditor):Null<ParameterHintsContent> {
        final widget = ParameterHintsController.get(editor).getWidget();
        return widget != null ? widget.getContent() : null;
    }

    function testSignatureHelpWidgetOpensOnATriggerCharacter() {
        final editor = newEditor();
        editor.setPosition(new Position(1, 9));
        TimeTravelScheduler.runWithFakedTimers(scheduler -> {
            editor.trigger('keyboard', 'type', {text: 'max('});
            scheduler.runAll();
        });
        assertEquals(1, provider.contexts.length);
        assertEquals(SignatureHelpTriggerKind.TriggerCharacter, provider.contexts[0].triggerKind);
        assertEquals('(', provider.contexts[0].triggerCharacter);
        assertEquals(false, provider.contexts[0].isRetrigger);

        assertEquals(true, ParameterHintsContext.Visible.getValue(editor.contextKeyService));
        assertEquals(true, ParameterHintsContext.MultipleSignatures.getValue(editor.contextKeyService));

        final content = contentOf(editor);
        assertNotNull(content);
        assertEquals('max(a: number, b: number): number', content.label);
        assertTrue(content.multiple);
        assertEquals('1/2', content.overloads);
        // `a: number` found in the label as a word
        assertEquals(4, content.activeStart);
        assertEquals(13, content.activeEnd);
        assertEquals('max(', content.before());
        assertEquals('a: number', content.active());
        assertEquals(', b: number): number', content.after());
        assertTrue(content.hasDocs);
        switch content.parameterDocumentation {
            case Plain(text): assertEquals('The first number', text);
            case _: fail('expected the plain documentation of the parameter');
        }
        switch content.signatureDocumentation {
            case Markdown(md): assertEquals('Returns the **larger** of two numbers.', md.value);
            case _: fail('expected the markdown documentation of the signature');
        }
    }

    function testRetriggerCharacterMovesTheActiveParameter() {
        final editor = newEditor();
        editor.setPosition(new Position(1, 9));
        TimeTravelScheduler.runWithFakedTimers(scheduler -> {
            editor.trigger('keyboard', 'type', {text: 'max('});
            scheduler.runAll();
            editor.trigger('keyboard', 'type', {text: '1,'});
            scheduler.runAll();
        });
        final last = provider.contexts[provider.contexts.length - 1];
        assertEquals(SignatureHelpTriggerKind.TriggerCharacter, last.triggerKind);
        assertEquals(',', last.triggerCharacter);
        assertEquals(true, last.isRetrigger);
        assertNotNull(last.activeSignatureHelp);

        final content = contentOf(editor);
        assertNotNull(content);
        // the label offsets of the second parameter
        assertEquals(15, content.activeStart);
        assertEquals(24, content.activeEnd);
        assertEquals('b: number', content.active());
        switch content.parameterDocumentation {
            case Plain(text): assertEquals('The second number', text);
            case _: fail('expected the plain documentation of the parameter');
        }

        // leaving the call closes the hints
        TimeTravelScheduler.runWithFakedTimers(scheduler -> {
            editor.trigger('keyboard', 'type', {text: '2)'});
            scheduler.runAll();
        });
        assertEquals(false, ParameterHintsContext.Visible.getValue(editor.contextKeyService));
        assertNull(contentOf(editor));
    }

    function testOverloadsWithTheKeyboard() {
        final editor = newEditor();
        editor.setPosition(new Position(1, 9));
        TimeTravelScheduler.runWithFakedTimers(scheduler -> {
            editor.trigger('keyboard', 'type', {text: 'max('});
            scheduler.runAll();
        });
        assertEquals('1/2', contentOf(editor).overloads);

        // showNextParameterHint (Down)
        assertTrue(press(editor, 'down'));
        var content = contentOf(editor);
        assertEquals('2/2', content.overloads);
        assertEquals('max(...values: number[]): number', content.label);
        assertEquals('...values: number[]', content.active());
        assertFalse(content.hasDocs);

        // cycles (parameterHints.cycle is true by default)
        assertTrue(press(editor, 'down'));
        assertEquals('1/2', contentOf(editor).overloads);

        // showPrevParameterHint (Up)
        assertTrue(press(editor, 'up'));
        assertEquals('2/2', contentOf(editor).overloads);
        // the cursor did not move
        assertTrue(editor.getPosition().equals(new Position(1, 13)));

        // closeParameterHints (Escape)
        assertTrue(press(editor, 'escape'));
        assertEquals(false, ParameterHintsContext.Visible.getValue(editor.contextKeyService));
        assertNull(contentOf(editor));

        // without the hints, Down moves the cursor
        assertTrue(press(editor, 'down'));
        assertEquals(2, editor.getPosition().lineNumber);
    }

    function testNoCycleClosesAtTheLastOverload() {
        final editor = newEditor({parameterHints: {cycle: false}});
        editor.setPosition(new Position(1, 9));
        TimeTravelScheduler.runWithFakedTimers(scheduler -> {
            editor.trigger('keyboard', 'type', {text: 'max('});
            scheduler.runAll();
        });
        assertTrue(press(editor, 'down'));
        assertEquals('2/2', contentOf(editor).overloads);
        assertTrue(press(editor, 'down'));
        assertEquals(false, ParameterHintsContext.Visible.getValue(editor.contextKeyService));
    }

    function testTriggerParameterHintsAction() {
        final editor = newEditor();
        model.setValue('max(1, ');
        editor.setPosition(new Position(1, 8));
        TimeTravelScheduler.runWithFakedTimers(scheduler -> {
            editor.trigger('keyboard', 'editor.action.triggerParameterHints', null);
            scheduler.runAll();
        });
        assertEquals(1, provider.contexts.length);
        assertEquals(SignatureHelpTriggerKind.Invoke, provider.contexts[0].triggerKind);
        assertEquals('b: number', contentOf(editor).active());

        // Cmd+Shift+Space (Ctrl+Shift+Space elsewhere) is bound to it
        final kb = context.keybindingService.lookupKeybinding('editor.action.triggerParameterHints');
        assertNotNull(kb);
    }

    function testParameterHintsDisabled() {
        final editor = newEditor({parameterHints: {enabled: false}});
        editor.setPosition(new Position(1, 9));
        TimeTravelScheduler.runWithFakedTimers(scheduler -> {
            editor.trigger('keyboard', 'type', {text: 'max('});
            scheduler.runAll();
        });
        assertEquals(0, provider.contexts.length);
        assertTrue(ParameterHintsContext.Visible.getValue(editor.contextKeyService) != true);
    }

    /**
     * EditorParameterHints.validate (editorOptions.ts): `boolean()` of each
     * field, the defaults for anything else.
     */
    function testParameterHintsOptionValidation() {
        final option = new EditorParameterHints();
        assertDeepEquals({enabled: true, cycle: true}, option.defaultValue);
        assertDeepEquals({enabled: true, cycle: true}, option.validate(null));
        assertDeepEquals({enabled: true, cycle: true}, option.validate('on'));
        assertDeepEquals({enabled: false, cycle: true}, option.validate({enabled: false}));
        assertDeepEquals({enabled: true, cycle: false}, option.validate({cycle: 'false'}));
        assertDeepEquals({enabled: true, cycle: true}, option.validate({enabled: 1}));
        final editor = newEditor({parameterHints: {cycle: false}});
        assertEquals(false, editor.getOption(EditorOption.parameterHints).cycle);
        assertEquals(true, editor.getOption(EditorOption.parameterHints).enabled);
    }

    /**
     * parameterHintsWidget.ts `getParameterLabelOffsets`: the label offsets
     * of a parameter, or its label found as a word of the signature.
     */
    function testParameterLabelOffsets() {
        final signature:SignatureInformation = {
            label: 'f(a, aa, b: a)',
            parameters: [{label: 'a'}, {label: 'aa'}, {label: [9, 13]}, {label: ''}, {label: 'zz'}]
        };
        assertDeepEquals([2, 3], ParameterHintsWidget.getParameterLabelOffsets(signature, 0));
        assertDeepEquals([5, 7], ParameterHintsWidget.getParameterLabelOffsets(signature, 1));
        assertDeepEquals([9, 13], ParameterHintsWidget.getParameterLabelOffsets(signature, 2));
        assertDeepEquals([0, 0], ParameterHintsWidget.getParameterLabelOffsets(signature, 3));
        assertDeepEquals([0, 0], ParameterHintsWidget.getParameterLabelOffsets(signature, 4));
        assertDeepEquals([0, 0], ParameterHintsWidget.getParameterLabelOffsets(signature, 5));
        // the overload counter is padded like the count
        final many:SignatureHelp = {signatures: [for (i in 0...12) ({label: 'f' + i, parameters: []} : SignatureInformation)], activeSignature: 2, activeParameter: 0};
        assertEquals('03/12', ParameterHintsWidget.content(many).overloads);
    }

    // ---- snippets through the editor's API

    function testSnippetSessionThroughTheEditor() {
        final editor = newEditor();
        model.setValue('');
        editor.setPosition(new Position(1, 1));
        final controller = SnippetController2.get(editor);
        controller.insert("for (let ${1:i} = 0; $1 < ${2:count}; $1++) {\n\t$0\n}");
        assertEquals('for (let i = 0; i < count; i++) {\n    \n}', model.getValue());
        assertEquals(true, SnippetController2.InSnippetMode.getValue(editor.contextKeyService));
        assertEquals(false, SnippetController2.HasPrevTabstop.getValue(editor.contextKeyService));
        assertEquals(true, SnippetController2.HasNextTabstop.getValue(editor.contextKeyService));
        assertEquals(3, editor.getSelections().length);
        assertTrue(editor.getSelection().equalsSelection(new Selection(1, 10, 1, 11)));

        // the placeholders are decorated: the active ones and the final tab stop
        var placeholders = 0;
        var finals = 0;
        for (d in model.getAllDecorations()) {
            if (d.options.className == 'snippet-placeholder') {
                placeholders++;
            }
            else if (d.options.className == 'finish-snippet-placeholder') {
                finals++;
            }
        }
        assertEquals(4, placeholders);
        assertEquals(1, finals);
        // their look (snippetSession.css) in the theme colors
        assertNotNull(context.decorationStyles.get('snippet-placeholder'));
        assertEquals(4.0, context.decorationStyles.get('snippet-placeholder').minWidth);

        // typing changes the mirrors
        editor.trigger('keyboard', 'type', {text: 'k'});
        assertEquals('for (let k = 0; k < count; k++) {\n    \n}', model.getValue());

        // Tab: jumpToNextSnippetPlaceholder
        assertTrue(press(editor, 'tab'));
        assertTrue(editor.getSelection().equalsSelection(new Selection(1, 21, 1, 26)));
        assertEquals(true, SnippetController2.HasPrevTabstop.getValue(editor.contextKeyService));

        // Shift+Tab: jumpToPrevSnippetPlaceholder
        assertTrue(press(editor, 'shift-tab'));
        assertTrue(editor.getSelection().equalsSelection(new Selection(1, 10, 1, 11)));

        // Tab, Tab: the final tab stop leaves snippet mode
        assertTrue(press(editor, 'tab'));
        assertTrue(press(editor, 'tab'));
        assertEquals(false, SnippetController2.InSnippetMode.getValue(editor.contextKeyService));
        assertTrue(editor.getSelection().equalsSelection(new Selection(2, 5, 2, 5)));
        for (d in model.getAllDecorations()) {
            assertTrue(d.options.className != 'snippet-placeholder' && d.options.className != 'finish-snippet-placeholder');
        }
    }

    function testEscapeLeavesTheSnippet() {
        final editor = newEditor();
        model.setValue('');
        editor.setPosition(new Position(1, 1));
        SnippetController2.get(editor).insert("${1:a} ${1:a} $2");
        assertEquals(2, editor.getSelections().length);
        // leaveSnippet keeps the primary cursor
        assertTrue(press(editor, 'escape'));
        assertEquals(false, SnippetController2.InSnippetMode.getValue(editor.contextKeyService));
        assertEquals(1, editor.getSelections().length);
    }

    function testSnippetChoicesShowInTheSuggestWidget() {
        final editor = newEditor();
        model.setValue('');
        editor.setPosition(new Position(1, 1));
        TimeTravelScheduler.runWithFakedTimers(scheduler -> {
            SnippetController2.get(editor).insert("color: ${1|red,green,blue|};$0");
            scheduler.runAll();
        });
        assertEquals('color: red;', model.getValue());
        final widget = SuggestController.get(editor).widget;
        assertTrue(widget.isVisible());
        final labels = [for (item in widget.items) item.textLabel];
        assertEquals('red,green,blue', labels.join(','));
        // choosing one replaces the placeholder and goes to the next tab stop
        widget.selectAt(labels.indexOf('blue'));
        assertEquals('color: blue;', model.getValue());
        assertTrue(editor.getSelection().equalsSelection(new Selection(1, 13, 1, 13)));
    }

    function testSnippetVariablesOfTheEditor() {
        final editor = newEditor();
        model.setValue('hello world');
        editor.setSelection(new Selection(1, 7, 1, 12));
        context.readClipboardText = () -> 'clip';
        SnippetController2.get(editor).insert("[$TM_SELECTED_TEXT|$TM_FILENAME|$TM_FILENAME_BASE|$TM_DIRECTORY|$TM_FILEPATH|$RELATIVE_FILEPATH|$TM_LINE_NUMBER|$WORKSPACE_NAME|$WORKSPACE_FOLDER|$CLIPBOARD]", {clipboardText: 'clip'});
        // Monaco's standalone services: file paths, the `inmemory://model/` workspace
        assertEquals('hello [world|max.txt|max|/|/max.txt|/max.txt|1||/|clip]', model.getValue());
    }

}
