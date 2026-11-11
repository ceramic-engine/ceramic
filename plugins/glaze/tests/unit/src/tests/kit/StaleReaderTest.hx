package tests.kit;

import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Keystroke;
import glaze.Model;
import glaze.Modifiers;
import glaze.MouseDownEvent;
import glaze.MouseMoveEvent;
import glaze.MouseUpEvent;
import glaze.OperatingSystem;
import glaze.Point;
import glaze.Range;
import glaze.Render;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.WindowState;
import glaze.kit.base.Root;
import glaze.kit.base.TextSelection;
import glaze.kit.base.TextSelectionScopeId;
import glaze.kit.base.WindowSelectionState;
import glaze.kit.base.input.InputBaseState;
import glaze.kit.base.input.TextareaState;
import glaze.kit.base.text.TextViewState;
import glaze.kit.input.InputOverlays;
import glaze.kit.input.SearchPanel;
import glaze.kit.input.Textarea;
import glaze.kit.text.TextView;
import glaze.kit.theme.Theme;
import glaze.kit.theme.ThemeMode;
import glaze.scene.SceneDump;
import testing.TestCase;

import glaze.Prelude.*;

using glaze.kit.WindowExt;
using glaze.kit.base.input.InputSearchExt;

/**
 * Views that read another entity's plain fields in their render, and the
 * frames the port draws after that entity is notified (view caching on, in
 * place rendering on: the defaults), compared with the frame GPUI draws
 * (a reference window rendering every view after each step).
 *
 * Each page is a `Root` holding a `StalePage` view: a selectable `TextView`
 * ("Hello world") and a `StaleField` view holding a searchable `Textarea`
 * (whose search panel is a child view of the field). The scenarios:
 *
 * - A. `SearchPanel.render` reads `InputBaseState.replaceable`, `disabled`
 *   and `readonly` (through `isReplaceable`); the input's component sets
 *   `disabled` and `readonly` on the state while the field renders.
 * - B. `SearchPanel.session` is a copy made by `InputOverlayHost.sync`
 *   while the field renders, without a notify of the panel.
 * - C1. The field reads `searchSession.open` while it renders; `openSearch`
 *   notifies the state only.
 * - C2. `Root.render` calls `WindowState.prepare`, which activates the text
 *   selection scope of the topmost dialog; `openDialog` notifies the window
 *   state only, whose layer keeps its bounds.
 *
 * Variants: the defaults with the suite's cache check (`glaze_verify_cache`,
 * which renders a reusable view for real and reports a difference), the
 * defaults without the check (what an application runs), in place rendering
 * off, and view caching off. The cache check messages are collected here
 * and fail the test that gets one, with the message.
 *
 * Set `GLAZE_STALE_LOG=1` to print what each frame did.
 */
@:access(glaze.kit.input.SearchPanel)
@:access(glaze.kit.input.InputOverlayHost)
@:access(glaze.kit.input.InputOverlayRegistry)
@:access(glaze.kit.WindowState)
@:access(glaze.kit.base.WindowSelectionState)
class StaleReaderTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final windows:Array<Window> = [];

    var pages:Array<StalePage> = [];

    final messages:Array<String> = [];

    var savedHandler:Null<(String) -> Void> = null;

    var savedVerify:Bool = false;

    var savedFailures:Int = 0;

    static final verbose:Bool = Sys.getEnv('GLAZE_STALE_LOG') == '1';

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.update(cx -> {
            cx.setReduceMotion(true);
            Theme.setMode(ThemeMode.Light, cx);
            Theme.setScrollbarMode(Always, cx);
            // The port's text system only has Inter and JetBrains Mono.
            Theme.globalMut(cx).monoFontFamily = 'JetBrains Mono';
            Theme.syncBase(cx);
        });
        messages.resize(0);
        savedHandler = Window.onCacheVerificationFailure;
        savedVerify = Window.verifyCache;
        savedFailures = Window.cacheVerificationFailures;
        Window.onCacheVerificationFailure = message -> messages.push(message);
        flushImmediate();
    }

    override function teardown() {
        for (window in windows) {
            window.destroy();
        }
        windows.resize(0);
        pages = [];
        Window.onCacheVerificationFailure = savedHandler;
        Window.verifyCache = savedVerify;
        Window.cacheVerificationFailures = savedFailures;
        flushImmediate();
    }

    inline function flushImmediate():Void {
        ceramic.App.app.flushImmediate();
    }

    function log(line:String):Void {
        if (verbose) {
            Sys.println('    [stale] $line');
        }
    }

