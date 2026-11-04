// Ported from gpui-kit 0.8.1: crates/base/src/input/base/state.rs (the helpers of the tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.ClipboardItem;
import gpui.Context;
import gpui.Entity;
import gpui.Range;
import gpui.Window;
import gpui.base.NumberStep;
import gpui.base.StepAction;
import gpui.base.input.EditorState;
import gpui.base.input.EditedText;
import gpui.base.input.FoldRange;
import gpui.base.input.HighlightStyleResolver;
import gpui.base.input.InputEdit;
import gpui.base.input.InputHighlighter.InputHighlighterBase;
import gpui.base.input.InputBaseState.TextEdit;
import gpui.base.input.LspHover;
import gpui.base.input.LspPosition;
import gpui.base.input.StyledRange;
import gpui.base.input.TabSize;
import gpui.base.input.TextDecoration;
import gpui.base.input.TextElement;
import gpui.base.input.WrappingIndent;
import ropey.Rope;
import gpui.base.input.InputActions;
import gpui.base.input.InputBaseState;
import gpui.base.input.InputEvent;
import gpui.base.input.InputKeyBindings;
import gpui.base.input.InputState;
import gpui.base.input.MaskPattern;
import gpui.base.input.TextareaState;
import testing.InteractionScript.ScriptView;
import testing.VisualTestContext;

import gpui.Prelude.*;

using gpui.base.input.InputMovement;
using gpui.base.input.InputDecorationsExt;
using gpui.base.input.InputLspExt;
using gpui.base.input.MaskPattern.MaskPatternTools;
using gpui.base.NumberStep.NumberStepTools;

/** Rust `InputView<M>`: a state of one mode opened in a window. */
class InputView {

    public final input:Entity<InputBaseState>;

    public final cx:VisualTestContext;

    public function new(input:Entity<InputBaseState>, cx:VisualTestContext) {
        this.input = input;
        this.cx = cx;
    }

    /** `cx.update(|window, cx| input.update(cx, |state, cx| f(state, window, cx)))`. */
    public function update(f:(InputBaseState, Window, Context<InputBaseState>) -> Void):Void {
        cx.update((window, app) -> input.update(app, (state, cx) -> f(state, window, cx)));
    }

    public function state():InputBaseState {
        return input;
    }

}

/**
 * The helpers of the input state tests (Rust `state.rs` test module). The
 * states are held as `Entity<InputBaseState>` so that their update contexts
 * are the `Context<InputBaseState>` the methods take.
 */
class InputStateTestCase extends KitTestCase {

    final contexts:Array<VisualTestContext> = [];

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        super.teardown();
    }

    /** Rust `InputView::build_with`. */
    function buildWith(make:(Window, Context<InputBaseState>) -> InputBaseState):InputView {
        var input:Entity<InputBaseState> = null;
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, cx:Context<ScriptView>) -> {
            // Set up the theme first
            gpui.base.theme.Theme.globalMut(cx.app);
            // Initialize input keybindings
            InputKeyBindings.init(cx.app);
            input = cx.app.newEntity((cx:Context<InputBaseState>) -> make(window, cx));
            final child = input;
            return new ScriptView((_, _) -> div().sizeFull().child(child));
        });
        contexts.push(opened.cx);
        return new InputView(input, opened.cx);
    }

    function build(?f:(InputState) -> InputBaseState):InputView {
        return buildWith((window, cx) -> {
            final state = new InputState(window, cx);
            return f != null ? f(state) : state;
        });
    }

    function buildTextarea(?f:(TextareaState) -> InputBaseState):InputView {
        return buildWith((window, cx) -> {
            final state = new TextareaState(window, cx);
            return f != null ? f(state) : state;
        });
    }

    function buildEditor(?f:(EditorState) -> InputBaseState):InputView {
        return buildWith((window, cx) -> {
            final state = new EditorState(window, cx).language("sql");
            return f != null ? f(state) : state;
        });
    }

    function range(start:Int, end:Int):Range {
        return new Range(start, end);
    }

    final ENTER = new Enter(false, false);

    function assertRange(start:Int, end:Int, actual:Range, ?pos:haxe.PosInfos):Void {
        assertEquals(start + ".." + end, actual.start + ".." + actual.end, null, pos);
    }

    /** Opens a window whose root builds `make` once, like `cx.open_window(size(400, 100), ...)`. */
    function openWithState(make:(Window, Context<ScriptView>) -> Void):Void {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, cx:Context<ScriptView>) -> {
            make(window, cx);
            return new ScriptView((_, _) -> div());
        }, 400, 100);
        contexts.push(opened.cx);
    }

    /** Opens `make` in a window of the given size, rendered like Rust's `TestRoot`. */
    function buildSized(width:Float, height:Float, make:(Window, Context<InputBaseState>) -> InputBaseState):InputView {
        var input:Entity<InputBaseState> = null;
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, cx:Context<ScriptView>) -> {
            gpui.base.theme.Theme.globalMut(cx.app);
            InputKeyBindings.init(cx.app);
            input = cx.app.newEntity((cx:Context<InputBaseState>) -> make(window, cx));
            final child = input;
            return new ScriptView((_, _) -> div().sizeFull().child(child));
        }, width, height);
        contexts.push(opened.cx);
        return new InputView(input, opened.cx);
    }

    function longText():String {
        return [for (n in 0...60) 'line $n'].join("\n");
    }

    /** Sends one trackpad packet straight to the input. */
    function swipe(view:InputView, dy:Float, phase:gpui.TouchPhase):Void {
        view.update((state, window, cx) -> state.onScrollWheel(new gpui.ScrollEvent(new gpui.Point(0, 0), Pixels(new gpui.Point(0., dy)), null, phase), window, cx));
    }

    function draw(view:InputView):Void {
        view.cx.update((window, _) -> window.draw());
    }

    /**
     * Swipes far past the end of the text and returns where the text
     * scrolled to and how far its edge stretched.
     */
    function swipePastTheEnd(view:InputView):{end:Float, stretch:Float} {
        draw(view);
        swipe(view, -20., Started);
        swipe(view, -100000., Moved);
        final state = view.state();
        return {end: state.scrollHandle.offset().y, stretch: state.overscroll.offset()};
    }

    function longUrl():String {
        var value = "https://example.com/v1/users?";
        for (_ in 0...120)
            value += "x=1&";
        return value;
    }

    /** Rust `str::split_inclusive(' ')`. */
    function splitInclusive(s:String):Array<String> {
        final result = [];
        var start = 0;
        for (i in 0...s.length) {
            if (s.charAt(i) == " ") {
                result.push(s.substring(start, i + 1));
                start = i + 1;
            }
        }
        if (start < s.length)
            result.push(s.substring(start));
        return result;
    }

}
