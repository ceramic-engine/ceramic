// New code for Cityscape (not a port): the diff editor component in a Glaze
// window (headless) and the view zones of the editor. vscode has no tests of
// its diff editor widget: these check Monaco's rules (aligned lines, the
// zones of the inline view, the hidden regions of `UnchangedRegion.fromDiffs`)
// on texts whose diffs come from the ported algorithm (its own tests are the
// vscode ones).
package tests.view;

import cityscape.CityscapeDiffEditor;
import cityscape.CityscapeEditor;
import cityscape.common.config.EditorOptions.EditorOption;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.model.TextModel;
import cityscape.view.CityscapeView;
import cityscape.view.EditorBrowser;
import cityscape.view.widget.codeEditor.CodeEditorWidget;
import cityscape.view.widget.diffEditor.DiffEditorOptions.IDiffEditorOptions;
import cityscape.view.widget.diffEditor.DiffEditorViewModel;
import cityscape.view.widget.diffEditor.DiffProviderFactoryService.DiffComputationMode;
import glaze.App;
import glaze.MouseButton;
import glaze.MouseDownEvent;
import glaze.MouseUpEvent;
import glaze.TestDispatcher;
import glaze.Window;
import testing.TestCase;
import tests.TestTextModel.createTextModel;

import glaze.Prelude.*;

class DiffEditorTest extends TestCase {

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

    function lines(count:Int, ?prefix:String):Array<String> {
        final p = prefix != null ? prefix : 'line';
        return [for (i in 1...count + 1) p + ' ' + i];
    }

    /**
     * Opens one diff editor (synchronous diff) and draws until it is laid out.
     */
    function open(original:TextModel, modified:TextModel, ?options:IDiffEditorOptions, width:Float = 1200):CityscapeDiffEditor {
        var editor:Null<CityscapeDiffEditor> = null;
        window = Window.open(app, {width: width, height: 400, scaleFactor: 2, autoDraw: false, bindInput: false}, DiffHost.component([{original: original, modified: modified}], options, e -> editor = e));
        draw();
        draw();
        assertNotNull(editor, 'the diff editor is created with its two editors');
        editor.getWidget()._flush();
        draw();
        return editor;
    }

    static function widgetOf(e:CityscapeEditor):CodeEditorWidget {
        return cast e.getEditor();
    }

    function testSideBySideAlignsTheLines() {
        final original = createTextModel(['a', 'b', 'c', 'd'].join('\n'));
        final modified = createTextModel(['a', 'X', 'Y', 'b', 'c', 'd'].join('\n'));
        final diffEditor = open(original, modified);
        assertTrue(diffEditor.renderSideBySide, 'side by side above the inline breakpoint');
        final changes = diffEditor.getLineChanges();
        assertDeepEquals([{
            originalStartLineNumber: 1,
            originalEndLineNumber: 0,
            modifiedStartLineNumber: 2,
            modifiedEndLineNumber: 3,
            charChanges: null
        }], changes);
        final o = widgetOf(diffEditor.getOriginalEditor());
        final m = widgetOf(diffEditor.getModifiedEditor());
        final lineHeight:Float = m.getOption(EditorOption.lineHeight);
        // The original gets a zone of two lines after its line 1 (Monaco's
        // diagonal fill), so that `b` is at the same height on both sides
        final whitespaces = o.getWhitespaces();
        assertEquals(1, whitespaces.length);
        assertEquals(1, whitespaces[0].afterLineNumber);
        assertEquals(2 * lineHeight, whitespaces[0].height);
        assertEquals(0, m.getWhitespaces().length);
        assertEquals(m.getTopForLineNumber(4), o.getTopForLineNumber(2));
        assertEquals(m.getTopForLineNumber(6), o.getTopForLineNumber(4));
        assertEquals(m.getContentHeight(), o.getContentHeight());
        // decorations: line-insert on the inserted lines, line-delete nowhere
        var insertLines = 0;
        for (d in m.getModel().getAllDecorations(m.getNumericId())) {
            if (d.options.className == 'line-insert') {
                insertLines += d.range.endLineNumber - d.range.startLineNumber + 1;
            }
        }
        assertEquals(2, insertLines);
        draw();
    }

