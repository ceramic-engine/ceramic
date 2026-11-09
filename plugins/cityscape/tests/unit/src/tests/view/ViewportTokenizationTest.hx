// New code for Cityscape (not a port): the tokenization state Monaco's Enter
// sees right after typing, in an editor rendered by Glaze.
package tests.view;

import cityscape.Cityscape;
import cityscape.CityscapeEditor;
import cityscape.base.common.RegExp;
import cityscape.common.EncodedTokenAttributes;
import cityscape.common.Languages;
import cityscape.common.languages.LanguageConfiguration;
import cityscape.common.languages.NullTokenize;
import cityscape.common.model.TextModel;
import glaze.App;
import glaze.TestDispatcher;
import glaze.Window;
import testing.TestCase;
import testing.TestTokenizationSupport;

import glaze.Prelude.*;

class ViewportTokenizationTestHost extends glaze.Component {

    final model:TextModel;
    final onEditor:(editor:CityscapeEditor) -> Void;

    public function new(model:TextModel, onEditor:(editor:CityscapeEditor) -> Void) {
        super();
        this.model = model;
        this.onEditor = onEditor;
    }

    public function render(window:Window, cx:App):glaze.IntoElement {
        return div().flex().sizeFull().child(CityscapeEditor.component().model(model).onCreate(onEditor).flex1());
    }

}

/**
 * Enter just after typing a line that an `onEnterRules` rule indents after
 * (`choice`), like loreline-monaco's choice options.
 *
 * Monaco's Enter applies the language's rules only when the line is cheap to
 * tokenize (`isCheapToTokenize`: the line is the first one without a valid
 * end state, or before it), else it keeps the indentation
 * (cursorTypeEditOperations.ts `_enter`). An edit invalidates the end states
 * from its first line (`TokenizerWithStateStore.acceptChanges`); typing a
 * character on a cheap line tokenizes it (autoIndent's
 * `getIndentActionForType`), and the rest is tokenized by the background
 * tokenizer in idle time and by the viewport refresh 50 ms after a change of
 * the visible lines. Cityscape keeps these rules: the background tokenizer
 * runs each frame (`BackgroundScheduler`), and the view tokenizes its visible
 * lines when they change.
 */
class ViewportTokenizationTest extends TestCase {

    static inline final LANGUAGE_ID = 'viewportTokenizationTest';

    var app:App;
    var context:Cityscape;
    var window:Null<Window> = null;
    var editor:Null<CityscapeEditor> = null;

    override public function setup():Void {
        app = new App(new TestDispatcher());
        context = new Cityscape();
        context.languageService.registerLanguage({id: LANGUAGE_ID});
        final encodedLanguageId:LanguageId = context.languageService.languageIdCodec.encodeLanguageId(LANGUAGE_ID);
        context.tokenizationRegistry.register(LANGUAGE_ID, new TestTokenizationSupport(
            () -> NullTokenize.NullState,
            (line, hasEOL, state) -> NullTokenize.nullTokenizeEncoded(encodedLanguageId, state)
        ));
        context.languageConfigurationService.register(LANGUAGE_ID, {
            onEnterRules: [{
                beforeText: new RegExp('^\\s*choice\\s*$'),
                action: {indentAction: IndentAction.Indent}
            }]
        });
    }

    override public function teardown():Void {
        if (window != null) {
            window.destroy();
            window = null;
        }
        ceramic.App.app.flushImmediate();
    }

    function open(text:String):TextModel {
        final model = new TextModel(text, LANGUAGE_ID, TextModel.DEFAULT_CREATION_OPTIONS, null, context);
        window = Window.open(app, {width: 600, height: 300, scaleFactor: 2, autoDraw: false, bindInput: false},
            ViewportTokenizationTestHost.component(model, e -> editor = e));
        frame();
        return model;
    }

    /**
     * One frame of a running app: the update (background tokenization within
     * the frame budget), then the draw.
     */
    function frame():Void {
        context.backgroundScheduler.runFor(context.backgroundScheduler.budgetMs);
        app.update(_ -> window.draw());
    }

    function type(text:String, framesBetweenKeys:Bool):Void {
        for (i in 0...text.length) {
            editor.trigger('keyboard', 'type', {text: text.charAt(i)});
            if (framesBetweenKeys) {
                frame();
            }
        }
    }

    function testEnterAfterTypingWithFramesBetweenKeys() {
        final model = open('');
        editor.setPosition({lineNumber: 1, column: 1});
        type('intro\nchoice\nok', true);
        assertEquals('intro\nchoice\n    ok', model.getValue(), haxe.Json.stringify(model.getValue()));
    }

    function testEnterAfterTypingBelowTheViewport() {
        // the visible lines do not change when lines are added: the
        // background tokenizer makes the typed line cheap
        final lines = [for (i in 0...200) 'line ' + i];
        final model = open(lines.join('\n'));
        editor.setPosition({lineNumber: 5, column: 7});
        type('\nchoice\nok', true);
        assertEquals('line 4\nchoice\n    ok', model.getValueInRange({startLineNumber: 5, startColumn: 1, endLineNumber: 7, endColumn: 7}, cityscape.common.Model.EndOfLinePreference.LF));
    }

    function testEnterInTheSameFrameAsTheEditKeepsTheIndentation() {
        // Monaco: nothing tokenized the lines invalidated by the first Enter
        // (no idle time, no viewport refresh in between), so the line typed
        // after it is not cheap to tokenize and Enter keeps the indentation
        final lines = [for (i in 0...200) 'line ' + i];
        final model = open(lines.join('\n'));
        editor.setPosition({lineNumber: 5, column: 7});
        type('\nchoice', false);
        assertFalse(model.tokenization.hasAccurateTokensForLine(5));
        assertFalse(model.tokenization.isCheapToTokenize(6));
        type('\nok', false);
        assertEquals('line 4\nchoice\nok', model.getValueInRange({startLineNumber: 5, startColumn: 1, endLineNumber: 7, endColumn: 3}, cityscape.common.Model.EndOfLinePreference.LF));
        // after a frame of background work, the line is cheap again
        frame();
        assertTrue(model.tokenization.isCheapToTokenize(7));
    }

}
