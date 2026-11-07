// Ported from gpui-kit 0.8.1: crates/story/src/stories/input_completion.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.Keystroke;
import glaze.TestDispatcher;
import glaze.kit.base.Root;
import glaze.kit.Component;
import story.stories.InputCompletion;
import story.stories.InputCompletion.CompletionExample;
import testing.TestCase;
import testing.VisualTestContext;

/**
 * The `#[cfg(test)]` tests of the story gallery's `input_completion.rs`
 * (`samples/story`): the application-owned `$` completion menu.
 */
@:access(story.stories.InputCompletion.CompletionExample)
class StoryInputCompletionTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        ceramic.App.app.flushImmediate();
    }

    static function query(text:String, cursor:Int):Null<String> {
        final found = InputCompletion.activeVariableQuery(text, cursor);
        return found == null ? null : found.tokenStart + ':' + found.query;
    }

    function testTriggerOpensAtLineStartAndAfterWhitespace() {
        assertEquals('0:HO', query("$HO", 3));
        assertEquals('5:HO', query("echo $HO", 8));
        assertEquals('5:', query("echo $", 6));
        assertEquals(null, query("a$b", 3));
        assertEquals(null, query("mail$x", 6));
        assertEquals(null, query("echo $HO ", 9));
    }

    function testRankingPutsPrefixMatchesFirst() {
        assertEquals('PATH,PWD', InputCompletion.rankedVariables('P').join(','));
        assertEquals('EDITOR,HOME,SHELL,TERM,USER', InputCompletion.rankedVariables('e').join(','));
        assertEquals(0, InputCompletion.rankedVariables('ZZZ').length);
    }

    function mount():{story:Entity<CompletionExample>, cx:VisualTestContext} {
        app.update(cx -> Component.init(cx));
        var story:Null<Entity<CompletionExample>> = null;
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, rootCx:Context<Root>) -> {
            story = CompletionExample.create(window, rootCx.app);
            return new Root(story, window, rootCx);
        });
        final cx = opened.cx;
        contexts.push(cx);
        cx.update((window, app) -> {
            story.read(app).input.update(app, (input, cx) -> input.focus(window, cast cx));
        });
        draw(cx);
        return {story: story, cx: cx};
    }

    static function draw(cx:VisualTestContext):Void {
        cx.runUntilParked();
        cx.update((window, _) -> window.draw());
    }

    /** Rust `simulate_input`: every character dispatched as a keystroke. */
    static function simulateInput(cx:VisualTestContext, text:String):Void {
        for (c in new haxe.iterators.StringIteratorUnicode(text)) {
            final keystroke = Keystroke.parse(String.fromCharCode(c));
            cx.update((window, app) -> window.dispatchKeystroke(keystroke, app));
        }
        cx.runUntilParked();
    }

    function value(story:Entity<CompletionExample>):String {
        return story.read(app).input.read(app).value();
    }

    function menuItems(story:Entity<CompletionExample>):Null<String> {
        final items = story.read(app).menuItems();
        return items == null ? null : items.join(',');
    }

    function testKeyboardSelectsAndAcceptsACandidate() {
        final mounted = mount();
        final story = mounted.story;
        final cx = mounted.cx;
        simulateInput(cx, "echo $P");
        draw(cx);
        assertEquals('PATH,PWD', menuItems(story));

        cx.simulateKeystrokes('down tab');
        draw(cx);
        assertEquals("echo $PWD ", value(story));
        assertEquals(null, menuItems(story));

        simulateInput(cx, "$HO");
        draw(cx);
        cx.simulateKeystrokes('enter');
        draw(cx);
        assertEquals("echo $PWD $HOME ", value(story));
    }

    function testLeavingTheTokenWithoutEditingReleasesTheKeyboard() {
        final mounted = mount();
        final story = mounted.story;
        final cx = mounted.cx;
        simulateInput(cx, "echo $HO");
        draw(cx);
        assertEquals('HOME', menuItems(story));

        // Moving the caret changes no text, so no `Change` event fires. No
        // draw separates the keys: Enter must notice the stale menu itself
        // and submit instead of accepting.
        cx.simulateKeystrokes('home enter');
        assertEquals("echo $HO", value(story));
        assertEquals(null, menuItems(story));
        assertEquals('Submitted "echo $$HO"', story.read(app).statusText());
    }

}
