// New code for Cityscape (not a port): the folding contribution in editors
// placed in a Glaze window (headless): gutter clicks, the ellipsis of a
// collapsed line, the cursor revealing a folded region, two editors on one
// model folding independently, an off side language, marker regions,
// the commands and keybindings of folding.ts, a folding range provider.
// Expected behaviour: Monaco's folding.ts (mouse handlers, actions,
// `revealCursor`) and its folding decorations.
package tests.contrib.folding;

import cityscape.Cityscape;
import cityscape.CityscapeEditor;
import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.Event;
import cityscape.base.common.RegExp;
import cityscape.common.Languages.FoldingContext;
import cityscape.common.Languages.FoldingRange;
import cityscape.common.Languages.FoldingRangeKind;
import cityscape.common.Languages.FoldingRangeProvider;
import cityscape.common.Model.ITextModel;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.model.TextModel;
import cityscape.contrib.folding.view.Folding;
import cityscape.view.CityscapeView;
import cityscape.view.EditorBrowser.MouseTargetType;
import glaze.App;
import glaze.Entity;
import glaze.MouseButton;
import glaze.MouseDownEvent;
import glaze.MouseUpEvent;
import glaze.TestDispatcher;
import glaze.Window;
import testing.TestCase;
import tests.TestTextModel;

import glaze.Prelude.*;

class FoldingControllerTest extends TestCase {

    var app:App;
    var window:Null<Window> = null;

    override public function setup():Void {
        app = new App(new TestDispatcher());
    }

    override public function teardown():Void {
        if (window != null) {
            window.destroy();
            window = null;
        }
        ceramic.App.app.flushImmediate();
    }

    function draw():Void {
        app.update(_ -> window.draw());
    }

    function open(modelA:TextModel, ?modelB:TextModel, ?optionsA:IEditorOptions, ?optionsB:IEditorOptions):{a:CityscapeView, b:CityscapeView} {
        var a:Null<Entity<CityscapeView>> = null;
        var b:Null<Entity<CityscapeView>> = null;
        if (window != null) {
            window.destroy();
            window = null;
        }
        window = Window.open(app, {width: 900, height: 400, scaleFactor: 2, autoDraw: false, bindInput: false}, FoldingEditors.component(modelA, modelB != null ? modelB : modelA, optionsA, optionsB, v -> a = v, v -> b = v));
        draw();
        final viewA:CityscapeView = a;
        final viewB:CityscapeView = b;
        // the folding ranges are computed after a delay (Monaco's debounce)
        viewA.foldingController._flushPendingUpdate();
        viewB.foldingController._flushPendingUpdate();
        draw();
        return {a: viewA, b: viewB};
    }

    static function hiddenAreas(view:CityscapeView):String {
        return [for (r in view.viewModel.getHiddenAreas()) r.startLineNumber + '-' + r.endLineNumber].join(',');
    }

    static function regions(view:CityscapeView):String {
        final foldingModel = view.foldingController._getCurrentFoldingModel();
        final regions = foldingModel.regions;
        return [for (i in 0...regions.length) regions.getStartLineNumber(i) + '-' + regions.getEndLineNumber(i) + (regions.isCollapsed(i) ? '+' : '')].join(',');
    }

    /**
     * The folding decorations of an editor (the model also has the tracked
     * ranges of the cursors).
     */
    static function foldingDecorations(view:CityscapeView, ownerId:Int, ?model:TextModel):Int {
        var count = 0;
        final m:cityscape.common.Model.ITextModel = model != null ? model : view.model;
        for (d in m.getAllDecorations(ownerId)) {
            if (d.ownerId == ownerId && StringTools.startsWith(d.options.description, 'folding')) {
                count++;
            }
        }
        return count;
    }

    function lineCenterY(view:CityscapeView, modelLineNumber:Int):Float {
        final viewModel = view.viewModel;
        final viewLine = viewModel.coordinatesConverter.convertModelPositionToViewPosition(new cityscape.common.core.Position(modelLineNumber, 1)).lineNumber;
        final lineHeight:Float = view.configuration.options.get(EditorOption.lineHeight);
        return view.elementBounds.origin.y + viewModel.viewLayout.getVerticalOffsetForLineNumber(viewLine) - viewModel.viewLayout.getCurrentScrollTop() + lineHeight / 2;
    }

