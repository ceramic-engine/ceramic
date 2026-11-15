// New code for Cityscape (not a port): the editor's cached rendering does not
// outlive a focus change or a layout change.
package tests.view;

import cityscape.CityscapeEditor;
import cityscape.common.config.EditorOptions.EditorOption;
import cityscape.common.config.EditorOptions.IEditorOptions;
import cityscape.common.core.Selection;
import cityscape.common.model.TextModel;
import cityscape.view.CityscapeView;
import glaze.App;
import glaze.Component;
import glaze.FocusHandle;
import glaze.Keystroke;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.Root;
import testing.TestCase;
import tests.TestTextModel.createTextModel;

import glaze.Prelude.*;

using glaze.kit.WindowExt;

/**
 * The editor paints in a view of its own (`CityscapeView.paintView`), which
 * a window keeps in its cache while nothing notifies it. Its cached
 * rendering holds the editor's input handler and hitboxes, so it must be
 * notified when the focus enters or leaves the editor and when the layout
 * of the editor changes:
 *
 * - a dialog (or any element) taking the focus over the editor: the text
 *   typed next must not reach the editor behind it;
 * - a font size or a wrapping change through the options: the hitboxes
 *   move with the lines.
 *
 * The suite runs with `glaze_verify_cache`: a cached rendering that differs
 * from a fresh one fails the test by itself (`testing.TestRunner`).
 */
class StaleEditorCacheTest extends TestCase {

    var app:App;
    var window:Null<Window> = null;
    var state:StaleCacheHostState;

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

    function settle():Int {
        var frames = 0;
        ceramic.App.app.flushImmediate();
        while (frames < 10 && window.drawIfDirty()) {
            frames++;
            ceramic.App.app.flushImmediate();
        }
        return frames;
    }

    /** A key typed by the user: its character goes to the input handler of the frame drawn last. */
    function typeKey(source:String):Void {
        app.update(cx -> window.dispatchKeystroke(Keystroke.parse(source), cx));
        settle();
    }

    /** Turns the cache check off for this test: cached views are reused as in an application. */
    function useCache():Void {
        #if glaze_verify_cache
        glaze.Window.verifyCache = false;
        #end
    }

    function open():CityscapeView {
        state = new StaleCacheHostState(createTextModel('first line\nsecond line\nthird line'));
        app.update(cx -> state.other = cx.focusHandle());
        window = Window.open(app, {width: 800, height: 400, scaleFactor: 2, autoDraw: false, bindInput: false},
            (_, _) -> Root.component().child(StaleCacheHost.component(state)));
        settle();
        final editor = state.editor;
        assertNotNull(editor);
        final view:CityscapeView = editor.getView();
        app.update(_ -> view.focusHandle.focus(window, app));
        settle();
        view.viewModel.setSelections('test', [new Selection(1, 1, 1, 1)]);
        settle();
        return view;
    }

    function testTypingReachesTheFocusedEditor() {
        open();
        typeKey('a');
        assertEquals('afirst line', state.model.getLineContent(1));
    }

    function testTextTypedInADialogDoesNotReachTheEditor() {
        scenarioTextTypedInADialogDoesNotReachTheEditor();
    }

    /** The same with the cache really used (the check renders every view for real). */
    function testTextTypedInADialogDoesNotReachTheEditorWithTheCacheUsed() {
        useCache();
        scenarioTextTypedInADialogDoesNotReachTheEditor();
    }

    function scenarioTextTypedInADialogDoesNotReachTheEditor() {
        final view = open();
        typeKey('a');
        assertEquals('afirst line', state.model.getLineContent(1));
        app.update(cx -> window.openDialog(cx, (dialog, _, _) -> dialog.title('Hello').child(div().h(px(40)))));
        settle();
        assertTrue(window.hasActiveDialog(app));
        assertFalse(view.focusHandle.isFocused(window), 'the dialog took the focus');
        typeKey('b');
        typeKey('c');
        assertEquals('afirst line', state.model.getLineContent(1), 'the editor behind the dialog got nothing');
        // back in the editor once the dialog is closed
        app.update(cx -> window.closeDialog(cx));
        settle();
        app.update(_ -> view.focusHandle.focus(window, app));
        settle();
        typeKey('d');
        assertEquals('adfirst line', state.model.getLineContent(1));
    }

    /** The dialog is opened by a view while it renders (a focus change asked while drawing refreshes nothing). */
    function testADialogOpenedWhileRenderingTakesTheInputToo() {
        scenarioADialogOpenedWhileRenderingTakesTheInputToo();
    }

