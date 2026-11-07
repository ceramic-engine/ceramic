package;

#if unity

import ceramic.ScanCode;
import ceramic.ScrollUnit;
import gpui.Context;
import gpui.Entity;
import gpui.IntoElement;
import gpui.Model;
import gpui.Render;
import gpui.Window;
import gpui.base.Root;
import gpui.base.input.InputState;
import gpui.component.input.Input;

import gpui.Prelude.*;

/**
 * Input self test of Ceramic's Unity backend, in batch mode (no window):
 * virtual devices of the Input System receive queued events (state, text and
 * IME composition events), and the test checks what Ceramic (and GPUI, for
 * the scroll of a list) receives:
 *
 * - `mouseScroll` per event with the unit rule of the platform, the legacy
 *   `mouseWheel` per frame, the offset of a GPUI list;
 * - key repeat (repeated `keyDown` of the held key, modifiers never repeat,
 *   no repeat after the release), the system repeat settings read;
 * - text: an emoji (UTF-32 event split by the Input System into two
 *   surrogates, and two separate surrogate events) arrives as one
 *   `textCommit`, after the `keyDown` of the same frame; IME composition;
 * - clipboard through `GUIUtility.systemCopyBuffer` (the previous text of
 *   the system clipboard is put back);
 * - touch down then cancel;
 * - window focus: Unity's `OnApplicationFocus` and `OnApplicationPause`
 *   messages sent to the Ceramic game object (`SendMessage`, reaching the
 *   `UnityLifecycle` component) give `windowFocusChange`, the background
 *   and foreground events on mobile, and GPUI windows deactivated then
 *   activated again;
 * - virtual keyboard: a simulated `TouchScreenKeyboard`
 *   (`FakeVirtualKeyboard`) opens when a gpui-kit `Input` gets the focus,
 *   with the keyboard of its configuration, and its edits (typing,
 *   backspace, emoji, caret moves, autocorrection, return key) reach the
 *   input; Android's focus loss while it is visible keeps the window
 *   active; a tap on the input opens it again; a blur closes it.
 *
 * Exits the editor with 0 when every check passes, 1 otherwise.
 */