    function testInnerHunkAlignment() {
        // A change inside lines aligns the text after it (innerHunkAlignment)
        final original = createTextModel(['function a() {', '    return 1;', '}', 'end'].join('\n'));
        final modified = createTextModel(['function a() {', '    const x = 2;', '    const y = 3;', '    return x + y;', '}', 'end'].join('\n'));
        final diffEditor = open(original, modified);
        final o = widgetOf(diffEditor.getOriginalEditor());
        final m = widgetOf(diffEditor.getModifiedEditor());
        assertEquals(m.getTopForLineNumber(5), o.getTopForLineNumber(3));
        assertEquals(m.getTopForLineNumber(6), o.getTopForLineNumber(4));
        assertEquals(m.getContentHeight(), o.getContentHeight());
    }

    function testScrollingIsSynchronized() {
        final original = createTextModel(lines(200).join('\n'));
        final modifiedLines = lines(200);
        modifiedLines[50] = 'changed 51';
        final modified = createTextModel(modifiedLines.join('\n'));
        final diffEditor = open(original, modified);
        final o = widgetOf(diffEditor.getOriginalEditor());
        final m = widgetOf(diffEditor.getModifiedEditor());
        m.setScrollTop(500);
        assertEquals(500.0, o.getScrollTop());
        o.setScrollTop(200);
        assertEquals(200.0, m.getScrollTop());
        draw();
    }

    function testInlineViewShowsTheDeletedLines() {
        final original = createTextModel(['a', 'b', 'c', 'd'].join('\n'));
        final modified = createTextModel(['a', 'd'].join('\n'));
        final diffEditor = open(original, modified, {renderSideBySide: false});
        assertFalse(diffEditor.renderSideBySide);
        final o = widgetOf(diffEditor.getOriginalEditor());
        final m = widgetOf(diffEditor.getModifiedEditor());
        final lineHeight:Float = m.getOption(EditorOption.lineHeight);
        // The deleted lines `b` and `c` are a zone of the modified editor
        // after its line 1 (Monaco's `renderLines` of the original)
        final whitespaces = m.getWhitespaces();
        assertEquals(1, whitespaces.length);
        assertEquals(1, whitespaces[0].afterLineNumber);
        assertEquals(2 * lineHeight, whitespaces[0].height);
        // the original, narrow, keeps its lines aligned with the modified
        assertEquals(m.getTopForLineNumber(2), o.getTopForLineNumber(4));
        // only the margin of the original is shown
        final originalView:CityscapeView = diffEditor.getOriginalEditor().getView();
        final modifiedView:CityscapeView = diffEditor.getModifiedEditor().getView();
        assertTrue(originalView.elementBounds.size.width < 100, 'the original shows its line numbers only');
        assertTrue(modifiedView.elementBounds.size.width > 900, 'the modified takes the rest');
        draw();
    }

    /**
     * style.css gives the gutter of the changed lines (`gutter-insert`,
     * `gutter-delete`, the margin of the inline view's deleted lines)
     * `var(--vscode-diffEditorGutter-..., var(--vscode-diffEditor-...LineBackground), var(--vscode-diffEditor-...TextBackground))`:
     * CSS takes everything after the first comma as one fallback, two
     * colors, which is invalid, so Monaco 0.52.2 leaves the gutter
     * transparent unless the theme sets the `diffEditorGutter` colors
     * (checked in Chromium: the original line number column of an inserted
     * line is empty in the inline view). Regression: it was painted red.
     */
    function testGutterIsTransparentWithoutGutterColors() {
        final original = createTextModel(['a', 'b', 'c'].join('\n'));
        final modified = createTextModel(['a', 'x', 'b'].join('\n'));
        final diffEditor = open(original, modified, {renderSideBySide: false});
        final context = widgetOf(diffEditor.getModifiedEditor()).context;
        for (name in ['gutter-insert', 'gutter-delete']) {
            final style = context.decorationStyles.get(name);
            assertNotNull(style, name);
            assertEquals(null, style.background, name + ' has no background');
        }
        // with the gutter colors of the theme, the gutter takes them
        context.themeService.defineTheme('gutter-colors', {base: 'vs-dark', inherit: true, rules: [], colors: {
            'diffEditorGutter.insertedLineBackground': '#00ff0033',
            'diffEditorGutter.removedLineBackground': '#ff000033'
        }});
        context.themeService.setTheme('gutter-colors');
        draw();
        final insert = context.decorationStyles.get('gutter-insert');
        final delete = context.decorationStyles.get('gutter-delete');
        assertEquals('diffEditorGutter.insertedLineBackground', (insert.background : Dynamic).id);
        assertEquals('diffEditorGutter.removedLineBackground', (delete.background : Dynamic).id);
        draw();
    }