    function click(x:Float, y:Float, ?button:MouseButton):Void {
        final b = button != null ? button : MouseButton.Left;
        window.dispatchEvent(new MouseDownEvent(b, point(x, y)), app);
        window.dispatchEvent(new MouseUpEvent(b, point(x, y)), app);
    }

    function clickFoldingControl(view:CityscapeView, modelLineNumber:Int):Void {
        final layoutInfo = view.configuration.options.get(EditorOption.layoutInfo);
        click(view.elementBounds.origin.x + layoutInfo.decorationsLeft + layoutInfo.decorationsWidth / 2 + 2, lineCenterY(view, modelLineNumber));
    }

    function key(source:String):Void {
        window.dispatchEvent(new glaze.KeyDownEvent(glaze.Keystroke.parse(source), false, false), app);
    }

    static inline function cmd():String {
        return cityscape.base.common.Platform.isMacintosh ? 'cmd' : 'ctrl';
    }

    static final JAVA = [
        /* 1*/ 'class A {',
        /* 2*/ '  void foo() {',
        /* 3*/ '    console.log();',
        /* 4*/ '    console.log();',
        /* 5*/ '  }',
        /* 6*/ '',
        /* 7*/ '  void bar() {',
        /* 8*/ '    console.log();',
        /* 9*/ '  }',
        /*10*/ '}',
        /*11*/ 'interface B {',
        /*12*/ '  void bar();',
        /*13*/ '}',
    ].join('\n');

    function testRegionsAreComputedByIndentation() {
        final views = open(TestTextModel.createTextModel(JAVA));
        // indentRangeProvider.test.ts 'Fold Java'
        assertEquals('1-9,2-4,7-8,11-12', regions(views.a));
        assertEquals('', hiddenAreas(views.a));
        // the folding decorations belong to each editor
        assertEquals(4, foldingDecorations(views.a, views.a.editorId));
        assertEquals(4, foldingDecorations(views.a, views.b.editorId));
        assertEquals(0, foldingDecorations(views.a, 0));
    }

    function testGutterClickFolds() {
        final views = open(TestTextModel.createTextModel(JAVA));
        final a = views.a;
        a.viewModel.setSelections('test', [new Selection(13, 1, 13, 1)]);
        // the gutter click is a GUTTER_LINE_DECORATIONS target
        final layoutInfo = a.configuration.options.get(EditorOption.layoutInfo);
        final target = a.mouseTargetAt(point(a.elementBounds.origin.x + layoutInfo.decorationsLeft + 6, lineCenterY(a, 2)));
        assertEquals((MouseTargetType.GUTTER_LINE_DECORATIONS : Int), (target.type : Int));
        assertEquals('[2,1 -> 2,15]', target.range.toString());
        clickFoldingControl(a, 2);
        assertEquals('1-9,2-4+,7-8,11-12', regions(a));
        assertEquals('3-4', hiddenAreas(a));
        assertEquals(11, a.viewModel.getLineCount());
        // the click did not move the cursor (Monaco: the gutter does not take the cursor)
        assertEquals('[13,1 -> 13,1]', a.viewModel.getSelection().toString());
        draw();
        // a click on the chevron of the collapsed region unfolds it
        clickFoldingControl(a, 2);
        assertEquals('1-9,2-4,7-8,11-12', regions(a));
        assertEquals('', hiddenAreas(a));
        // a click in the first 4 pixels of the line decorations does nothing (dirty diff)
        click(a.elementBounds.origin.x + layoutInfo.decorationsLeft + 2, lineCenterY(a, 2));
        assertEquals('', hiddenAreas(a));
        // shift click folds recursively: the children first, then the region
        window.dispatchEvent(new MouseDownEvent(MouseButton.Left, point(a.elementBounds.origin.x + layoutInfo.decorationsLeft + 10, lineCenterY(a, 1)), glaze.Modifiers.of(false, false, true, false, false)), app);
        window.dispatchEvent(new MouseUpEvent(MouseButton.Left, point(a.elementBounds.origin.x + layoutInfo.decorationsLeft + 10, lineCenterY(a, 1)), glaze.Modifiers.of(false, false, true, false, false)), app);
        assertEquals('1-9,2-4+,7-8+,11-12', regions(a));
        draw();
    }

