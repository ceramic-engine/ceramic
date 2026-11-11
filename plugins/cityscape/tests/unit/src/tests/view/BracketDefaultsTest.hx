// New code for Cityscape (not a port): the bracket features a CityscapeEditor
// has when its host gives no option (Cityscape's defaults, DEVIATIONS.md
// "Bracket features off by default"), and Monaco's behaviour when it does.
package tests.view;

import cityscape.Cityscape;
import cityscape.CityscapeEditor;
import cityscape.common.Model.ITextModel;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.contrib.bracketMatching.view.BracketMatching.BracketMatchingController;
import cityscape.view.viewParts.indentGuides.IndentGuides;
import glaze.App;
import glaze.TestDispatcher;
import glaze.Window;
import testing.TestCase;
import tests.view.EditorFontsTest.EditorFontsTestHost;

class BracketDefaultsTest extends TestCase {

    static final TEXT = 'function f(a) {\n    if (a) {\n        g([1, 2]);\n    }\n}';

    var app:App;
    var context:Cityscape;
    var window:Null<Window> = null;
    var editor:Null<CityscapeEditor> = null;

    override public function setup():Void {
        app = new App(new TestDispatcher());
        context = new Cityscape();
        context.languageService.registerLanguage({id: 'brackets'});
        context.languageConfigurationService.register('brackets', {
            brackets: [['{', '}'], ['[', ']'], ['(', ')']]
        });
    }

    override public function teardown():Void {
        if (window != null) {
            window.destroy();
            window = null;
        }
        ceramic.App.app.flushImmediate();
    }

    function open(model:ITextModel, options:Null<IEditorOptions>):CityscapeEditor {
        window = Window.open(app, {width: 800, height: 400, scaleFactor: 1, autoDraw: false, bindInput: false},
            EditorFontsTestHost.component(model, options, e -> editor = e));
        app.update(_ -> window.draw());
        return editor;
    }

    function close():Void {
        window.destroy();
        window = null;
        editor = null;
    }

    function newModel():ITextModel {
        return Cityscape.createModel(TEXT, 'brackets', null, context);
    }

    /** The bracket pair colors of the visible lines (`line:column`). */
    function colorizedBrackets(e:CityscapeEditor):String {
        final viewModel = e.getEditor()._getViewModel();
        final names:Array<Int> = [];
        for (d in viewModel.getDecorationsInViewport(new Range(1, 1, 5, 2))) {
            final name = d.options.inlineClassName;
            if (name != null && StringTools.startsWith(name, 'bracket-highlighting-')) {
                names.push(d.range.startLineNumber * 1000 + d.range.startColumn);
            }
        }
        names.sort((a, b) -> a - b);
        return [for (n in names) Std.int(n / 1000) + ':' + (n % 1000)].join(',');
    }

    /** The boxes of the matching brackets with the cursor at `position`. */
    function matchingBrackets(e:CityscapeEditor, position:Position):String {
        final widget = e.getEditor();
        widget._getViewModel().setHasFocus(true);
        widget.setPosition(position);
        final controller = BracketMatchingController.get(widget);
        controller._flushPendingUpdate();
        final result:Array<String> = [];
        final model = widget.getModel();
        for (d in model.getAllDecorations()) {
            if (d.options.className == 'bracket-match') {
                result.push(Range.lift(d.range).toString());
            }
        }
        result.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
        return result.join(' ');
    }

    /** The class names of the guides of the lines, other than indentation guides. */
    function bracketGuides(e:CityscapeEditor, position:Position):String {
        final widget = e.getEditor();
        widget.setPosition(position);
        final viewModel = widget._getViewModel();
        final names:Array<String> = [];
        final byLine = IndentGuides.getGuidesByLine(viewModel, widget.getOption(EditorOption.guides), 1, 5, position);
        for (guides in byLine) {
            for (guide in guides) {
                if (!StringTools.startsWith(guide.className, 'core-guide-indent')) {
                    names.push(guide.className);
                }
            }
        }
        return names.join(',');
    }

    function testNoBracketFeaturesByDefault() {
        final model = newModel();
        final e = open(model, null);
        assertFalse(e.getOption(EditorOption.bracketPairColorization).enabled);
        assertFalse(model.getOptions().bracketPairColorizationOptions.enabled);
        assertEquals('never', e.getOption(EditorOption.matchBrackets));
        assertEquals('', colorizedBrackets(e));
        assertEquals('', matchingBrackets(e, new Position(1, 11)));
        assertEquals('', bracketGuides(e, new Position(3, 12)));
        close();
        model.dispose();
    }

    function testMonacoBehaviourWhenGiven() {
        final model = newModel();
        final e = open(model, {bracketPairColorization: {enabled: true}, matchBrackets: 'always', guides: {bracketPairs: true}});
        assertTrue(model.getOptions().bracketPairColorizationOptions.enabled);
        assertEquals('1:11,1:13,1:15,2:8,2:10,2:12,3:10,3:11,3:16,3:17,4:5,5:1', colorizedBrackets(e));
        assertEquals('[1,11 -> 1,12] [1,13 -> 1,14]', matchingBrackets(e, new Position(1, 11)));
        assertTrue(bracketGuides(e, new Position(3, 12)) != '');
        close();
        model.dispose();
    }

    /**
     * The other fields of `bracketPairColorization` given without `enabled`
     * keep Cityscape's default for it.
     */
    function testEnabledDefaultWithOtherFields() {
        final model = newModel();
        final e = open(model, {bracketPairColorization: {independentColorPoolPerBracketType: true}});
        final value = e.getOption(EditorOption.bracketPairColorization);
        assertFalse(value.enabled);
        assertTrue(value.independentColorPoolPerBracketType);
        assertEquals('', colorizedBrackets(e));
        close();
        model.dispose();
    }

    /** Options set to null are left out: Cityscape's defaults. */
    function testNullOptionsTakeTheDefaults() {
        final model = newModel();
        final e = open(model, {matchBrackets: null, bracketPairColorization: null});
        assertEquals('never', e.getOption(EditorOption.matchBrackets));
        assertFalse(e.getOption(EditorOption.bracketPairColorization).enabled);
        assertEquals('', colorizedBrackets(e));
        close();
        model.dispose();
    }

    /**
     * Regression: a model option of the configuration changing (the tab size
     * an editor writes there) gave the models the configuration's bracket
     * colorization again, over the one of their editor.
     */
    function testTabSizeChangeKeepsTheEditorColorization() {
        final model = newModel();
        final e = open(model, null);
        e.updateOptions(cast {tabSize: 2});
        app.update(_ -> window.draw());
        assertFalse(model.getOptions().bracketPairColorizationOptions.enabled);
        assertEquals('', colorizedBrackets(e));
        close();
        model.dispose();

        final model = newModel();
        final e = open(model, {bracketPairColorization: {enabled: true}});
        e.updateOptions(cast {tabSize: 2});
        app.update(_ -> window.draw());
        assertTrue(model.getOptions().bracketPairColorizationOptions.enabled);
        close();
        model.dispose();
    }

}