    function testNarrowDiffEditorUsesTheInlineView() {
        final original = createTextModel(['a', 'b'].join('\n'));
        final modified = createTextModel(['a', 'B'].join('\n'));
        final diffEditor = open(original, modified, null, 800);
        // `useInlineViewWhenSpaceIsLimited` below `renderSideBySideInlineBreakpoint` (900)
        assertFalse(diffEditor.renderSideBySide);
        diffEditor.updateOptions({useInlineViewWhenSpaceIsLimited: false});
        draw();
        assertTrue(diffEditor.renderSideBySide);
        draw();
    }

    function testHideUnchangedRegions() {
        final original = createTextModel(lines(60).join('\n'));
        final modifiedLines = lines(60);
        modifiedLines[29] = 'changed 30';
        final modified = createTextModel(modifiedLines.join('\n'));
        final diffEditor = open(original, modified, {hideUnchangedRegions: {enabled: true}});
        final viewModel = diffEditor.getWidget().getViewModel();
        final regions = viewModel.unchangedRegions;
        // UnchangedRegion.fromDiffs: lines 1 to 26 and 34 to 60 (3 lines of context)
        assertEquals(2, regions.length);
        assertEquals('[1,27)', regions[0].getHiddenModifiedRange().toString());
        assertEquals('[34,61)', regions[1].getHiddenModifiedRange().toString());
        final m = widgetOf(diffEditor.getModifiedEditor());
        final o = widgetOf(diffEditor.getOriginalEditor());
        // the hidden lines leave 7 view lines, and a bar (24 px) per region
        assertEquals(7, m._getViewModel().getLineCount());
        assertEquals(7, o._getViewModel().getLineCount());
        var bars = 0;
        for (w in m.getWhitespaces()) {
            if (w.height == 24) {
                bars++;
            }
        }
        assertEquals(2, bars);
        draw();
        // a click on the bottom edge of the first bar shows 20 more lines
        // (revealLineCount) below it
        regions[0].showMoreBelow(20);
        assertEquals('[1,7)', regions[0].getHiddenModifiedRange().toString());
        assertEquals(27, m._getViewModel().getLineCount());
        diffEditor.showAllUnchangedRegions();
        assertEquals(60, m._getViewModel().getLineCount());
        diffEditor.collapseAllUnchangedRegions();
        assertEquals(7, m._getViewModel().getLineCount());
        // moving the cursor into a hidden region reveals its line
        m.setPosition(new Position(10, 1));
        assertEquals(true, m._getViewModel().coordinatesConverter.modelPositionIsVisible(new Position(10, 1)));
        draw();
    }