    /** The same with the cache really used (the check renders every view for real). */
    function testADialogOpenedWhileRenderingTakesTheInputTooWithTheCacheUsed() {
        useCache();
        scenarioADialogOpenedWhileRenderingTakesTheInputToo();
    }

    function scenarioADialogOpenedWhileRenderingTakesTheInputToo() {
        final view = open();
        state.dialogWanted = true;
        settle();
        assertTrue(window.hasActiveDialog(app));
        settle();
        assertFalse(view.focusHandle.isFocused(window), 'the dialog took the focus');
        typeKey('b');
        assertEquals('first line', state.model.getLineContent(1), 'the editor behind the dialog got nothing');
    }

    /**
     * Another element takes the focus while a view renders, without the
     * editor being told (an inline field), then the editor takes it back
     * with its own `focus()`, from a render too.
     */
    function testAnotherElementTakingTheFocusWhileRendering() {
        scenarioAnotherElementTakingTheFocusWhileRendering(true);
    }

    /** The same with the cache really used (the check renders every view for real). */
    function testAnotherElementTakingTheFocusWhileRenderingWithTheCacheUsed() {
        useCache();
        scenarioAnotherElementTakingTheFocusWhileRendering(true);
    }

    /**
     * The focus comes back through the bare focus handle while a view
     * renders: Glaze ignores the refresh a focus change asks while drawing
     * (GPUI's rule), so the frame being drawn still holds the cached
     * painting. The focus listener of the view notifies it once that frame
     * is drawn, and the next frame has the input handler. Run with the cache
     * used: the check would report the frame in between.
     */
    function testTheFocusGivenBackThroughTheHandleWhileRendering() {
        useCache();
        final notifications = cityscape.base.common.DebugCounters.focusNotifications;
        scenarioAnotherElementTakingTheFocusWhileRendering(false);
        assertTrue(cityscape.base.common.DebugCounters.focusNotifications >= notifications + 2, 'the view was notified when the focus left and when it came back');
    }

    function scenarioAnotherElementTakingTheFocusWhileRendering(throughEditor:Bool) {
        final view = open();
        state.focusOther = true;
        settle();
        assertTrue(state.other.isFocused(window));
        typeKey('b');
        assertEquals('first line', state.model.getLineContent(1), 'the editor that lost the focus got nothing');
        // and back, from a render too
        state.focusOther = false;
        if (throughEditor) state.focusEditor = true;
        else state.focusHandle = true;
        settle();
        assertTrue(view.focusHandle.isFocused(window));
        typeKey('c');
        assertEquals('cfirst line', state.model.getLineContent(1));
    }

    /**
     * An inline field of the application: a kit input created by a
     * component, which takes the focus in a deferred call of its `init`.
     */
    function testAnInlineFieldTakingTheFocus() {
        scenarioAnInlineFieldTakingTheFocus();
    }

    function testAnInlineFieldTakingTheFocusWithTheCacheUsed() {
        useCache();
        scenarioAnInlineFieldTakingTheFocus();
    }

    function scenarioAnInlineFieldTakingTheFocus() {
        final view = open();
        state.inlineField = true;
        settle();
        settle();
        assertFalse(view.focusHandle.isFocused(window), 'the field took the focus');
        typeKey('b');
        typeKey('c');
        assertEquals('first line', state.model.getLineContent(1), 'the editor got nothing');
        assertNotNull(state.field);
        assertEquals('bc', app.update(cx -> state.field.read(cx).value()));
        // the field goes away, the editor takes the focus back
        state.inlineField = false;
        settle();
        app.update(_ -> view.focus());
        settle();
        typeKey('d');
        assertEquals('dfirst line', state.model.getLineContent(1));
    }

    function testAFontSizeChangeThroughTheOptions() {
        scenarioAFontSizeChangeThroughTheOptions();
    }

    /** The same with the cache really used (the check renders every view for real). */
    function testAFontSizeChangeThroughTheOptionsWithTheCacheUsed() {
        useCache();
        scenarioAFontSizeChangeThroughTheOptions();
    }

    function scenarioAFontSizeChangeThroughTheOptions() {
        final view = open();
        final editor = state.editor;
        assertEquals(14., editor.getOption(EditorOption.fontSize));
        for (size in [18, 24, 12, 14]) {
            state.fontSize = size;
            settle();
            assertEquals((size : Float), editor.getOption(EditorOption.fontSize));
            // the pointer over the lines: their hitboxes are the ones of this frame
            window.dispatchEvent(new glaze.MouseMoveEvent(new glaze.Point(200, 100 + size), null, glaze.Modifiers.none()), app);
            settle();
        }
    }