/// Fixture

    /**
     * The window drawn by the variant and its reference. `Default`: the
     * suite's settings (view caching, in place rendering, the cache check as
     * the runner set it). `NoVerify`: the same without the cache check.
     * `NoInPlace`: `inPlaceRendering` off. `NoCaching`: view caching off.
     */
    function openPair(variant:Variant, name:String):StalePage {
        currentCase = '$name-${variantName(variant)}';
        log('--- $currentCase');
        Window.verifyCache = variant == Default ? savedVerify : false;
        final page = open(variant != NoCaching, variant != NoInPlace, false);
        open(false, true, true);
        settle('opened');
        return page;
    }

    function open(caching:Bool, inPlace:Bool, reference:Bool):StalePage {
        var page:Null<StalePage> = null;
        final window = Window.open(app, {width: 512, height: 512, scaleFactor: 2, autoDraw: false, active: false, bindInput: false, viewCaching: caching}, (window, cx) -> {
            final entity = cx.newEntity((c:Context<StalePage>) -> page = new StalePage(window, c));
            page.entity = entity;
            return Root.component().child(entity);
        });
        window.viewCachingDisabled = !caching;
        window.inPlaceRendering = inPlace;
        windows.push(window);
        page.window = window;
        page.reference = reference;
        window.draw();
        app.update(_ -> window.setActive(true));
        dispatcher.runUntilParked();
        pages.push(page);
        return page;
    }

    /** One step on every page, in one update. */
    function each(fn:(StalePage, App) -> Void):Void {
        app.update(cx -> {
            for (page in pages) fn(page, cx);
        });
        dispatcher.runUntilParked();
    }

    /**
     * The next frame: the variant's window draws if it is dirty (like the
     * GlazeSystem every frame); the reference renders every view again.
     * Returns whether the variant's window drew.
     */
    function frame(step:String):Bool {
        flushImmediate();
        var drew = false;
        for (page in pages) {
            final window = page.window;
            if (page.reference) {
                app.update(_ -> {
                    window.refresh();
                    window.draw();
                });
            }
            else {
                final fallbacks = window.inPlaceFallbackCount;
                final count = window.drawCount;
                window.drawIfDirty();
                drew = window.drawCount != count;
                log('$step: ' + (drew
                    ? 'drew (rendered ${window.renderedViewCount}: ${renderedNames(page)}; reused ${window.reusedViewCount}, in place ${window.inPlaceViewCount}, fallbacks +${window.inPlaceFallbackCount - fallbacks})'
                    : 'window clean, no frame') + ', quads ${window.renderedScene().quads.length}, cache messages ${messages.length}' + (messages.length > 0 ? ': ' + messages[messages.length - 1] : ''));
            }
        }
        dispatcher.runUntilParked();
        return drew;
    }

    /** Frames until every window is clean (at most 8). */
    function settle(step:String):Void {
        for (i in 0...8) {
            flushImmediate();
            var any = false;
            for (page in pages) {
                if (page.window.dirty) any = true;
            }
            if (!any) return;
            frame('$step (settle $i)');
        }
    }

    /**
     * A later frame caused by something unrelated: a sibling view of the
     * field is notified (its render reads nothing of the inputs).
     */
    function tick(step:String):Bool {
        each((page, cx) -> page.marker.update(cx, (_, cx) -> cx.notify()));
        return frame(step);
    }

    static final tilePlace = ~/("tile":\s*\{\s*"texture_index":\s*\d+,\s*"bounds":\s*\{\s*"x":\s*)\d+(,\s*"y":\s*)\d+/g;

    /**
     * The scene of the window's last frame. The place of a glyph or icon in
     * the atlas depends on the order the two windows rasterized them: it is
     * left out (its size stays).
     */
    static function dump(window:Window):String {
        final json = SceneDump.toJson(window.renderedScene(), window.viewportSize().width * 2, window.viewportSize().height * 2);
        return tilePlace.map(json, r -> r.matched(1) + '0' + r.matched(2) + '0');
    }

    /** The names of the views rendered by the last frame of the page's window (debug log). */
    function renderedNames(page:StalePage):String {
        final names = new Map<Int, String>();
        names.set(page.entity.entityId(), 'page');
        names.set(page.field.entityId(), 'field');
        names.set(page.marker.entityId(), 'marker');
        names.set(page.text.entityId(), 'text');
        names.set(page.area.entityId(), 'state');
        final state = WindowState.tryRead(page.window);
        if (state != null) names.set(state.entityId, 'windowState');
        final panel = panel(page);
        if (panel != null) names.set(panel.entityId(), 'panel');
        final result = [];
        for (id in @:privateAccess page.window.renderedViews.keys()) {
            result.push(names.exists(id) ? names.get(id) : 'view $id');
        }
        result.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
        return result.join(' ');
    }

    /** Whether the view is in the dispatch tree of the window's last frame. */
    function drawn(page:StalePage, id:Int):Bool {
        return @:privateAccess page.window.renderedFrame.dispatchTree.viewNodeId(id) != -1;
    }

    static final dumpDir:Null<String> = Sys.getEnv('GLAZE_STALE_DUMP');

    /** The case and variant running (dump file names) */
    var currentCase:String = '';

    static function variantName(variant:Variant):String {
        return switch variant {
            case Default: 'Default';
            case NoVerify: 'NoVerify';
            case NoInPlace: 'NoInPlace';
            case _: 'NoCaching';
        }
    }

    /** The variant's scene equals the reference's. */
    function assertSameScene(step:String, ?pos:haxe.PosInfos):Bool {
        final a = dump(pages[0].window);
        final b = dump(pages[1].window);
        if (a != b) {
            final linesA = a.split('\n');
            final linesB = b.split('\n');
            var line = 0;
            while (line < linesA.length && line < linesB.length && linesA[line] == linesB[line]) {
                line++;
            }
            final from = Std.int(Math.max(0, line - 3));
            final context = [for (i in from...line + 3) '$i: variant=${linesA[i]} | reference=${linesB[i]}'].join('\n');
            final quads = '${pages[0].window.renderedScene().quads.length} quads against ${pages[1].window.renderedScene().quads.length}, ${pages[0].window.renderedScene().monochromeSprites.length} glyphs against ${pages[1].window.renderedScene().monochromeSprites.length}';
            log('$step: scenes differ ($quads)');
            if (dumpDir != null) {
                final name = ~/[^a-zA-Z0-9]+/g.replace('$currentCase-$step', '-');
                sys.io.File.saveContent('$dumpDir/$name-variant.json', a);
                sys.io.File.saveContent('$dumpDir/$name-reference.json', b);
            }
            fail('$step: the scene differs from a full render ($quads), line $line\n$context', pos);
            return false;
        }
        log('$step: same scene as the reference');
        assertTrue(true);
        return true;
    }

    /** No difference reported by the cache check so far in this test. */
    function assertNoCacheMessage(step:String, ?pos:haxe.PosInfos):Void {
        if (messages.length > 0) {
            fail('$step: the cache check found a stale cached rendering:\n' + messages.join('\n'), pos);
            messages.resize(0);
        }
        else {
            assertTrue(true);
        }
    }

    /** The search panel of a page's textarea (null before the first frame with the search open). */
    function panel(page:StalePage):Null<Entity<SearchPanel>> {
        final registry = InputOverlayRegistry.get(app);
        if (registry == null) return null;
        final entry = registry.hosts.get(page.area.entityId());
        return entry != null ? @:privateAccess entry.host.search : null;
    }

    function openSearch():Void {
        each((page, cx) -> page.area.update(cx, (s, cx) -> s.openSearch(false, cast cx)));
        settle('search open');
        final p = panel(pages[0]);
        log('search open: panel ' + (p == null ? 'none' : 'open=${p.read(app).session.open} drawn=${drawn(pages[0], p.entityId())} field drawn=${drawn(pages[0], pages[0].field.entityId())}'));
        assertSameScene('search open');
        for (page in pages) assertTrue(page.area.read(app).searchSession.open, 'the search session is open');
    }

    function focusEditor():Void {
        each((page, cx) -> page.area.update(cx, (s, cx) -> s.focus(page.window, cast cx)));
        settle('editor focused');
        assertSameScene('editor focused');
    }

    function isReplaceable(page:StalePage):Bool {
        return page.area.read(app).isReplaceable();
    }

/// A. The panel reads `disabled`, `readonly` and `replaceable` of the state

    /**
     * The field sets the input's `disabled` prop (the component writes it to
     * the state while the field renders, like gpui-kit's `Input::render`).
     * The panel's replace button must go.
     */
    function caseDisabled(variant:Variant):Void {
        final page = openPair(variant, 'disabled');
        openSearch();
        assertTrue(isReplaceable(page), 'precondition: replaceable');
        each((p, cx) -> {
            p.disabled = true;
            p.notifyField(cx);
        });
        final drew = frame('disabled');
        assertTrue(drew, 'disabled: the next frame is drawn');
        assertFalse(isReplaceable(page), 'disabled: the state is not replaceable');
        final same = assertSameScene('disabled');
        assertNoCacheMessage('disabled');
        if (!same) {
            // A later frame caused by something else
            tick('disabled, later frame');
            assertSameScene('disabled, later frame');
            assertNoCacheMessage('disabled, later frame');
        }
    }

    function testDisabledDefault() caseDisabled(Default);
    function testDisabledNoVerify() caseDisabled(NoVerify);
    function testDisabledNoInPlace() caseDisabled(NoInPlace);
    function testDisabledNoCaching() caseDisabled(NoCaching);

    /** The same with the `readonly` prop (which also leaves replace mode). */
    function caseReadonly(variant:Variant):Void {
        final page = openPair(variant, 'readonly');
        openSearch();
        assertTrue(isReplaceable(page), 'precondition: replaceable');
        each((p, cx) -> {
            p.readonly = true;
            p.notifyField(cx);
        });
        final drew = frame('readonly');
        assertTrue(drew, 'readonly: the next frame is drawn');
        assertFalse(isReplaceable(page), 'readonly: the state is not replaceable');
        final same = assertSameScene('readonly');
        assertNoCacheMessage('readonly');
        if (!same) {
            tick('readonly, later frame');
            assertSameScene('readonly, later frame');
            assertNoCacheMessage('readonly, later frame');
        }
    }

    function testReadonlyDefault() caseReadonly(Default);
    function testReadonlyNoVerify() caseReadonly(NoVerify);
    function testReadonlyNoInPlace() caseReadonly(NoInPlace);
    function testReadonlyNoCaching() caseReadonly(NoCaching);

    /**
     * `replaceable` turned off on the state, outside any draw, with a notify
     * of the state (there is no prop for it: `withReplaceable` is a builder).
     */
    function caseReplaceable(variant:Variant):Void {
        final page = openPair(variant, 'replaceable');
        openSearch();
        assertTrue(isReplaceable(page), 'precondition: replaceable');
        each((p, cx) -> p.area.update(cx, (s, cx) -> {
            s.withReplaceable(false);
            cx.notify();
        }));
        final drew = frame('replaceable off');
        assertTrue(drew, 'replaceable off: the next frame is drawn');
        assertFalse(isReplaceable(page), 'replaceable off: the state is not replaceable');
        final same = assertSameScene('replaceable off');
        assertNoCacheMessage('replaceable off');
        if (!same) {
            tick('replaceable off, later frame');
            assertSameScene('replaceable off, later frame');
            assertNoCacheMessage('replaceable off, later frame');
        }
    }

    function testReplaceableDefault() caseReplaceable(Default);
    function testReplaceableNoVerify() caseReplaceable(NoVerify);
    function testReplaceableNoInPlace() caseReplaceable(NoInPlace);
    function testReplaceableNoCaching() caseReplaceable(NoCaching);

/// B. The panel's session is a copy made while the field renders

    /**
     * Typing in the editor with the search open and a query that matches:
     * the match count label must follow.
     */
    function caseTyping(variant:Variant):Void {
        final page = openPair(variant, 'typing');
        // Select the first word, so the search opens with the query "foo"
        each((p, cx) -> p.area.update(cx, (s, cx) -> s.setSelectedRange(new Range(0, 3), cast cx)));
        settle('selected');
        openSearch();
        final before = page.area.read(app).searchSession.matcher.label();
        assertEquals('1/3', before, 'precondition: 3 matches of "foo"');
        final panelBefore = panel(page);
        assertTrue(panelBefore != null, 'precondition: the panel exists (the field rendered since the search opened)');
        if (panelBefore == null) return;
        assertEquals(before, panelBefore.read(app).session.matcher.label(), 'precondition: the panel shows the count');

        // Back to the editor, then type another match at the end of the text
        focusEditor();
        each((p, cx) -> p.area.update(cx, (s, cx) -> s.setSelectedRange(new Range(s.text.len(), s.text.len()), cast cx)));
        settle('cursor at end');
        each((p, cx) -> {
            final handler = p.window.peekInputHandler();
            assertTrue(handler != null, 'the editor has the input handler');
            if (handler != null) handler.replaceTextInRange(null, ' foo');
        });
        final drew = frame('typed');
        assertTrue(drew, 'typed: the next frame is drawn');
        final after = page.area.read(app).searchSession.matcher.label();
        assertEquals('1/4', after, 'typed: the state counts 4 matches');
        final same = assertSameScene('typed');
        assertEquals(after, panel(page).read(app).session.matcher.label(), 'typed: the panel holds the new count');
        assertNoCacheMessage('typed');
        if (!same) {
            tick('typed, later frame');
            assertSameScene('typed, later frame');
            assertNoCacheMessage('typed, later frame');
        }
    }

    function testTypingDefault() caseTyping(Default);
    function testTypingNoVerify() caseTyping(NoVerify);
    function testTypingNoInPlace() caseTyping(NoInPlace);
    function testTypingNoCaching() caseTyping(NoCaching);

/// C1. The field reads `searchSession.open`

    /** The search shortcut through the window, with the editor focused. */
    function caseShortcut(variant:Variant):Void {
        final page = openPair(variant, 'shortcut');
        focusEditor();
        final quads = page.window.renderedScene().quads.length;
        each((p, cx) -> p.window.dispatchKeystroke(Keystroke.parseWithOs('secondary-f', OperatingSystem.current), cx));
        final drew = frame('shortcut');
        assertTrue(page.area.read(app).searchSession.open, 'shortcut: the session is open');
        assertTrue(drew, 'shortcut: the next frame is drawn');
        assertTrue(page.window.renderedScene().quads.length > quads, 'shortcut: the panel is in the scene (${page.window.renderedScene().quads.length} quads, $quads before)');
        final same = assertSameScene('shortcut');
        assertNoCacheMessage('shortcut');
        if (!same) {
            tick('shortcut, later frame');
            assertSameScene('shortcut, later frame');
            assertNoCacheMessage('shortcut, later frame');
        }
        // The frames that follow (focus moves to the search input)
        settle('shortcut settled');
        assertSameScene('shortcut settled');
        assertNoCacheMessage('shortcut settled');
    }

    function testShortcutDefault() caseShortcut(Default);
    function testShortcutNoVerify() caseShortcut(NoVerify);
    function testShortcutNoInPlace() caseShortcut(NoInPlace);
    function testShortcutNoCaching() caseShortcut(NoCaching);

    /** `openSearch` called on the state (the public method), editor not focused. */
    function caseOpenSearchMethod(variant:Variant):Void {
        final page = openPair(variant, 'openSearch');
        final quads = page.window.renderedScene().quads.length;
        each((p, cx) -> p.area.update(cx, (s, cx) -> s.openSearch(false, cast cx)));
        final drew = frame('openSearch');
        assertTrue(drew, 'openSearch: the next frame is drawn');
        assertTrue(page.window.renderedScene().quads.length > quads, 'openSearch: the panel is in the scene (${page.window.renderedScene().quads.length} quads, $quads before)');
        final same = assertSameScene('openSearch');
        assertNoCacheMessage('openSearch');
        if (!same) {
            tick('openSearch, later frame');
            assertSameScene('openSearch, later frame');
            assertNoCacheMessage('openSearch, later frame');
        }
        settle('openSearch settled');
        assertSameScene('openSearch settled');
        assertNoCacheMessage('openSearch settled');
    }

    function testOpenSearchDefault() caseOpenSearchMethod(Default);
    function testOpenSearchNoVerify() caseOpenSearchMethod(NoVerify);
    function testOpenSearchNoInPlace() caseOpenSearchMethod(NoInPlace);
    function testOpenSearchNoCaching() caseOpenSearchMethod(NoCaching);

/// C2. Root.render activates the selection scope of the dialog

    function activeScope(page:StalePage):Null<TextSelectionScopeId> {
        final state = WindowSelectionState.existing(page.window, app);
        return state != null ? state.read(app).activeScope : null;
    }

    function dialogScope(page:StalePage):TextSelectionScopeId {
        return WindowState.read(page.window).activeTextSelectionScope();
    }

    function selectedText(page:StalePage):String {
        return app.update(cx -> TextSelection.selectedText(page.window, cx));
    }

    /** A drag across the page's text view ("Hello world"), frames drawn as dirty. */
    function dragAcrossText():Void {
        for (page in pages) {
            final bounds = page.text.read(app).bounds();
            final from = new Point(bounds.origin.x + 1., bounds.center().y);
            final to = new Point(bounds.origin.x + bounds.size.width + 60., bounds.center().y);
            app.update(cx -> page.window.dispatchEvent(new MouseDownEvent(Left, from, Modifiers.none(), 1, false), cx));
            frame('drag: down');
            app.update(cx -> page.window.dispatchEvent(new MouseMoveEvent(to, Left, Modifiers.none()), cx));
            frame('drag: move');
            app.update(cx -> page.window.dispatchEvent(new MouseUpEvent(Left, to, Modifiers.none(), 1), cx));
            frame('drag: up');
        }
    }

    /**
     * A dialog opened through the kit API: the next frame draws it, and the
     * window's text selection scope is the dialog's, so the text behind the
     * dialog's overlay cannot be selected.
     */
    function caseDialog(variant:Variant):Void {
        final page = openPair(variant, 'dialog');
        final reference = pages[1];
        // The selection state exists once a selectable text is registered
        assertTrue(activeScope(page) != null, 'precondition: the window has a selection state');
        assertEquals(TextSelectionScopeId.DEFAULT, activeScope(page), 'precondition: default scope');
        final quads = page.window.renderedScene().quads.length;

        each((p, cx) -> p.window.openDialog(cx, (dialog, _, _) -> dialog.child(div().child('Dialog text'))));
        final drew = frame('dialog opened');
        assertTrue(drew, 'dialog: the next frame is drawn');
        assertTrue(page.window.renderedScene().quads.length > quads, 'dialog: the dialog is in the scene (${page.window.renderedScene().quads.length} quads, $quads before)');
        assertTrue(dialogScope(page) != TextSelectionScopeId.DEFAULT, 'dialog: the window state has the dialog scope');
        final immediate = activeScope(page) == dialogScope(page);
        assertTrue(immediate, 'dialog: the selection scope is the dialog scope (active ${activeScope(page)}, dialog ${dialogScope(page)})');
        assertEquals(dialogScope(reference), activeScope(reference), 'reference: the selection scope is the dialog scope');
        assertSameScene('dialog opened');
        assertNoCacheMessage('dialog opened');

        // The dialog's frames (transition), then a drag across the text behind it
        dispatcher.advanceClock(0.5);
        settle('dialog settled');
        log('dialog settled: active ${activeScope(page)}, dialog ${dialogScope(page)}');
        assertSameScene('dialog settled');
        dragAcrossText();
        assertEquals('', selectedText(reference), 'reference: the text behind the dialog is not selectable');
        assertEquals('', selectedText(page), 'the text behind the dialog is not selectable');
        assertTrue(activeScope(page) == dialogScope(page), 'after the drag: the selection scope is the dialog scope (active ${activeScope(page)}, dialog ${dialogScope(page)})');
        assertSameScene('after the drag');
        assertNoCacheMessage('after the drag');
    }

    /**
     * The dialog closed through the kit API. Nothing was focused before it
     * opened, so closing it restores no focus (the window's focus is only
     * forgotten) and the window state alone is notified: the next frame must
     * take the dialog away and give the selection back to the page's text.
     */
    function caseDialogClose(variant:Variant):Void {
        final page = openPair(variant, 'dialogClose');
        final reference = pages[1];
        assertTrue(page.window.focused(app) == null, 'precondition: nothing focused');
        each((p, cx) -> p.window.openDialog(cx, (dialog, _, _) -> dialog.child(div().child('Dialog text'))));
        settle('dialog opened');
        dispatcher.advanceClock(0.5);
        settle('dialog settled');
        assertSameScene('dialog settled');
        assertTrue(activeScope(page) == dialogScope(page), 'precondition: the dialog scope is active');
        final quads = page.window.renderedScene().quads.length;

        each((p, cx) -> p.window.closeDialog(cx));
        final drew = frame('dialog closed');
        assertTrue(drew, 'closed: the next frame is drawn');
        assertFalse(page.window.hasActiveDialog(app), 'closed: no active dialog');
        assertTrue(page.window.renderedScene().quads.length < quads, 'closed: the dialog left the scene (${page.window.renderedScene().quads.length} quads, $quads before)');
        assertEquals(TextSelectionScopeId.DEFAULT, dialogScope(page), 'closed: the window state is back to the default scope');
        assertEquals(TextSelectionScopeId.DEFAULT, activeScope(page), 'closed: the selection scope is the default one');
        assertEquals(TextSelectionScopeId.DEFAULT, activeScope(reference), 'reference: the selection scope is the default one');
        assertSameScene('dialog closed');
        assertNoCacheMessage('dialog closed');

        dispatcher.advanceClock(0.5);
        settle('closed settled');
        dragAcrossText();
        final expected = selectedText(reference);
        assertTrue(expected.indexOf('Hello world') != -1, 'reference: the text is selectable again ("$expected")');
        final selected = selectedText(page);
        assertTrue(selected.indexOf('Hello world') != -1, 'the text is selectable again ("$selected", scope ${activeScope(page)})');
        assertSameScene('after the drag');
        assertNoCacheMessage('after the drag');
    }

    function testDialogCloseDefault() caseDialogClose(Default);
    function testDialogCloseNoVerify() caseDialogClose(NoVerify);
    function testDialogCloseNoInPlace() caseDialogClose(NoInPlace);
    function testDialogCloseNoCaching() caseDialogClose(NoCaching);

    function testDialogDefault() caseDialog(Default);
    function testDialogNoVerify() caseDialog(NoVerify);
    function testDialogNoInPlace() caseDialog(NoInPlace);
    function testDialogNoCaching() caseDialog(NoCaching);

}

private enum abstract Variant(Int) {
    var Default;
    var NoVerify;
    var NoInPlace;
    var NoCaching;
}

/** A view whose render reads nothing of the inputs (notified to cause a frame). */
private class StaleMarker extends Model implements Render {

    public var renders:Int = 0;

    public function new() {
        super();
    }

    public function render(_:Window, _:Context<Dynamic>):IntoElement {
        renders++;
        return div().w(px(8)).h(px(8)).bg(hsla(0.3, 0.5, 0.5, 1));
    }

}

/** The view holding the textarea (the enclosing view of the input). */
private class StaleField extends Model implements Render {

    final page:StalePage;

    public var renders:Int = 0;

    public function new(page:StalePage) {
        super();
        this.page = page;
    }

    public function render(_:Window, _:Context<Dynamic>):IntoElement {
        renders++;
        return div().sizeFull().child(Textarea.component(page.area).disabled(page.disabled).readonly(page.readonly).hFull());
    }

}

/**
 * The page: a marker (8 x 8), a selectable text view (300 x 40) and the
 * field (400 x 200), in a column with padding 16 and gap 16.
 */
private class StalePage extends Model implements Render {

    public var window:Window;

    public var reference:Bool = false;

    public var entity:Null<Entity<StalePage>> = null;

    public final area:Entity<TextareaState>;

    public final text:Entity<TextViewState>;

    public final field:Entity<StaleField>;

    public final marker:Entity<StaleMarker>;

    public var disabled:Bool = false;

    public var readonly:Bool = false;

    public var renders:Int = 0;

    public function new(window:Window, cx:Context<StalePage>) {
        super();
        this.window = window;
        area = cx.newEntity((c:Context<TextareaState>) -> (new TextareaState(window, c).withSearchable(true).defaultValue('foo bar foo\nbaz foo') : TextareaState));
        text = cx.newEntity((c:Context<TextViewState>) -> TextViewState.markdown('Hello world', c));
        field = cx.newEntity((_:Context<StaleField>) -> new StaleField(this));
        marker = cx.newEntity((_:Context<StaleMarker>) -> new StaleMarker());
    }

    public function notifyField(cx:App):Void {
        field.update(cx, (_, cx) -> cx.notify());
    }

    public function render(_:Window, _:Context<Dynamic>):IntoElement {
        renders++;
        return div()
            .sizeFull()
            .flex()
            .flexCol()
            .p(px(16))
            .gap(px(16))
            .child(marker)
            .child(div().w(px(300)).h(px(40)).flexNone().child(TextView.create(text).selectable(true)))
            .child(div().w(px(400)).h(px(200)).flexNone().child(field));
    }

}