    function testEditsRecomputeTheDiff() {
        final original = createTextModel(['a', 'b', 'c'].join('\n'));
        final modified = createTextModel(['a', 'b', 'c'].join('\n'));
        final diffEditor = open(original, modified);
        assertEquals(0, diffEditor.getLineChanges().length);
        var updates = 0;
        diffEditor.onDidUpdateDiff(() -> updates++);
        modified.applyEdits([{range: new Range(2, 1, 2, 2), text: 'B'}]);
        final viewModel = diffEditor.getWidget().getViewModel();
        assertFalse(viewModel.isDiffUpToDate, 'the diff waits for the debounce');
        diffEditor.getWidget()._flush();
        assertTrue(viewModel.isDiffUpToDate);
        assertTrue(updates > 0);
        // The whole line changed: `normalizeRangeMapping` of the diff editor
        // view model extends the inner change to the start of the next line
        assertDeepEquals([{
            originalStartLineNumber: 2,
            originalEndLineNumber: 2,
            modifiedStartLineNumber: 2,
            modifiedEndLineNumber: 2,
            charChanges: [{
                originalStartLineNumber: 2,
                originalStartColumn: 1,
                originalEndLineNumber: 3,
                originalEndColumn: 1,
                modifiedStartLineNumber: 2,
                modifiedStartColumn: 1,
                modifiedEndLineNumber: 3,
                modifiedEndColumn: 1
            }]
        }], diffEditor.getLineChanges());
        draw();
    }

    function testIgnoreTrimWhitespaceOption() {
        final original = createTextModel(['a', 'b'].join('\n'));
        final modified = createTextModel(['a', '  b'].join('\n'));
        final diffEditor = open(original, modified);
        // `ignoreTrimWhitespace` is true by default
        assertTrue(diffEditor.ignoreTrimWhitespace);
        assertEquals(0, diffEditor.getLineChanges().length);
        diffEditor.updateOptions({ignoreTrimWhitespace: false});
        diffEditor.getWidget()._flush();
        assertEquals(1, diffEditor.getLineChanges().length);
        draw();
    }

    function testNavigationBetweenChanges() {
        final originalLines = lines(40);
        final modifiedLines = lines(40);
        modifiedLines[4] = 'changed 5';
        modifiedLines[19] = 'changed 20';
        modifiedLines[34] = 'changed 35';
        final diffEditor = open(createTextModel(originalLines.join('\n')), createTextModel(modifiedLines.join('\n')));
        final m = widgetOf(diffEditor.getModifiedEditor());
        m.setPosition(new Position(1, 1));
        diffEditor.goToDiff('next');
        assertEquals(5, m.getPosition().lineNumber);
        diffEditor.goToDiff('next');
        assertEquals(20, m.getPosition().lineNumber);
        diffEditor.goToDiff('next');
        assertEquals(35, m.getPosition().lineNumber);
        diffEditor.goToDiff('next');
        assertEquals(5, m.getPosition().lineNumber, 'wraps to the first change');
        diffEditor.goToDiff('previous');
        assertEquals(35, m.getPosition().lineNumber, 'wraps to the last change');
        diffEditor.goToDiff('previous');
        assertEquals(20, m.getPosition().lineNumber);
        draw();
    }

    function testTwoDiffEditorsAtOnce() {
        final a1 = createTextModel(['x', 'y'].join('\n'));
        final a2 = createTextModel(['x', 'Y', 'z'].join('\n'));
        final b1 = createTextModel(['1', '2', '3'].join('\n'));
        final b2 = createTextModel(['1', '3'].join('\n'));
        final editors:Array<CityscapeDiffEditor> = [];
        window = Window.open(app, {width: 2400, height: 400, scaleFactor: 2, autoDraw: false, bindInput: false}, DiffHost.component([{original: a1, modified: a2}, {original: b1, modified: b2}], null, e -> editors.push(e)));
        draw();
        draw();
        assertEquals(2, editors.length);
        for (e in editors) {
            e.getWidget()._flush();
        }
        draw();
        final first = editors[0].getModel().original == a1 ? editors[0] : editors[1];
        final second = first == editors[0] ? editors[1] : editors[0];
        assertEquals(1, first.getLineChanges().length);
        assertEquals(2, first.getLineChanges()[0].modifiedStartLineNumber);
        assertEquals(3, first.getLineChanges()[0].modifiedEndLineNumber);
        assertEquals(1, second.getLineChanges().length);
        assertEquals(2, second.getLineChanges()[0].originalStartLineNumber);
        assertEquals(0, second.getLineChanges()[0].modifiedEndLineNumber);
        // each one scrolls its own editors
        widgetOf(first.getModifiedEditor()).setScrollTop(0);
        assertTrue(widgetOf(first.getOriginalEditor()) != widgetOf(second.getOriginalEditor()));
        draw();
    }

