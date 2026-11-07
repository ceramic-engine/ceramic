// Ported from gpui-pre 0.3.10: src/input.rs (tests), examples/input.rs (tests)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests;

import gpui.App;
import gpui.Bounds;
import gpui.ClipboardEntry;
import gpui.ClipboardItem;
import gpui.ClipboardString;
import gpui.Context;
import gpui.ElementInputHandler;
import gpui.EntityInputHandler;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.Model;
import gpui.PlatformInputHandler;
import gpui.Point;
import gpui.Range;
import gpui.Render;
import gpui.TestClipboard;
import gpui.TestDispatcher;
import gpui.TextInputConfiguration;
import gpui.TextInputStateChange;
import gpui.UTF16Selection;
import gpui.Window;
import gpui.util.Ref;
import testing.TestCase;
import testing.TestPlatformTextInput;
import testing.VisualTestContext;
import textfield.TextInput;

import gpui.Prelude.*;

/**
 * Text input handlers: the tests of `input.rs` (configuration and text input
 * state forwarded to the platform), the tests of GPUI's `examples/input.rs`
 * (run on its port, `samples/textfield`), clipboard items and the IME
 * candidate position.
 */
class InputHandlerTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var cx:Null<VisualTestContext> = null;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.setTextSystem(TextFixtures.textSystem());
        app.platformClipboard = new TestClipboard();
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        if (cx != null) {
            cx.destroy();
            cx = null;
        }
        ceramic.App.app.flushImmediate();
    }

    function openConfigurationView(platform:TestPlatformTextInput, configuration:TextInputConfiguration):ConfigurationTestView {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, cx:Context<ConfigurationTestView>) -> {
            window.textInputPlatform = platform;
            return new ConfigurationTestView(cx.focusHandle(), configuration, true);
        });
        cx = opened.cx;
        return opened.view.read(app);
    }

    static function configurations(list:Array<TextInputConfiguration>):String {
        return [for (c in list) c.toString()].join('\n');
    }