    function testAWrappingChangeThroughTheOptions() {
        scenarioAWrappingChangeThroughTheOptions();
    }

    /** The same with the cache really used (the check renders every view for real). */
    function testAWrappingChangeThroughTheOptionsWithTheCacheUsed() {
        useCache();
        scenarioAWrappingChangeThroughTheOptions();
    }

    function scenarioAWrappingChangeThroughTheOptions() {
        open();
        final editor = state.editor;
        state.model.setValue('a long line that wraps ' + [for (i in 0...40) 'word' + i].join(' ') + '\nsecond line\n\tthird line that wraps too ' + [for (i in 0...40) 'word' + i].join(' '));
        settle();
        for (wrap in ['on', 'off', 'on']) {
            state.wordWrap = wrap;
            settle();
            assertEquals(wrap, Reflect.field(editor.getRawOptions(), 'wordWrap'));
        }
        state.wrappingIndentColumns = 4;
        settle();
        state.wrappingIndentColumns = 0;
        settle();
    }

}

class StaleCacheHostState implements tracker.Observable {

    public final model:TextModel;

    @observe public var fontSize:Int = 14;
    @observe public var wordWrap:String = 'off';
    @observe public var wrappingIndentColumns:Int = 0;
    @observe public var dialogWanted:Bool = false;
    @observe public var focusOther:Bool = false;
    @observe public var focusEditor:Bool = false;
    @observe public var focusHandle:Bool = false;
    @observe public var inlineField:Bool = false;

    public var field:Null<glaze.Entity<glaze.kit.base.input.InputState>> = null;

    public var dialogOpened:Bool = false;

    public var other:FocusHandle;

    public var editor:Null<CityscapeEditor> = null;

    /** One function for every render: a new closure would render the editor each time. */
    public final created:(CityscapeEditor) -> Void;

    public function new(model:TextModel) {
        this.model = model;
        created = e -> editor = e;
    }

}

/**
 * The editor under a toolbar, as an application hosts it: the options are
 * built from observable settings at each render.
 */
class StaleCacheHost extends Component {

    final state:StaleCacheHostState;

    public function new(state:StaleCacheHostState) {
        super();
        this.state = state;
    }

    override public function init(window:Window, cx:App):Void {}

    public function render(window:Window, cx:App):glaze.IntoElement {
        final state = this.state;
        final options:IEditorOptions = cast {
            fontSize: state.fontSize,
            lineHeight: 0,
            wordWrap: state.wordWrap,
            wrappingIndent: 'indent',
            scrollBeyondLastLine: false
        };
        if (state.dialogWanted && !state.dialogOpened) {
            state.dialogOpened = true;
            window.openDialog(cx, (dialog, _, _) -> dialog.title('Hello').child(div().h(px(40))));
        }
        if (state.focusOther) {
            state.other.focus(window, cx);
        }
        else if (state.focusEditor && state.editor != null) {
            state.editor.focus();
        }
        else if (state.focusHandle && state.editor != null) {
            final view:CityscapeView = state.editor.getView();
            view.focusHandle.focus(window, cx);
        }
        final top = div().id('other').trackFocus(state.other).h(px(48)).flexShrink0();
        if (state.inlineField) {
            top.child(StaleCacheField.component(state));
        }
        return div().flex().flexCol().sizeFull()
            .child(top)
            .child(CityscapeEditor.component().at('editor').model(state.model).options(options)
                .wrappingIndentColumns(state.wrappingIndentColumns)
                .onCreate(state.created).flex1());
    }

}

/** An inline field: a kit input focused in a deferred call of `init`, as an application does. */
class StaleCacheField extends Component {

    final state:StaleCacheHostState;

    public function new(state:StaleCacheHostState) {
        super();
        this.state = state;
    }

    override public function init(window:Window, cx:App):Void {
        final created = cx.newEntity(c -> new glaze.kit.base.input.InputState(window, c));
        state.field = created;
        window.defer(cx, (window, cx) -> {
            created.update(cx, (input, c) -> {
                input.focus(window, cast c);
                return null;
            });
        });
    }

    public function render(window:Window, cx:App):glaze.IntoElement {
        return glaze.kit.input.Input.component(state.field);
    }

}