    function testCollapsedLineShowsTheEllipsis() {
        final views = open(TestTextModel.createTextModel(JAVA));
        final a = views.a;
        assertFalse(CityscapeView.lineHasFoldedEllipsis(a.renderViewLine(1)));
        clickFoldingControl(a, 1);
        assertEquals('2-9', hiddenAreas(a));
        draw();
        // the first line of the folded range ends with the `inline-folded`
        // after content and has the `folded-background` whole line decoration
        final line = a.renderViewLine(1);
        assertTrue(CityscapeView.lineHasFoldedEllipsis(line));
        assertTrue(a.foldedEllipsisWidth(line) > 0);
        var background = false;
        var collapsedIcon = false;
        for (d in a.viewModel.getDecorationsInViewport(new Range(1, 1, 3, 1))) {
            if (d.options.className == 'folded-background' && d.range.startLineNumber == 1) {
                background = true;
            }
            if (d.options.firstLineDecorationClassName == 'codicon codicon-folding-collapsed' && d.range.startLineNumber == 1) {
                collapsedIcon = true;
            }
        }
        assertTrue(background);
        assertTrue(collapsedIcon);
        // the ellipsis is text of the line (CONTENT_TEXT at the end of the line)
        final layoutInfo = a.configuration.options.get(EditorOption.layoutInfo);
        final x = a.elementBounds.origin.x + layoutInfo.contentLeft + line.layout.width + a.foldedEllipsisWidth(line) / 2;
        final target = a.mouseTargetAt(point(x, lineCenterY(a, 1)));
        assertEquals((MouseTargetType.CONTENT_TEXT : Int), (target.type : Int));
        assertEquals('[1,10 -> 1,10]', target.range.toString());
        // a click on it unfolds (folding.ts `onEditorMouseUp`)
        click(x, lineCenterY(a, 1));
        assertEquals('', hiddenAreas(a));
        // after the ellipsis: empty content, which unfolds only with `unfoldOnClickAfterEndOfLine`
        clickFoldingControl(a, 1);
        final after = a.elementBounds.origin.x + layoutInfo.contentLeft + line.layout.width + a.foldedEllipsisWidth(line) + 40;
        assertEquals((MouseTargetType.CONTENT_EMPTY : Int), (a.mouseTargetAt(point(after, lineCenterY(a, 1))).type : Int));
        click(after, lineCenterY(a, 1));
        assertEquals('2-9', hiddenAreas(a));
        a.updateOptions({unfoldOnClickAfterEndOfLine: true});
        click(after, lineCenterY(a, 1));
        assertEquals('', hiddenAreas(a));
        draw();
    }

    function testCursorInAFoldedRegionUnfoldsIt() {
        final views = open(TestTextModel.createTextModel(JAVA));
        final a = views.a;
        clickFoldingControl(a, 2);
        assertEquals('3-4', hiddenAreas(a));
        // moving down from line 2 skips the hidden lines
        a.viewModel.setSelections('test', [new Selection(2, 3, 2, 3)]);
        app.update(_ -> a.focusHandle.focus(window, app));
        key('down');
        assertEquals(5, a.viewModel.getPosition().lineNumber);
        a.foldingController._flushCursorReveal();
        assertEquals('3-4', hiddenAreas(a));
        // a cursor placed in the hidden lines reveals them (`revealCursor`)
        a.viewModel.setSelections('test', [new Selection(3, 5, 3, 5)]);
        a.foldingController._flushCursorReveal();
        assertEquals('', hiddenAreas(a));
        assertEquals('1-9,2-4,7-8,11-12', regions(a));
        assertEquals('[3,5 -> 3,5]', a.viewModel.getSelection().toString());
        draw();
    }