/// input.rs

    function testTextInputConfigurationAndFocusStateAreForwardedOnChange() {
        final custom = new TextInputConfiguration(true, null, false, Send);
        final platform = new TestPlatformTextInput();
        final view = openConfigurationView(platform, custom);
        final draw = () -> cx.update((window, _) -> window.draw());

        // Nothing is focused, so the platform learns the default configuration.
        draw();
        assertEquals(configurations([TextInputConfiguration.defaultValue()]), configurations(platform.textInputConfigurations));
        assertEquals(0, platform.textInputStateChanges.length);

        // Focusing the view routes its configuration to the platform.
        cx.update((window, cx) -> window.focus(view.focusHandle, cx));
        draw();
        assertEquals(configurations([TextInputConfiguration.defaultValue(), custom]), configurations(platform.textInputConfigurations));
        assertEquals([TextInputStateChange.FocusGained].join(','), platform.textInputStateChanges.join(','));

        // Redrawing without a change forwards nothing.
        draw();
        assertEquals(2, platform.textInputConfigurations.length);
        assertEquals(1, platform.textInputStateChanges.length);

        // Changing the configuration forwards the new value.
        final updated = custom.with(null, null, true);
        cx.update((_, app) -> app.updateEntity(view, (view, cx) -> {
            view.configuration = updated;
            cx.notify();
        }));
        draw();
        assertTrue(updated.equals(platform.textInputConfigurations[platform.textInputConfigurations.length - 1]));
        assertEquals(3, platform.textInputConfigurations.length);
        assertEquals(1, platform.textInputStateChanges.length);

        // Losing focus reverts the platform to the default configuration.
        cx.update((window, cx) -> window.blur(cx));
        draw();
        assertTrue(TextInputConfiguration.defaultValue().equals(platform.textInputConfigurations[platform.textInputConfigurations.length - 1]));
        assertEquals(4, platform.textInputConfigurations.length);
        assertEquals([TextInputStateChange.FocusGained, TextInputStateChange.FocusLost].join(','), platform.textInputStateChanges.join(','));
    }

    function testTextNotificationsRequireAFocusedInputAndTrackFieldChanges() {
        final platform = new TestPlatformTextInput();
        final view = openConfigurationView(platform, TextInputConfiguration.defaultValue());
        final window = cx.window;
        final firstFocus = view.focusHandle;
        cx.update((window, cx) -> {
            window.focus(firstFocus, cx);
            window.draw();
            window.notifyTextInputChanged(firstFocus);
            window.notifyTextSelectionChanged(firstFocus);
        });

        final installedHandler = window.takeInputHandler();
        assertTrue(installedHandler != null);
        assertTrue(installedHandler.queryAcceptsFocusedTextInput());
        assertEquals(firstFocus.id, installedHandler.focusId());
        final secondFocus = cx.update((window, cx) -> {
            final secondFocus = cx.updateEntity(view, (view, cx) -> {
                view.focusHandle = cx.focusHandle();
                cx.notify();
                return view.focusHandle;
            });
            window.focus(secondFocus, cx);
            return secondFocus;
        });
        assertFalse(installedHandler.queryAcceptsFocusedTextInput());
        window.setInputHandler(installedHandler);
        cx.update((window, cx) -> {
            window.draw();
            window.notifyTextInputChanged(firstFocus);
        });
        assertEquals([TextInputStateChange.FocusGained, TextInputStateChange.ContentChanged, TextInputStateChange.SelectionChanged].join(','), platform.textInputStateChanges.join(','));

        final installedHandler = window.takeInputHandler();
        assertEquals(secondFocus.id, installedHandler.focusId());
        window.setInputHandler(installedHandler);
        cx.update((window, cx) -> {
            window.draw();
            window.notifyTextSelectionChanged(secondFocus);
        });

        cx.update((_, app) -> app.updateEntity(view, (view, cx) -> {
            view.acceptsTextInputValue = false;
            cx.notify();
        }));
        cx.update((window, cx) -> {
            window.draw();
            window.notifyTextInputChanged(secondFocus);
            window.notifyTextSelectionChanged(secondFocus);
            final ordinaryFocus = cx.focusHandle();
            window.focus(ordinaryFocus, cx);
            window.draw();
            window.notifyTextInputChanged(ordinaryFocus);
        });
        assertEquals([
            TextInputStateChange.FocusGained,
            TextInputStateChange.ContentChanged,
            TextInputStateChange.SelectionChanged,
            TextInputStateChange.SelectionChanged,
            TextInputStateChange.FocusLost
        ].join(','), platform.textInputStateChanges.join(','));
    }

/// examples/input.rs

    function openInput(content:String):gpui.Entity<TextInput> {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, cx:Context<TextInput>) -> new TextInput(cx.focusHandle(), content, ''));
        cx = opened.cx;
        return opened.view;
    }

    function testNativeSelectionAndLengthUseUtf16() {
        final view = openInput('e🙂漢');
        cx.update((window, app) -> view.update(app, (input, cx) -> {
            assertEquals(4, input.textLengthUtf16(window, cx));
            input.setSelectedTextRange(new Range(1, 3), window, cx);
            assertEquals('1..5', input.selectedRange.toString());
            assertEquals('1..3', input.selectedTextRange(false, window, cx).range.toString());
            input.setSelectedTextRange(new Range(3, 99), window, cx);
            assertEquals('5..8', input.selectedRange.toString());
        }));
    }

    function testMarkedSelectionIsRelativeToInsertedText() {
        final view = openInput('A🙂Z');
        cx.update((window, app) -> view.update(app, (input, cx) -> {
            input.replaceAndMarkTextInRange(new Range(1, 3), 'é🙂', new Range(1, 3), window, cx);
            assertEquals('Aé🙂Z', input.content);
            assertEquals('1..7', Range.describe(input.markedRange));
            assertEquals('3..7', input.selectedRange.toString());

            input.replaceAndMarkTextInRange(null, '漢', new Range(1, 1), window, cx);
            assertEquals('A漢Z', input.content);
            assertEquals('1..4', Range.describe(input.markedRange));
            assertEquals('4..4', input.selectedRange.toString());

            input.replaceAndMarkTextInRange(null, '', new Range(0, 0), window, cx);
            assertEquals('AZ', input.content);
            assertEquals('None', Range.describe(input.markedRange));
            assertEquals('1..1', input.selectedRange.toString());
        }));
    }

    function testLongSingleLineSelectionUsesOneGeometryFragment() {
        final view = openInput('');
        cx.update((_, app) -> view.update(app, (input, cx) -> {
            input.content = StringTools.lpad('', 'a', 10000);
            cx.notify();
        }));
        cx.runUntilParked();
        cx.update((window, app) -> view.update(app, (input, cx) -> {
            final bounds = input.lastBounds;
            assertTrue(bounds != null, 'input was painted');
            final rectangles = input.selectionBoundsForRange(new Range(0, 10000), bounds, window, cx);
            assertEquals(1, rectangles.length);
            assertTrue(rectangles[0].size.width > 0);
        }));
    }