    function testViewZonesOfAnEditor() {
        final model = createTextModel(['one', 'two', 'three'].join('\n'));
        var viewEntity:Null<glaze.Entity<CityscapeView>> = null;
        window = Window.open(app, {width: 800, height: 400, scaleFactor: 2, autoDraw: false, bindInput: false}, tests.view.CityscapeEditorTest.TwoEditors.component(model, model, v -> viewEntity = v, v -> {}));
        draw();
        final view:CityscapeView = viewEntity;
        final editor = view.widget;
        final lineHeight:Float = editor.getOption(EditorOption.lineHeight);
        var painted = 0;
        var zoneId = '';
        editor.changeViewZones(accessor -> {
            zoneId = accessor.addZone({afterLineNumber: 1, heightInLines: 2, paint: (window, cx, bounds) -> painted++});
        });
        assertEquals(lineHeight * 3, editor.getTopForLineNumber(2));
        assertEquals(1, editor.getWhitespaces().length);
        draw();
        assertTrue(painted > 0, 'the zone is painted');
        // the mouse over the zone targets it
        final layoutInfo = editor.getLayoutInfo();
        final target = view.mouseTargetAt(point(view.elementBounds.origin.x + layoutInfo.contentLeft + 20, view.elementBounds.origin.y + lineHeight * 1.5));
        assertEquals(MouseTargetType.CONTENT_VIEW_ZONE, target.type);
        assertEquals(zoneId, target.viewZoneData.viewZoneId);
        // a zone of a hidden line takes no space unless showInHiddenAreas
        editor.setHiddenAreas([new Range(2, 1, 2, 1)]);
        editor.changeViewZones(accessor -> {
            accessor.removeZone(zoneId);
            accessor.addZone({afterLineNumber: 1, heightInLines: 1});
        });
        assertEquals(0.0, editor.getWhitespaces()[0].height);
        editor.changeViewZones(accessor -> {
            accessor.addZone({afterLineNumber: 1, heightInLines: 1, showInHiddenAreas: true});
        });
        assertEquals(2, editor.getWhitespaces().length);
        draw();
    }

    /**
     * The diff computed off the frame (a background thread on the native
     * targets, the next frame on the web) reaches the editor.
     */
    function asyncTestDiffComputedOffTheFrame(done:() -> Void) {
        final original = createTextModel(lines(300).join('\n'));
        final modifiedLines = lines(300);
        modifiedLines[150] = 'changed 151';
        final modified = createTextModel(modifiedLines.join('\n'));
        var editor:Null<CityscapeDiffEditor> = null;
        window = Window.open(app, {width: 1200, height: 400, scaleFactor: 2, autoDraw: false, bindInput: false}, DiffHost.component([{original: original, modified: modified}], null, e -> editor = e, true));
        draw();
        draw();
        editor.waitForDiff(() -> {
            assertEquals(1, editor.getLineChanges().length);
            assertEquals(151, editor.getLineChanges()[0].modifiedStartLineNumber);
            draw();
            done();
        });
    }

}

class DiffHost extends glaze.Component {

    final models:Array<IDiffEditorModel>;
    final options:Null<IDiffEditorOptions>;
    final onEditor:(editor:CityscapeDiffEditor) -> Void;
    final defaultMode:Bool;

    public function new(models:Array<IDiffEditorModel>, options:Null<IDiffEditorOptions>, onEditor:(editor:CityscapeDiffEditor) -> Void, defaultMode:Bool = false) {
        super();
        this.models = models;
        this.options = options;
        this.onEditor = onEditor;
        this.defaultMode = defaultMode;
    }

    public function render(window:Window, cx:App):glaze.IntoElement {
        final root = div().flex().flexRow().sizeFull();
        for (i in 0...models.length) {
            final editor = CityscapeDiffEditor.component().at('diff' + i).model(models[i]).options(options).onCreate(e -> onEditor(e)).flex1();
            if (!defaultMode) {
                editor.computationMode(DiffComputationMode.Synchronous);
            }
            root.child(editor);
        }
        return root;
    }

}