    function testFoldingMovesTheCursorOutOfTheHiddenLines() {
        final views = open(TestTextModel.createTextModel(JAVA));
        final a = views.a;
        a.viewModel.setSelections('test', [new Selection(3, 5, 3, 5)]);
        // `onHiddenRangesChanges`: the selections are adjusted to the end of the folded line
        a.runFoldingCommand('editor.fold', {selectionLines: [1]});
        assertEquals('3-4', hiddenAreas(a));
        assertEquals('[2,15 -> 2,15]', a.viewModel.getSelection().toString());
    }

    function testTwoEditorsOnOneModelFoldIndependently() {
        final model = TestTextModel.createTextModel(JAVA);
        final views = open(model, model, null, {showFoldingControls: 'always'});
        final a = views.a;
        final b = views.b;
        clickFoldingControl(a, 1);
        assertEquals('2-9', hiddenAreas(a));
        assertEquals('', hiddenAreas(b));
        assertEquals('1-9+,2-4,7-8,11-12', regions(a));
        assertEquals('1-9,2-4,7-8,11-12', regions(b));
        clickFoldingControl(b, 11);
        assertEquals('12-12', hiddenAreas(b));
        assertEquals('2-9', hiddenAreas(a));
        // each editor's decorations: `mouseover` controls in a, `always` in b
        var aExpanded = 0;
        var bAlways = 0;
        for (d in model.getAllDecorations(a.editorId)) {
            if (d.options.firstLineDecorationClassName == 'codicon codicon-folding-expanded') {
                aExpanded++;
            }
        }
        for (d in model.getAllDecorations(b.editorId)) {
            if (d.options.firstLineDecorationClassName == 'alwaysShowFoldIcons codicon codicon-folding-expanded') {
                bAlways++;
            }
        }
        assertEquals(1, aExpanded); // 11-12 (2-4 and 7-8 are hidden in the collapsed 1-9)
        assertEquals(3, bAlways);
        // an edit in one editor updates the regions of both
        model.applyEdits([cityscape.common.core.EditOperation.insert(new cityscape.common.core.Position(13, 2), '\nx {\n  y\n}')]);
        a.foldingController._flushPendingUpdate();
        b.foldingController._flushPendingUpdate();
        assertEquals('1-9+,2-4,7-8,11-12,14-15', regions(a));
        assertEquals('1-9,2-4,7-8,11-12+,14-15', regions(b));
        draw();
    }

    function testOffSideLanguage() {
        final context = new Cityscape();
        context.languageService.registerLanguage({id: 'offside'});
        context.languageConfigurationService.register('offside', {folding: {offSide: true}});
        final model = TestTextModel.instantiateTextModel(context, [
        /* 1*/ 'def a:',
        /* 2*/ '  pass',
        /* 3*/ '   ',
        /* 4*/ '  def b:',
        /* 5*/ '    pass',
        /* 6*/ '  ',
        /* 7*/ '      ',
        /* 8*/ 'def c: # since there was a deintent here'
        ].join('\n'), 'offside');
        final views = open(model);
        // indentRangeProvider.test.ts 'Fold Whitespace Python' (off side: the
        // empty lines go to the block above)
        assertEquals('1-5,4-5', regions(views.a));
        clickFoldingControl(views.a, 1);
        assertEquals('2-5', hiddenAreas(views.a));
        // the same text in a language that is not off side (Monaco's
        // plaintext is off side)
        context.languageService.registerLanguage({id: 'notoffside'});
        context.languageConfigurationService.register('notoffside', {});
        final plain = TestTextModel.instantiateTextModel(context, model.getValue(), 'notoffside');
        final viewsPlain = open(plain);
        assertEquals('1-7,4-7', regions(viewsPlain.a));
    }

