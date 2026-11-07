// Ported from gpui-pre 0.3.10: src/interactive.rs (tests)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests;

import glaze.Action;
import glaze.App;
import glaze.Context;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.KeyBinding;
import glaze.Keystroke;
import glaze.Model;
import glaze.Modifiers;
import glaze.Render;
import glaze.TestDispatcher;
import glaze.Window;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;

@:action(namespace = test_only) class InteractiveTestAction implements Action {}

/**
 * Tests of `interactive.rs`: key down and action listeners, standalone modifier bindings.
 */
class InteractiveTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var cx:Null<VisualTestContext> = null;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        if (cx != null) {
            cx.destroy();
            cx = null;
        }
        ceramic.App.app.flushImmediate();
    }

    function testOnEvents() {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, cx:Context<InteractiveTestView>) -> new InteractiveTestView(cx.focusHandle()));
        cx = opened.cx;
        final window = opened.view;

        app.update(cx -> {
            cx.bindKeys([new KeyBinding('ctrl-g', new InteractiveTestAction(), 'parent')]);
        });

        window.update(app, (testView, cx) -> {
            this.cx.window.focus(testView.focusHandle, cx.app);
        });

        // Rust `cx.dispatch_keystroke(window, keystroke)`
        cx.update((window, cx) -> window.dispatchKeystroke(Keystroke.parse('a'), cx));
        cx.update((window, cx) -> window.dispatchKeystroke(Keystroke.parse('ctrl-g'), cx));

        window.update(app, (testView, _) -> {
            assertTrue(testView.sawKeyDown || testView.sawAction);
            assertTrue(testView.sawKeyDown);
            assertTrue(testView.sawAction);
        });
    }

    function testMultiModifierGestureDoesNotDispatchStandaloneModifierBinding() {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, cx:Context<InteractiveTestView>) -> new InteractiveTestView(cx.focusHandle()));
        cx = opened.cx;
        final testView = opened.view;

        cx.update((_, cx) -> {
            cx.bindKeys([new KeyBinding('shift', new InteractiveTestAction(), null)]);
        });
        testView.update(app, (testView, cx) -> {
            this.cx.window.focus(testView.focusHandle, cx.app);
        });

        cx.simulateModifiersChange(Modifiers.altKey());
        cx.simulateModifiersChange(Modifiers.of(false, true, true));
        cx.simulateModifiersChange(Modifiers.shiftKey());
        cx.simulateModifiersChange(Modifiers.none());
        assertFalse(testView.read(app).sawAction);

        cx.simulateModifiersChange(Modifiers.shiftKey());
        cx.simulateModifiersChange(Modifiers.none());
        assertTrue(testView.read(app).sawAction);
    }

}

private class InteractiveTestView extends Model implements Render {

    public var sawKeyDown:Bool = false;

    public var sawAction:Bool = false;

    public final focusHandle:FocusHandle;

    public function new(focusHandle:FocusHandle) {
        super();
        this.focusHandle = focusHandle;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().id('testview').child(
            div()
                .keyContext('parent')
                .onKeyDown((_, _, cx) -> {
                    cx.stopPropagation();
                    sawKeyDown = true;
                })
                .onAction(InteractiveTestAction, (_, _, _) -> sawAction = true)
                .child(
                    div()
                        .keyContext('nested')
                        .trackFocus(focusHandle)
                )
        );
    }

}
