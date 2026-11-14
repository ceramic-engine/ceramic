// New code for Cityscape (not a port): what one typed character renders
// (debug counters), in an editor alone and in hosts shaped like an
// application around it.
package tests.view;

import cityscape.CityscapeEditor;
import cityscape.base.common.DebugCounters;
import cityscape.common.config.EditorOptions.IEditorOptions;
import cityscape.common.core.Selection;
import cityscape.common.model.TextModel;
import cityscape.view.CityscapeView;
import glaze.App;
import glaze.Component;
import glaze.TestDispatcher;
import glaze.Window;
import testing.TestCase;
import tests.TestTextModel.createTextModel;

import glaze.Prelude.*;

/**
 * What typing one character costs in renders, read from the debug counters
 * (`DebugCounters.hostRenders`, `DebugCounters.paintRenders`), the frames
 * drawn and the resets of the rendered line cache:
 *
 * - one frame per character (nothing notified during the draw asks for a
 *   second one);
 * - the `CityscapeEditor` host and the paint view render once each;
 * - the rendered lines are kept (the options did not change), whatever the
 *   host does: options built again at each of its renders included.
 *
 * The counts are read with Glaze's cache check off (it renders the cached
 * views a second time to compare them); the same typing then runs with the
 * check on, which compares every frame drawn in place with a full frame.
 */
class KeystrokeRenderCountTest extends TestCase {

    static inline final TEXT = 'first line\nsecond line\nthird line\nfourth line';

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

    function open(state:KeystrokeHostState):CityscapeView {
        window = Window.open(app, {width: 800, height: 400, scaleFactor: 2, autoDraw: false, bindInput: false}, KeystrokeHost.component(state));
        settle();
        final editor = state.editor;
        assertNotNull(editor);
        final view:CityscapeView = editor.getView();
        app.update(_ -> view.focusHandle.focus(window, app));
        settle();
        view.viewModel.setSelections('test', [new Selection(1, 11, 1, 11)]);
        settle();
        return view;
    }

    /** Draws until nothing is dirty; the number of frames drawn. */
    function settle():Int {
        var frames = 0;
        ceramic.App.app.flushImmediate();
        while (frames < 10 && window.drawIfDirty()) {
            frames++;
            ceramic.App.app.flushImmediate();
        }
        return frames;
    }

    /**
     * Types `text` one character at a time, a settled window between two
     * characters. Every character must cost the same; returns the counts of
     * one character.
     */
    function typeCounting(state:KeystrokeHostState, view:CityscapeView, text:String):KeystrokeCounts {
        final verify = Window.verifyCache;
        Window.verifyCache = false;
        var result:Null<KeystrokeCounts> = null;
        for (i in 0...text.length) {
            final hostRenders = DebugCounters.hostRenders;
            final paintRenders = DebugCounters.paintRenders;
            final rootRenders = state.rootRenders;
            final resets = DebugCounters.renderCacheResets;
            final inPlace = window.inPlaceFrameCount;
            view.type(text.charAt(i));
            final counts:KeystrokeCounts = {
                frames: settle(),
                host: DebugCounters.hostRenders - hostRenders,
                paint: DebugCounters.paintRenders - paintRenders,
                root: state.rootRenders - rootRenders,
                cacheResets: DebugCounters.renderCacheResets - resets,
                inPlace: window.inPlaceFrameCount - inPlace
            };
            if (result != null) {
                assertEquals(describe(result), describe(counts), 'character ' + i + ' costs what the previous one did');
            }
            result = counts;
        }
        Window.verifyCache = verify;
        // the same typing under the cache check (every frame drawn in place
        // is compared with a full frame)
        for (i in 0...text.length) {
            view.type(text.charAt(i));
            settle();
        }
        return result;
    }

    static function describe(c:KeystrokeCounts):String {
        return 'frames ${c.frames}, host renders ${c.host}, paint renders ${c.paint}, root renders ${c.root}, cache resets ${c.cacheResets}, frames in place ${c.inPlace}';
    }

    /** An editor in a host that reads nothing of it. */
    function testOneCharacterInAnEditorAlone() {
        final state = new KeystrokeHostState(createTextModel(TEXT));
        final view = open(state);
        final counts = typeCounting(state, view, 'abc');
        trace('keystroke counts, editor alone: ' + describe(counts));
        assertEquals('frames 1, host renders 1, paint renders 1, root renders 0, cache resets 0, frames in place 1', describe(counts));
        assertEquals('first lineabcabc', state.model.getLineContent(1));
    }