    function testMarkerRegions() {
        final context = new Cityscape();
        context.languageService.registerLanguage({id: 'markers'});
        context.languageConfigurationService.register('markers', {
            folding: {markers: {start: new RegExp('^\\s*//\\s*#?region\\b'), end: new RegExp('^\\s*//\\s*#?endregion\\b')}}
        });
        final model = TestTextModel.instantiateTextModel(context, [
        /* 1*/ '// #region imports',
        /* 2*/ 'import a;',
        /* 3*/ 'import b;',
        /* 4*/ '// #endregion',
        /* 5*/ 'class A {',
        /* 6*/ '  //#region fields',
        /* 7*/ '  var x;',
        /* 8*/ '  //#endregion',
        /* 9*/ '}',
        ].join('\n'), 'markers');
        final views = open(model);
        final a = views.a;
        assertEquals('1-4,5-8,6-8', regions(a));
        a.viewModel.setSelections('test', [new Selection(9, 1, 9, 1)]);
        // `editor.foldAllMarkerRegions` folds the regions whose start line matches the start marker
        assertTrue(a.runFoldingCommand('editor.foldAllMarkerRegions'));
        assertEquals('1-4+,5-8,6-8+', regions(a));
        assertEquals('2-4,7-8', hiddenAreas(a));
        assertTrue(a.runFoldingCommand('editor.unfoldAllMarkerRegions'));
        assertEquals('', hiddenAreas(a));
    }

    function testFoldingCommands() {
        final views = open(TestTextModel.createTextModel(JAVA));
        final a = views.a;
        a.viewModel.setSelections('test', [new Selection(3, 1, 3, 1)]);
        assertTrue(a.runFoldingCommand('editor.foldAll'));
        assertEquals('1-9+,2-4+,7-8+,11-12+', regions(a));
        assertTrue(a.runFoldingCommand('editor.unfoldAll'));
        assertEquals('1-9,2-4,7-8,11-12', regions(a));
        // folding hid the cursor line: the cursor went to the end of line 1
        assertEquals('[1,10 -> 1,10]', a.viewModel.getSelection().toString());
        a.viewModel.setSelections('test', [new Selection(3, 1, 3, 1)]);
        assertTrue(a.runFoldingCommand('editor.foldLevel2'));
        assertEquals('1-9,2-4,7-8+,11-12', regions(a)); // 2-4 holds the cursor
        assertTrue(a.runFoldingCommand('editor.unfoldAll'));
        // fold, then fold again: the parent
        a.viewModel.setSelections('test', [new Selection(3, 1, 3, 1)]);
        assertTrue(a.runFoldingCommand('editor.fold'));
        assertEquals('1-9,2-4+,7-8,11-12', regions(a));
        assertEquals('[2,15 -> 2,15]', a.viewModel.getSelection().toString());
        assertTrue(a.runFoldingCommand('editor.fold'));
        assertEquals('1-9+,2-4+,7-8,11-12', regions(a));
        assertEquals('[1,10 -> 1,10]', a.viewModel.getSelection().toString());
        assertTrue(a.runFoldingCommand('editor.unfoldRecursively'));
        assertEquals('1-9,2-4,7-8,11-12', regions(a));
        a.viewModel.setSelections('test', [new Selection(3, 1, 3, 1)]);
        assertTrue(a.runFoldingCommand('editor.toggleFold'));
        assertEquals('1-9,2-4+,7-8,11-12', regions(a));
        assertTrue(a.runFoldingCommand('editor.toggleFold'));
        assertEquals('1-9,2-4,7-8,11-12', regions(a));
        a.viewModel.setSelections('test', [new Selection(3, 1, 3, 1)]);
        assertTrue(a.runFoldingCommand('editor.foldRecursively', null));
        assertEquals('1-9,2-4+,7-8,11-12', regions(a));
        assertTrue(a.runFoldingCommand('editor.unfold', {levels: 1, direction: 'up'}));
        assertEquals('1-9,2-4,7-8,11-12', regions(a));
        // arguments are checked like Monaco's `foldingArgumentsConstraint`
        assertFalse(a.runFoldingCommand('editor.fold', cast {levels: 'two'}));
        assertFalse(a.runFoldingCommand('editor.nope'));
        // go to the parent fold, next and previous folding ranges
        a.viewModel.setSelections('test', [new Selection(8, 1, 8, 1)]);
        assertTrue(a.runFoldingCommand('editor.gotoParentFold'));
        assertEquals('[7,1 -> 7,1]', a.viewModel.getSelection().toString());
        assertTrue(a.runFoldingCommand('editor.gotoPreviousFold'));
        assertEquals('[2,1 -> 2,1]', a.viewModel.getSelection().toString());
        assertTrue(a.runFoldingCommand('editor.gotoNextFold'));
        assertEquals('[7,1 -> 7,1]', a.viewModel.getSelection().toString());
        // a manual folding range from the selection, then removed
        a.viewModel.setSelections('test', [new Selection(3, 1, 4, 3)]);
        assertTrue(a.runFoldingCommand('editor.createFoldingRangeFromSelection'));
        assertEquals('1-9,2-4,3-4+,7-8,11-12', regions(a));
        assertEquals('4-4', hiddenAreas(a));
        a.viewModel.setSelections('test', [new Selection(3, 1, 3, 1)]);
        assertTrue(a.runFoldingCommand('editor.removeManualFoldingRanges'));
        a.foldingController._flushPendingUpdate();
        assertEquals('1-9,2-4,7-8,11-12', regions(a));
        // the folding actions are Monaco's, with its ids
        final ids = [for (action in FoldingCommands.all()) action.id];
        for (id in ['editor.fold', 'editor.unfold', 'editor.foldAll', 'editor.unfoldAll', 'editor.foldRecursively', 'editor.toggleFold', 'editor.foldLevel1', 'editor.foldLevel7', 'editor.foldAllBlockComments', 'editor.foldAllExcept', 'editor.unfoldAllExcept']) {
            assertTrue(ids.indexOf(id) != -1, id);
        }
        assertEquals(25, ids.length);
    }