/// Element input handler routing

    function testElementInputHandlerForwardsToTheViewWithElementBounds() {
        final view = openInput('ab');
        final handle = view.read(app).focusHandle;
        cx.update((window, cx) -> window.focus(handle, cx));
        cx.runUntilParked();
        final handler = cx.window.peekInputHandler();
        assertTrue(handler != null, 'registered when focused');
        assertEquals(handle.id, handler.focusId());
        final elementBounds = handler.elementBounds();
        assertTrue(elementBounds != null && elementBounds.size.width > 0);
        assertEquals(2, handler.textLengthUtf16());
        // The cursor is at 0
        handler.replaceTextInRange(null, '🙂');
        assertEquals('🙂ab', view.read(app).content);
        assertEquals('2..2', handler.selectedTextRange(false).range.toString());
        final adjusted = new Ref<Null<Range>>(null);
        assertEquals('ab', handler.textForRange(new Range(2, 4), adjusted));
        assertEquals('2..4', Range.describe(adjusted.value));
        handler.replaceAndMarkTextInRange(null, 'か', new Range(1, 1));
        assertEquals('2..3', Range.describe(handler.markedTextRange()));
        handler.unmarkText();
        assertEquals('None', Range.describe(handler.markedTextRange()));
        handler.paste(ClipboardItem.newString('!'));
        assertEquals('🙂か!ab', view.read(app).content);

        // Blurred: the next frame registers no handler
        cx.update((window, cx) -> window.blur(cx));
        cx.runUntilParked();
        assertTrue(cx.window.peekInputHandler() == null);
        assertFalse(cx.window.hasFocusedTextInput());
    }

/// IME candidate position (PlatformInputHandler.compute_ime_candidate_bounds)

    function testImeCandidateBounds() {
        // One line: x = 10 * offset. Two lines from offset 5: y = 20.
        final queried:Array<String> = [];
        final boundsFor = (twoLines:Bool) -> (range:Range) -> {
            queried.push(range.toString());
            final line = twoLines && range.start >= 5 ? 1 : 0;
            final x = (range.start - line * 5) * 10.0;
            return new Bounds(new Point(x, line * 20.0), size(px(0), px(20)));
        };
        // No composition: the selection head
        assertEquals(60.0, PlatformInputHandler.computeImeCandidateBounds(null, new UTF16Selection(new Range(3, 6), false), boundsFor(false)).origin.x);
        assertEquals(30.0, PlatformInputHandler.computeImeCandidateBounds(null, new UTF16Selection(new Range(3, 6), true), boundsFor(false)).origin.x);
        // Composition on one line: start of the marked text
        queried.resize(0);
        final bounds = PlatformInputHandler.computeImeCandidateBounds(new Range(2, 6), new UTF16Selection(new Range(6, 6), false), boundsFor(false));
        assertEquals(20.0, bounds.origin.x);
        assertEquals('6..6,5..5,4..4,3..3,2..2,2..2', queried.join(','));
        // Composition wrapped on the next line: start of the caret's line
        queried.resize(0);
        final wrapped = PlatformInputHandler.computeImeCandidateBounds(new Range(2, 7), new UTF16Selection(new Range(7, 7), false), boundsFor(true));
        assertEquals(0.0, wrapped.origin.x);
        assertEquals(20.0, wrapped.origin.y);
        assertEquals('7..7,6..6,5..5,4..4,5..5', queried.join(','));
    }