    /**
     * The host shows the cursor position from its own render (an observable
     * it reads) and builds the editor options again each time: it renders at
     * each character, and the editor keeps its rendered lines since the
     * options are the same by content.
     */
    function testOneCharacterWhenTheHostRendersWithOptionsBuiltAgain() {
        final state = new KeystrokeHostState(createTextModel(TEXT));
        state.rootReadsCursor = true;
        state.rebuildOptions = true;
        final view = open(state);
        final counts = typeCounting(state, view, 'abc');
        trace('keystroke counts, host rendering with options built again: ' + describe(counts));
        // (the root of the window is never rendered alone: a full frame)
        assertEquals('frames 1, host renders 1, paint renders 1, root renders 1, cache resets 0, frames in place 0', describe(counts));
        assertEquals(17, state.cursorColumn);
    }

    /**
     * The same host with the cursor position shown by a component of its
     * own: the root does not render anymore, the label still follows.
     */
    function testOneCharacterWhenAStatusComponentReadsTheCursor() {
        final state = new KeystrokeHostState(createTextModel(TEXT));
        state.rebuildOptions = true;
        final view = open(state);
        final statusRenders = state.statusRenders;
        final counts = typeCounting(state, view, 'abc');
        trace('keystroke counts, status component reading the cursor: ' + describe(counts));
        assertEquals('frames 1, host renders 1, paint renders 1, root renders 0, cache resets 0, frames in place 1', describe(counts));
        assertEquals(17, state.cursorColumn);
        assertEquals('Col 17', state.statusText, 'the status component follows the cursor');
        assertTrue(state.statusRenders > statusRenders);
    }

}

typedef KeystrokeCounts = {
    var frames:Int;
    var host:Int;
    var paint:Int;
    var root:Int;
    var cacheResets:Int;
    var inPlace:Int;
}

/** What the host of `KeystrokeRenderCountTest` shows, and what it rendered. */
class KeystrokeHostState implements tracker.Observable {

    public final model:TextModel;

    @observe public var cursorColumn:Int = 1;

    /** The root shows the cursor column itself (else a status component does). */
    public var rootReadsCursor:Bool = false;

    /** The options are a new object, with the same content, at each render of the root. */
    public var rebuildOptions:Bool = false;

    public var editor:Null<CityscapeEditor> = null;
    public var rootRenders:Int = 0;
    public var statusRenders:Int = 0;
    public var statusText:String = '';

    public final options:IEditorOptions = buildOptions();

    public function new(model:TextModel) {
        this.model = model;
    }

    public static function buildOptions():IEditorOptions {
        return {
            fontSize: 14,
            lineHeight: 21,
            lineNumbers: 'on',
            padding: {top: 6},
            scrollBeyondLastLine: false,
            stickyScroll: {enabled: true},
            guides: {indentation: true},
            inlayHints: {enabled: 'on', padding: true},
            semanticHighlighting: {enabled: true},
            renderLineHighlight: 'all'
        };
    }

}

/** An application around an editor: the editor above a status line. */
class KeystrokeHost extends Component {

    final state:KeystrokeHostState;

    public function new(state:KeystrokeHostState) {
        super();
        this.state = state;
    }

    override public function init(window:Window, cx:App):Void {}

    public function render(window:Window, cx:App):glaze.IntoElement {
        final state = this.state;
        state.rootRenders++;
        // The interface around the editor (Glaze renders a view alone only
        // when it is less than half of the frame)
        final toolbar = div().flex().flexRow().flexWrap().h(px(48)).flexShrink0();
        for (i in 0...60) {
            toolbar.child(div().id('tool-' + i).w(px(12)).h(px(12)).onClick(_ -> {}));
        }
        final root = div().flex().flexCol().sizeFull()
            .child(toolbar)
            .child(CityscapeEditor.component().at('editor').model(state.model)
                .options(state.rebuildOptions ? KeystrokeHostState.buildOptions() : state.options)
                .onCreate(e -> {
                    state.editor = e;
                    e.onDidChangeCursorPosition(event -> state.cursorColumn = event.position.column);
                })
                .flex1());
        if (state.rootReadsCursor) {
            root.child(div().h(px(24)).flexShrink0().child('Col ' + state.cursorColumn));
        }
        else {
            root.child(KeystrokeStatus.component(state));
        }
        return root;
    }

}

/** The status line as a component of its own: it alone reads the cursor. */
class KeystrokeStatus extends Component {

    final state:KeystrokeHostState;

    public function new(state:KeystrokeHostState) {
        super();
        this.state = state;
    }

    override public function init(window:Window, cx:App):Void {}

    public function render(window:Window, cx:App):glaze.IntoElement {
        final state = this.state;
        state.statusRenders++;
        state.statusText = 'Col ' + state.cursorColumn;
        return div().h(px(24)).wFull().flexShrink0().overflowHidden()
            .child(div().w(px(120)).flexShrink0().child(state.statusText));
    }

}