    function testFoldingKeybindings() {
        final views = open(TestTextModel.createTextModel(JAVA));
        final a = views.a;
        app.update(_ -> a.focusHandle.focus(window, app));
        a.viewModel.setSelections('test', [new Selection(3, 1, 3, 1)]);
        final mac = cityscape.base.common.Platform.isMacintosh;
        // Cmd+Alt+[ on macOS, Ctrl+Shift+[ elsewhere: fold
        key(mac ? 'cmd-alt-[' : 'ctrl-shift-[');
        assertEquals('1-9,2-4+,7-8,11-12', regions(a));
        key(mac ? 'cmd-alt-]' : 'ctrl-shift-]');
        assertEquals('1-9,2-4,7-8,11-12', regions(a));
        // the chords of Cmd+K (Ctrl+K)
        key(cmd() + '-k');
        key(cmd() + '-0');
        assertEquals('1-9+,2-4+,7-8+,11-12+', regions(a));
        key(cmd() + '-k');
        key(cmd() + '-j');
        assertEquals('1-9,2-4,7-8,11-12', regions(a));
        // a chord that is no command uses the second key
        a.viewModel.setSelections('test', [new Selection(3, 1, 3, 1)]);
        key(cmd() + '-k');
        key('down');
        assertEquals('[3,1 -> 3,1]', a.viewModel.getSelection().toString());
        // folding off: no fold
        a.updateOptions({folding: false});
        key(mac ? 'cmd-alt-[' : 'ctrl-shift-[');
        assertEquals('', hiddenAreas(a));
        assertNull(a.foldingController._getCurrentFoldingModel());
        draw();
    }