/// Clipboard

    function testClipboardItemText() {
        assertEquals('hello', ClipboardItem.newString('hello').text());
        assertEquals(null, ClipboardItem.newString('hello').metadata());
        final withMetadata = ClipboardItem.newStringWithMetadata('a', '{"k":1}');
        assertEquals('{"k":1}', withMetadata.metadata());
        final json = ClipboardItem.newStringWithJsonMetadata('b', {k: 2});
        assertEquals(2, (switch json.entries[0] {
            case String(string): string.metadataJson();
            case _: null;
        }).k);
        final multi = new ClipboardItem([String(new ClipboardString('a', 'm')), String(new ClipboardString('b'))]);
        assertEquals('ab', multi.text());
        assertEquals(null, multi.metadata());
        assertEquals(null, new ClipboardItem([String(new ClipboardString(''))]).text());
        assertEquals(null, new ClipboardItem([]).text());
        assertTrue(ClipboardItem.newString('x').equals(ClipboardItem.newString('x')));
        assertFalse(ClipboardItem.newString('x').equals(ClipboardItem.newStringWithMetadata('x', 'm')));
    }

    function testAppClipboardRoundTrip() {
        assertEquals(null, app.readFromClipboard());
        final item = ClipboardItem.newStringWithMetadata('line1\nline2', '{"kind":"test"}');
        app.writeToClipboard(item);
        final read = app.readFromClipboard();
        assertEquals('line1\nline2', read.text());
        assertEquals('{"kind":"test"}', read.metadata());
    }

}

/**
 * Rust `ConfigurationTestView`: registers an `ElementInputHandler` from a
 * canvas filling the view.
 */
private class ConfigurationTestView extends Model implements Render implements EntityInputHandler {

    public var focusHandle:FocusHandle;

    public var configuration:TextInputConfiguration;

    public var acceptsTextInputValue:Bool;

    public function new(focusHandle:FocusHandle, configuration:TextInputConfiguration, acceptsTextInput:Bool) {
        super();
        this.focusHandle = focusHandle;
        this.configuration = configuration;
        this.acceptsTextInputValue = acceptsTextInput;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final cx:Context<ConfigurationTestView> = cast cx;
        final view = cx.entity();
        final focusHandle = this.focusHandle;
        return div().sizeFull().trackFocus(focusHandle).child(
            canvas((_, _, _) -> 0, (bounds, _, window, cx) -> {
                window.handleInput(focusHandle, new ElementInputHandler(bounds, view), cx);
            }).sizeFull()
        );
    }

    public function acceptsTextInput(window:Window, cx:Context<Dynamic>):Bool {
        return acceptsTextInputValue;
    }

    public function textForRange(range:Range, adjustedRange:Ref<Null<Range>>, window:Window, cx:Context<Dynamic>):Null<String> {
        return null;
    }

    public function selectedTextRange(ignoreDisabledInput:Bool, window:Window, cx:Context<Dynamic>):Null<UTF16Selection> {
        return null;
    }

    public function markedTextRange(window:Window, cx:Context<Dynamic>):Null<Range> {
        return null;
    }

    public function unmarkText(window:Window, cx:Context<Dynamic>):Void {}

    public function replaceTextInRange(range:Null<Range>, text:String, window:Window, cx:Context<Dynamic>):Void {}

    public function replaceAndMarkTextInRange(range:Null<Range>, newText:String, newSelectedRange:Null<Range>, window:Window, cx:Context<Dynamic>):Void {}

    public function boundsForRange(rangeUtf16:Range, elementBounds:Bounds, window:Window, cx:Context<Dynamic>):Null<Bounds> {
        return null;
    }

    public function characterIndexForPoint(point:Point, window:Window, cx:Context<Dynamic>):Null<Int> {
        return null;
    }

    public function textInputConfiguration(window:Window, cx:Context<Dynamic>):TextInputConfiguration {
        return configuration;
    }

}