@:classCode('
    static UnityEngine.InputSystem.Mouse testMouse;
    static UnityEngine.InputSystem.Keyboard testKeyboard;
    static UnityEngine.InputSystem.Touchscreen testTouchscreen;

    public static void setupDevices() {
        UnityEngine.Application.SetStackTraceLogType(UnityEngine.LogType.Log, UnityEngine.StackTraceLogType.None);
        // A batch editor has no focused game view: let the state events of
        // the virtual devices reach the game (the default behaviors route
        // them to editor updates, or disable the devices without focus)
        var settings = UnityEngine.InputSystem.InputSystem.settings;
        settings.backgroundBehavior = UnityEngine.InputSystem.InputSettings.BackgroundBehavior.IgnoreFocus;
#if UNITY_EDITOR
        settings.editorInputBehaviorInPlayMode = UnityEngine.InputSystem.InputSettings.EditorInputBehaviorInPlayMode.AllDeviceInputAlwaysGoesToGameView;
#endif
        testMouse = UnityEngine.InputSystem.InputSystem.AddDevice<UnityEngine.InputSystem.Mouse>("CeramicTestMouse");
        testKeyboard = UnityEngine.InputSystem.InputSystem.AddDevice<UnityEngine.InputSystem.Keyboard>("CeramicTestKeyboard");
        testTouchscreen = UnityEngine.InputSystem.InputSystem.AddDevice<UnityEngine.InputSystem.Touchscreen>("CeramicTestTouchscreen");
        testMouse.MakeCurrent();
        testKeyboard.MakeCurrent();
        testTouchscreen.MakeCurrent();
    }

    public static void removeDevices() {
        if (testMouse != null) UnityEngine.InputSystem.InputSystem.RemoveDevice(testMouse);
        if (testKeyboard != null) UnityEngine.InputSystem.InputSystem.RemoveDevice(testKeyboard);
        if (testTouchscreen != null) UnityEngine.InputSystem.InputSystem.RemoveDevice(testTouchscreen);
        testMouse = null;
        testKeyboard = null;
        testTouchscreen = null;
    }

    public static bool devicesAreCurrent() {
        return UnityEngine.InputSystem.Mouse.current == testMouse && UnityEngine.InputSystem.Keyboard.current == testKeyboard;
    }

    public static void csQueueScroll(double posX, double posY, double x, double y) {
        UnityEngine.InputSystem.InputSystem.QueueStateEvent(testMouse, new UnityEngine.InputSystem.LowLevel.MouseState {
            position = new UnityEngine.Vector2((float)posX, (float)posY),
            scroll = new UnityEngine.Vector2((float)x, (float)y)
        });
    }

    public static void csQueueKeys(string names) {
        var keys = new System.Collections.Generic.List<UnityEngine.InputSystem.Key>();
        foreach (var name in names.Split(new char[] { (char)44 }, System.StringSplitOptions.RemoveEmptyEntries)) {
            keys.Add((UnityEngine.InputSystem.Key)System.Enum.Parse(typeof(UnityEngine.InputSystem.Key), name));
        }
        UnityEngine.InputSystem.InputSystem.QueueStateEvent(testKeyboard, new UnityEngine.InputSystem.LowLevel.KeyboardState(keys.ToArray()));
    }

    public static void csQueueText(int character) {
        var ev = UnityEngine.InputSystem.LowLevel.TextEvent.Create(testKeyboard.deviceId, character, -1);
        UnityEngine.InputSystem.InputSystem.QueueEvent(ref ev);
    }

    public static void csQueueTextUnit(int unit) {
        UnityEngine.InputSystem.InputSystem.QueueTextEvent(testKeyboard, (char)unit);
    }

    public static void csQueueComposition(string text) {
        var ev = UnityEngine.InputSystem.LowLevel.IMECompositionEvent.Create(testKeyboard.deviceId, text, UnityEngine.InputSystem.LowLevel.InputState.currentTime);
        UnityEngine.InputSystem.InputSystem.QueueEvent(ref ev);
    }

    public static void csQueueTouch(int touchId, int phase, double x, double y) {
        UnityEngine.InputSystem.InputSystem.QueueStateEvent(testTouchscreen, new UnityEngine.InputSystem.LowLevel.TouchState {
            touchId = touchId,
            phase = (UnityEngine.InputSystem.TouchPhase)phase,
            position = new UnityEngine.Vector2((float)x, (float)y)
        });
    }

    public static string systemClipboard() {
        return UnityEngine.GUIUtility.systemCopyBuffer;
    }

    public static void csSendLifecycle(string name, bool value) {
        global::haxe.root.Main.monoBehaviour.gameObject.SendMessage(name, value, UnityEngine.SendMessageOptions.RequireReceiver);
    }

    public static bool csHasLifecycle() {
        return global::haxe.root.Main.monoBehaviour.gameObject.GetComponent<global::backend.UnityLifecycle>() != null;
    }

    public static void exitWith(int code) {
#if UNITY_EDITOR
        UnityEditor.EditorApplication.Exit(code);
#else
        UnityEngine.Application.Quit(code);
#endif
    }
')
class UnityInputSelfTest {

    final scene:MainScene;

    var checks:Int = 0;

    var failures:Int = 0;

    var scrolls:Array<String> = [];

    var wheels:Array<String> = [];

    var keyDowns:Array<Int> = [];

    var keyUps:Array<Int> = [];

    var texts:Array<String> = [];

    var compositions:Array<String> = [];

    var order:Array<String> = [];

    var touches:Array<String> = [];

    var focusEvents:Array<String> = [];

    var lifecycle:Array<String> = [];

    /** Steps, each returning the seconds to wait before the next one. */
    var steps:Array<()->Float> = [];

    final os:String;

    /** Mouse position of the scroll events: the middle of the list, in Unity pixels (bottom left origin). */
    var mouseX:Float = 0;

    var mouseY:Float = 0;

    public function new(scene:MainScene) {

        this.scene = scene;
        os = ceramic.App.app.backend.info.operatingSystem();

        final screen = ceramic.App.app.screen;
        final input = ceramic.App.app.input;
        screen.onMouseScroll(scene, (dx, dy, unit) -> scrolls.push('${MainScene.fmt(dx)} ${MainScene.fmt(dy)} ${unit == ScrollUnit.LINES ? 'LINES' : 'PIXELS'}'));
        screen.onMouseWheel(scene, (x, y) -> wheels.push('${MainScene.fmt(x)} ${MainScene.fmt(y)}'));
        input.onKeyDown(scene, key -> {
            keyDowns.push(key.scanCode);
            order.push('down ' + key.scanCodeName);
        });
        input.onKeyUp(scene, key -> keyUps.push(key.scanCode));
        input.onTextCommit(scene, text -> {
            texts.push(text);
            order.push('text ' + text);
        });
        input.onTextComposition(scene, (text, start, length) -> compositions.push('$text $start $length'));
        screen.onTouchDown(scene, (index, x, y) -> touches.push('down $index'));
        screen.onTouchUp(scene, (index, x, y) -> touches.push('up $index'));
        screen.onTouchCancel(scene, (index, x, y) -> touches.push('cancel $index'));
        screen.onWindowFocusChange(scene, focused -> focusEvents.push(focused ? 'focused' : 'unfocused'));
        final app = ceramic.App.app;
        app.onBeginEnterBackground(scene, () -> lifecycle.push('beginEnterBackground'));
        app.onFinishEnterBackground(scene, () -> lifecycle.push('finishEnterBackground'));
        app.onBeginEnterForeground(scene, () -> lifecycle.push('beginEnterForeground'));
        app.onFinishEnterForeground(scene, () -> lifecycle.push('finishEnterForeground'));

        print('unity-input self test, operating system: $os');
        untyped __cs__('global::haxe.root.UnityInputSelfTest.setupDevices()');

        addSteps();
        // Let the backend bind the new keyboard and the GPUI window draw once
        ceramic.Timer.delay(scene, 0.3, nextStep);

    }

    function nextStep():Void {

        if (steps.length == 0) {
            finish();
            return;
        }
        final step = steps.shift();
        var wait = 0.0;
        try {
            wait = step();
        }
        catch (e:Dynamic) {
            check(false, 'step error: $e');
        }
        ceramic.Timer.delay(scene, wait, nextStep);

    }

    function addSteps():Void {

        final mac = os == 'mac';
        final scale = os == 'windows' ? 120.0 : 1.0;

        steps.push(() -> {
            check(untyped __cs__('global::haxe.root.UnityInputSelfTest.devicesAreCurrent()'), 'virtual mouse and keyboard are current');
            final density = ceramic.App.app.backend.screen.getDensity();
            final pixelHeight = ceramic.App.app.backend.screen.getHeight() * density;
            mouseX = ceramic.App.app.backend.screen.getWidth() * density * 0.5;
            mouseY = pixelHeight * 0.5;
            final lineHeight:Float = (scene.window.lineHeight() : Float);
            print('line height $lineHeight, screen ${ceramic.App.app.backend.screen.getWidth()} x ${ceramic.App.app.backend.screen.getHeight()} density $density');
            print('key repeat of the system: delay ${backend.KeyRepeatSettings.delay()} s, interval ${backend.KeyRepeatSettings.interval()} s');
            // Two events in one frame: one mouseScroll each, one mouseWheel for the frame
            queueScroll(0, -1 * scale);
            queueScroll(0, -2 * scale);
            0.2;
        });

        // GPUI: list offset after two notches down (lines times the line height)
        var offsetBefore:Float = 0;
        steps.push(() -> {
            final lineHeight:Float = (scene.window.lineHeight() : Float);
            final offset:Float = scene.view.list.offset().y;
            checkEquals('0 1 LINES|0 2 LINES', scrolls.join('|'), 'mouseScroll per event, lines');
            checkEquals('0 -3', wheels.join('|'), 'one mouseWheel for the frame (Unity sign, notches)');
            checkFloat(-3 * lineHeight, offset, 'GPUI list offset after 3 lines');
            offsetBefore = offset;
            scrolls = [];
            wheels = [];
            // A precise device on macOS: fractional value
            queueScroll(0, -0.25 * scale);
            0.2;
        });

        steps.push(() -> {
            final lineHeight:Float = (scene.window.lineHeight() : Float);
            final offset:Float = scene.view.list.offset().y;
            if (mac) {
                checkEquals('0 2.5 PIXELS', scrolls.join('|'), 'fractional value on macOS: pixels times 10');
                checkFloat(offsetBefore - 2.5, offset, 'GPUI list offset after 2.5 pixels');
            }
            else {
                checkEquals('0 0.25 LINES', scrolls.join('|'), 'fractional value: lines');
                checkFloat(offsetBefore - 0.25 * lineHeight, offset, 'GPUI list offset after 0.25 line');
            }
            checkEquals('', wheels.join('|'), 'no mouseWheel below one notch');
            scrolls = [];
            // Whole value less than 0.5 s after the precise one
            queueScroll(0, -1 * scale);
            0.8;
        });

        steps.push(() -> {
            checkEquals(mac ? '0 10 PIXELS' : '0 1 LINES', scrolls.join('|'), 'whole value within 0.5 s of a precise one');
            checkEquals('0 -1', wheels.join('|'), 'mouseWheel keeps the fraction of the previous frames');
            scrolls = [];
            wheels = [];
            // More than 0.5 s later: a notched wheel again; and a horizontal event
            queueScroll(0, -1 * scale);
            queueScroll(3 * scale, 0);
            0.2;
        });

        steps.push(() -> {
            checkEquals('0 1 LINES|3 0 LINES', scrolls.join('|'), 'whole values after 0.5 s: lines; horizontal');
            checkEquals('3 -1', wheels.join('|'), 'mouseWheel of the frame');
            scrolls = [];
            wheels = [];
            // Scroll up: the legacy wheel is symmetric now (floor gave -1 for -0.3)
            queueScroll(0, 0.3 * scale);
            0.2;
        });

        steps.push(() -> {
            checkEquals('', wheels.join('|'), 'no mouseWheel for 0.3 notch up');
            wheels = [];
            scrolls = [];

            // Key repeat, fast settings for the test
            final keyRepeat = @:privateAccess ceramic.App.app.backend.input.keyRepeat;
            keyRepeat.delay = 0.3;
            keyRepeat.interval = 0.05;
            keyDowns = [];
            keyUps = [];
            queueKeys('LeftArrow');
            0.7;
        });

        steps.push(() -> {
            final downs = count(keyDowns, ScanCode.LEFT);
            print('left arrow held 0.7 s: $downs key downs');
            check(downs >= 4 && downs <= 12, 'held left arrow repeats (delay 0.3 s, interval 0.05 s): $downs key downs');
            check(count(keyUps, ScanCode.LEFT) == 0, 'no key up while held');
            queueKeys('');
            0.1;
        });

        steps.push(() -> {
            check(count(keyUps, ScanCode.LEFT) == 1, 'one key up');
            keyDowns = [];
            0.4;
        });

        steps.push(() -> {
            check(count(keyDowns, ScanCode.LEFT) == 0, 'no repeat after the release');
            // A modifier never repeats; a key pressed while it is held does
            queueKeys('LeftShift');
            0.5;
        });

        steps.push(() -> {
            check(count(keyDowns, ScanCode.LSHIFT) == 1, 'shift held 0.5 s: one key down only (${count(keyDowns, ScanCode.LSHIFT)})');
            queueKeys('LeftShift,A');
            0.5;
        });

        steps.push(() -> {
            check(count(keyDowns, ScanCode.KEY_A) >= 2, 'A held with shift repeats (${count(keyDowns, ScanCode.KEY_A)})');
            queueKeys('');
            0.1;
        });

        steps.push(() -> {
            keyDowns = [];
            keyUps = [];
            @:privateAccess ceramic.App.app.backend.input.keyRepeat.delay = 0.5;
            // Text: emoji as one UTF-32 event, then as two surrogate events
            ceramic.App.app.input.startTextEditing(10, 10, 100, 20);
            order = [];
            texts = [];
            queueKeys('B');
            queueText('b'.code);
            queueText(0x1F600);
            queueTextUnit(0xD83D);
            queueTextUnit(0xDE01);
            queueTextUnit(0xE9);
            0.2;
        });

        steps.push(() -> {
            checkEquals('b|${String.fromCharCode(0x1F600)}|${String.fromCharCode(0x1F601)}|${String.fromCharCode(0xE9)}', texts.join('|'), 'text commits, emoji joined');
            checkEquals('down B', order.length > 0 ? order[0] : '', 'key down before the text of the same frame');
            queueKeys('');
            // IME composition then commit
            compositions = [];
            texts = [];
            queueComposition('ni');
            queueComposition('にほ');
            queueComposition('');
            queueText(0x65E5);
            0.2;
        });

        steps.push(() -> {
            checkEquals('ni 2 0|にほ 2 0| 0 0', compositions.join('|'), 'IME composition');
            checkEquals('日', texts.join('|'), 'IME commit');
            ceramic.App.app.input.stopTextEditing();
            compositions = [];
            texts = [];
            queueComposition('x');
            queueText('c'.code);
            0.2;
        });

        steps.push(() -> {
            checkEquals('', compositions.join('|') + texts.join('|'), 'no text events without text editing');

            // Clipboard through the system clipboard
            final clipboard = ceramic.App.app.backend.clipboard;
            final previous = clipboard.getText();
            final value = 'ceramic unity clipboard ${String.fromCharCode(0x1F600)} ${Std.random(100000)}';
            clipboard.setText(value);
            checkEquals(value, clipboard.getText(), 'clipboard text read back');
            checkEquals(value, untyped __cs__('global::haxe.root.UnityInputSelfTest.systemClipboard()'), 'GUIUtility.systemCopyBuffer holds the text');
            clipboard.setText(previous != null ? previous : '');

            // Touch down then cancel
            touches = [];
            queueTouch(1, 1, 100, 100);
            0.2;
        });

        steps.push(() -> {
            queueTouch(1, 4, 100, 100);
            0.2;
        });

        steps.push(() -> {
            checkEquals('down 0|cancel 0|up 0', touches.join('|'), 'touch down then cancel (Ceramic ends it with an up)');
            0.0;
        });

        addFocusSteps();
        addKeyboardSteps();

    }

    inline function sendLifecycle(name:String, value:Bool):Void {

        untyped __cs__('global::haxe.root.UnityInputSelfTest.csSendLifecycle({0}, {1})', name, value);

    }

    function addFocusSteps():Void {

        final backendScreen = ceramic.App.app.backend.screen;
        final screen = ceramic.App.app.screen;

        steps.push(() -> {
            check(untyped __cs__('global::haxe.root.UnityInputSelfTest.csHasLifecycle()'), 'UnityLifecycle component on the Ceramic game object');
            check(screen.windowFocused, 'window focused in batch mode');
            check(scene.window.isWindowActive(), 'GPUI window active');
            checkEquals('', focusEvents.join('|'), 'no focus event from Unity in batch mode');
            // Unity's messages are ignored in batch mode unless asked for
            sendLifecycle('OnApplicationFocus', false);
            0.2;
        });

        steps.push(() -> {
            checkEquals('', focusEvents.join('|'), 'OnApplicationFocus ignored in batch mode by default');
            backendScreen.applicationFocusInBatchMode = true;
            sendLifecycle('OnApplicationFocus', false);
            0.2;
        });

        steps.push(() -> {
            checkEquals('unfocused', focusEvents.join('|'), 'OnApplicationFocus(false): windowFocusChange(false)');
            check(!screen.windowFocused && !backendScreen.isWindowFocused(), 'window not focused');
            check(!scene.window.isWindowActive(), 'GPUI window deactivated');
            // The same message again changes nothing
            sendLifecycle('OnApplicationFocus', false);
            0.2;
        });

        steps.push(() -> {
            checkEquals('unfocused', focusEvents.join('|'), 'no event without a change');
            sendLifecycle('OnApplicationFocus', true);
            0.2;
        });

        steps.push(() -> {
            checkEquals('unfocused|focused', focusEvents.join('|'), 'OnApplicationFocus(true): windowFocusChange(true)');
            check(screen.windowFocused, 'window focused again');
            check(scene.window.isWindowActive(), 'GPUI window active again');
            // Desktop: a pause is not a background state
            focusEvents = [];
            lifecycle = [];
            backendScreen.pauseMeansBackground = false;
            sendLifecycle('OnApplicationPause', true);
            0.2;
        });

        steps.push(() -> {
            checkEquals('', focusEvents.join('|') + lifecycle.join('|'), 'desktop: OnApplicationPause ignored');
            sendLifecycle('OnApplicationPause', false);
            // Mobile: background
            backendScreen.pauseMeansBackground = true;
            sendLifecycle('OnApplicationPause', true);
            0.2;
        });

        steps.push(() -> {
            checkEquals('beginEnterBackground|finishEnterBackground', lifecycle.join('|'), 'mobile: OnApplicationPause(true) enters background');
            checkEquals('unfocused', focusEvents.join('|'), 'mobile: not focused in background');
            check(!scene.window.isWindowActive(), 'GPUI window deactivated in background');
            lifecycle = [];
            sendLifecycle('OnApplicationPause', false);
            0.2;
        });

        steps.push(() -> {
            checkEquals('beginEnterForeground|finishEnterForeground', lifecycle.join('|'), 'mobile: OnApplicationPause(false) enters foreground');
            checkEquals('unfocused|focused', focusEvents.join('|'), 'mobile: focused in foreground');
            check(scene.window.isWindowActive(), 'GPUI window active in foreground');
            backendScreen.pauseMeansBackground = false;
            focusEvents = [];
            lifecycle = [];
            0.0;
        });

    }

    var keyboard:FakeVirtualKeyboard = null;

    var keyboardWindow:Window = null;

    var keyboardInput:Entity<InputState> = null;

    function inputValue():String {

        return keyboardInput.read(gpui.App.current).value();

    }

    function inputFocused():Bool {

        return keyboardInput.read(gpui.App.current).focusHandle.isFocused(keyboardWindow);

    }

    function addKeyboardSteps():Void {

        final textInput = ceramic.App.app.backend.textInput;
        final backendScreen = ceramic.App.app.backend.screen;
        final screen = ceramic.App.app.screen;
        final grin = String.fromCharCode(0x1F600);
        var opensBefore = 0;

        steps.push(() -> {
            check(textInput.virtualKeyboard == null, 'no TouchScreenKeyboard on desktop');
            keyboard = new FakeVirtualKeyboard();
            textInput.virtualKeyboard = keyboard;
            // A gpui-kit input in a second window
            final cx = gpui.App.current;
            gpui.component.Component.init(cx);
            keyboardWindow = Window.open(cx, {width: 400, height: 60}, (window, cx) -> {
                return cx.newEntity((rootCx:Context<Root>) -> {
                    final content = rootCx.newEntity((viewCx:Context<KeyboardView>) -> {
                        final view = new KeyboardView();
                        keyboardInput = viewCx.newEntity((inputCx:Context<InputState>) -> new InputState(window, inputCx));
                        view.input = keyboardInput;
                        return view;
                    });
                    return new Root(content, window, rootCx);
                });
            });
            scene.add(keyboardWindow.renderable);
            keyboardWindow.renderable.depth = 10;
            gpui.GpuiInput.activateWindow(keyboardWindow);
            0.3;
        });

        steps.push(() -> {
            check(!textInput.keyboardOpen, 'keyboard closed before the focus');
            keyboardInput.read(gpui.App.current).focusHandle.focus(keyboardWindow, gpui.App.current);
            0.4;
        });

        steps.push(() -> {
            print('virtual keyboard opens: ${keyboard.opens.join(', ')}');
            check(ceramic.App.app.input.textEditing, 'text editing started by the focused input');
            check(textInput.keyboardOpen, 'keyboard open');
            checkEquals('DEFAULT single', keyboard.opens.join(', '), 'one open, keyboard of a single line input (Done key)');
            check(screen.windowFocused, 'window focused with the keyboard');
            texts = [];
            keyDowns = [];
            keyboard.type('h');
            keyboard.type('i');
            0.2;
        });

        steps.push(() -> {
            checkEquals('hi', texts.join(''), 'typed text committed');
            checkEquals('hi', inputValue(), 'typed text in the input');
            keyboard.backspace();
            0.2;
        });

        steps.push(() -> {
            check(count(keyDowns, ScanCode.BACKSPACE) == 1, 'one backspace key');
            checkEquals('h', inputValue(), 'backspace in the input');
            keyboard.type(grin);
            0.2;
        });

        steps.push(() -> {
            checkEquals('h' + grin, inputValue(), 'emoji in the input');
            keyDowns = [];
            keyboard.moveCaret(-2);
            0.2;
        });

        steps.push(() -> {
            check(count(keyDowns, ScanCode.LEFT) == 1, 'caret moved over the emoji: one left key (${count(keyDowns, ScanCode.LEFT)})');
            keyboard.type('X');
            0.2;
        });

        steps.push(() -> {
            checkEquals('hX' + grin, inputValue(), 'typed at the moved caret');
            keyboard.moveCaret(2);
            keyboard.type('teh');
            0.2;
        });

        steps.push(() -> {
            checkEquals('hX' + grin + 'teh', inputValue(), 'caret back at the end');
            keyboard.replaceBefore(3, 'the ');
            0.2;
        });

        steps.push(() -> {
            checkEquals('hX' + grin + 'the ', inputValue(), 'autocorrection replaced the word');
            // Android: the keyboard takes the focus of the app
            focusEvents = [];
            backendScreen.applicationFocusInBatchMode = true;
            sendLifecycle('OnApplicationFocus', false);
            0.2;
        });

        steps.push(() -> {
            checkEquals('', focusEvents.join('|'), 'focus loss while the keyboard is visible: no event');
            check(keyboardWindow.isWindowActive(), 'GPUI window still active');
            check(inputFocused(), 'input still focused');
            sendLifecycle('OnApplicationFocus', true);
            keyDowns = [];
            // The return key of a single line keyboard
            keyboard.status = DONE;
            0.2;
        });

        steps.push(() -> {
            check(count(keyDowns, ScanCode.ENTER) == 1, 'return key: one enter key');
            check(!textInput.keyboardOpen, 'keyboard closed by its return key');
            check(ceramic.App.app.input.textEditing, 'text editing still active');
            checkEquals('', focusEvents.join('|'), 'still focused after the keyboard closed');
            // A tap on the input opens it again
            opensBefore = keyboard.opens.length;
            final density = backendScreen.getDensity();
            final pixelHeight = backendScreen.getHeight() * density;
            queueTouch(2, 1, 100 * density, pixelHeight - 30 * density);
            0.1;
        });

        steps.push(() -> {
            final density = backendScreen.getDensity();
            final pixelHeight = backendScreen.getHeight() * density;
            queueTouch(2, 3, 100 * density, pixelHeight - 30 * density);
            0.3;
        });

        steps.push(() -> {
            check(keyboard.opens.length == opensBefore + 1 && textInput.keyboardOpen, 'tap on the input opens the keyboard again');
            checkEquals('hX' + grin + 'the ', inputValue(), 'input unchanged by the tap');
            keyboardWindow.blur();
            0.3;
        });

        steps.push(() -> {
            check(!ceramic.App.app.input.textEditing, 'text editing stopped by the blur');
            check(!textInput.keyboardOpen && keyboard.status == CLOSED, 'keyboard closed by the blur');
            textInput.virtualKeyboard = null;
            backendScreen.applicationFocusInBatchMode = false;
            0.0;
        });

    }

    function finish():Void {

        untyped __cs__('global::haxe.root.UnityInputSelfTest.removeDevices()');
        print('$checks checks, $failures failed');
        untyped __cs__('global::haxe.root.UnityInputSelfTest.exitWith({0})', failures == 0 ? 0 : 1);

    }

    inline function queueScroll(x:Float, y:Float):Void {

        untyped __cs__('global::haxe.root.UnityInputSelfTest.csQueueScroll({0}, {1}, {2}, {3})', mouseX, mouseY, x, y);

    }

    inline function queueKeys(names:String):Void {

        untyped __cs__('global::haxe.root.UnityInputSelfTest.csQueueKeys({0})', names);

    }

    inline function queueText(code:Int):Void {

        untyped __cs__('global::haxe.root.UnityInputSelfTest.csQueueText({0})', code);

    }

    inline function queueTextUnit(unit:Int):Void {

        untyped __cs__('global::haxe.root.UnityInputSelfTest.csQueueTextUnit({0})', unit);

    }

    inline function queueComposition(text:String):Void {

        untyped __cs__('global::haxe.root.UnityInputSelfTest.csQueueComposition({0})', text);

    }

    inline function queueTouch(touchId:Int, phase:Int, x:Float, y:Float):Void {

        untyped __cs__('global::haxe.root.UnityInputSelfTest.csQueueTouch({0}, {1}, {2}, {3})', touchId, phase, x, y);

    }

    static function count(values:Array<Int>, value:Int):Int {

        var n = 0;
        for (v in values) if (v == value) n++;
        return n;

    }

    function check(ok:Bool, label:String):Void {

        checks++;
        if (ok) {
            print('ok   $label');
        }
        else {
            failures++;
            print('FAIL $label');
        }

    }

    function checkEquals(expected:String, actual:String, label:String):Void {

        check(expected == actual, expected == actual ? label : '$label: expected ${haxe.Json.stringify(expected)}, got ${haxe.Json.stringify(actual)}');

    }

    function checkFloat(expected:Float, actual:Float, label:String):Void {

        final ok = Math.abs(expected - actual) < 0.001;
        check(ok, ok ? label : '$label: expected $expected, got $actual');

    }

    inline function print(line:String):Void {

        MainScene.print(line);

    }

}

/**
 * A gpui-kit input, for the virtual keyboard steps.
 */
class KeyboardView extends Model implements Render {

    public var input:Entity<InputState> = null;

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {

        return div().sizeFull().p2().bg(hsla(0, 0, 1, 1)).child(new Input(input));

    }

}

#end