    function testFoldingRangeProvider() {
        final context = new Cityscape();
        context.languageService.registerLanguage({id: 'provided'});
        final model = TestTextModel.instantiateTextModel(context, ['a', 'b', 'c', 'd', 'e'].join('\n'), 'provided');
        final provider = new SimpleFoldingRangeProvider([{start: 1, end: 3, kind: FoldingRangeKind.Comment}, {start: 4, end: 5}]);
        final registration = context.languageFeaturesService.foldingRangeProvider.register('provided', provider);
        final views = open(model, null, null, {foldingStrategy: 'indentation'});
        // `auto` uses the provider, `indentation` the indentation (nothing here)
        assertEquals('1-3,4-5', regions(views.a));
        assertEquals('', regions(views.b));
        // the provider tells that its ranges changed
        provider.ranges = [{start: 2, end: 5}];
        provider.fireChange();
        views.a.foldingController._flushPendingUpdate();
        assertEquals('2-5', regions(views.a));
        // `editor.foldAllBlockComments` folds the ranges of kind comment
        provider.ranges = [{start: 1, end: 2, kind: FoldingRangeKind.Comment}, {start: 3, end: 5, kind: FoldingRangeKind.Region}];
        provider.fireChange();
        views.a.foldingController._flushPendingUpdate();
        views.a.viewModel.setSelections('test', [new Selection(5, 1, 5, 1)]);
        views.a.runFoldingCommand('editor.foldAllBlockComments');
        assertEquals('1-2+,3-5', regions(views.a));
        // without providers, the indentation ranges (none here); the
        // collapsed range stays, recovered (`sanitizeAndMerge`)
        registration.dispose();
        views.a.foldingController._flushPendingUpdate();
        assertEquals('1-2+', regions(views.a));
    }

    function testFoldsAreKeptWhenTheModelComesBack() {
        final modelA = TestTextModel.createTextModel(JAVA);
        final modelB = TestTextModel.createTextModel('x {\n  y\n}');
        final views = open(modelA);
        final a = views.a;
        clickFoldingControl(a, 7);
        assertEquals('8-8', hiddenAreas(a));
        a.setModel(modelB);
        a.foldingController._flushPendingUpdate();
        assertEquals('', hiddenAreas(a));
        assertEquals(0, foldingDecorations(a, a.editorId, modelA));
        a.setModel(modelA);
        // Monaco's `saveViewState`/`restoreViewState` of the contribution
        assertEquals('8-8', hiddenAreas(a));
        a.foldingController._flushPendingUpdate();
        assertEquals('1-9,2-4,7-8+,11-12', regions(a));
        assertEquals('8-8', hiddenAreas(a));
    }

}

class SimpleFoldingRangeProvider implements FoldingRangeProvider {

    public var id(default, null):Null<String> = 'simple';
    public var onDidChange(default, null):Null<Event<FoldingRangeProvider>>;

    final _onDidChange = new Emitter<FoldingRangeProvider>();

    public var ranges:Array<FoldingRange>;

    public function new(ranges:Array<FoldingRange>) {
        this.ranges = ranges;
        this.onDidChange = _onDidChange.event;
    }

    public function fireChange():Void {
        _onDidChange.fire(this);
    }

    public function provideFoldingRanges(model:ITextModel, context:FoldingContext, token:CancellationToken, resolve:(ranges:Null<Array<FoldingRange>>) -> Void):Void {
        resolve(ranges);
    }

}

class FoldingEditors extends glaze.Component {

    final modelA:TextModel;
    final modelB:TextModel;
    final optionsA:Null<IEditorOptions>;
    final optionsB:Null<IEditorOptions>;
    final onA:(view:Entity<CityscapeView>) -> Void;
    final onB:(view:Entity<CityscapeView>) -> Void;

    public function new(modelA:TextModel, modelB:TextModel, optionsA:Null<IEditorOptions>, optionsB:Null<IEditorOptions>, onA:(view:Entity<CityscapeView>) -> Void, onB:(view:Entity<CityscapeView>) -> Void) {
        super();
        this.modelA = modelA;
        this.modelB = modelB;
        this.optionsA = optionsA;
        this.optionsB = optionsB;
        this.onA = onA;
        this.onB = onB;
    }

    public function render(window:Window, cx:App):glaze.IntoElement {
        return div().flex().sizeFull()
            .child(CityscapeEditor.component().model(modelA).options(optionsA != null ? optionsA : {lineNumbers: 'on'}).onCreate(e -> onA(e.getView())).flex1())
            .child(CityscapeEditor.component().model(modelB).options(optionsB != null ? optionsB : {lineNumbers: 'on'}).onCreate(e -> onB(e.getView())).flex1());
    }

}
